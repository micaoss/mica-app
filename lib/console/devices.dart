import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A device the app has signed in to: where its API is, and the fingerprint
/// of the certificate it presented the first time. No password is kept.
class Saved {
  const Saved(this.name, this.base, {this.pin});

  final String name;
  final Uri base;
  final String? pin;

  Saved withPin(String? pin) => Saved(name, base, pin: pin);

  Map<String, Object?> toJson() => {'name': name, 'base': '$base', 'pin': ?pin};

  static Saved? fromJson(Object? j) => j is Map && j['name'] is String && j['base'] is String
      ? Saved(j['name'] as String, Uri.parse(j['base'] as String), pin: j['pin'] is String ? j['pin'] as String : null)
      : null;
}

abstract class DeviceStore {
  Future<List<Saved>> load();
  Future<void> save(List<Saved> devices);
}

class PrefsDeviceStore implements DeviceStore {
  static const _key = 'devices';

  @override
  Future<List<Saved>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    final list = raw == null ? const [] : jsonDecode(raw);
    return [for (final j in list is List ? list : const []) ?Saved.fromJson(j)];
  }

  @override
  Future<void> save(List<Saved> devices) async =>
      (await SharedPreferences.getInstance()).setString(_key, jsonEncode([for (final d in devices) d.toJson()]));
}

/// [devices] with [d] in place of the entry at the same address, first.
List<Saved> remember(List<Saved> devices, Saved d) => [d, ...devices.where((x) => x.base != d.base)];

/// What a person typed as the device's address: a URL, `host`, `host:port`
/// or an IPv6 literal. The candidates to try in order; HTTPS first unless the
/// scheme was given or the port says otherwise.
List<Uri> candidates(String typed) {
  final s = typed.trim();
  if (s.isEmpty) return const [];
  if (s.startsWith('http://') || s.startsWith('https://')) {
    final u = Uri.tryParse(s);
    return u == null || u.host.isEmpty ? const [] : [u.replace(path: '/', query: null, fragment: null)];
  }
  final u = Uri.tryParse('//${s.contains(':') && !s.contains('[') && ':'.allMatches(s).length > 1 ? '[$s]' : s}');
  if (u == null || u.host.isEmpty) return const [];
  return forPort(u.host, u.hasPort ? u.port : null);
}

/// The console at [host] on [port]: 443 is HTTPS, 80 is HTTP, anything else
/// either, HTTPS first.
List<Uri> forPort(String host, int? port) => switch (port) {
  null => [Uri(scheme: 'https', host: host, path: '/'), Uri(scheme: 'http', host: host, path: '/')],
  443 => [Uri(scheme: 'https', host: host, path: '/')],
  80 => [Uri(scheme: 'http', host: host, path: '/')],
  _ => [
    Uri(scheme: 'https', host: host, port: port, path: '/'),
    Uri(scheme: 'http', host: host, port: port, path: '/'),
  ],
};
