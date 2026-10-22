import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mica_app/protocol/bytes.dart';
import 'package:mica_app/protocol/keys.dart';

void main() {
  test('RFC 8439 2.8.2 AEAD vector', () {
    final key = fromHex('808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f');
    final nonce = fromHex('070000004041424344454647');
    final aad = fromHex('50515253c0c1c2c3c4c5c6c7');
    final plaintext = utf8.encode("Ladies and Gentlemen of the class of '99: If I could offer you "
        'only one tip for the future, sunscreen would be it.');
    final sealed = aeadSeal(key, nonce, aad, plaintext);
    expect(hex(sealed.sublist(0, 16)), 'd31a8d34648e60db7b86afbc53ef7ec2');
    expect(hex(sealed.sublist(sealed.length - 16)), '1ae10b594f09e26a7e902ecbd0600691');
    expect(aeadOpen(key, nonce, aad, sealed), plaintext);
    expect(() => aeadOpen(key, nonce, Uint8List(0), sealed), throwsFormatException);
  });

  test('sealed messages open in order, and only once', () {
    final key = Uint8List.fromList(List.generate(32, (i) => i));
    final out = Sealer(key);
    final into = Sealer(key);
    for (final text in ['{"a":1}', 'x' * 300, '{}']) {
      final sealed = out.seal(utf8.encode(text));
      expect(sealed.length, text.length + 16);
      expect(utf8.decode(into.open(sealed)), text);
    }
    final replay = out.seal(utf8.encode('again'));
    into.open(replay);
    expect(() => into.open(replay), throwsFormatException);
  });

  test('a flipped bit does not open', () {
    final key = Uint8List(32);
    final sealed = Sealer(key).seal(utf8.encode('hello'))..[0] ^= 1;
    expect(() => Sealer(key).open(sealed), throwsFormatException);
  });
}
