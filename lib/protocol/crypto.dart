/// The cryptography of protocol 1 (mica-core docs/ble-provisioning.md):
/// X25519 for `none`, SPAKE2+ (RFC 9383, P256-SHA256-HKDF-SHA256-HMAC-SHA256)
/// for `password` and `temp-code`, AES-256-GCM records.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'bytes.dart';

const idProver = 'mica-provisioning phone';
const idVerifier = 'mica-provisioning device';
const _keysInfo = 'mica-provisioning/1 session keys';
final _recordAad = utf8Bytes('mica-provisioning/1');

typedef SessionKeys = ({Uint8List phoneToDevice, Uint8List deviceToPhone});

enum SpakeMode {
  password('password'),
  tempCode('temp-code');

  const SpakeMode(this.wire);
  final String wire;

  String get context => 'mica-provisioning/1 $wire';
}

// --- primitives -------------------------------------------------------------

Uint8List sha256(List<int> data) => SHA256Digest().process(Uint8List.fromList(data));

Uint8List hmacSha256(List<int> key, List<int> data) =>
    (HMac(SHA256Digest(), 64)..init(KeyParameter(Uint8List.fromList(key)))).process(Uint8List.fromList(data));

/// HKDF-SHA256; a null [salt] is HashLen zero bytes (RFC 5869).
Uint8List hkdf(List<int>? salt, List<int> ikm, String info, int length) =>
    (HKDFKeyDerivator(SHA256Digest())..init(
          HkdfParameters(
            Uint8List.fromList(ikm),
            length,
            salt == null ? null : Uint8List.fromList(salt),
            utf8Bytes(info),
          ),
        ))
        .process(Uint8List(0));

final _random = Random.secure();

Uint8List randomBytes(int n) => Uint8List.fromList(List.generate(n, (_) => _random.nextInt(256)));

SessionKeys _split(Uint8List k) =>
    (phoneToDevice: Uint8List.sublistView(k, 0, 32), deviceToPhone: Uint8List.sublistView(k, 32));

// --- X25519 (RFC 7748) ------------------------------------------------------

final _p25519 = (BigInt.one << 255) - BigInt.from(19);
final _a24 = BigInt.from(121665);

BigInt _le(List<int> b) => bytesBigInt(b.reversed.toList());

/// X25519(k, u). Arithmetic on BigInt, not constant time.
Uint8List x25519(List<int> k, List<int> u) {
  if (k.length != 32 || u.length != 32) throw ArgumentError('X25519 takes 32-byte inputs');
  final p = _p25519;
  final s = Uint8List.fromList(k);
  s[0] &= 248;
  s[31] = (s[31] & 127) | 64;
  final scalar = _le(s);
  final x1 = _le(Uint8List.fromList(u)..[31] &= 127) % p;
  var x2 = BigInt.one, z2 = BigInt.zero, x3 = x1, z3 = BigInt.one;
  var swap = 0;
  for (var t = 254; t >= 0; t--) {
    final bit = ((scalar >> t) & BigInt.one).toInt();
    if (swap ^ bit == 1) {
      (x2, x3) = (x3, x2);
      (z2, z3) = (z3, z2);
    }
    swap = bit;
    final a = (x2 + z2) % p, aa = a * a % p;
    final b = (x2 - z2) % p, bb = b * b % p;
    final e = (aa - bb) % p;
    final c = (x3 + z3) % p, d = (x3 - z3) % p;
    final da = d * a % p, cb = c * b % p;
    x3 = (da + cb) * (da + cb) % p;
    z3 = x1 * ((da - cb) * (da - cb) % p) % p;
    x2 = aa * bb % p;
    z2 = e * ((aa + _a24 * e) % p) % p;
  }
  if (swap == 1) {
    (x2, x3) = (x3, x2);
    (z2, z3) = (z3, z2);
  }
  final x = x2 * z2.modPow(p - BigInt.two, p) % p;
  return Uint8List.fromList(bigIntBytes(x, 32).reversed.toList());
}

