import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'crypto.dart';
import 'fragments.dart';

// The phone's end of a protocol 1 session: info, authentication on `session`,
// then encrypted operations on `command` and `event`.

const serviceUuid = 'a7f50001-aa05-4fbe-ae8a-39652ca94ed5';
const infoUuid = 'a7f50002-aa05-4fbe-ae8a-39652ca94ed5';
const sessionUuid = 'a7f50003-aa05-4fbe-ae8a-39652ca94ed5';
const commandUuid = 'a7f50004-aa05-4fbe-ae8a-39652ca94ed5';
const eventUuid = 'a7f50005-aa05-4fbe-ae8a-39652ca94ed5';

/// The protocol versions this app speaks.
const supportedProtocols = [1];

/// What the client needs from a connection; the tests stand in for it.
/// The connection is already subscribed to `session` and `event`.
abstract class Transport {
  Future<Uint8List> readInfo();
  Future<void> writeSession(Uint8List fragment);
  Future<void> writeCommand(Uint8List fragment);
  Stream<Uint8List> get sessionNotifications;
  Stream<Uint8List> get eventNotifications;

  /// Completes once when the link goes down, from either end.
  Future<void> get disconnected;
  Future<void> disconnect();
}

enum Auth { none, password, tempCode, passwordUnavailable }

class DeviceInfo {
  const DeviceInfo({
    required this.protocol,
    required this.model,
    required this.hostname,
    required this.claimed,
    required this.auth,
    required this.ops,
    required this.maxWrite,
  });

  factory DeviceInfo.parse(List<int> raw) {
    final Object? v;
    try {
      v = jsonDecode(utf8.decode(raw));
    } on FormatException {
      throw const ProtocolError('info is not JSON');
    }
    if (v is! Map<String, dynamic> || v['protocol'] is! int) throw const ProtocolError('info has no protocol');
    final maxWrite = v['maxWrite'];
    return DeviceInfo(
      protocol: v['protocol'] as int,
      model: v['model'] is String ? v['model'] as String : '',
      hostname: v['hostname'] is String ? v['hostname'] as String : '',
      claimed: v['claimed'] == true,
      auth: switch (v['auth']) {
        'none' => Auth.none,
        'password' => Auth.password,
        'temp-code' => Auth.tempCode,
        _ => Auth.passwordUnavailable,
      },
      ops: v['ops'] is List ? (v['ops'] as List).whereType<String>().toList() : const [],
      maxWrite: maxWrite is int ? maxWrite.clamp(20, 512) : 20,
    );
  }

  final int protocol;
  final String model;
  final String hostname;
  final bool claimed;
  final Auth auth;
  final List<String> ops;
  final int maxWrite;

  DeviceInfo copyWith({bool? claimed, String? hostname}) => DeviceInfo(
    protocol: protocol,
    model: model,
    hostname: hostname ?? this.hostname,
    claimed: claimed ?? this.claimed,
    auth: auth,
    ops: ops,
    maxWrite: maxWrite,
  );
}

/// An event from the device: `{"id":n,"event":"…",…}`.
class DeviceEvent {
  DeviceEvent(this.json);

  final Map<String, dynamic> json;

  int? get id => json['id'] is int ? json['id'] as int : null;
  String get event => '${json['event']}';
  String? get reason => json['reason'] is String ? json['reason'] as String : null;
  bool get failed => event == 'failed';

  Object? operator [](String member) => json[member];
}

/// The device answered `session` with `{"t":"error"}`, or the phone refused
/// its confirmation (`auth_failed`).
class SessionError implements Exception {
  const SessionError(this.reason, {this.attemptsLeft, this.retryAfter});

  final String reason;
  final int? attemptsLeft;
  final int? retryAfter;

  @override
  String toString() => 'session: $reason';
}

/// The connection dropped while the phone waited for the device.
class DisconnectedError implements Exception {
  const DisconnectedError();

  @override
  String toString() => 'disconnected';
}

/// The device sent something protocol 1 does not allow.
class ProtocolError implements Exception {
  const ProtocolError(this.message);

  final String message;

  @override
  String toString() => 'protocol: $message';
}

/// w0 and w1 from the password; slow (PBKDF2), so the app runs it off the UI
/// isolate.
typedef Kdf = Future<({BigInt w0, BigInt w1})> Function(String pw, Uint8List salt, int iterations);

