import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mica_app/protocol/client.dart';
import 'package:mica_app/protocol/crypto.dart';

import '../support/mock_device.dart';

const routers = {'Harbour': WifiRouter('harbour-wifi-1', ip: '192.168.8.41')};

Future<(MockDevice, ProvisioningClient)> open(MockDevice d) async {
  final c = ProvisioningClient(d.connect());
  await c.readInfo();
  return (d, c);
}

void main() {
  test('info is parsed and maxWrite clamped', () {
    final i = DeviceInfo.parse(MockDevice(maxWrite: 9999).info());
    expect(i.protocol, 1);
    expect(i.hostname, 'mica-a4e2e69e');
    expect(i.auth, Auth.none);
    expect(i.maxWrite, 512);
    expect(DeviceInfo.parse('{"protocol":1,"auth":"x"}'.codeUnits).auth, Auth.passwordUnavailable);
    expect(() => DeviceInfo.parse('nope'.codeUnits), throwsA(isA<ProtocolError>()));
  });

  test('unclaimed: none, claim, setWifi with progress, finish', () async {
    final (d, c) = await open(MockDevice(routers: routers, maxWrite: 40));
    await c.authenticateNone();
    expect((await c.run('getStatus'))['wifiMode'], 'ap');
    expect((await c.run('scanWifi')).reason, 'ap_active');
    expect(
      (await c.run('setWifi', {'ssid': 'Harbour', 'psk': 'harbour-wifi-1', 'hidden': false})).reason,
      'not_claimed',
    );
    expect((await c.run('claim', {'password': 'admin-pass-1', 'hostname': 'quay-7'})).event, 'claimStaged');
    final progress = <String>[];
    final e = await c.run('setWifi', {
      'ssid': 'Harbour',
      'psk': 'harbour-wifi-1',
      'hidden': false,
    }, (e) => progress.add(e.event));
    expect(progress, ['connecting']);
    expect(e.event, 'connected');
    expect(e['ip'], '192.168.8.41');
    expect(e['hostname'], 'quay-7');
    var dropped = false;
    c.onDisconnect = () => dropped = true;
    final f = await c.run('finish');
    expect(f.json, {
      'id': 6,
      'event': 'finished',
      'claimed': true,
      'hostname': 'quay-7',
      'apPsk': 'harbour-ap-key-7f3a',
    });
    await pumpEventQueue();
    expect(dropped, isTrue);
    expect(d.claimed, isTrue);
    expect(d.largestWrite, lessThanOrEqualTo(40));
    expect(d.largestWrite, greaterThan(20));
  });

  test('the client runs one operation at a time', () async {
    final (_, c) = await open(MockDevice(routers: routers, connectDelay: const Duration(milliseconds: 50)));
    await c.authenticateNone();
    await c.run('claim', {'password': 'admin-pass-1'});
    final join = c.run('setWifi', {'ssid': 'Harbour', 'psk': 'harbour-wifi-1', 'hidden': false});
    await expectLater(() => c.run('getStatus'), throwsStateError);
    expect((await join).event, 'connected');
  });

  test('password: wrong then right; the count comes back', () async {
    final (d, c) = await open(MockDevice(claimed: true, secret: 'harbour-pw-1', wifiMode: 'client'));
    await expectLater(
      c.authenticateSpake(SpakeMode.password, 'wrong'),
      throwsA(
        isA<SessionError>().having((e) => e.reason, 'reason', 'auth_failed').having((e) => e.attemptsLeft, 'left', 4),
      ),
    );
    expect(d.sessionLog.map((m) => m['t']), ['start', 'share']);
    await c.authenticateSpake(SpakeMode.password, 'harbour-pw-1');
    expect(d.attemptsLeft, 5);
    expect(c.authenticated, isTrue);
    expect((await c.run('claim', {'password': 'admin-pass-1'})).reason, 'not_allowed');
    expect((await c.run('finish')).json, {'id': 2, 'event': 'finished', 'claimed': true, 'hostname': 'mica-a4e2e69e'});
  });

  test('temp-code authenticates in its own context', () async {
    final (d, c) = await open(MockDevice(claimed: true, auth: 'temp-code', secret: '40718263'));
    await expectLater(
      c.authenticateSpake(SpakeMode.password, '40718263'),
      throwsA(isA<SessionError>().having((e) => e.reason, 'reason', 'unsupported_auth')),
    );
    await c.authenticateSpake(SpakeMode.tempCode, '40718263');
    expect((await c.run('getStatus')).event, 'status');
    expect(d.commands.single, {'id': 1, 'op': 'getStatus'});
  });

  test('locked carries retryAfter', () async {
    final (d, c) = await open(MockDevice(claimed: true, secret: 's3cret-pw', maxAttempts: 1));
    await expectLater(c.authenticateSpake(SpakeMode.password, 'nope'), throwsA(isA<SessionError>()));
    expect(d.attemptsLeft, 0);
    await expectLater(
      c.authenticateSpake(SpakeMode.password, 's3cret-pw'),
      throwsA(
        isA<SessionError>().having((e) => e.reason, 'reason', 'locked').having((e) => e.retryAfter, 'retry', 600),
      ),
    );
  });

  test('closing then a drop fails the pending operation', () async {
    final (d, c) = await open(MockDevice(routers: routers, connectDelay: const Duration(seconds: 1)));
    await c.authenticateNone();
    await c.run('claim', {'password': 'admin-pass-1'});
    String? closing;
    c.onClosing = (r) => closing = r;
    final connecting = Completer<void>();
    final pending = c.run('setWifi', {
      'ssid': 'Harbour',
      'psk': 'harbour-wifi-1',
      'hidden': false,
    }, (_) => connecting.complete());
    await connecting.future;
    await d.close('idle');
    await expectLater(pending, throwsA(isA<DisconnectedError>()));
    expect(closing, 'idle');
    expect(c.connected, isFalse);
    await expectLater(c.run('getStatus'), throwsStateError);
  });

  test('a GATT refusal from a second central surfaces from readInfo', () async {
    final c = ProvisioningClient(MockDevice(busy: true).connect());
    await expectLater(c.readInfo(), throwsStateError);
  });
}