final _basepoint25519 = Uint8List(32)..[0] = 9;

/// The phone's side of `auth: none`.
class X25519Start {
  X25519Start({List<int>? private}) : _private = Uint8List.fromList(private ?? randomBytes(32)) {
    pub = x25519(_private, _basepoint25519);
  }

  final Uint8List _private;
  late final Uint8List pub;

  /// The session keys from the device's public key. Throws [FormatException]
  /// for an all-zero shared secret.
  SessionKeys finish(List<int> devicePub) {
    if (devicePub.length != 32) throw const FormatException('device key is not 32 bytes');
    final s = x25519(_private, devicePub);
    if (s.every((b) => b == 0)) throw const FormatException('all-zero shared secret');
    final salt = sha256(concat([utf8Bytes('mica-provisioning/1 none'), pub, devicePub]));
    return _split(hkdf(salt, s, _keysInfo, 64));
  }
}

// --- P-256 and SPAKE2+ (RFC 9383) --------------------------------------------

final _curve = ECCurve_secp256r1();
final _fieldP = BigInt.parse('ffffffff00000001000000000000000000000000ffffffffffffffffffffffff', radix: 16);
final _b = BigInt.parse('5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b', radix: 16);

/// The order of P-256.
BigInt get p256Order => _curve.n;
ECPoint get p256G => _curve.G;

/// RFC 9383 section 4.
final spakeM = _curve.curve.decodePoint(fromHex('02886e2f97ace46e55ba9dd7242579f2993b64e16ef3dcab95afd497333d8fa12f'))!;
final spakeN = _curve.curve.decodePoint(fromHex('03d8bbd6c639c62937b04d997f38c3770719c629d7014d49a24b4f98baa1292b49'))!;

Uint8List encodePoint(ECPoint p) => p.getEncoded(false);

/// An uncompressed P-256 point, checked to lie on the curve.
ECPoint decodePoint(List<int> bytes) {
  if (bytes.length != 65 || bytes[0] != 0x04) throw const FormatException('not an uncompressed P-256 point');
  final x = bytesBigInt(bytes.sublist(1, 33));
  final y = bytesBigInt(bytes.sublist(33));
  if (x >= _fieldP || y >= _fieldP) throw const FormatException('coordinate out of range');
  if ((y * y - (x * x * x - BigInt.from(3) * x + _b)) % _fieldP != BigInt.zero) {
    throw const FormatException('point not on P-256');
  }
  return _curve.curve.decodePoint(bytes)!;
}

/// The PBKDF2 input of the mica profile: `len(pw) || pw || len(idProver) ||
/// idProver || len(idVerifier) || idVerifier`.
Uint8List pbkdfInput(String pw) =>
    concat([len8(utf8Bytes(pw)), len8(utf8Bytes(idProver)), len8(utf8Bytes(idVerifier))]);

/// w0 and w1 from a password, the device's salt and iteration count.
({BigInt w0, BigInt w1}) spakeScalars(String pw, List<int> salt, int iterations) {
  final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(Uint8List.fromList(salt), iterations, 80));
  final out = kdf.process(pbkdfInput(pw));
  return (w0: bytesBigInt(out.sublist(0, 40)) % p256Order, w1: bytesBigInt(out.sublist(40)) % p256Order);
}

/// Everything RFC 9383 section 3.4 derives from the transcript.
class SpakeSchedule {
  SpakeSchedule._(this.transcript, this.kMain, this.kConfirmP, this.kConfirmV, this.kShared);

