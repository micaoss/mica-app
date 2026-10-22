import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:mica_app/protocol/client.dart';
import 'package:mica_app/protocol/framing.dart';
import 'package:mica_app/protocol/keys.dart';
import 'package:mica_app/protocol/spake2.dart';

/// The phone's end of an in-memory link to a [FakeDevice].
class MemoryLink implements Link {
  MemoryLink(this._toDevice, this._fromDevice, this.chunkSize);

  final StreamController<List<int>> _toDevice;
  final Stream<List<int>> _fromDevice;

  @override
  final int chunkSize;

  @override
  Stream<List<int>> get incoming => _fromDevice;

  @override
  Future<void> write(Uint8List chunk) async {
    if (chunk.length > chunkSize) throw StateError('chunk too large');
    if (!_toDevice.isClosed) _toDevice.add(chunk);
  }

  @override
  Future<void> close() async {
    await _toDevice.close();
  }
}

typedef Handler = ({int status, Object? body}) Function(String method, String path, Object? body);

/// The device side of the protocol, as `mica-bled` is specified to behave.
class FakeDevice {
  FakeDevice({this.deviceId = '00112233445566778899aabbccddeeff', this.pin = '000000'});

  final String deviceId;
  String pin;
  final phones = <String, ({String name, Uint8List secret})>{};
  final routes = <String, Handler>{};
  int failures = 0;
  final requests = <String>[];

  bool get pinSet => pin != '000000';

  /// A link to a fresh connection.
  MemoryLink connect({int chunkSize = 20}) {
    final toDevice = StreamController<List<int>>();
    final fromDevice = StreamController<List<int>>();
    _Connection(this, toDevice.stream, fromDevice, chunkSize);
    return MemoryLink(toDevice, fromDevice.stream, chunkSize);
  }
}

class _Connection {
  _Connection(this.device, Stream<List<int>> input, this._output, this.chunkSize) {
    input.listen(_onChunk, onDone: _output.close);
  }

  final FakeDevice device;
  final StreamController<List<int>> _output;
  final int chunkSize;
  final _deframer = Deframer();
  Spake2? _spake;
  Spake2Keys? _keys;
  String? _phone;
  Sealer? _in, _out;
  String? scope;

  void _send(List<int> message) {
    for (final chunk in chunks(frame(message), chunkSize)) {
      _output.add(chunk);
    }
  }

  void _json(Map<String, Object?> value) => _send(utf8.encode(jsonEncode(value)));

  void _error(String code, {int? retryAfter, bool close = true}) {
    _json({'t': 'error', 'code': code, 'retryAfter': ?retryAfter});
    if (close) _output.close();
  }

  void _onChunk(List<int> chunk) {
    try {
      _dispatch(chunk);
    } catch (_) {
      // A device that fails drops the connection.
      _output.close();
    }
  }

  void _dispatch(List<int> chunk) {
    for (final message in _deframer.add(chunk)) {
      if (_in != null) {
        _request(jsonDecode(utf8.decode(_in!.open(message))) as Map<String, dynamic>);
      } else {
        _handshake(jsonDecode(utf8.decode(message)) as Map<String, dynamic>);
      }
    }
  }

  void _handshake(Map<String, dynamic> m) {
    switch (m['t']) {
      case 'hello':
        if (m['v'] != protocolVersion) return _error('bad-version');
        _json({'t': 'hello', 'v': 1, 'device': device.deviceId, 'name': 'mica-test', 'pinSet': device.pinSet});
      case 'auth':
        if (device.failures > 0) {
          return _error('backoff', retryAfter: min(1 << (device.failures - 1), 300), close: false);
        }
        final List<int> secret;
        final String idA;
        if (m['kind'] == 'pin') {
          secret = utf8.encode(device.pin);
          idA = 'pin';
        } else {
          final phone = device.phones[m['phone']];
          // An unknown phone runs against a random secret so it fails at confirm.
          secret = phone?.secret ?? Uint8List(32);
          _phone = m['phone'] as String;
          idA = 'phone:$_phone';
        }
        _spake = Spake2.b(utf8.encode(idA), utf8.encode(device.deviceId),
            passwordScalar(device.deviceId, secret));
        _keys = _spake!.finish(base64.decode(m['pA'] as String), aad: utf8.encode(spakeAad));
        _json({'t': 'auth', 'pB': base64.encode(_spake!.message)});
      case 'confirm':
        if (!_keys!.verify(base64.decode(m['cA'] as String))) {
          device.failures++;
          return _error('auth-failed');
        }
        device.failures = 0;
        scope = device.pinSet || _phone != null ? 'full' : 'pin-change';
        _json({'t': 'confirm', 'cB': base64.encode(_keys!.confirmation), 'scope': scope});
        final session = sessionKeys(_keys!.ke);
        _in = Sealer(session.phoneToDevice);
        _out = Sealer(session.deviceToPhone);
      default:
        _error('bad-request');
    }
  }

  void _request(Map<String, dynamic> m) {
    final method = m['method'] as String;
    final path = m['path'] as String;
    device.requests.add('$method $path');
    final (status, body) = _answer(method, path, m['body']);
    _send(_out!.seal(utf8.encode(jsonEncode({'t': 'res', 'id': m['id'], 'status': status, 'body': ?body}))));
  }

  (int, Object?) _answer(String method, String path, Object? body) {
    if (scope == 'pin-change' && !(method == 'PUT' && path == '/ble/pin')) {
      return (403, {'code': 'pin-unset', 'message': 'set a PIN first'});
    }
    switch ((method, path)) {
      case ('PUT', '/ble/pin'):
        final pin = (body as Map)['pin'] as String;
        if (!RegExp(r'^\d{6}$').hasMatch(pin) || pin == '000000') {
          return (400, {'code': 'bad-pin', 'message': 'six digits, not 000000'});
        }
        device.pin = pin;
        scope = 'full';
        return (204, null);
      case ('POST', '/ble/phones'):
        final id = 'p${device.phones.length + 1}';
        final secret = Uint8List.fromList(List.generate(32, (i) => i + device.phones.length));
        device.phones[id] = (name: (body as Map)['name'] as String, secret: secret);
        return (201, {'phone': id, 'secret': base64.encode(secret)});
      case ('GET', '/ble/phones'):
        return (200, [
          for (final e in device.phones.entries)
            {'phone': e.key, 'name': e.value.name, 'created': 0, 'current': e.key == _phone}
        ]);
    }
    if (method == 'DELETE' && path.startsWith('/ble/phones/')) {
      device.phones.remove(path.substring('/ble/phones/'.length));
      return (204, null);
    }
    final handler = device.routes['$method $path'];
    if (handler == null) return (403, {'code': 'not-allowed', 'message': path});
    final r = handler(method, path, body);
    return (r.status, r.body);
  }
}
