import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pointycastle/digests/sha256.dart';

// The device's HTTP API (mica-core `crates/mica-apid/openapi.json`), as the
// web console speaks it: a session cookie and its CSRF token.

/// One HTTP exchange's answer.
class Reply {
  const Reply(this.status, this.body, {this.cookie, this.retryAfter, this.location});

  final int status;
  final String body;

  /// The `apid_session` value a `Set-Cookie` carried; empty when it cleared it.
  final String? cookie;

  /// `Retry-After` in seconds.
  final int? retryAfter;
  final String? location;
}

/// How requests reach one device: HTTP for the app, a mock in the tests.
abstract class Transport {
  Uri get base;

  /// The fingerprint of the certificate the device presented, once it did.
  String? get seen;

  Future<Reply> send(String method, String path, {Object? body, Map<String, String> headers = const {}});

  void close();
}

/// The certificate a TLS connection presented did not match the one stored.
class PinMismatch implements Exception {
  const PinMismatch(this.seen);

  /// The fingerprint presented instead.
  final String seen;
}

/// SHA-256 of a certificate's DER, lowercase hex.
String fingerprint(List<int> der) =>
    SHA256Digest().process(Uint8List.fromList(der)).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// dart:io's client. HTTPS takes the device's self-signed certificate on
/// first use and only that one afterwards: [pin] is the fingerprint stored for
/// this device, null on first contact; [seen] is what the device presented.
class IoTransport implements Transport {
  IoTransport(this.base, {this.pin}) {
    _client
      ..connectionTimeout = const Duration(seconds: 6)
      ..badCertificateCallback = (cert, host, port) {
        seen = fingerprint(cert.der);
        return pin == null || pin == seen;
      };
  }

  @override
  final Uri base;
  final String? pin;
  @override
  String? seen;
  final _client = HttpClient();

  @override
  Future<Reply> send(String method, String path, {Object? body, Map<String, String> headers = const {}}) async {
    final HttpClientResponse response;
    try {
      final request = await _client.openUrl(method, base.resolve(path)).timeout(const Duration(seconds: 10));
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      response = await request.close().timeout(const Duration(seconds: 30));
    } on HandshakeException {
      final s = seen;
      if (pin != null && s != null && s != pin) throw PinMismatch(s);
      rethrow;
    }
    final text = await response.transform(utf8.decoder).join();
    String? cookie;
    for (final c in response.cookies) {
      if (c.name == 'apid_session') cookie = c.maxAge == 0 ? '' : c.value;
    }
    return Reply(
      response.statusCode,
      text,
      cookie: cookie,
      retryAfter: int.tryParse(response.headers.value('retry-after') ?? ''),
      location: response.headers.value('location'),
    );
  }

  @override
  void close() => _client.close(force: true);
}

/// A refused request: the HTTP status and the error envelope's code.
class ApiFailure implements Exception {
  const ApiFailure(this.status, this.code, [this.message = '', this.retryAfter]);

  final int status;
  final String code;
  final String message;
  final int? retryAfter;

  @override
  String toString() => 'ApiFailure($status, $code)';
}

/// A queued apply had not finished when the app stopped waiting.
class TaskPending implements Exception {
  const TaskPending();
}

/// `GET /api/v1/session`'s `state`.
enum SessionState { setup, unauthenticated, authenticated }

class Session {
  const Session(this.state, {this.deviceCodeRequired = false});

  final SessionState state;

  /// In setup: the claim must carry the device code.
  final bool deviceCodeRequired;
}

typedef Json = Map<String, Object?>;

/// The API calls the app makes, with the session they need.
class ConsoleClient {
  ConsoleClient(this.transport);

  final Transport transport;
  String? _cookie, _csrf;

  Uri get base => transport.base;

  Future<Object?> _call(String method, String path, [Object? body]) async {
    final headers = <String, String>{
      'accept': 'application/json',
      if (_cookie != null) 'cookie': 'apid_session=$_cookie',
      if (_csrf != null && method != 'GET') 'x-csrf-token': _csrf!,
    };
    final r = await transport.send(method, path, body: body, headers: headers);
    if (r.cookie != null) _cookie = r.cookie!.isEmpty ? null : r.cookie;
    final Object? json;
    try {
      json = r.body.isEmpty ? null : jsonDecode(r.body);
    } on FormatException {
      if (r.status >= 400) throw ApiFailure(r.status, 'http_${r.status}');
      rethrow;
    }
    if (r.status >= 400) {
      final e = json is Map && json['error'] is Map ? json['error'] as Map : const {};
      throw ApiFailure(r.status, '${e['code'] ?? 'http_${r.status}'}', '${e['message'] ?? ''}', r.retryAfter);
    }
    return json;
  }

  Future<Json> _object(String path) async {
    final v = await _call('GET', path);
    return v is Map ? v.cast<String, Object?>() : const {};
  }

  Future<Session> session() async {
    final s = await _object('/api/v1/session');
    if (s['csrfToken'] is String) _csrf = s['csrfToken'] as String;
    return Session(switch (s['state']) {
      'setup' => SessionState.setup,
      'authenticated' => SessionState.authenticated,
      _ => SessionState.unauthenticated,
    }, deviceCodeRequired: s['deviceCode'] == 'required');
  }