Future<({BigInt w0, BigInt w1})> _inline(String pw, Uint8List salt, int iterations) async =>
    spakeScalars(pw, salt, iterations);

class ProvisioningClient {
  ProvisioningClient(this._t, {this.kdf = _inline}) {
    _subs = [_t.sessionNotifications.listen(_sessionFragment), _t.eventNotifications.listen(_eventFragment)];
    _t.disconnected.then((_) => _dropped());
  }

  final Transport _t;
  final Kdf kdf;
  late final List<StreamSubscription<Uint8List>> _subs;

  /// `{"event":"closing"}`: the device is about to disconnect on its own.
  void Function(String reason) onClosing = (_) {};
  void Function() onDisconnect = () {};

  int _maxWrite = 20;
  bool _closed = false;
  final _sessionIn = Reassembler();
  final _eventIn = Reassembler();
  final _sessionQueue = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? _sessionWaiter;
  RecordCipher? _sealer, _opener;
  final _early = <Uint8List>[];
  Completer<DeviceEvent>? _statusWaiter;
  int _nextId = 1;
  ({int id, Completer<DeviceEvent> done, void Function(DeviceEvent)? onProgress})? _pending;

  bool get connected => !_closed;
  bool get authenticated => _sealer != null;

  Future<DeviceInfo> readInfo() async {
    final info = DeviceInfo.parse(await _t.readInfo());
    _maxWrite = info.maxWrite;
    return info;
  }

  /// `auth: none` (X25519). Completes with the id-less `status` event that
  /// `start {"status": true}` asks for, or null when the device's `ready` does
  /// not echo the member (the phone then asks with `getStatus`).
  Future<DeviceEvent?> authenticateNone() async {
    final x = X25519Start();
    final ready = await _session({'t': 'start', 'auth': 'none', 'pub': base64.encode(x.pub), 'status': true}, 'ready');
    final SessionKeys keys;
    try {
      keys = x.finish(_b64(ready['pub']));
    } on FormatException {
      throw const ProtocolError('bad device key');
    }
    return _ready(keys, ready);
  }

  /// `password` or `temp-code` (SPAKE2+). A wrong secret throws
  /// [SessionError] `auth_failed` with the attempts left, if the device said.
  /// A temp-code is used without its spaces and dashes; a password as typed.
  /// Completes like [authenticateNone].
  Future<DeviceEvent?> authenticateSpake(SpakeMode mode, String secret) async {
    final pw = mode == SpakeMode.tempCode ? secret.replaceAll(RegExp(r'[\s-]'), '') : secret;
    final params = await _session({'t': 'start', 'auth': mode.wire, 'status': true}, 'params');
    final iterations = params['iterations'];
    if (iterations is! int || iterations < 10000 || iterations > 10000000) {
      throw const ProtocolError('iterations out of range');
    }
    final w = await kdf(pw, _b64(params['salt']), iterations);
    final prover = SpakeProver(mode.context, w.w0, w.w1);
    final share = await _session({'t': 'share', 'shareP': base64.encode(prover.shareP)}, 'share');
    final attemptsLeft = share['attemptsLeft'] is int ? share['attemptsLeft'] as int : null;
    final ({Uint8List confirmP, SpakeSchedule schedule}) done;
    try {
      done = prover.finish(_b64(share['shareV']), _b64(share['confirmV']));
    } on ConfirmationError {
      // The device has counted the attempt; the phone sends nothing more.
      throw SessionError('auth_failed', attemptsLeft: attemptsLeft);
    } on FormatException {
      throw const ProtocolError('bad device share');
    }
    final ready = await _session({'t': 'confirm', 'confirmP': base64.encode(done.confirmP)}, 'ready');
    return _ready(done.schedule.sessionKeys, ready);
  }

  Future<DeviceEvent?> _ready(SessionKeys keys, Map<String, dynamic> ready) async {
    _sealer = RecordCipher(keys.phoneToDevice);
    _opener = RecordCipher(keys.deviceToPhone);
    final status = ready['status'] == true ? _statusWaiter = Completer() : null;
    // The status event follows ready at once and can arrive before this runs.
    final early = List.of(_early);
    _early.clear();
    early.forEach(_eventRecord);
    return status?.future;
  }

