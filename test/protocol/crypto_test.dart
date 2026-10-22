import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mica_app/protocol/bytes.dart';
import 'package:mica_app/protocol/crypto.dart';
import 'package:mica_app/protocol/fragments.dart';

import '../support/verifier.dart';

// The vectors of mica-core docs/ble-provisioning.md, extracted by
// tools/extract_vectors.py.
final Map<String, dynamic> vectors = jsonDecode(File('test/protocol/vectors.json').readAsStringSync());

BigInt big(String h) => BigInt.parse(h, radix: 16);

void main() {
  test('SPAKE2+ reproduces RFC 9383 Appendix C (P256-SHA256-HKDF-HMAC-SHA256)', () {
    const context = 'SPAKE2+-P256-SHA256-HKDF-SHA256-HMAC-SHA256 Test Vectors';
    final w0 = big('bb8e1bbcf3c48f62c08db243652ae55d3e5586053fca77102994f23ad95491b3');
    final w1 = big('7e945f34d78785b8a3ef44d0df5a1a97d6b3b460409a345ca7830387a74b1dba');
    final l = (p256G * w1)!;
    expect(
      hex(encodePoint(l)),
      '04eb7c9db3d9a9eb1f8adab81b5794c1f13ae3e225efbe91ea487425854c7fc00f00bfedcbd09b2400142d40a14f2064ef31dfaa903b91d1faea7093d835966efd',
    );
    final prover = SpakeProver(
      context,
      w0,
      w1,
      x: big('d1232c8e8693d02368976c174e2088851b8365d0d79a9eee709c6a05a2fad539'),
      prover: 'client',
      verifier: 'server',
    );
    expect(
      hex(prover.shareP),
      '04ef3bd051bf78a2234ec0df197f7828060fe9856503579bb1733009042c15c0c1de127727f418b5966afadfdd95a6e4591d171056b333dab97a79c7193e341727',
    );
    final y = big('717a72348a182085109c8d3917d6c43d59b224dc6a7fc4f0483232fa6516d8b3');
    final shareV = encodePoint(((p256G * y)! + (spakeN * w0))!);
    expect(
      hex(shareV),
      '04c0f65da0d11927bdf5d560c69e1d7d939a05b0e88291887d679fcadea75810fb5cc1ca7494db39e82ff2f50665255d76173e09986ab46742c798a9a68437b048',
    );
    const confirmV = '9747bcc4f8fe9f63defee53ac9b07876d907d55047e6ff2def2e7529089d3e68';
    final r = prover.finish(shareV, fromHex(confirmV));
    expect(hex(r.schedule.kMain), '4c59e1ccf2cfb961aa31bd9434478a1089b56cd11542f53d3576fb6c2a438a29');
    expect(hex(r.schedule.kConfirmP), '871ae3f7b78445e34438fb284504240239031c39d80ac23eb5ab9be5ad6db58a');
    expect(hex(r.schedule.kConfirmV), 'ccd53c7c1fa37b64a462b40db8be101cedcf838950162902054e644b400f1680');
    expect(hex(r.confirmP), '926cc713504b9b4d76c9162ded04b5493e89109f6d89462cd33adc46fda27527');
    expect(hex(r.schedule.kShared), '0c5f8ccd1413423a54f6c1fb26ff01534a87f893779c6e68666d772bfd91f3e7');
  });

  for (final (title, mode) in [
    ('SPAKE2+, auth password', SpakeMode.password),
    ('SPAKE2+, auth temp-code', SpakeMode.tempCode),
  ]) {
    test('$title: the document vector, both ends', () {
      final v = vectors[title] as Map<String, dynamic>;
      final pw = v['pw (UTF-8)'] as String;
      final salt = fromHex(v['salt'] as String);
      final iterations = v['iterations'] as int;
      expect(hex(pbkdfInput(pw)), v['PBKDF2 password input']);
      final w = spakeScalars(pw, salt, iterations);
      expect(hex(bigIntBytes(w.w0, 32)), v['w0']);
      expect(hex(bigIntBytes(w.w1, 32)), v['w1']);
      final record = VerifierRecord.register(pw, salt, iterations);
      expect(hex(encodePoint(record.l)), v['L']);

      final prover = SpakeProver(mode.context, w.w0, w.w1, x: big(v['x'] as String));
      expect(hex(prover.shareP), v['shareP']);
      final device = respond(record, mode.context, prover.shareP, y: big(v['y'] as String));
      expect(hex(device.shareV), v['shareV']);
      expect(hex(device.schedule.transcript), v['TT']);
      expect(hex(device.schedule.kMain), v['Kmain']);
      expect(hex(device.confirmV), v['confirmV']);
      expect(hex(device.schedule.kShared), v['Kshared']);

      final r = prover.finish(device.shareV, device.confirmV);
      expect(hex(r.confirmP), v['confirmP']);
      expect(hex(r.schedule.transcript), v['TT']);
      final keys = r.schedule.sessionKeys;
      expect(hex(keys.phoneToDevice), v['kPhoneToDevice']);
      expect(hex(keys.deviceToPhone), v['kDeviceToPhone']);

      // The session messages, as the phone sends and receives them.
      final m = (v['messages'] as List).cast<Map<String, dynamic>>();
      expect(m[0], {'t': 'params', 'salt': base64.encode(salt), 'iterations': iterations});
      expect(m[1], {'t': 'share', 'shareP': base64.encode(prover.shareP)});
      expect(m[2], {
        't': 'share',
        'shareV': base64.encode(device.shareV),
        'confirmV': base64.encode(device.confirmV),
        'attemptsLeft': 4,
      });
      expect(m[3], {'t': 'confirm', 'confirmP': base64.encode(r.confirmP)});
    });
  }

  test('SPAKE2+: a wrong password fails at confirmV', () {
    final salt = Uint8List(16);
    final record = VerifierRecord.register('right-password', salt, 10000);
    final w = spakeScalars('wrong-password', salt, 10000);
    final prover = SpakeProver(SpakeMode.password.context, w.w0, w.w1);
    final device = respond(record, SpakeMode.password.context, prover.shareP);
    expect(() => prover.finish(device.shareV, device.confirmV), throwsA(isA<ConfirmationError>()));
  });

  test('SPAKE2+: a share off the curve is refused', () {
    final prover = SpakeProver(SpakeMode.password.context, BigInt.one, BigInt.two);
    final bad = Uint8List.fromList(prover.shareP)..[64] ^= 1;
    expect(() => prover.finish(bad, Uint8List(32)), throwsFormatException);
    expect(() => prover.finish(Uint8List(65), Uint8List(32)), throwsFormatException);
  });

  test('X25519 reproduces RFC 7748 section 5.2 and 6.1', () {
    expect(
      hex(
        x25519(
          fromHex('a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4'),
          fromHex('e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c'),
        ),
      ),
      'c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552',
    );
    final v = vectors['Auth none (X25519)'] as Map<String, dynamic>;
    final phone = X25519Start(private: fromHex(v['phone private'] as String));
    expect(hex(phone.pub), v['phone public']);
    final devicePub = x25519(fromHex(v['device private'] as String), Uint8List(32)..[0] = 9);
    expect(hex(devicePub), v['device public']);
    expect(hex(x25519(fromHex(v['phone private'] as String), devicePub)), v['shared secret']);
    final keys = phone.finish(devicePub);
    expect(hex(keys.phoneToDevice), v['kPhoneToDevice']);
    expect(hex(keys.deviceToPhone), v['kDeviceToPhone']);
    final m = (v['messages'] as List).cast<Map<String, dynamic>>();
    expect(m[0], {'t': 'start', 'auth': 'none', 'pub': base64.encode(phone.pub)});
    expect(m[1], {'t': 'ready', 'pub': base64.encode(devicePub)});
  });

  test('X25519 refuses an all-zero shared secret', () {
    expect(() => X25519Start().finish(Uint8List(32)), throwsFormatException);
  });

  test('records: the document vector, counters per direction', () {
    final v = vectors['Records (keys of the password vector)'] as Map<String, dynamic>;
    final pairs = (v['pairs'] as List).map((p) => (p as List).cast<String>()).toList();
    final keys = (vectors['SPAKE2+, auth password'] as Map<String, dynamic>);
    final command = RecordCipher(fromHex(keys['kPhoneToDevice'] as String));
    final event = RecordCipher(fromHex(keys['kDeviceToPhone'] as String));
    expect(hex(command.seal(utf8.encode(pairs[0][1]))), pairs[2][1]);
    expect(
      utf8.decode(RecordCipher(fromHex(keys['kDeviceToPhone'] as String)).open(fromHex(pairs[5][1]))),
      pairs[3][1],
    );
    expect(hex(event.seal(utf8.encode(pairs[3][1]))), pairs[5][1]);
    expect(hex(command.seal(utf8.encode('{"id":2,"op":"scanWifi"}'))), pairs[7][1]);
  });

  test('records: a tampered record does not open', () {
    final key = Uint8List(32);
    final record = RecordCipher(key).seal(utf8.encode('{}'))..[0] ^= 1;
    expect(() => RecordCipher(key).open(record), throwsFormatException);
    expect(() => RecordCipher(key).open(Uint8List(3)), throwsFormatException);
  });

  group('fragments', () {
    test('the document vector: the first command record in 20-byte writes', () {
      final v = vectors['Fragments of the first command record, 20-byte writes'] as Map<String, dynamic>;
      final record = fromHex((vectors['Records (keys of the password vector)'] as Map)['record'] as String);
      expect(fragment(record, 20).map(hex).toList(), v['lines']);
    });

    test('one fragment is header 0000 01; reassembly round-trips', () {
      expect(hex(fragment(utf8.encode('{}'), 20).single), '0000017b7d');
      final message = Uint8List.fromList(List.generate(1000, (i) => i & 0xff));
      final r = Reassembler();
      final parts = fragment(message, 23);
      for (final f in parts.take(parts.length - 1)) {
        expect(r.push(f), isNull);
      }
      expect(r.push(parts.last), message);
    });

    test('out of order, bad flags and oversize are refused', () {
      final parts = fragment(Uint8List(100), 20);
      expect(() => Reassembler().push(parts[1]), throwsFormatException);
      expect(() => Reassembler().push(Uint8List.fromList([0, 0, 2, 1])), throwsFormatException);
      final r = Reassembler();
      expect(() {
        for (var seq = 0; ; seq++) {
          r.push(
            Uint8List(512)
              ..[0] = seq >> 8
              ..[1] = seq & 0xff,
          );
        }
      }, throwsFormatException);
      expect(() => fragment(Uint8List(maxMessage + 1), 20), throwsArgumentError);
    });
  });
}
