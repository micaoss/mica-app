// A mica device's HTTP API for tests, written from mica-core
// crates/mica-apid/openapi.json and docs/provisioning-flow.md, not from the
// app's client: the session cookie and its CSRF token, setup with the device
// code, login, and the read-only routes the status screen uses.

import 'dart:convert';
import 'dart:io';

import 'package:mica_app/console/client.dart';
import 'package:mica_app/console/devices.dart';
import 'package:mica_app/console/discovery.dart';

class MockConsole {
  MockConsole({
    this.password,
    this.deviceCode = 'K7Q2-9XW4',
    this.codeRequired = true,
    this.hostname = 'mica-a4e2e69e',
    this.features = const ['ssh', 'containers'],
    this.console = true,
    this.certificate = 'aa11',
    this.wifiEnabled = true,
    this.wifiMode = 'ap',
    this.scan = const [],
    Map<String, Map<String, Object?>>? configured,
    this.applyFailure,
  }) : configured = configured ?? {};

  bool wifiEnabled;
  String wifiMode;

  /// What a scan finds, `{ssid, bssid, signalDbm, flags}`.
  final List<Map<String, Object?>> scan;
  final networks = <Map<String, Object?>>[];
  final Map<String, Map<String, Object?>> configured;
  bool sshEnabled = false;
  final keys = <Map<String, Object?>>[];

  /// The message every apply fails with, when set.
  String? applyFailure;

  /// Answers nothing from now on: it moved to another address.
  bool gone = false;
  final _tasks = <String, Map<String, Object?>>{};

  Reply _accepted() {
    final id = 't${_tasks.length}';
    _tasks[id] = {
      'id': id,
      'status': 'finished',
      'phase': 'applied',
      'outcome': applyFailure == null ? 'succeeded' : 'failed',
      'message': ?applyFailure,
    };
    return _json(202, {'taskId': id});
  }

  /// Null while the device is in setup.
  String? password;
  final String deviceCode;
  final bool codeRequired;
  String hostname;
  final List<String> features;

  /// Whether `/` serves a console; an API-only device answers 404.
  final bool console;

  /// The fingerprint its HTTPS certificate has.
  String certificate;

  final _sessions = <String, String>{};
  int _next = 0;
  final calls = <String>[];

  /// Drops every session, as an apid restart does.
  void restart() => _sessions.clear();

  Reply _json(int status, Object? body, {String? cookie}) =>
      Reply(status, body == null ? '' : jsonEncode(body), cookie: cookie);

  Reply _error(int status, String code) => _json(status, {
    'error': {'code': code, 'message': code},
  });

