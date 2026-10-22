// A mica device's end of protocol 1, for tests: the characteristics'
// behaviour, the session state machine and the operations, written from
// mica-core docs/ble-provisioning.md and not from the app's client. The
// primitives come from the app's crypto.dart, which the vector tests check.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mica_app/protocol/bytes.dart';
import 'package:mica_app/protocol/client.dart';
import 'package:mica_app/protocol/crypto.dart';
import 'package:mica_app/protocol/fragments.dart';

import 'verifier.dart';

typedef Json = Map<String, dynamic>;

class WifiRouter {
  const WifiRouter(this.psk, {this.fail, this.ip = '192.168.1.57'});

  final String psk;

  /// A failure reason to answer instead of connecting.
  final String? fail;
  final String ip;
}

final _hostname = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$', caseSensitive: false);
final _psk = RegExp(r'^(?:[\x20-\x7E]{8,63}|[0-9a-fA-F]{64})$');

class MockDevice {
  MockDevice({
    this.protocol = 1,
    this.model = 'mica cx3576',
    String hostname = 'mica-a4e2e69e',
    bool claimed = false,
    String? auth,
    this.ops = const ['getStatus', 'scanWifi', 'claim', 'setWifi', 'finish'],
    this.maxWrite = 20,
    this.notifySize = 20,
    String wifiMode = 'ap',
    this.networks = const [],
    this.routers = const {},
    this.secret = '',
    this.iterations = 10000,
    this.maxAttempts = 5,
    this.claimedElsewhere = false,
    this.busy = false,
    this.generatedApPsk = 'harbour-ap-key-7f3a',
    this.connectDelay = const Duration(milliseconds: 5),
  }) : _hostname0 = hostname,
       claimed = claimed,
       auth = auth ?? (claimed ? 'password' : 'none'),
       attemptsLeft = maxAttempts,
       wifi = (mode: wifiMode, connected: wifiMode == 'client', ssid: null, ip: null);

  final int protocol;
  final String model;
  final String _hostname0;
  final List<String> ops;
  final int maxWrite, notifySize;
  final List<Json> networks;
  final Map<String, WifiRouter> routers;

  /// The administrator password or the temp-code.
  final String secret;
  final int iterations, maxAttempts;

  /// Another channel claims the device before `finish`.
  final bool claimedElsewhere;

  /// Another phone holds the connection: GATT reads and writes are refused.
  final bool busy;
  final String generatedApPsk;
  final Duration connectDelay;

  /// `none`, `password`, `temp-code` or `password-unavailable`.
  String auth;
  bool claimed;
  late String hostname = _hostname0;
  int attemptsLeft;
  ({String mode, bool connected, String? ssid, String? ip}) wifi;

  /// Every decrypted command and every session message the phone sent.
  final commands = <Json>[];
  final sessionLog = <Json>[];
  int largestWrite = 0;
  ({String password, String? hostname, String? apPsk})? staged;

  MockTransport? _link;
  Reassembler _sessionIn = Reassembler(), _commandIn = Reassembler();
  String? _auth;
  VerifierRecord? _record;
  VerifierResponse? _spake;
  RecordCipher? _commandCipher, _eventCipher;
  bool _running = false;
  Future<void> _chain = Future.value();

  bool get connected => _link != null;

  /// A central connects; the transport is already subscribed.
  MockTransport connect() {
    final link = MockTransport._(this);
    _link = link;
    return link;
  }

  Uint8List info() => utf8Bytes(
    jsonEncode({
      'protocol': protocol,
      'model': model,
      'hostname': hostname,
      'claimed': claimed,
      'auth': auth,
      'ops': ops,
      'maxWrite': maxWrite,
    }),
  );

  /// The link went down, from either end.
  void _linkDown() {
    _link?._down();
    _link = null;
    staged = null;
    _auth = null;
    _commandCipher = _eventCipher = null;
    _sessionIn = Reassembler();
    _commandIn = Reassembler();
  }

  /// The device ends the session itself, as after `finish` or 2 minutes idle.
  Future<void> close([String? reason]) async {
    if (reason != null) await _event({'event': 'closing', 'reason': reason});
    _linkDown();
  }

