import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mica_app/protocol/bytes.dart';
import 'package:mica_app/protocol/keys.dart';
import 'package:mica_app/protocol/spake2.dart';

/// Recomputes every value in vectors.json, which mica-bled checks too.
Map<String, Object> compute() {
  const deviceId = '00112233445566778899aabbccddeeff';
  final phoneSecret = List.generate(32, (i) => i);
  final wPin = passwordScalar(deviceId, utf8.encode('000000'));
  final wPhone = passwordScalar(deviceId, phoneSecret);

  final x = BigInt.parse('43dd0fd7215bdcb482879fca3220c6a968e66d70b1356cac18bb26c84a78d729', radix: 16);
  final y = BigInt.parse('dcb60106f276b02606d8ef0a328c02e4b629f84f89786af5befb0bc75b6e66be', radix: 16);
  final idA = utf8.encode('pin');
  final idB = utf8.encode(deviceId);
  final a = Spake2.a(idA, idB, wPin, scalar: x);
  final b = Spake2.b(idA, idB, wPin, scalar: y);
  final keysA = a.finish(b.message, aad: utf8.encode(spakeAad));
  final keysB = b.finish(a.message, aad: utf8.encode(spakeAad));
  final session = sessionKeys(keysA.ke);

  const request = '{"t":"req","id":1,"method":"GET","path":"/v1/network/status"}';
  final sealer = Sealer(session.phoneToDevice);
  return {
    'deviceId': deviceId,
    'pin': '000000',
    'wPin': hex(bigIntBytes(wPin, 32)),
    'phoneSecret': hex(phoneSecret),
    'wPhone': hex(bigIntBytes(wPhone, 32)),
    'spake2': {
      'idA': 'pin',
      'idB': deviceId,
      'aad': spakeAad,
      'x': hex(bigIntBytes(x, 32)),
      'y': hex(bigIntBytes(y, 32)),
      'pA': hex(a.message),
      'pB': hex(b.message),
      'ke': hex(keysA.ke),
      'cA': hex(keysA.confirmation),
      'cB': hex(keysB.confirmation),
    },
    'session': {
      'phoneToDevice': hex(session.phoneToDevice),
      'deviceToPhone': hex(session.deviceToPhone),
      'plaintext': request,
      'sealedCounter0': hex(sealer.seal(utf8.encode(request))),
      'sealedCounter1': hex(sealer.seal(utf8.encode(request))),
    },
  };
}

void main() {
  test('vectors.json matches this implementation', () {
    final file = File('test/protocol/vectors.json');
    final computed = compute();
    if (Platform.environment['WRITE_VECTORS'] == '1') {
      file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(computed)}\n');
    }
    expect(jsonDecode(file.readAsStringSync()), computed);
  });
}
