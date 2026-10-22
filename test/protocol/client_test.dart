import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mica_app/protocol/bytes.dart';
import 'package:mica_app/protocol/client.dart';
import 'package:mica_app/protocol/crypto.dart';
import 'package:mica_app/protocol/fragments.dart';

import '../support/mock_device.dart';

const routers = {'Harbour': WifiRouter('harbour-wifi-1', ip: '192.168.8.41')};

Future<(MockDevice, ProvisioningClient)> open(MockDevice d) async {
  final c = ProvisioningClient(d.connect());
  await c.readInfo();
  return (d, c);
}

const wifiJoin = {'ssid': 'Harbour', 'psk': 'harbour-wifi-1', 'hidden': false};

void main() {
  test('info is parsed and maxWrite clamped', () {
    final i = DeviceInfo.parse(MockDevice(maxWrite: 9999).info());
    expect(i.protocol, 1);
    expect(i.hostname, 'mica-a4e2e69e');
    expect(i.auth, Auth.none);
    expect(i.ops, opsN6);
    expect(i.maxWrite, 512);
    expect(DeviceInfo.parse('{"protocol":1,"auth":"x"}'.codeUnits).auth, Auth.passwordUnavailable);
    expect(() => DeviceInfo.parse('nope'.codeUnits), throwsA(isA<ProtocolError>()));
  });

  test('start asks for the status; ready echoes it and the id-less status event comes back', () async {
    final (d, c) = await open(MockDevice());
    final status = await c.authenticateNone();
    expect(d.sessionLog.first, containsPair('status', true));
    expect(status!.event, 'status');
    expect(status.id, isNull);
    expect(status['wifiMode'], 'ap');
    expect((status['interfaces'] as List).first, {
      'name': 'end0',
      'kind': 'ethernet',
      'carrier': true,
      'address': null,
    });
    expect(d.commands, isEmpty);
  });

  test('a device that does not echo status gives none; the phone asks with getStatus', () async {
    final (_, c) = await open(MockDevice(echoStatus: false));
    expect(await c.authenticateNone(), isNull);
    expect((await c.run('getStatus')).event, 'status');
  });

  test('a status event that arrives before ready is processed waits for the keys', () async {
    final t = _RaceTransport();
    final c = ProvisioningClient(t);
    await c.readInfo();
    final status = await c.authenticateNone();
    expect(status!['wifiMode'], 'client');
    expect(c.connected, isTrue);
  });

  test('unclaimed, N6: setWifi without a claim, finish without fields, nothing claimed', () async {
    final (d, c) = await open(MockDevice(routers: routers, maxWrite: 40));
    await c.authenticateNone();
    final progress = <String>[];
    final e = await c.run('setWifi', wifiJoin, (e) => progress.add(e.event));
    expect(progress, ['connecting']);
    expect(e.json, {'id': 1, 'event': 'connected', 'ip': '192.168.8.41', 'hostname': 'mica-a4e2e69e'});
    var dropped = false;
    c.onDisconnect = () => dropped = true;
    final f = await c.run('finish');
    expect(d.commands.last, {'id': 2, 'op': 'finish'});
    expect(f.json, {
      'id': 2,
      'event': 'finished',
      'claimed': false,
      'hostname': 'mica-a4e2e69e',
      'interface': {'name': 'wlan0', 'kind': 'wifi', 'address': '192.168.8.41/24'},
      'consoleUrls': ['http://192.168.8.41', 'http://mica-a4e2e69e.local'],
      'ap': 'off',
    });
    await pumpEventQueue();
    expect(dropped, isTrue);
    expect(d.claimed, isFalse);
    expect(d.largestWrite, inInclusiveRange(21, 40));
  });

  test('setNetwork: applying is progress, up is final', () async {
    final (_, c) = await open(MockDevice());
    await c.authenticateNone();
    final progress = <String>[];
    final e = await c.run('setNetwork', {'interface': 'end0', 'dhcp': true}, (e) => progress.add(e.event));
    expect(progress, ['applying']);
    expect(e.json, {'id': 1, 'event': 'up', 'interface': 'end0', 'address': '192.168.8.50/24'});
    expect((await c.run('setNetwork', {'interface': 'wlan0', 'dhcp': true})).reason, 'unknown_interface');
    final f = await c.run('finish');
    expect(f['ap'], 'on');
    expect(f['consoleUrls'], ['http://192.168.8.50', 'http://mica-a4e2e69e.local']);
  });

  test('a 0.0.3 device (claim in ops) still claims and generates the AP key', () async {
    final (d, c) = await open(MockDevice(ops: opsLegacy, routers: routers));
    await c.authenticateNone();
    expect((await c.run('setWifi', wifiJoin)).reason, 'not_claimed');
    expect((await c.run('claim', {'password': 'admin-pass-1', 'hostname': 'quay-7'})).event, 'claimStaged');
    expect((await c.run('setWifi', wifiJoin)).event, 'connected');
    final f = await c.run('finish');
    expect(f.json, {
      'id': 4,
      'event': 'finished',
      'claimed': true,
      'hostname': 'quay-7',
      'apPsk': 'harbour-ap-key-7f3a',
    });
    expect(d.claimed, isTrue);
    expect((await open(MockDevice())).$1.ops.contains('claim'), isFalse);
  });

  test('the client runs one operation at a time', () async {
    final (_, c) = await open(MockDevice(routers: routers, connectDelay: const Duration(milliseconds: 50)));
    await c.authenticateNone();
    final join = c.run('setWifi', wifiJoin);
    await expectLater(() => c.run('getStatus'), throwsStateError);
    expect((await join).event, 'connected');
  });

  test('password: wrong then right; the count comes back; the status comes with ready', () async {
    final (d, c) = await open(MockDevice(claimed: true, secret: 'harbour-pw-1', wifiMode: 'client'));
    await expectLater(
      c.authenticateSpake(SpakeMode.password, 'wrong'),
      throwsA(
        isA<SessionError>().having((e) => e.reason, 'reason', 'auth_failed').having((e) => e.attemptsLeft, 'left', 4),
      ),
    );
    expect(d.sessionLog.map((m) => m['t']), ['start', 'share']);
    final status = await c.authenticateSpake(SpakeMode.password, 'harbour-pw-1');
    expect(status!['wifiMode'], 'client');
    expect(d.attemptsLeft, 5);
    expect((await c.run('finish')).json, containsPair('claimed', true));
  });

  test('temp-code authenticates in its own context', () async {
    final (d, c) = await open(MockDevice(claimed: true, auth: 'temp-code', secret: '40718263'));
    await expectLater(
      c.authenticateSpake(SpakeMode.password, '40718263'),
      throwsA(isA<SessionError>().having((e) => e.reason, 'reason', 'unsupported_auth')),
    );
    await c.authenticateSpake(SpakeMode.tempCode, '4071-8263');
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
    String? closing;
    c.onClosing = (r) => closing = r;
    final connecting = Completer<void>();
    final pending = c.run('setWifi', wifiJoin, (_) => connecting.complete());
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

/// A device that puts `ready` and the status event on the air in the same
/// instant, so the event reaches the phone before it has its keys.
class _RaceTransport implements Transport {
  final _session = StreamController<Uint8List>();
  final _events = StreamController<Uint8List>();

  @override
  Future<Uint8List> readInfo() async => utf8Bytes('{"protocol":1,"auth":"none","maxWrite":512}');

  @override
  Future<void> writeSession(Uint8List f) async {
    final start = jsonDecode(utf8.decode(Reassembler().push(f)!)) as Map;
    final private = Uint8List(32)..[0] = 7;
    final devicePub = x25519(private, Uint8List(32)..[0] = 9);
    final phonePub = base64.decode(start['pub'] as String);
    final salt = sha256(concat([utf8Bytes('mica-provisioning/1 none'), phonePub, devicePub]));
    final k = hkdf(salt, x25519(private, phonePub), 'mica-provisioning/1 session keys', 64);
    final ready = utf8.encode(jsonEncode({'t': 'ready', 'pub': base64.encode(devicePub), 'status': true}));
    final event = RecordCipher(k.sublist(32)).seal(utf8.encode(jsonEncode({'event': 'status', 'wifiMode': 'client'})));
    fragment(ready, 512).forEach(_session.add);
    fragment(event, 512).forEach(_events.add);
  }

  @override
  Future<void> writeCommand(Uint8List f) async {}

  @override
  Stream<Uint8List> get sessionNotifications => _session.stream;

  @override
  Stream<Uint8List> get eventNotifications => _events.stream;

  @override
  Future<void> get disconnected => Completer<void>().future;

  @override
  Future<void> disconnect() async {}
}