  factory SpakeSchedule(
    String context,
    Uint8List shareP,
    Uint8List shareV,
    ECPoint z,
    ECPoint v,
    BigInt w0, {
    String prover = idProver,
    String verifier = idVerifier,
  }) {
    final tt = concat([
      len8(utf8Bytes(context)),
      len8(utf8Bytes(prover)),
      len8(utf8Bytes(verifier)),
      len8(encodePoint(spakeM)),
      len8(encodePoint(spakeN)),
      len8(shareP),
      len8(shareV),
      len8(encodePoint(z)),
      len8(encodePoint(v)),
      len8(bigIntBytes(w0, 32)),
    ]);
    final kMain = sha256(tt);
    final conf = hkdf(null, kMain, 'ConfirmationKeys', 64);
    return SpakeSchedule._(tt, kMain, conf.sublist(0, 32), conf.sublist(32), hkdf(null, kMain, 'SharedKey', 32));
  }

  final Uint8List transcript, kMain, kConfirmP, kConfirmV, kShared;

  Uint8List confirmP(Uint8List shareV) => hmacSha256(kConfirmP, shareV);
  Uint8List confirmV(Uint8List shareP) => hmacSha256(kConfirmV, shareP);

  SessionKeys get sessionKeys => _split(hkdf(null, kShared, _keysInfo, 64));
}

/// The device's confirmation did not match: the password or code is wrong.
class ConfirmationError implements Exception {
  @override
  String toString() => 'SPAKE2+ confirmation mismatch';
}

BigInt randomScalar() {
  while (true) {
    final v = bytesBigInt(randomBytes(32));
    if (v > BigInt.zero && v < p256Order) return v;
  }
}

/// The Prover (the phone). [prover] and [verifier] are fixed by the protocol;
/// the RFC's own vector uses others.
class SpakeProver {
  SpakeProver(this.context, this.w0, this.w1, {BigInt? x, this.prover = idProver, this.verifier = idVerifier})
    : _x = x ?? randomScalar() {
    shareP = encodePoint(((p256G * _x)! + (spakeM * w0))!);
  }

  final String context, prover, verifier;
  final BigInt w0, w1;
  final BigInt _x;
  late final Uint8List shareP;

  /// Checks the device's share and confirmation; returns confirmP and the
  /// keys. Throws [FormatException] for a bad share, [ConfirmationError] for
  /// a wrong password.
  ({Uint8List confirmP, SpakeSchedule schedule}) finish(List<int> shareVBytes, List<int> confirmV) {
    final y = decodePoint(shareVBytes);
    if (y.isInfinity) throw const FormatException('shareV is the identity');
    final shareV = Uint8List.fromList(shareVBytes);
    final yn = (y - (spakeN * w0)!)!;
    final z = (yn * _x)!, v = (yn * w1)!;
    if (z.isInfinity || v.isInfinity) throw const FormatException('degenerate point');
    final s = SpakeSchedule(context, shareP, shareV, z, v, w0, prover: prover, verifier: verifier);
    if (!constantTimeEquals(s.confirmV(shareP), confirmV)) throw ConfirmationError();
    return (confirmP: s.confirmP(shareV), schedule: s);
  }
}

// --- records ----------------------------------------------------------------

/// One direction of a session: AES-256-GCM with a counter nonce.
class RecordCipher {
  RecordCipher(this._key);

  final Uint8List _key;
  int _counter = 0;

  GCMBlockCipher _cipher(bool encrypt) {
    final nonce = ByteData(12)..setUint64(4, _counter++);
    return GCMBlockCipher(AESEngine())
      ..init(encrypt, AEADParameters(KeyParameter(_key), 128, nonce.buffer.asUint8List(), _recordAad));
  }

  Uint8List seal(List<int> plaintext) => _cipher(true).process(Uint8List.fromList(plaintext));

  /// Throws [FormatException] when the record does not authenticate.
  Uint8List open(List<int> record) {
    try {
      return _cipher(false).process(Uint8List.fromList(record));
    } on InvalidCipherTextException {
      throw const FormatException('record does not authenticate');
    } on ArgumentError {
      throw const FormatException('record too short');
    }
  }
}