  Reply handle(String method, String path, Object? body, Map<String, String> headers) {
    calls.add('$method $path');
    final cookie = RegExp(r'apid_session=([^;]+)').firstMatch(headers['cookie'] ?? '')?.group(1);
    final csrf = cookie == null ? null : _sessions[cookie];
    final signedIn = csrf != null;
    final b = body is Map ? body : const {};

    Reply open() {
      final id = 's${_next++}', token = 'csrf-$id';
      _sessions[id] = token;
      return _json(201, {'state': 'authenticated', 'csrfToken': token}, cookie: id);
    }

    switch ((method, path)) {
      case ('GET', '/'):
        return Reply(console ? 307 : 404, '', location: console ? '/_ui/' : null);
      case ('GET', '/api/v1/session'):
        return _json(200, {
          'state': password == null
              ? 'setup'
              : signedIn
              ? 'authenticated'
              : 'unauthenticated',
          if (signedIn) 'csrfToken': csrf,
          if (password == null) 'deviceCode': codeRequired ? 'required' : 'off',
        });
      case ('POST', '/api/v1/setup'):
        if (password != null) return _error(409, 'already_configured');
        final code = '${b['deviceCode'] ?? ''}'.replaceAll('-', '').toUpperCase();
        if (codeRequired && code.isEmpty) return _error(422, 'validation_failed');
        if (codeRequired && code != deviceCode.replaceAll('-', '')) return _error(403, 'device_code_incorrect');
        if (b['password'] is! String || utf8.encode(b['password'] as String).length < 8) {
          return _error(422, 'validation_failed');
        }
        password = b['password'] as String;
        if (b['hostname'] is String) hostname = b['hostname'] as String;
        final r = open();
        return Reply(201, jsonEncode({'csrfToken': jsonDecode(r.body)['csrfToken']}), cookie: r.cookie);
      case ('POST', '/api/v1/session'):
        if (password == null) return _error(409, 'setup_required');
        if (b['password'] != password) return _error(401, 'invalid_credentials');
        return open();
      case ('DELETE', '/api/v1/session'):
        if (!signedIn) return _error(401, 'not_authenticated');
        _sessions.remove(cookie);
        return Reply(204, '', cookie: '');
      case ('GET', '/api/v1/meta'):
        return _json(200, {
          'api': 'v1',
          'settingsSchemaVersion': 1,
          'daemon': 'micad',
          'features': features,
          'init': 'systemd',
          'webMode': 'network',
        });
    }
    if (!signedIn) return _error(401, 'not_authenticated');
    if (method != 'GET' && headers['x-csrf-token'] != csrf) return _error(403, 'csrf_invalid');
    return switch ((method, path)) {
      ('GET', '/api/v1/health') => _json(200, {'apid': 'ok', 'micad': 'ok', 'checkedAt': 4000}),
      ('GET', '/api/v1/settings/hostname') => _json(200, hostname),
      ('GET', '/api/v1/system/info') => _json(200, {
        'release': {'available': true, 'version': '20261024-0910', 'prettyName': 'Mica OS'},
        'board': {'available': true, 'model': 'cx3576'},
        'kernel': {'available': true, 'release': '6.12.40-mica'},
        'deployment': {'available': false, 'detail': 'no deployment'},
        'uptime': {'available': true, 'seconds': 93780},
      }),
      ('GET', '/api/v1/time/status') => _json(200, {'status': 'synchronized', 'synchronized': true}),
      ('GET', '/api/v1/network/status') => _json(200, {
        'interfaces': {
          'available': true,
          'entries': [
            {
              'name': 'lo',
              'type': 'loopback',
              'link': {'operationalState': 'carrier'},
              'addresses': [
                {'address': '127.0.0.1', 'prefixLength': 8, 'family': 'ipv4', 'scope': 'host'},
              ],
            },
            {
              'name': 'eth0',
              'type': 'ether',
              'link': {'operationalState': 'routable', 'carrier': true},
              'addresses': [
                {'address': '192.168.1.57', 'prefixLength': 24, 'family': 'ipv4', 'scope': 'global'},
                {'address': 'fe80::1', 'prefixLength': 64, 'family': 'ipv6', 'scope': 'link'},
              ],
            },
            {'name': 'veth3', 'link': {}, 'addresses': []},
            {
              'name': 'eth1',
              'type': 'ether',
              'link': {'operationalState': 'no-carrier', 'carrier': false},
              'addresses': [],
            },
          ],
        },
        'defaultRoutes': {'available': true, 'entries': []},
      }),
      ('POST', '/api/v1/actions/change-password') =>
        b['currentPassword'] != password ? _error(403, 'wrong_password') : _changed(b, cookie!),
      ('PUT', '/api/v1/settings/hostname') => _setHostname(body),
      ('GET', '/api/v1/settings/access.ssh.enabled') => _json(200, sshEnabled),
      ('PUT', '/api/v1/settings/access.ssh.enabled') => _setSsh(body),
      ('GET', '/api/v1/wifi') => _json(200, {'enabled': wifiEnabled, 'mode': wifiMode, 'locked': false}),
      ('PUT', '/api/v1/wifi') => _setRole(b),
      ('GET', '/api/v1/wifi/client/networks') => _json(200, [
        for (final n in networks) {...n, if (n['psk'] != null) 'psk': '<redacted>'},
      ]),
      ('POST', '/api/v1/wifi/client/networks') => _addNetwork(b),
      ('POST', '/api/v1/wifi/client/scan') =>
        wifiEnabled && wifiMode == 'client'
            ? _json(200, {'available': true, 'interface': 'wlan0', 'networks': scan})
            : _json(200, {'available': false, 'reason': 'access-point'}),
      ('GET', '/api/v1/network') => _json(200, {
        'configured': configured,
        'configuredCount': configured.length,
        'version': 'v${configured.length}',
        'observed': <String, Object?>{},
      }),
      ('GET', '/api/v1/ssh/authorized-keys') => _json(200, {'keys': keys, 'notice': 'root'}),
      ('POST', '/api/v1/ssh/authorized-keys') => _addKey(b),
      _ when method == 'GET' && path.startsWith('/api/v1/tasks/') =>
        _tasks[path.substring(14)] == null ? _error(404, 'task_not_found') : _json(200, _tasks[path.substring(14)]),
      _ when method == 'DELETE' && path.startsWith('/api/v1/wifi/client/networks/') => _removeNetwork(
        Uri.decodeComponent(path.substring(29)),
      ),
      _ when method == 'DELETE' && path.startsWith('/api/v1/ssh/authorized-keys/') => _removeKey(
        Uri.decodeComponent(path.substring(28)),
      ),
      _ when method == 'PUT' && path.startsWith('/api/v1/network/') => _setInterface(
        Uri.decodeComponent(path.substring(16)),
        b,
      ),
      _ => _error(404, 'not_found'),
    };
  }

