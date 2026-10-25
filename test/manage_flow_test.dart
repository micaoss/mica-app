import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mica_app/ble.dart';
import 'package:mica_app/console/devices.dart';
import 'package:mica_app/console/discovery.dart';
import 'package:mica_app/l10n/app_localizations.dart';
import 'package:mica_app/main.dart';
import 'package:mica_app/manage_settings.dart';
import 'package:mica_app/protocol/client.dart';
import 'package:mica_app/protocol/crypto.dart';
import 'package:mica_app/setup_page.dart';
import 'package:mica_app/wifi.dart';

import 'support/mock_console.dart';

final https = Uri.parse('https://192.168.1.57/');
final http = Uri.parse('http://192.168.1.80/');

class NoBluetooth implements Bluetooth {
  @override
  Stream<RadioState> get state => Stream.value(RadioState.unsupported);

  @override
  Stream<List<FoundDevice>> scan() => const Stream.empty();

  @override
  Future<Transport> connect(FoundDevice d) => throw UnimplementedError();
}

class NoWifi implements Wifi {
  @override
  Future<bool> join(String ssid, String psk) async => false;
}

Future<({BigInt w0, BigInt w1})> kdf(String pw, List<int> salt, int iterations) async =>
    spakeScalars(pw, salt, iterations);

Future<void> start(
  WidgetTester tester,
  MockNetwork network, {
  MemoryStore? store,
  List<Uri>? opened,
  String lang = 'zh',
}) async {
  await tester.pumpWidget(
    MicaApp(
      key: UniqueKey(),
      radio: NoBluetooth(),
      kdf: kdf,
      wifi: NoWifi(),
      discovery: FakeDiscovery(network),
      store: store ?? MemoryStore(),
      transport: network.transport,
      open: (u) async => opened?.add(u),
      locale: Locale(lang),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.lan_outlined));
  await tester.pumpAndSettle();
}

extension on WidgetTester {
  Future<void> tapText(String text) async {
    await ensureVisible(find.text(text).last);
    await tap(find.text(text).last);
    await pumpAndSettle();
  }

  Future<void> type(String label, String text) async {
    await enterText(find.widgetWithText(TextField, label), text);
    await pump();
  }

  Future<void> setUp(String code, String password) async {
    if (code.isNotEmpty) await type('设备码', code);
    await type('管理员密码（至少 8 位）', password);
    await type('再次输入密码', password);
    await tapText('下一步');
  }
}

/// Signed in to [device], on its status screen.
Future<void> signedIn(WidgetTester tester, MockConsole device) async {
  await start(tester, MockNetwork({https: device}, found: [const Found('mica-a4e2e69e', '192.168.1.57', 443)]));
  await tester.tapText('mica-a4e2e69e');
  await tester.type('管理员密码', 'harbour-admin');
  await tester.tapText('登录');
}