  /// First-run setup; the device answers with a signed-in session.
  Future<void> setup({required String password, String hostname = '', String deviceCode = ''}) async {
    final r = await _call('POST', '/api/v1/setup', {
      'password': password,
      if (hostname.isNotEmpty) 'hostname': hostname,
      if (deviceCode.isNotEmpty) 'deviceCode': deviceCode,
    });
    if (r is Map && r['csrfToken'] is String) _csrf = r['csrfToken'] as String;
  }

  Future<void> login(String password) async {
    final r = await _call('POST', '/api/v1/session', {'password': password});
    if (r is Map && r['csrfToken'] is String) _csrf = r['csrfToken'] as String;
  }

  Future<void> logout() async {
    try {
      await _call('DELETE', '/api/v1/session');
    } finally {
      _cookie = null;
      _csrf = null;
    }
  }

  Future<Json> meta() => _object('/api/v1/meta');
  Future<Json> health() => _object('/api/v1/health');
  Future<Json> systemInfo() => _object('/api/v1/system/info');
  Future<Json> timeStatus() => _object('/api/v1/time/status');
  Future<Json> networkStatus() => _object('/api/v1/network/status');

  Future<String> hostname() async => '${await _call('GET', '/api/v1/settings/hostname') ?? ''}';

  Future<void> changePassword(String current, String next) =>
      _call('POST', '/api/v1/actions/change-password', {'currentPassword': current, 'newPassword': next});

  /// A write the device persisted and queued: its task id.
  Future<String> _task(String method, String path, Object? body) async {
    final r = await _call(method, path, body);
    return r is Map && r['taskId'] is String ? r['taskId'] as String : '';
  }

  Future<String> setHostname(String name) => _task('PUT', '/api/v1/settings/hostname', name);

  Future<Object?> setting(String path) => _call('GET', '/api/v1/settings/$path');
  Future<String> setSetting(String path, Object value) => _task('PUT', '/api/v1/settings/$path', value);

  /// `{enabled, mode, locked}`: which role holds the radio.
  Future<Json> wifiRole() => _object('/api/v1/wifi');

  /// Switches the radio's role, keeping that role's stored configuration.
  Future<String> setWifiRole({required bool enabled, required String mode}) =>
      _task('PUT', '/api/v1/wifi', {'enabled': enabled, 'mode': mode});

  Future<List<Json>> wifiNetworks() async {
    final v = await _call('GET', '/api/v1/wifi/client/networks');
    return [
      for (final n in v is List ? v : const [])
        if (n is Map) n.cast<String, Object?>(),
    ];
  }

  Future<void> addWifiNetwork(String ssid, String psk, {bool hidden = false}) => _call(
    'POST',
    '/api/v1/wifi/client/networks',
    {'ssid': ssid, if (psk.isNotEmpty) 'psk': psk, 'hidden': hidden, 'priority': 0},
  );

  Future<void> removeWifiNetwork(String ssid) =>
      _call('DELETE', '/api/v1/wifi/client/networks/${Uri.encodeComponent(ssid)}');

  /// `{available, networks?, reason?}`: what the station's radio found.
  Future<Json> scanWifi() async {
    final v = await _call('POST', '/api/v1/wifi/client/scan');
    return v is Map ? v.cast<String, Object?>() : const {};
  }

  /// The declared `network` map, by interface name.
  Future<Json> configuredNetwork() async {
    final v = (await _object('/api/v1/network'))['configured'];
    return v is Map ? v.cast<String, Object?>() : const {};
  }

  Future<String> setInterface(String name, Json entry) =>
      _task('PUT', '/api/v1/network/${Uri.encodeComponent(name)}', entry);

  Future<List<Json>> sshKeys() async {
    final v = (await _object('/api/v1/ssh/authorized-keys'))['keys'];
    return [
      for (final k in v is List ? v : const [])
        if (k is Map) k.cast<String, Object?>(),
    ];
  }

  Future<void> addSshKey(String line) => _call('POST', '/api/v1/ssh/authorized-keys', {'key': line});

  Future<void> removeSshKey(String fingerprint) =>
      _call('DELETE', '/api/v1/ssh/authorized-keys/${Uri.encodeComponent(fingerprint)}');

  /// Waits for a queued apply to finish: null when it succeeded, the device's
  /// message when it failed. Gives up after [limit], answering [TaskPending].
  Future<String?> settle(String id, {Duration every = const Duration(seconds: 1), int limit = 30}) async {
    if (id.isEmpty) return null;
    for (var i = 0; i < limit; i++) {
      final r = await _object('/api/v1/tasks/${Uri.encodeComponent(id)}');
      if (r['status'] == 'finished') {
        return r['outcome'] == 'succeeded' ? null : '${r['message'] ?? r['outcome'] ?? ''}';
      }
      await Future<void>.delayed(every);
    }
    throw const TaskPending();
  }

  /// Whether `/` serves a console: an API-only device answers 404.
  Future<bool> hasConsole() async {
    final r = await transport.send('GET', '/', headers: const {'accept': 'text/html'});
    return r.status != 404;
  }

  void close() => transport.close();
}
