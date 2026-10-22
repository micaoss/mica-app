import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'framing.dart';
import 'keys.dart';
import 'spake2.dart';

/// A byte pipe to the device: the GATT characteristics, or a fake in tests.
abstract interface class Link {
  Stream<List<int>> get incoming;

  /// The largest chunk [write] accepts.
  int get chunkSize;

  Future<void> write(Uint8List chunk);

  Future<void> close();
}

sealed class Credential {
  const Credential();
}

final class PinCredential extends Credential {
  const PinCredential(this.pin);
  final String pin;
}

final class PhoneCredential extends Credential {
  const PhoneCredential(this.phone, this.secret);
  final String phone;
  final Uint8List secret;
}

class ProtocolException implements Exception {
  const ProtocolException(this.code, [this.message = '', this.retryAfter]);

  final String code;
  final String message;

  /// Seconds to wait, for `backoff`.
  final int? retryAfter;

  @override
  String toString() => 'ProtocolException($code${message.isEmpty ? '' : ': $message'})';
}

class DeviceHello {
  const DeviceHello({required this.deviceId, required this.name, required this.pinSet});

  final String deviceId;
  final String name;
  final bool pinSet;
}

class ApiResponse {
  const ApiResponse(this.status, this.body);

  final int status;
  final Object? body;

  bool get ok => status >= 200 && status < 300;

  /// The error code of a failed response, if it carries one.
  String? get code => body is Map ? (body as Map)['code'] as String? : null;
}

const defaultTimeout = Duration(seconds: 20);

/// Messages over a [Link]: framing on the way out, reassembly on the way in.
class _Pipe {
  _Pipe(this.link) {
    _subscription = link.incoming.listen(_onChunk, onError: _fail, onDone: () => _fail(null));
  }

  final Link link;
  late final StreamSubscription<List<int>> _subscription;
  final _deframer = Deframer();
  final _queue = Queue<Uint8List>();
  final _waiters = Queue<Completer<Uint8List>>();
  Object? _closed;

  void _onChunk(List<int> chunk) {
    try {
      for (final message in _deframer.add(chunk)) {
        if (_waiters.isNotEmpty) {
          _waiters.removeFirst().complete(message);
        } else {
          _queue.add(message);
        }
      }
    } on FormatException catch (e) {
      _fail(e);
    }
  }

  void _fail(Object? error) {
    _closed = error ?? const ProtocolException('closed', 'the device closed the connection');
    while (_waiters.isNotEmpty) {
      _waiters.removeFirst().completeError(_closed!);
    }
  }

  Future<Uint8List> next(Duration timeout) {
    if (_queue.isNotEmpty) return Future.value(_queue.removeFirst());
    if (_closed != null) return Future.error(_closed!);
    final waiter = Completer<Uint8List>();
    _waiters.add(waiter);
    return waiter.future.timeout(timeout, onTimeout: () {
      _waiters.remove(waiter);
      throw const ProtocolException('timeout', 'the device did not answer');
    });
  }

  Future<void> _sending = Future.value();

  /// Send one message; messages go out whole and in call order.
  Future<void> send(List<int> message) {
    final framed = frame(message);
    final done = _sending.then((_) async {
      for (final chunk in chunks(framed, link.chunkSize)) {
        await link.write(chunk);
      }
    });
    _sending = done.catchError((_) {});
    return done;
  }

  Future<void> close() async {
    if (_closed == null) _fail(const ProtocolException('closed', 'the connection was closed'));
    await _subscription.cancel();
    await link.close();
  }
}

Map<String, dynamic> _decode(Uint8List message) {
  final value = jsonDecode(utf8.decode(message));
  if (value is! Map<String, dynamic>) throw const ProtocolException('bad-request', 'not an object');
  return value;
}

Uint8List _encode(Map<String, Object?> value) => utf8.encode(jsonEncode(value));

/// A connection after hello, before authentication.
class Connection {
  Connection._(this._pipe, this.hello, this.timeout);

  final _Pipe _pipe;
  final DeviceHello hello;
  final Duration timeout;

  /// Say hello over [link].
  static Future<Connection> open(Link link, {Duration timeout = defaultTimeout}) async {
    final pipe = _Pipe(link);
    try {
      await pipe.send(_encode({'t': 'hello', 'v': protocolVersion}));
      final answer = await _expect(pipe, 'hello', timeout);
      if (answer['v'] != protocolVersion) {
        throw const ProtocolException('bad-version', 'the device speaks another version');
      }
      return Connection._(
        pipe,
        DeviceHello(
          deviceId: answer['device'] as String,
          name: answer['name'] as String? ?? '',
          pinSet: answer['pinSet'] as bool,
        ),
        timeout,
      );
    } catch (_) {
      await pipe.close();
      rethrow;
    }
  }