void main() {
  testWidgets('a device in setup on this network: the device code, the password, then its status', (tester) async {
    final device = MockConsole();
    final network = MockNetwork({https: device}, found: [const Found('mica-a4e2e69e', '192.168.1.57', 443)]);
    final store = MemoryStore();
    final opened = <Uri>[];
    await start(tester, network, store: store, opened: opened);

    expect(find.text('本网络中的设备'), findsOneWidget);
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('首次设置'), findsOneWidget);

    await tester.setUp('K7Q2-9XW5', 'harbour-admin');
    expect(find.text('设备码不正确'), findsOneWidget);
    expect(device.password, isNull);

    await tester.setUp('k7q29xw4', 'harbour-admin');
    expect(device.password, 'harbour-admin');
    expect(find.text('设备状态'), findsOneWidget);
    expect(find.text('20261024-0910'), findsOneWidget);
    expect(find.text('cx3576'), findsOneWidget);
    expect(find.text('1 天 2 小时 3 分'), findsOneWidget);
    expect(find.text('已同步'), findsOneWidget);
    expect(find.text('192.168.1.57/24 · routable'), findsOneWidget);
    expect(find.text('lo'), findsNothing);
    expect(find.text('veth3'), findsNothing);
    expect(find.text('ssh, containers'), findsOneWidget);

    expect(store.devices.single.base, https);
    expect(store.devices.single.pin, 'aa11');

    await tester.tapText('打开控制台');
    expect(opened, [https]);

    await tester.tapText('退出登录');
    expect(device.calls, contains('DELETE /api/v1/session'));
    expect(find.text('登录过的设备'), findsOneWidget);
  });

  testWidgets('setup checks the form before sending: code, length, repeat, hostname', (tester) async {
    final device = MockConsole();
    await start(tester, MockNetwork({https: device}, found: [const Found('mica-a4e2e69e', '192.168.1.57', 443)]));
    await tester.tapText('mica-a4e2e69e');
    await tester.setUp('', 'harbour-admin');
    expect(find.text('印在设备标签上，也显示在设备的登录提示中'), findsWidgets);
    await tester.setUp('K7Q2-9XW4', 'short');
    expect(find.text('密码至少 8 位'), findsOneWidget);
    await tester.type('管理员密码（至少 8 位）', 'harbour-admin');
    await tester.type('再次输入密码', 'harbour-admim');
    await tester.tapText('下一步');
    expect(find.text('两次输入的密码不一致'), findsOneWidget);
    await tester.type('再次输入密码', 'harbour-admin');
    await tester.type('主机名（可选）', 'bad_name');
    await tester.tapText('下一步');
    expect(find.text('主机名只能包含字母、数字和连字符，不能以连字符开头或结尾，最多 63 个字符'), findsOneWidget);
    expect(device.calls.where((c) => c.startsWith('POST')), isEmpty);
  });

  testWidgets('a typed address: HTTPS first, then HTTP; a wrong password; no console on the device', (tester) async {
    final device = MockConsole(password: 'harbour-admin', console: false);
    final store = MemoryStore();
    await start(tester, MockNetwork({http: device}), store: store);

    expect(find.text('没有设备响应。设备会在它接入的网络中广播自己；手机用网线直连设备，或设备关闭了广播时，请输入它的地址。'), findsOneWidget);
    await tester.type('设备地址', '192.168.1.80');
    await tester.tapText('连接');
    expect(find.text('登录'), findsWidgets);

    await tester.type('管理员密码', 'wrong-password');
    await tester.tapText('登录');
    expect(find.text('密码错误'), findsOneWidget);

    await tester.type('管理员密码', 'harbour-admin');
    await tester.tapText('登录');
    expect(find.text('设备状态'), findsOneWidget);
    expect(find.text('此设备没有网页控制台，请在这里管理。'), findsOneWidget);
    expect(find.text('打开控制台'), findsNothing);
    expect(store.devices.single.base, http);
    expect(store.devices.single.pin, isNull);
  });

  testWidgets('an address nothing answers at says so', (tester) async {
    await start(tester, MockNetwork({}));
    await tester.type('设备地址', '10.0.0.9');
    await tester.tapText('连接');
    expect(find.text('设备在 10.0.0.9 没有响应'), findsOneWidget);
  });

  testWidgets('hostname.local is resolved over mDNS', (tester) async {
    final device = MockConsole(password: 'harbour-admin');
    await start(tester, MockNetwork({https: device}, names: {'mica-a4e2e69e': '192.168.1.57'}));
    await tester.type('设备地址', 'mica-a4e2e69e.local');
    await tester.tapText('连接');
    expect(find.text('https://192.168.1.57/'), findsOneWidget);
    expect(device.calls, ['GET /api/v1/session']);
  });

  testWidgets('a saved device whose certificate changed: stop, show it, trust only on request', (tester) async {
    final device = MockConsole(password: 'harbour-admin', certificate: 'bb22');
    final store = MemoryStore([Saved('mica-a4e2e69e', https, pin: 'aa11')]);
    await start(tester, MockNetwork({https: device}), store: store);

    await tester.tapText('mica-a4e2e69e');
    expect(find.textContaining('设备出示的证书与第一次不同'), findsOneWidget);
    expect(find.text('bb22'), findsOneWidget);
    expect(device.calls, isEmpty);

    await tester.tapText('信任新证书');
    expect(store.devices.single.pin, 'bb22');
    expect(find.text('登录'), findsWidgets);
  });

  testWidgets('a session the device dropped asks to sign in again on refresh', (tester) async {
    final device = MockConsole(password: 'harbour-admin');
    await start(tester, MockNetwork({https: device}, found: [const Found('mica-a4e2e69e', '192.168.1.57', 443)]));
    await tester.tapText('mica-a4e2e69e');
    await tester.type('管理员密码', 'harbour-admin');
    await tester.tapText('登录');
    device.restart();
    await tester.tapText('刷新');
    expect(find.text('登录已失效，请重新登录'), findsOneWidget);
  });

  testWidgets('a device that serves its API only locally cannot be managed from here', (tester) async {
    await start(tester, MockNetwork({}, found: [const Found('mica-a4e2e69e', '192.168.1.57', 0)]));
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('此设备的 API 只对设备本机开放，无法通过网络管理。'), findsOneWidget);
  });

  testWidgets('forgetting a saved device', (tester) async {
    final store = MemoryStore([Saved('mica-a4e2e69e', https, pin: 'aa11')]);
    await start(tester, MockNetwork({}), store: store);
    await tester.tap(find.byTooltip('移除'));
    await tester.pumpAndSettle();
    expect(store.devices, isEmpty);
    expect(find.text('登录过的设备'), findsNothing);
  });

  testWidgets('English', (tester) async {
    await start(tester, MockNetwork({}), lang: 'en');
    expect(find.text('Network management'), findsOneWidget);
    expect(find.text('Device address'), findsOneWidget);
  });

  testWidgets('Bluetooth setup done: manage the device in the app', (tester) async {
    Uri? managed;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: DoneView(
            step: const DoneStep(reached: null, urls: ['https://192.168.1.57'], claimed: false, apOn: false),
            open: (_) async {},
            manage: (u) => managed = u,
          ),
        ),
      ),
    );
    await tester.tap(find.text('在 App 中管理'));
    expect(managed, Uri.parse('https://192.168.1.57'));
  });

  testWidgets('Wi-Fi on the hotspot: no scan, the name typed, the key; the radio goes to the station', (tester) async {
    final device = MockConsole(password: 'harbour-admin', features: ['wifi', 'ssh']);
    await signedIn(tester, device);
    await tester.tapText('网络');
    expect(find.text('Wi-Fi 模式: Wi-Fi 接入点'), findsOneWidget);
    expect(find.text('没有保存的网络'), findsOneWidget);

    await tester.tapText('配置 Wi-Fi');
    expect(find.text('设备当前为 Wi-Fi 接入点模式，不能扫描，请输入网络名称。'), findsOneWidget);
    await tester.type('网络名称', 'Harbour');
    await tester.tapText('下一步');
    expect(find.text('设备将关闭热点并连接 Harbour，连着设备热点的终端会断开'), findsOneWidget);
    await tester.type('Wi-Fi 密码（开放网络留空）', 'harbour-wifi-1');
    await tester.tapText('连接');

    expect(device.networks.single, {'ssid': 'Harbour', 'psk': 'harbour-wifi-1', 'hidden': false, 'priority': 0});
    expect((device.wifiEnabled, device.wifiMode), (true, 'client'));
    expect(find.text('已保存并应用'), findsOneWidget);
    expect(find.text('Wi-Fi 模式: Wi-Fi 客户端'), findsOneWidget);
    expect(find.text('Harbour'), findsOneWidget);
  });

  testWidgets('Wi-Fi as a station: the scan, a pick, the key; and removing a network', (tester) async {
    final device = MockConsole(
      password: 'harbour-admin',
      features: ['wifi'],
      wifiMode: 'client',
      scan: [
        {'ssid': 'Harbour', 'bssid': 'aa:01', 'signalDbm': -48, 'flags': '[WPA2-PSK-CCMP][ESS]'},
        {'ssid': 'Marina Guest', 'bssid': 'aa:02', 'signalDbm': -70, 'flags': '[ESS]'},
      ],
    );
    await signedIn(tester, device);
    await tester.tapText('网络');
    await tester.tapText('配置 Wi-Fi');
    expect(find.text('wpa2-psk · -48 dBm'), findsOneWidget);
    expect(find.text('开放 · -70 dBm'), findsOneWidget);
    await tester.tapText('Harbour');
    await tester.type('Wi-Fi 密码（开放网络留空）', 'harbour-wifi-1');
    await tester.tapText('连接');
    expect(device.networks.single['ssid'], 'Harbour');
    expect(device.calls.where((c) => c == 'PUT /api/v1/wifi'), isEmpty);

    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    expect(device.networks, isEmpty);
    expect(device.calls, contains('DELETE /api/v1/wifi/client/networks/Harbour'));
  });

  testWidgets('no Wi-Fi: the wired ports alone; static addressing keeps the rest of the entry', (tester) async {
    final device = MockConsole(
      password: 'harbour-admin',
      features: [],
      configured: {
        'eth0': {
          'kind': 'physical',
          'dhcp': true,
          'internet': true,
          'routes': [
            {'destination': '10.9.0.0/16', 'gateway': '192.168.1.1'},
          ],
        },
      },
    );
    await signedIn(tester, device);
    await tester.tapText('网络');
    expect(find.text('Wi-Fi'), findsNothing);
    expect(find.text('已插网线 · 192.168.1.57/24 · 自动获取（DHCP）'), findsOneWidget);
    expect(find.text('未插网线 · 无地址 · 未声明（DHCP）'), findsOneWidget);

    await tester.tapText('eth0');
    await tester.tapText('静态地址');
    await tester.type('地址/前缀（如 192.168.1.40/24）', '192.168.1.40');
    await tester.tapText('应用');
    expect(find.text('地址应为 IPv4 地址加前缀，如 192.168.1.40/24'), findsOneWidget);
    await tester.type('地址/前缀（如 192.168.1.40/24）', '192.168.1.40/24');
    await tester.type('网关（可选）', '192.168.1.1');
    await tester.type('DNS 服务器（可选，用空格或逗号分隔）', '1.1.1.1 9.9.9.9');
    await tester.tapText('应用');
    expect(device.configured['eth0'], {
      'kind': 'physical',
      'dhcp': false,
      'internet': true,
      'routes': [
        {'destination': '10.9.0.0/16', 'gateway': '192.168.1.1'},
      ],
      'static': {
        'address': '192.168.1.40/24',
        'gateway': '192.168.1.1',
        'dns': ['1.1.1.1', '9.9.9.9'],
      },
    });
    expect(find.text('已保存并应用'), findsOneWidget);
  });

  testWidgets('an apply that fails says why; a device that stops answering says it may have moved', (tester) async {
    final device = MockConsole(password: 'harbour-admin', features: [], applyFailure: 'eth1: no carrier');
    await signedIn(tester, device);
    await tester.tapText('网络');
    await tester.tapText('eth1');
    await tester.tapText('应用');
    expect(find.text('已保存，但应用失败：eth1: no carrier'), findsOneWidget);

    device.applyFailure = null;
    device.gone = true;
    await tester.tapText('应用');
    expect(find.text('设备不再响应：它可能换到了别的网络或地址，请回到列表重新查找。'), findsOneWidget);
  });

  testWidgets('settings: hostname, the administrator password, SSH and its keys', (tester) async {
    final device = MockConsole(password: 'harbour-admin', features: ['ssh']);
    await signedIn(tester, device);
    await tester.tapText('系统设置');

    await tester.type('主机名', 'bench_7');
    await tester.tapText('保存');
    expect(find.text('主机名只能包含字母、数字和连字符，不能以连字符开头或结尾，最多 63 个字符'), findsOneWidget);
    await tester.type('主机名', 'bench-7');
    await tester.tapText('保存');
    expect(device.hostname, 'bench-7');

    await tester.type('当前密码', 'not-it-at-all');
    await tester.type('管理员密码（至少 8 位）', 'harbour-admin-2');
    await tester.type('再次输入密码', 'harbour-admin-2');
    await tester.tapText('修改管理员密码');
    expect(find.text('当前密码不正确'), findsOneWidget);
    await tester.type('当前密码', 'harbour-admin');
    await tester.type('管理员密码（至少 8 位）', 'harbour-admin-2');
    await tester.type('再次输入密码', 'harbour-admin-2');
    await tester.tapText('修改管理员密码');
    expect(device.password, 'harbour-admin-2');

    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(device.sshEnabled, isTrue);

    await tester.type('添加公钥', 'ssh-ed25519 AAAAC3Nza harbour@laptop');
    await tester.tapText('添加公钥');
    expect(device.keys.single['comment'], 'harbour@laptop');
    expect(find.text('harbour@laptop'), findsOneWidget);
    await tester.tap(find.byTooltip('删除'));
    await tester.pumpAndSettle();
    expect(device.keys, isEmpty);
  });

  testWidgets('no SSH feature, no SSH section', (tester) async {
    await signedIn(tester, MockConsole(password: 'harbour-admin', features: []));
    await tester.tapText('系统设置');
    expect(find.text('SSH'), findsNothing);
  });

  test('a scan in the Bluetooth screens\' shape', () {
    final list = scanned({
      'networks': [
        {'ssid': 'Harbour', 'signalDbm': -61, 'flags': '[WPA2-PSK-CCMP]'},
        {'ssid': 'Harbour', 'signalDbm': -48, 'flags': '[WPA2-PSK-CCMP]'},
        {'ssid': 'Lab', 'signalDbm': -50, 'flags': '[SAE]'},
        {'ssid': '', 'signalDbm': -40, 'flags': '[ESS]'},
      ],
    });
    expect(list.map((n) => (n.ssid, n.signalDbm, n.security)), [('Harbour', -48, 'wpa2-psk'), ('Lab', -50, 'sae')]);
  });

  test('typed addresses', () {
    expect(candidates('192.168.1.9'), [Uri.parse('https://192.168.1.9/'), Uri.parse('http://192.168.1.9/')]);
    expect(candidates(' mica-ab12.local:8443 '), [
      Uri.parse('https://mica-ab12.local:8443/'),
      Uri.parse('http://mica-ab12.local:8443/'),
    ]);
    expect(candidates('http://10.0.0.5:8080/_ui/'), [Uri.parse('http://10.0.0.5:8080/')]);
    expect(candidates('fe80::1').map((u) => '${u.scheme} ${u.host}'), ['https fe80::1', 'http fe80::1']);
    expect(candidates('192.168.1.9:80'), [Uri.parse('http://192.168.1.9/')]);
    expect(candidates(''), isEmpty);
  });

  test('TXT records', () {
    expect(parseTxt('txtvers=1\nproduct=cx3576-dev\nhostname=mica-ab12'), {
      'txtvers': '1',
      'product': 'cx3576-dev',
      'hostname': 'mica-ab12',
    });
  });
}
