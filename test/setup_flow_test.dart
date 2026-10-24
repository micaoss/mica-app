import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mica_app/ble.dart';
import 'package:mica_app/main.dart';
import 'package:mica_app/protocol/client.dart';
import 'package:mica_app/protocol/crypto.dart';
import 'package:mica_app/setup_page.dart';
import 'package:mica_app/wifi.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'support/mock_device.dart';

const routers = {'Harbour': WifiRouter('harbour-wifi-1', ip: '192.168.8.41')};
const networks = [
  {'ssid': 'Harbour', 'signalDbm': -61, 'security': 'wpa2-psk', 'channel': 6},
  {'ssid': 'Harbour', 'signalDbm': -48, 'security': 'wpa2-psk', 'channel': 36},
  {'ssid': 'Marina Guest', 'signalDbm': -70, 'security': 'open', 'channel': 11},
  {'ssid': '', 'signalDbm': -40, 'security': 'wpa2-psk', 'channel': 1},
];

/// The phone's Bluetooth with one device in range.
class FakeBluetooth implements Bluetooth {
  FakeBluetooth(this.device, {this.radioState = RadioState.on});

  final MockDevice device;
  final RadioState radioState;

  @override
  Stream<RadioState> get state => Stream.value(radioState);

  @override
  Stream<List<FoundDevice>> scan() => Stream.value([FoundDevice('AA:BB', device.hostname, -52)]);

  @override
  Future<Transport> connect(FoundDevice d) async => device.connect();
}

/// The phone's Wi-Fi: records what it was asked to join.
class FakeWifi implements Wifi {
  FakeWifi({this.accept = true});

  final bool accept;
  final joined = <(String, String)>[];

  @override
  Future<bool> join(String ssid, String psk) async {
    joined.add((ssid, psk));
    return accept;
  }
}

Future<({BigInt w0, BigInt w1})> inlineKdf(String pw, List<int> salt, int iterations) async =>
    spakeScalars(pw, salt, iterations);

Future<MockDevice> start(
  WidgetTester tester,
  MockDevice device, {
  String lang = 'zh',
  RadioState radio = RadioState.on,
  Wifi? wifi,
  List<Uri>? opened,
}) async {
  await tester.pumpWidget(
    MicaApp(
      key: UniqueKey(),
      radio: FakeBluetooth(device, radioState: radio),
      kdf: inlineKdf,
      wifi: wifi ?? FakeWifi(),
      open: (u) async => opened?.add(u),
      locale: Locale(lang),
    ),
  );
  await tester.pumpAndSettle();
  return device;
}

MockDevice unclaimed({
  Map<String, WifiRouter> routers = routers,
  bool claimedElsewhere = false,
  List<String> ops = opsN6,
  List<MockPort>? ports,
  String? wiredFail,
  bool echoStatus = true,
}) => MockDevice(
  routers: routers,
  networks: networks,
  claimedElsewhere: claimedElsewhere,
  ops: ops,
  ports: ports,
  wiredFail: wiredFail,
  echoStatus: echoStatus,
);

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

  Future<void> reachWifiNetwork() async {
    await tapText('mica-a4e2e69e');
    expect(find.text('当前状态'), findsOneWidget);
    await tapText('配置 Wi-Fi');
    expect(find.text('设备当前为 Wi-Fi 接入点模式，不能扫描，请输入网络名称。'), findsOneWidget);
  }

  Future<void> enterNetwork(String ssid, String psk) async {
    await type('网络名称', ssid);
    await tapText('下一步');
    expect(find.text('连接 $ssid'), findsWidgets);
    if (psk.isNotEmpty) await type('Wi-Fi 密码（开放网络留空）', psk);
    await tap(find.widgetWithText(FilledButton, '连接'));
    await pumpAndSettle();
  }
}

