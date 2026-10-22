import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'bytes.dart';
import 'spake2.dart';

const protocolVersion = 1;
const spakeAad = 'mica-ble/1';

/// SPAKE2's w for a device and a secret (protocol section 4).
BigInt passwordScalar(String deviceId, List<int> secret) {
  final input = BytesBuilder();
  writeLengthPrefixed(input, utf8.encode('mica-ble/1 w'));
  writeLengthPrefixed(input, utf8.encode(deviceId));
  writeLengthPrefixed(input, secret);
  return bytesBigInt(SHA512Digest().process(input.toBytes())) % p256Order;
}

/// The two directional session keys derived from SPAKE2's Ke (section 5).
({Uint8List phoneToDevice, Uint8List deviceToPhone}) sessionKeys(List<int> ke) => (
      phoneToDevice: hkdfSha256(ke, utf8.encode('mica-ble/1 phone->device'), 32),
      deviceToPhone: hkdfSha256(ke, utf8.encode('mica-ble/1 device->phone'), 32),
    );

/// One direction of the sealed session: ChaCha20-Poly1305 with a counter nonce.
class Sealer {
  Sealer(this._key);

  final Uint8List _key;
  int _counter = 0;

  Uint8List _nonce() {
    final nonce = ByteData(12)..setUint64(4, _counter++);
    return nonce.buffer.asUint8List();
  }

  Uint8List seal(List<int> plaintext) => aeadSeal(_key, _nonce(), const [], plaintext);

  /// Throws [FormatException] when the message does not authenticate.
  Uint8List open(List<int> sealed) => aeadOpen(_key, _nonce(), const [], sealed);
}

const _tagLength = 16;

/// AEAD_CHACHA20_POLY1305 (RFC 8439 section 2.8): ciphertext, then the tag.
Uint8List aeadSeal(List<int> key, List<int> nonce, List<int> aad, List<int> plaintext) {
  final (otk, cipher) = _start(key, nonce);
  final out = Uint8List(plaintext.length + _tagLength);
  cipher.processBytes(Uint8List.fromList(plaintext), 0, plaintext.length, out, 0);
  final ciphertext = Uint8List.sublistView(out, 0, plaintext.length);
  out.setRange(plaintext.length, out.length, _tag(otk, aad, ciphertext));
  return out;
}

/// Opens what [aeadSeal] sealed. Throws [FormatException] when the tag does
/// not match; nothing is decrypted then.
Uint8List aeadOpen(List<int> key, List<int> nonce, List<int> aad, List<int> sealed) {
  if (sealed.length < _tagLength) throw const FormatException('sealed message too short');
  final ciphertext = Uint8List.fromList(sealed.sublist(0, sealed.length - _tagLength));
  final (otk, cipher) = _start(key, nonce);
  if (!constantTimeEquals(_tag(otk, aad, ciphertext), sealed.sublist(ciphertext.length))) {
    throw const FormatException('sealed message does not authenticate');
  }
  final out = Uint8List(ciphertext.length);
  cipher.processBytes(ciphertext, 0, ciphertext.length, out, 0);
  return out;
}

/// The Poly1305 one-time key from block 0, and the cipher positioned at block 1.
(Uint8List, ChaCha7539Engine) _start(List<int> key, List<int> nonce) {
  final cipher = ChaCha7539Engine()
    ..init(true, ParametersWithIV(KeyParameter(Uint8List.fromList(key)), Uint8List.fromList(nonce)));
  final block = Uint8List(64);
  cipher.processBytes(Uint8List(64), 0, 64, block, 0);
  return (Uint8List.sublistView(block, 0, 32), cipher);
}

Uint8List _tag(Uint8List otk, List<int> aad, List<int> ciphertext) {
  Uint8List pad(int n) => Uint8List((16 - n % 16) % 16);
  final lengths = ByteData(16)
    ..setUint64(0, aad.length, Endian.little)
    ..setUint64(8, ciphertext.length, Endian.little);
  final data = Uint8List.fromList([
    ...aad,
    ...pad(aad.length),
    ...ciphertext,
    ...pad(ciphertext.length),
    ...lengths.buffer.asUint8List(),
  ]);
  final mac = Poly1305()..init(KeyParameter(otk));
  return mac.process(data);
}
