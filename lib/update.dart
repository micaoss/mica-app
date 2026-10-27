import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

// Android builds are published as releases of micaoss/mica-app
// (.github/workflows/release.yml): a release's tag is its version name, and
// every release attaches its APK as mica-app.apk.

final apkUrl = Uri.parse('https://github.com/micaoss/mica-app/releases/latest/download/mica-app.apk');
final _latestUrl = Uri.parse('https://api.github.com/repos/micaoss/mica-app/releases/latest');
final _version = RegExp(r'^\d{8}-\d{4}$');

/// Whether release [latest] is later than this build, [current]. Release
/// versions are UTC `YYYYMMDD-HHMM` and sort as text; a local build's version
/// is not one, and is never offered an update.
bool isNewer(String current, String latest) =>
    _version.hasMatch(current) && _version.hasMatch(latest) && latest.compareTo(current) > 0;

/// The newest release's version when it is later than this build's; null
/// when it is not, or when GitHub cannot be asked.
Future<String?> newerRelease() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final current = (await PackageInfo.fromPlatform()).version;
    final request = await client.getUrl(_latestUrl);
    request.headers.set('accept', 'application/vnd.github+json');
    final response = await request.close().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(await response.transform(utf8.decoder).join());
    final tag = body is Map ? body['tag_name'] : null;
    return tag is String && isNewer(current, tag) ? tag : null;
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}
