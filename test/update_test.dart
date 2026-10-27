import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mica_app/main.dart';
import 'package:mica_app/update.dart';

import 'manage_flow_test.dart' show NoBluetooth, NoWifi, kdf;
import 'support/mock_console.dart';

Future<void> start(WidgetTester tester, String? newer, List<Uri> opened) async {
  await tester.pumpWidget(
    MicaApp(
      radio: NoBluetooth(),
      kdf: kdf,
      wifi: NoWifi(),
      discovery: FakeDiscovery(MockNetwork({})),
      store: MemoryStore(),
      open: (u) async => opened.add(u),
      newerRelease: () async => newer,
      locale: const Locale('zh'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('only a later release version is newer', () {
    expect(isNewer('20261026-0612', '20261101-0900'), isTrue);
    expect(isNewer('20261026-0612', '20261026-0612'), isFalse);
    expect(isNewer('20261101-0900', '20261026-0612'), isFalse);
    // A local build's version is not a release's: nothing to compare.
    expect(isNewer('0.1.0', '20261101-0900'), isFalse);
    expect(isNewer('20261026-0612', 'v2'), isFalse);
  });

  testWidgets('a newer release offers its APK', (tester) async {
    final opened = <Uri>[];
    await start(tester, '20261101-0900', opened);
    expect(find.textContaining('20261101-0900'), findsOneWidget);
    await tester.tap(find.text('下载'));
    await tester.pumpAndSettle();
    expect(opened, [apkUrl]);
    expect(find.textContaining('20261101-0900'), findsNothing);
  });

  testWidgets('later dismisses the prompt', (tester) async {
    final opened = <Uri>[];
    await start(tester, '20261101-0900', opened);
    await tester.tap(find.text('稍后'));
    await tester.pumpAndSettle();
    expect(find.textContaining('20261101-0900'), findsNothing);
    expect(opened, isEmpty);
  });

  testWidgets('no newer release, no prompt', (tester) async {
    await start(tester, null, []);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