void main() {
  testWidgets('unclaimed, Wi-Fi: no password or hostname screen, the console sets the administrator', (tester) async {
    final d = await start(tester, unclaimed());
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('设置管理员'), findsNothing);
    // The status came with ready: ports, and the Wi-Fi or wired choice.
    expect(find.text('当前状态'), findsOneWidget);
    expect(find.text('有线 · 已插网线'), findsOneWidget);
    expect(find.text('Wi-Fi · 未连接 · 192.168.4.1/24'), findsOneWidget);
    expect(find.text('设备通过 Wi-Fi 还是网线上网？'), findsOneWidget);
    expect(find.text('配置有线网络'), findsOneWidget);
    expect(d.commands, isEmpty);
    await tester.tapText('配置 Wi-Fi');
    await tester.type('网络名称', 'Harbour');
    await tester.tapText('下一步');
    expect(find.text('设备将关闭热点并连接 Harbour，连着设备热点的终端会断开'), findsOneWidget);
    await tester.type('Wi-Fi 密码（开放网络留空）', 'harbour-wifi-1');
    await tester.tap(find.widgetWithText(FilledButton, '连接'));
    await tester.pumpAndSettle();
    // finish goes out as soon as the network is up: no joined screen.
    expect(find.text('主机名（可选）'), findsNothing);
    expect(find.text('完成配网'), findsNothing);
    expect(find.text('配网完成'), findsOneWidget);
    expect(find.text('已连接。Wi-Fi 192.168.8.41。'), findsOneWidget);
    expect(find.text('http://192.168.8.41:8080'), findsOneWidget);
    expect(find.text('http://mica-a4e2e69e.local:8080'), findsOneWidget);
    expect(find.text('此设备的控制台未对网络开放，无法从这里打开。'), findsNothing);
    expect(find.text('打开控制台设置管理员密码。控制台会要求输入设备码——它印在设备标签上，也显示在设备自身的控制台上（串口 / 显示器登录提示）。'), findsOneWidget);
    expect(find.text('设备热点仍开启，在控制台设置你自己的密码之前，热点密码为设备标签上的密码。'), findsNothing);
    expect(find.text('加入设备热点'), findsNothing);
    expect(find.text('设备热点的新密码'), findsNothing);
    expect(d.claimed, isFalse);
    expect(d.hostname, 'mica-a4e2e69e');
    expect(d.commands.map((c) => c['op']), ['getStatus', 'setWifi', 'finish']);
    expect(d.commands.last, {'id': 3, 'op': 'finish'});
  });

  testWidgets('an automatic finish that fails shows the reason and a finish button', (tester) async {
    final d = await start(tester, MockDevice(routers: routers, finishFail: 'busy'));
    await tester.reachWifiNetwork();
    await tester.enterNetwork('Harbour', 'harbour-wifi-1');
    expect(find.text('已连接 Harbour，IP：192.168.8.41'), findsOneWidget);
    expect(find.text('设备忙，请稍候重试'), findsOneWidget);
    await tester.tapText('完成配网');
    expect(find.text('配网完成'), findsOneWidget);
    expect(d.commands.map((c) => c['op']), ['getStatus', 'setWifi', 'finish', 'finish']);
  });

  testWidgets('https console URLs are offered; an empty list says the console is not on the network', (tester) async {
    await start(tester, MockDevice(routers: routers, https: true));
    await tester.reachWifiNetwork();
    await tester.enterNetwork('Harbour', 'harbour-wifi-1');
    expect(find.text('https://192.168.8.41'), findsOneWidget);
    expect(find.text('https://mica-a4e2e69e.local'), findsOneWidget);

    await start(tester, MockDevice(routers: routers, webMode: 'off'));
    await tester.reachWifiNetwork();
    await tester.enterNetwork('Harbour', 'harbour-wifi-1');
    expect(find.text('配网完成'), findsOneWidget);
    expect(find.text('此设备的控制台未对网络开放，无法从这里打开。'), findsOneWidget);
    expect(find.text('打开控制台：'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('unclaimed, hotspot on the label key: SSID, key, QR and join, on the status and done screens', (
    tester,
  ) async {
    final wifi = FakeWifi();
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    final opened = <Uri>[];
    await start(tester, unclaimed(), wifi: wifi, opened: opened);
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('加入设备热点'), findsOneWidget);
    expect(find.text('label-key-2f9c'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('复制热点密码'));
    await tester.tap(find.byTooltip('复制热点密码'));
    await tester.pumpAndSettle();
    expect(copied, ['label-key-2f9c']);
    await tester.tapText('连接设备热点');
    expect(wifi.joined, [('mica-a4e2e69e', 'label-key-2f9c')]);
    expect(opened, isEmpty);

    await tester.tapText('配置有线网络');
    await tester.tapText('应用');
    expect(find.text('配网完成'), findsOneWidget);
    expect(find.text('加入设备热点'), findsOneWidget);
    expect(find.text('label-key-2f9c'), findsOneWidget);
    // On the done screen joining opens the console on the hotspot's address.
    await tester.tapText('连接设备热点');
    expect(opened, [Uri.parse('http://192.168.4.1:8080')]);
  });

  testWidgets('a phone that cannot join says to use the QR code or the Wi-Fi settings', (tester) async {
    await start(tester, unclaimed(), wifi: FakeWifi(accept: false));
    await tester.tapText('mica-a4e2e69e');
    await tester.tapText('连接设备热点');
    expect(find.text('无法自动加入，请扫描二维码或在手机的 Wi-Fi 设置中加入。'), findsOneWidget);
  });

  testWidgets('no key, no block: an own key, or the older ap string', (tester) async {
    await start(tester, MockDevice(ownApKey: true));
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('当前状态'), findsOneWidget);
    expect(find.text('加入设备热点'), findsNothing);

    await start(tester, MockDevice(apObject: false));
    await tester.tapText('mica-a4e2e69e');
    await tester.tapText('配置有线网络');
    await tester.tapText('应用');
    expect(find.text('设备热点仍开启，在控制台设置你自己的密码之前，热点密码为设备标签上的密码。'), findsOneWidget);
    expect(find.text('加入设备热点'), findsNothing);
  });

  testWidgets('unclaimed, wired DHCP: the hotspot stays on with its label key', (tester) async {
    final d = await start(tester, unclaimed());
    await tester.tapText('mica-a4e2e69e');
    await tester.tapText('配置有线网络');
    expect(find.text('有线网络'), findsOneWidget);
    expect(find.text('end0'), findsOneWidget);
    await tester.tapText('应用');
    expect(find.text('已连接。有线 192.168.8.50。'), findsOneWidget);
    expect(find.text('http://192.168.8.50:8080'), findsOneWidget);
    expect(find.text('设备热点仍开启，在控制台设置你自己的密码之前，热点密码为设备标签上的密码。'), findsOneWidget);
    expect(
      [
        for (final c in d.commands) {...c}..remove('id'),
      ],
      [
        {'op': 'setNetwork', 'interface': 'end0', 'dhcp': true},
        {'op': 'finish'},
      ],
    );
  });

  testWidgets('wired static: the form checks address, gateway and DNS before sending', (tester) async {
    final d = await start(tester, unclaimed());
    await tester.tapText('mica-a4e2e69e');
    await tester.tapText('配置有线网络');
    await tester.tapText('静态地址');
    await tester.type('地址/前缀（如 192.168.1.40/24）', '10.0.0.5');
    await tester.tapText('应用');
    expect(find.text('地址应为 IPv4 地址加前缀，如 192.168.1.40/24'), findsOneWidget);
    await tester.type('地址/前缀（如 192.168.1.40/24）', '10.0.0.5/24');
    await tester.type('网关（可选）', '10.0.0.300');
    await tester.tapText('应用');
    expect(find.text('网关应为 IPv4 地址'), findsOneWidget);
    await tester.type('网关（可选）', '10.0.0.1');
    await tester.type('DNS 服务器（可选，用空格或逗号分隔）', '1.1.1.1, dns.example');
    await tester.tapText('应用');
    expect(find.text('DNS 服务器应为 IP 地址'), findsOneWidget);
    expect(d.commands, isEmpty);
    await tester.type('DNS 服务器（可选，用空格或逗号分隔）', '1.1.1.1, 2606:4700::1111');
    await tester.tapText('应用');
    expect(find.text('已连接。有线 10.0.0.5。'), findsOneWidget);
    expect(d.commands.map((c) => c['op']), ['setNetwork', 'finish']);
    expect(d.commands.first, {
      'id': 1,
      'op': 'setNetwork',
      'interface': 'end0',
      'static': {
        'address': '10.0.0.5/24',
        'gateway': '10.0.0.1',
        'dns': ['1.1.1.1', '2606:4700::1111'],
      },
    });
  });

  for (final (reason, text) in [
    ('no_carrier', '没有插网线。设置已保存，插上网线后生效'),
    ('dhcp_timeout', '30 秒内没有获得 DHCP 地址。设置已保存'),
    ('gateway_out_of_subnet', '网关不在该地址的子网内'),
  ]) {
    testWidgets('wired: $reason returns to the form with what was typed', (tester) async {
      await start(tester, unclaimed(wiredFail: reason));
      await tester.tapText('mica-a4e2e69e');
      await tester.tapText('配置有线网络');
      await tester.tapText('静态地址');
      await tester.type('地址/前缀（如 192.168.1.40/24）', '10.0.0.5/24');
      await tester.tapText('应用');
      expect(find.text(text), findsOneWidget);
      expect(find.text('有线网络'), findsOneWidget);
      expect(find.widgetWithText(TextField, '10.0.0.5/24'), findsOneWidget);
    });
  }

  testWidgets('no wired choice without setNetwork in ops, or without an Ethernet port', (tester) async {
    await start(tester, unclaimed(ops: const ['getStatus', 'scanWifi', 'setWifi', 'finish']));
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('配置 Wi-Fi'), findsOneWidget);
    expect(find.text('配置有线网络'), findsNothing);
    expect(find.text('设备通过 Wi-Fi 还是网线上网？'), findsNothing);
    await start(tester, unclaimed(ports: [MockPort('wlan0', 'wifi')]));
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('配置有线网络'), findsNothing);
  });

  testWidgets('a device whose ready does not echo the status is asked with getStatus', (tester) async {
    final d = await start(tester, unclaimed(echoStatus: false));
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('当前状态'), findsOneWidget);
    expect(d.commands.single, {'id': 1, 'op': 'getStatus'});
  });

  testWidgets('a 0.0.3 device (claim in ops): administrator screen, AP key shown once', (tester) async {
    final d = await start(tester, unclaimed(ops: opsLegacy));
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('设置管理员'), findsOneWidget);
    await tester.type('管理员密码（至少 8 位）', 'short');
    await tester.tapText('下一步');
    expect(find.text('密码至少 8 位'), findsOneWidget);
    await tester.type('管理员密码（至少 8 位）', 'admin-pass-1');
    await tester.type('再次输入密码', 'admin-pass-2');
    await tester.tapText('下一步');
    expect(find.text('两次输入的密码不一致'), findsOneWidget);
    await tester.type('再次输入密码', 'admin-pass-1');
    await tester.type('主机名（可选）', 'quay-7');
    await tester.tapText('下一步');
    await tester.tapText('配置 Wi-Fi');
    await tester.enterNetwork('Harbour', 'harbour-wifi-1');
    // The hostname went with the claim; finish carries none.
    expect(find.widgetWithText(TextField, '主机名（可选）'), findsNothing);
    await tester.tapText('完成配网');
    expect(find.text('http://192.168.8.41'), findsOneWidget);
    expect(find.text('http://quay-7.local'), findsOneWidget);
    expect(find.text('harbour-ap-key-7f3a'), findsOneWidget);
    expect(find.text('只显示这一次，请现在记下。'), findsOneWidget);
    expect(find.text('打开控制台设置管理员密码。控制台会要求输入设备码——它印在设备标签上，也显示在设备自身的控制台上（串口 / 显示器登录提示）。'), findsNothing);
    expect(d.claimed, isTrue);
    expect(d.commands.firstWhere((c) => c['op'] == 'claim'), {
      'id': 1,
      'op': 'claim',
      'password': 'admin-pass-1',
      'hostname': 'quay-7',
    });
    expect(d.commands.last, {'id': 4, 'op': 'finish'});
  });

  for (final (reason, ssid, psk, text, back) in [
    ('wrong_password', 'Harbour', 'not-the-key', 'Wi-Fi 密码错误', 7),
    ('ssid_not_found', 'Nowhere', 'whatever-1', '未找到该网络，请检查名称或靠近路由器', 6),
    ('dhcp_timeout', 'Marina', 'marina-key-1', '已连接但未获得 IP，请检查路由器', 7),
    ('unsupported_security', 'Corp', 'corp-key-12', '设备不支持该网络的加密方式', 6),
    ('busy', 'Busy', 'busy-key-12', '设备忙，请稍候重试', 7),
  ]) {
    testWidgets('step 8: $reason shows its text and returns to step $back', (tester) async {
      await start(
        tester,
        unclaimed(
          routers: {
            ...routers,
            'Marina': const WifiRouter('marina-key-1', fail: 'dhcp_timeout'),
            'Corp': const WifiRouter('corp-key-12', fail: 'unsupported_security'),
            'Busy': const WifiRouter('busy-key-12', fail: 'busy'),
          },
        ),
      );
      await tester.reachWifiNetwork();
      await tester.enterNetwork(ssid, psk);
      expect(find.text(text), findsOneWidget);
      if (back == 7) {
        expect(find.text('连接 $ssid'), findsOneWidget);
        expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Wi-Fi 密码（开放网络留空）')).controller!.text, '');
      } else {
        // Back at the network step; the device left access-point mode, so it scanned.
        expect(find.text('选择网络'), findsOneWidget);
        expect(find.text('Harbour'), findsOneWidget);
      }
    });
  }

  testWidgets('claimed device: a wrong password tells the attempts left; then scan, join, finish', (tester) async {
    final d = await start(
      tester,
      MockDevice(claimed: true, secret: 'harbour-pw-1', wifiMode: 'client', routers: routers, networks: networks),
    );
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('已认领'), findsOneWidget);
    await tester.type('管理员密码', 'wrong-pw');
    await tester.tapText('验证');
    expect(find.text('密码错误，还可尝试 4 次'), findsOneWidget);
    await tester.type('管理员密码', 'harbour-pw-1');
    await tester.tapText('验证');
    expect(find.text('当前状态'), findsOneWidget);
    expect(find.text('Wi-Fi 客户端'), findsOneWidget);
    await tester.tapText('配置 Wi-Fi');
    // Merged by name, strongest first; the hidden network has no row.
    expect(find.text('Harbour'), findsOneWidget);
    expect(find.text('wpa2-psk · -48 dBm'), findsOneWidget);
    expect(find.text('开放 · -70 dBm'), findsOneWidget);
    await tester.tapText('Harbour');
    expect(find.text('设备将关闭热点并连接 Harbour，连着设备热点的终端会断开'), findsNothing);
    await tester.type('Wi-Fi 密码（开放网络留空）', 'harbour-wifi-1');
    await tester.tap(find.widgetWithText(FilledButton, '连接'));
    await tester.pumpAndSettle();
    expect(find.text('已连接。Wi-Fi 192.168.8.41。'), findsOneWidget);
    expect(find.text('打开控制台设置管理员密码。控制台会要求输入设备码——它印在设备标签上，也显示在设备自身的控制台上（串口 / 显示器登录提示）。'), findsNothing);
    expect(d.sessionLog.where((m) => m['t'] == 'start').length, 2);
    expect(find.text('加入设备热点'), findsNothing);
  });

  testWidgets('temp-code: typed with spaces, used without', (tester) async {
    final d = await start(tester, MockDevice(claimed: true, auth: 'temp-code', secret: '40718263'));
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('控制台“蓝牙配网”中显示的 8 位数字'), findsOneWidget);
    await tester.type('临时配网码', '4071 8263');
    await tester.tapText('验证');
    expect(find.text('当前状态'), findsOneWidget);
    expect(d.sessionLog.first, {'t': 'start', 'auth': 'temp-code', 'status': true});
  });

  testWidgets('lockout stops with the time to wait', (tester) async {
    await start(tester, MockDevice(claimed: true, secret: 'harbour-pw-1', maxAttempts: 1));
    await tester.tapText('mica-a4e2e69e');
    await tester.type('管理员密码', 'wrong-pw');
    await tester.tapText('验证');
    expect(find.text('密码错误，还可尝试 0 次'), findsOneWidget);
    await tester.tapText('验证');
    expect(find.text('错误次数过多，设备已锁定，请在 10 分钟后重试'), findsOneWidget);
    expect(find.text('重新开始'), findsOneWidget);
  });

  testWidgets('password-unavailable and an unknown protocol stop at step 2', (tester) async {
    final d = await start(tester, MockDevice(claimed: true, auth: 'password-unavailable'));
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('请先登录一次控制台以启用蓝牙恢复'), findsOneWidget);
    expect(d.sessionLog, isEmpty);
    await start(tester, MockDevice(protocol: 2));
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('请升级应用或设备'), findsOneWidget);
  });

  testWidgets('claimed meanwhile by another channel: setWifi stops the flow', (tester) async {
    await start(tester, unclaimed(claimedElsewhere: true));
    await tester.reachWifiNetwork();
    await tester.enterNetwork('Harbour', 'harbour-wifi-1');
    expect(find.text('设备已被其他方式认领'), findsOneWidget);
  });

  testWidgets('a drop on an unclaimed device: reconnect starts again', (tester) async {
    final d = await start(tester, unclaimed());
    await tester.reachWifiNetwork();
    // The device's notifications ride fake-async timers: pumped, not awaited.
    unawaited(d.close('idle'));
    await tester.pumpAndSettle();
    expect(find.text('2 分钟无操作，设备断开了蓝牙。 蓝牙已断开，本次未完成的设置已撤销。重新连接后重新开始。'), findsOneWidget);
    await tester.tapText('重新连接');
    expect(find.text('当前状态'), findsOneWidget);
  });

  testWidgets('a drop on a claimed device asks to verify again', (tester) async {
    final d = await start(tester, MockDevice(claimed: true, secret: 'harbour-pw-1'));
    await tester.tapText('mica-a4e2e69e');
    await tester.type('管理员密码', 'harbour-pw-1');
    await tester.tapText('验证');
    unawaited(d.close());
    await tester.pumpAndSettle();
    expect(find.text('蓝牙已断开。重新连接并验证后继续。'), findsOneWidget);
    await tester.tapText('重新连接');
    expect(find.text('管理员密码'), findsOneWidget);
  });

  testWidgets('claimed elsewhere during the session', (tester) async {
    final d = await start(tester, unclaimed());
    await tester.reachWifiNetwork();
    unawaited(d.close('claimed_elsewhere'));
    await tester.pumpAndSettle();
    expect(find.text('设备已被其他方式认领'), findsOneWidget);
  });

  testWidgets('another phone holds the device', (tester) async {
    await start(tester, MockDevice(busy: true));
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('已有其他手机连接该设备，请等对方完成后重试'), findsOneWidget);
    expect(find.text('mica-a4e2e69e'), findsOneWidget);
  });

  testWidgets('Bluetooth off or missing', (tester) async {
    await start(tester, MockDevice(), radio: RadioState.off);
    expect(find.text('请打开蓝牙'), findsOneWidget);
    await start(tester, MockDevice(), radio: RadioState.unsupported, lang: 'en');
    expect(find.text('This phone has no Bluetooth Low Energy: set the device up through its hotspot'), findsOneWidget);
  });

  testWidgets('English, and the language switch', (tester) async {
    await start(tester, unclaimed(), lang: 'en');
    await tester.tapText('mica-a4e2e69e');
    expect(find.text('Does the device reach the network over Wi-Fi or a cable?'), findsOneWidget);
    await tester.tapText('中文');
    expect(find.text('设备通过 Wi-Fi 还是网线上网？'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
  });

  test('mergeNetworks keeps the strongest of a name and drops hidden ones', () {
    expect(mergeNetworks(networks).map((n) => (n.ssid, n.signalDbm)), [('Harbour', -48), ('Marina Guest', -70)]);
    expect(mergeNetworks('nope'), isEmpty);
  });

  test('address checks', () {
    expect(isCidr('10.0.0.5/24'), isTrue);
    expect(isCidr('10.0.0.5'), isFalse);
    expect(isCidr('10.0.0.5/33'), isFalse);
    expect(isCidr('10.0.0.256/24'), isFalse);
    expect(isIpv4('192.168.1.1'), isTrue);
    expect(isIpv4('2606:4700::1111'), isFalse);
    expect(isIp('2606:4700::1111'), isTrue);
    expect(splitList(' 1.1.1.1,9.9.9.9  8.8.8.8 '), ['1.1.1.1', '9.9.9.9', '8.8.8.8']);
  });

  test('the hotspot: both ap shapes; the Wi-Fi QR escapes its specials', () {
    expect(
      Hotspot.of({'on': true, 'ssid': 'mica-a4e2e69e', 'psk': 'label-key-2f9c'})!.qr,
      'WIFI:T:WPA;S:mica-a4e2e69e;P:label-key-2f9c;;',
    );
    expect(const Hotspot(r'a;b,c:d\e"f', 'k;1').qr, r'WIFI:T:WPA;S:a\;b\,c\:d\\e\"f;P:k\;1;;');
    expect(Hotspot.of({'on': true, 'ssid': 'x', 'psk': null}), isNull);
    expect(Hotspot.of({'on': false, 'ssid': 'x', 'psk': 'label-key-2f9c'}), isNull);
    expect(Hotspot.of('on'), isNull);
    expect(apOn('on'), isTrue);
    expect(apOn({'on': true}), isTrue);
    expect(apOn('off'), isFalse);
    expect(apOn({'on': false}), isFalse);
  });
}