  void _checkWrite(Uint8List f) {
    if (busy) throw StateError('org.bluez.Error.InProgress');
    if (f.length > maxWrite) throw StateError('write of ${f.length} bytes over maxWrite');
    if (f.length > largestWrite) largestWrite = f.length;
  }

  void _writeSession(Uint8List f) {
    _checkWrite(f);
    final m = _sessionIn.push(f);
    if (m != null) _serial(() => _onSession(jsonDecode(utf8.decode(m)) as Json));
  }

  void _writeCommand(Uint8List f) {
    _checkWrite(f);
    final m = _commandIn.push(f);
    if (m != null) _serial(() => _onCommand(m));
  }

  void _serial(Future<void> Function() fn) => _chain = _chain.then((_) => fn());

  Future<void> _notify(void Function(Uint8List) to, List<int> message) async {
    for (final f in fragment(message, notifySize)) {
      await Future<void>.delayed(Duration.zero);
      to(f);
    }
  }

  Future<void> _sendSession(Json m) async {
    final link = _link;
    if (link != null) await _notify(link._session.add, utf8.encode(jsonEncode(m)));
  }

  Future<void> _event(Json m) async {
    final link = _link, cipher = _eventCipher;
    if (link == null || cipher == null) return;
    await _notify(link._events.add, cipher.seal(utf8.encode(jsonEncode(m))));
  }

  Future<void> _keys(SessionKeys k) async {
    _commandCipher = RecordCipher(k.phoneToDevice);
    _eventCipher = RecordCipher(k.deviceToPhone);
  }

  Future<void> _onSession(Json m) async {
    sessionLog.add(m);
    Future<void> error(String reason, [Json extra = const {}]) =>
        _sendSession({'t': 'error', 'reason': reason, ...extra});
    switch (m['t']) {
      case 'start':
        _auth = null;
        _commandCipher = _eventCipher = null;
        if (auth == 'password-unavailable') return error('password_unavailable');
        if (m['auth'] != auth) return error('unsupported_auth');
        if (attemptsLeft <= 0) return error('locked', {'retryAfter': 600});
        if (auth == 'none') {
          final private = randomBytes(32);
          final devicePub = x25519(private, Uint8List(32)..[0] = 9);
          final phonePub = base64.decode(m['pub'] as String);
          final s = x25519(private, phonePub);
          final salt = sha256(concat([utf8Bytes('mica-provisioning/1 none'), phonePub, devicePub]));
          final k = hkdf(salt, s, 'mica-provisioning/1 session keys', 64);
          await _keys((phoneToDevice: k.sublist(0, 32), deviceToPhone: k.sublist(32)));
          _auth = 'none';
          return _sendSession({'t': 'ready', 'pub': base64.encode(devicePub)});
        }
        final salt = Uint8List.fromList(List.generate(16, (i) => i * 17));
        _record = VerifierRecord.register(secret, salt, iterations);
        _auth = auth;
        return _sendSession({'t': 'params', 'salt': base64.encode(salt), 'iterations': iterations});
      case 'share' when _record != null && _auth != null && _auth != 'none':
        try {
          _spake = respond(_record!, 'mica-provisioning/1 $_auth', base64.decode(m['shareP'] as String));
        } on FormatException {
          return error('bad_message');
        }
        // Counted as failed when share is sent; a valid confirmP takes it back.
        attemptsLeft--;
        return _sendSession({
          't': 'share',
          'shareV': base64.encode(_spake!.shareV),
          'confirmV': base64.encode(_spake!.confirmV),
          'attemptsLeft': attemptsLeft,
        });
      case 'confirm' when _spake != null:
        final ok = constantTimeEquals(base64.decode(m['confirmP'] as String), _spake!.confirmP);
        if (!ok) {
          return attemptsLeft <= 0
              ? error('locked', {'retryAfter': 600})
              : error('auth_failed', {'attemptsLeft': attemptsLeft});
        }
        attemptsLeft = maxAttempts;
        await _keys(_spake!.schedule.sessionKeys);
        _spake = null;
        return _sendSession({'t': 'ready'});
    }
    return error('bad_message');
  }

