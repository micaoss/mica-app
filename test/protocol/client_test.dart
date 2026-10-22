import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mica_app/protocol/client.dart';

import '../support/fake_device.dart';

void main() {
  test('first connection: the default PIN only allows a PIN change', () async {
    final device = FakeDevice();
    final connection = await Connection.open(device.connect());
    expect(connection.hello.pinSet, isFalse);
    expect(connection.hello.deviceId, device.deviceId);

    final session = await connection.authenticate(const PinCredential('000000'));
    expect(session.scope, 'pin-change');
    final refused = await session.request('GET', '/v1/network/status');
    expect(refused.status, 403);
    expect(refused.code, 'pin-unset');

    expect((await session.setPin('000000')).code, 'bad-pin');
    expect((await session.setPin('12345')).code, 'bad-pin');
    expect((await session.setPin('481516')).ok, isTrue);
    expect(session.scope, 'full');
    expect(device.pin, '481516');
    await session.close();
  });

  test('a wrong PIN fails, and the next attempt is backed off', () async {
    final device = FakeDevice(pin: '481516');
    final connection = await Connection.open(device.connect());
    await expectLater(
      connection.authenticate(const PinCredential('111111')),
      throwsA(isA<ProtocolException>().having((e) => e.code, 'code', 'auth-failed')),
    );

    final again = await Connection.open(device.connect());
    await expectLater(
      again.authenticate(const PinCredential('481516')),
      throwsA(isA<ProtocolException>()
          .having((e) => e.code, 'code', 'backoff')
          .having((e) => e.retryAfter, 'retryAfter', 1)),
    );
  });

  test('enroll, then reconnect with the phone credential and no PIN', () async {
    final device = FakeDevice(pin: '481516');
    final first = await (await Connection.open(device.connect()))
        .authenticate(const PinCredential('481516'));
    final enrolled = await first.request('POST', '/ble/phones', {'name': 'test phone'});
    expect(enrolled.status, 201);
    final body = enrolled.body as Map;
    await first.close();

    final credential = PhoneCredential(body['phone'] as String, base64.decode(body['secret'] as String));
    final second = await (await Connection.open(device.connect())).authenticate(credential);
    expect(second.scope, 'full');
    final phones = await second.request('GET', '/ble/phones');
    expect((phones.body as List).single['current'], isTrue);
  });

  test('requests are sealed and answered by id', () async {
    final device = FakeDevice(pin: '481516')
      ..routes['GET /v1/network/status'] = ((m, p, b) => (status: 200, body: {'interfaces': []}))
      ..routes['PUT /v1/wifi/client'] = ((m, p, b) => (status: 200, body: b));
    final session = await (await Connection.open(device.connect(chunkSize: 7)))
        .authenticate(const PinCredential('481516'));

    final results = await Future.wait([
      session.request('GET', '/v1/network/status'),
      session.request('PUT', '/v1/wifi/client', {'enabled': true}),
    ]);
    expect(results[0].body, {'interfaces': []});
    expect(results[1].body, {'enabled': true});
    expect(device.requests, ['GET /v1/network/status', 'PUT /v1/wifi/client']);

    final denied = await session.request('POST', '/v1/power/reboot');
    expect(denied.code, 'not-allowed');
  });

  test('an unknown phone credential fails', () async {
    final device = FakeDevice(pin: '481516');
    final connection = await Connection.open(device.connect());
    await expectLater(
      connection.authenticate(PhoneCredential('nope', base64.decode('AAAA'))),
      throwsA(isA<ProtocolException>().having((e) => e.code, 'code', 'auth-failed')),
    );
  });

  test('closing ends the session and refuses further requests', () async {
    final device = FakeDevice(pin: '481516');
    final session = await (await Connection.open(device.connect()))
        .authenticate(const PinCredential('481516'));
    await session.close();
    await expectLater(session.closed, completion(isA<ProtocolException>()));
    await expectLater(session.request('GET', '/v1/network/status'), throwsA(isA<ProtocolException>()));
  });

  test('a request in flight fails when the device closes', () async {
    final device = FakeDevice(pin: '481516')
      ..routes['GET /v1/network/status'] = ((m, p, b) => throw StateError('device crashed'));
    final session = await (await Connection.open(device.connect()))
        .authenticate(const PinCredential('481516'));
    await expectLater(session.request('GET', '/v1/network/status'), throwsA(isA<ProtocolException>()));
  });
}