  Reply _setHostname(Object? v) {
    if (v is! String || v.isEmpty) return _error(422, 'validation_failed');
    hostname = v;
    return _accepted();
  }

  Reply _setSsh(Object? v) {
    if (v is! bool) return _error(422, 'validation_failed');
    sshEnabled = v;
    return _accepted();
  }

  Reply _setRole(Map b) {
    if (b['enabled'] is! bool || (b['mode'] != 'client' && b['mode'] != 'ap')) {
      return _error(422, 'validation_failed');
    }
    wifiEnabled = b['enabled'] as bool;
    wifiMode = b['mode'] as String;
    return _accepted();
  }

  Reply _addNetwork(Map b) {
    if (b['ssid'] is! String || b['hidden'] is! bool || b['priority'] is! int) return _error(422, 'validation_failed');
    if (networks.any((n) => n['ssid'] == b['ssid'])) return _error(409, 'network_exists');
    networks.add({...b.cast<String, Object?>()});
    return _json(201, b);
  }

  Reply _removeNetwork(String ssid) {
    final before = networks.length;
    networks.removeWhere((n) => n['ssid'] == ssid);
    return networks.length == before ? _error(404, 'network_not_found') : const Reply(204, '');
  }

  Reply _addKey(Map b) {
    final parts = '${b['key']}'.split(' ');
    if (parts.length < 2 || !parts[0].startsWith('ssh-')) return _error(422, 'key_invalid');
    final entry = {'key': b['key'], 'fingerprint': 'SHA256:${parts[1]}', 'comment': parts.length > 2 ? parts[2] : null};
    keys.add(entry);
    return _json(201, entry);
  }

  Reply _removeKey(String fingerprint) {
    keys.removeWhere((k) => k['fingerprint'] == fingerprint);
    return const Reply(204, '');
  }

  Reply _setInterface(String name, Map b) {
    if (b['kind'] is! String || b['dhcp'] is! bool) return _error(422, 'validation_failed');
    if (b['dhcp'] == false && b['static'] is Map && !'${(b['static'] as Map)['address']}'.contains('/')) {
      return _error(422, 'validation_failed');
    }
    configured[name] = b.cast<String, Object?>();
    return _accepted();
  }

  Reply _changed(Map b, String keep) {
    password = b['newPassword'] as String;
    _sessions.removeWhere((k, _) => k != keep);
    return const Reply(204, '');
  }
}

/// The phone's view of the network: devices at addresses.
class MockNetwork {
  MockNetwork(this.devices, {this.found = const [], this.names = const {}});

  /// Each device at the scheme, host and port it serves.
  final Map<Uri, MockConsole> devices;
  List<Found> found;

  /// `<name>.local` answers.
  final Map<String, String> names;

  Transport transport(Uri base, String? pin) => _MockTransport(this, base, pin);
}

class _MockTransport implements Transport {
  _MockTransport(this.network, this.base, this.pin);

  final MockNetwork network;
  @override
  final Uri base;
  final String? pin;
  @override
  String? seen;

  @override
  Future<Reply> send(String method, String path, {Object? body, Map<String, String> headers = const {}}) async {
    final device = network.devices[base];
    if (device == null || device.gone) throw const SocketException('no route to host');
    if (base.scheme == 'https') {
      seen = device.certificate;
      if (pin != null && pin != seen) throw PinMismatch(seen!);
    }
    return device.handle(method, path, body == null ? null : jsonDecode(jsonEncode(body)), headers);
  }

  @override
  void close() {}
}

class FakeDiscovery implements Discovery {
  FakeDiscovery(this.network);

  final MockNetwork network;

  @override
  Future<List<Found>> browse() async => network.found;

  @override
  Future<String?> resolve(String name) async => network.names[name.replaceFirst(RegExp(r'\.local$'), '')];
}

class MemoryStore implements DeviceStore {
  MemoryStore([this.devices = const []]);

  List<Saved> devices;

  @override
  Future<List<Saved>> load() async => devices;

  @override
  Future<void> save(List<Saved> d) async => devices = d;
}