  /// Run SPAKE2 with [credential]. Throws [ProtocolException]; after
  /// `backoff` the connection may be authenticated again.
  Future<Session> authenticate(Credential credential) async {
    final (idA, secret) = switch (credential) {
      PinCredential(:final pin) => ('pin', utf8.encode(pin)),
      PhoneCredential(:final phone, :final secret) => ('phone:$phone', secret),
    };
    final spake = Spake2.a(
      utf8.encode(idA),
      utf8.encode(hello.deviceId),
      passwordScalar(hello.deviceId, secret),
    );
    await _pipe.send(_encode({
      't': 'auth',
      ...switch (credential) {
        PinCredential() => {'kind': 'pin'},
        PhoneCredential(:final phone) => {'kind': 'phone', 'phone': phone},
      },
      'pA': base64.encode(spake.message),
    }));
    final answer = await _expect(_pipe, 'auth', timeout);
    final keys = spake.finish(base64.decode(answer['pB'] as String), aad: utf8.encode(spakeAad));
    await _pipe.send(_encode({'t': 'confirm', 'cA': base64.encode(keys.confirmation)}));
    final confirm = await _expect(_pipe, 'confirm', timeout);
    if (!keys.verify(base64.decode(confirm['cB'] as String))) {
      await _pipe.close();
      throw const ProtocolException('impostor', 'the device could not prove the secret');
    }
    final session = sessionKeys(keys.ke);
    return Session._(
      _pipe,
      hello,
      confirm['scope'] as String,
      Sealer(session.phoneToDevice),
      Sealer(session.deviceToPhone),
      timeout,
    );
  }

  Future<void> close() => _pipe.close();
}

Future<Map<String, dynamic>> _expect(_Pipe pipe, String type, Duration timeout) async {
  final message = _decode(await pipe.next(timeout));
  if (message['t'] == 'error') {
    throw ProtocolException(
      message['code'] as String? ?? 'error',
      message['message'] as String? ?? '',
      message['retryAfter'] as int?,
    );
  }
  if (message['t'] != type) {
    throw ProtocolException('bad-request', 'expected $type, got ${message['t']}');
  }
  return message;
}

/// An authenticated, sealed session.
class Session {
  Session._(this._pipe, this.hello, this._scope, this._out, this._in, this.timeout) {
    unawaited(_receive());
  }

  final _Pipe _pipe;
  final DeviceHello hello;
  final Sealer _out, _in;
  final Duration timeout;
  final _pending = <int, Completer<ApiResponse>>{};
  var _nextId = 1;
  String _scope;
  final _closed = Completer<Object>();

  /// `full`, or `pin-change` while the device's PIN is unset.
  String get scope => _scope;

  /// Completes with the reason when the session ends.
  Future<Object> get closed => _closed.future;

  Future<void> _receive() async {
    try {
      while (true) {
        final message = _decode(_in.open(await _pipe.next(const Duration(days: 1))));
        if (message['t'] != 'res') continue;
        _pending.remove(message['id'])?.complete(ApiResponse(message['status'] as int, message['body']));
      }
    } catch (e) {
      final reason = e is ProtocolException ? e : ProtocolException('closed', '$e');
      for (final waiter in _pending.values) {
        waiter.completeError(reason);
      }
      _pending.clear();
      if (!_closed.isCompleted) _closed.complete(reason);
    }
  }

  Future<ApiResponse> request(String method, String path, [Object? body]) async {
    if (_closed.isCompleted) throw await _closed.future;
    final id = _nextId++;
    final waiter = Completer<ApiResponse>();
    _pending[id] = waiter;
    await _pipe.send(_out.seal(_encode({'t': 'req', 'id': id, 'method': method, 'path': path, 'body': ?body})));
    final response = await waiter.future.timeout(timeout, onTimeout: () {
      _pending.remove(id);
      throw const ProtocolException('timeout', 'the device did not answer');
    });
    return response;
  }

  /// Set the device's PIN; widens a `pin-change` session to `full`.
  Future<ApiResponse> setPin(String pin) async {
    final response = await request('PUT', '/ble/pin', {'pin': pin});
    if (response.ok) _scope = 'full';
    return response;
  }

  Future<void> close() => _pipe.close();
}