  Future<void> _onCommand(Uint8List record) async {
    final cipher = _commandCipher;
    if (cipher == null) return close();
    final Json c;
    try {
      c = jsonDecode(utf8.decode(cipher.open(record))) as Json;
    } on FormatException {
      return close();
    }
    commands.add(c);
    final id = c['id'];
    Future<void> failed(String reason) => _event({'id': id, 'event': 'failed', 'reason': reason});
    if (_running) return failed('busy');
    switch (c['op']) {
      case 'getStatus':
        return _event({
          'id': id,
          'event': 'status',
          'wifiMode': wifi.mode,
          'connected': wifi.connected,
          'ssid': wifi.ssid,
          'ip': wifi.ip,
        });
      case 'scanWifi':
        if (wifi.mode == 'ap') return failed('ap_active');
        return _event({'id': id, 'event': 'networks', 'networks': networks});
      case 'claim':
        if (_auth != 'none') return failed('not_allowed');
        if (claimed) return failed('already_claimed');
        final pw = c['password'];
        if (pw is! String || utf8.encode(pw).length < 8 || utf8.encode(pw).length > 1024) {
          return failed('invalid_password');
        }
        final host = c['hostname'];
        if (host != null && (host is! String || !_hostname.hasMatch(host))) return failed('invalid_hostname');
        staged = (password: pw, hostname: host as String?, apPsk: c['apPsk'] as String?);
        return _event({'id': id, 'event': 'claimStaged'});
      case 'setWifi':
        if (_auth == 'none' && staged == null) return failed('not_claimed');
        final ssid = c['ssid'], psk = c['psk'];
        if (ssid is! String || ssid.isEmpty || utf8.encode(ssid).length > 32) return failed('invalid_ssid');
        if (psk is! String || (psk.isNotEmpty && !_psk.hasMatch(psk))) return failed('invalid_psk');
        _running = true;
        await _event({'id': id, 'event': 'connecting'});
        // The connection runs beside further commands, which get `busy`.
        unawaited(
          Future<void>.delayed(connectDelay).then(
            (_) => _serial(() async {
              _running = false;
              wifi = (mode: 'client', connected: false, ssid: null, ip: null);
              final r = routers[ssid];
              if (r == null) return failed('ssid_not_found');
              if (r.fail != null) return failed(r.fail!);
              if (r.psk != psk) return failed('wrong_password');
              wifi = (mode: 'client', connected: true, ssid: ssid, ip: r.ip);
              return _event({'id': id, 'event': 'connected', 'ip': r.ip, 'hostname': staged?.hostname ?? hostname});
            }),
          ),
        );
        return;
      case 'finish':
        if (_auth != 'none') {
          await _event({'id': id, 'event': 'finished', 'claimed': true, 'hostname': hostname});
          return close();
        }
        if (claimedElsewhere) {
          staged = null;
          return failed('already_claimed');
        }
        final s = staged;
        if (s == null) return failed('not_claimed');
        claimed = true;
        hostname = s.hostname ?? hostname;
        await _event({
          'id': id,
          'event': 'finished',
          'claimed': true,
          'hostname': hostname,
          if (s.apPsk == null) 'apPsk': generatedApPsk,
        });
        return close();
    }
    return failed('unknown_op');
  }
}

/// The phone's GATT connection to a [MockDevice].
class MockTransport implements Transport {
  MockTransport._(this._device);

  final MockDevice _device;
  final _session = StreamController<Uint8List>();
  final _events = StreamController<Uint8List>();
  final _gone = Completer<void>();

  void _down() {
    if (!_gone.isCompleted) _gone.complete();
  }

  @override
  Future<Uint8List> readInfo() async {
    if (_device.busy) throw StateError('org.bluez.Error.InProgress');
    return _device.info();
  }

  @override
  Future<void> writeSession(Uint8List fragment) async => _device._writeSession(fragment);

  @override
  Future<void> writeCommand(Uint8List fragment) async => _device._writeCommand(fragment);

  @override
  Stream<Uint8List> get sessionNotifications => _session.stream;

  @override
  Stream<Uint8List> get eventNotifications => _events.stream;

  @override
  Future<void> get disconnected => _gone.future;

  @override
  Future<void> disconnect() async {
    if (identical(_device._link, this)) _device._linkDown();
  }
}