  /// Sends one operation; completes with its final event (`failed` included).
  Future<DeviceEvent> run(
    String op, [
    Map<String, Object?> params = const {},
    void Function(DeviceEvent)? onProgress,
  ]) async {
    final sealer = _sealer;
    if (sealer == null) throw StateError('not authenticated');
    if (_pending != null) throw StateError('an operation is running');
    if (_closed) throw const DisconnectedError();
    final id = _nextId++;
    final pending = (id: id, done: Completer<DeviceEvent>(), onProgress: onProgress);
    _pending = pending;
    try {
      await _write(_t.writeCommand, sealer.seal(utf8.encode(jsonEncode({'id': id, 'op': op, ...params}))));
    } catch (_) {
      if (identical(_pending, pending)) _pending = null;
      rethrow;
    }
    return pending.done.future;
  }

  Future<void> disconnect() => _t.disconnect();

  Uint8List _b64(Object? v) {
    try {
      return base64.decode(v as String);
    } catch (_) {
      throw const ProtocolError('a binary member is not base64');
    }
  }

  Future<void> _write(Future<void> Function(Uint8List) send, List<int> message) async {
    for (final f in fragment(message, _maxWrite)) {
      await send(f);
    }
  }

  Future<Map<String, dynamic>> _session(Map<String, Object?> msg, String want) async {
    if (_closed) throw const DisconnectedError();
    _sessionQueue.clear();
    await _write(_t.writeSession, utf8.encode(jsonEncode(msg)));
    final Map<String, dynamic> reply;
    if (_sessionQueue.isNotEmpty) {
      reply = _sessionQueue.removeAt(0);
    } else {
      final waiter = _sessionWaiter = Completer();
      reply = await waiter.future;
    }
    if (reply['t'] == 'error') {
      int? n(Object? v) => v is int ? v : null;
      throw SessionError(
        '${reply['reason']}',
        attemptsLeft: n(reply['attemptsLeft']),
        retryAfter: n(reply['retryAfter']),
      );
    }
    if (reply['t'] != want) throw ProtocolError('expected $want, got ${reply['t']}');
    return reply;
  }

  void _sessionFragment(Uint8List f) {
    final Map<String, dynamic> msg;
    try {
      final whole = _sessionIn.push(f);
      if (whole == null) return;
      final v = jsonDecode(utf8.decode(whole));
      if (v is! Map<String, dynamic> || v['t'] is! String) throw const FormatException('no t');
      msg = v;
    } on FormatException {
      _sessionWaiter?.completeError(const ProtocolError('malformed session message'));
      _sessionWaiter = null;
      return;
    }
    final waiter = _sessionWaiter;
    if (waiter != null) {
      _sessionWaiter = null;
      waiter.complete(msg);
    } else {
      _sessionQueue.add(msg);
    }
  }

  void _eventFragment(Uint8List f) {
    try {
      final whole = _eventIn.push(f);
      if (whole == null) return;
      if (_opener == null) {
        _early.add(whole);
        return;
      }
      _eventRecord(whole);
    } on FormatException catch (err) {
      _fatal(ProtocolError(err.message));
    }
  }

  void _eventRecord(Uint8List record) {
    final DeviceEvent e;
    try {
      final v = jsonDecode(utf8.decode(_opener!.open(record)));
      if (v is! Map<String, dynamic>) throw const FormatException('event is not an object');
      e = DeviceEvent(v);
    } on FormatException catch (err) {
      return _fatal(ProtocolError(err.message));
    }
    _dispatch(e);
  }

  void _dispatch(DeviceEvent e) {
    if (e.id == null) {
      if (e.event == 'closing') onClosing('${e['reason']}');
      if (e.event == 'status') {
        _statusWaiter?.complete(e);
        _statusWaiter = null;
      }
      return;
    }
    final p = _pending;
    if (p == null || e.id != p.id) return;
    if (e.event == 'connecting' || e.event == 'applying') {
      p.onProgress?.call(e);
      return;
    }
    _pending = null;
    p.done.complete(e);
  }

  void _fatal(Object err) {
    _pending?.done.completeError(err);
    _pending = null;
    _t.disconnect();
  }

  void _dropped() {
    if (_closed) return;
    _closed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _sessionWaiter?.completeError(const DisconnectedError());
    _sessionWaiter = null;
    _sealer = _opener = null;
    _statusWaiter?.completeError(const DisconnectedError());
    _statusWaiter = null;
    _pending?.done.completeError(const DisconnectedError());
    _pending = null;
    onDisconnect();
  }
}
