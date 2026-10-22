/// SPAKE2-P256-SHA256-HKDF-HMAC (RFC 9382).
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'bytes.dart';

final _curve = ECCurve_secp256r1();
final _p = BigInt.parse(
    'ffffffff00000001000000000000000000000000ffffffffffffffffffffffff',
    radix: 16);
final _b = BigInt.parse(
    '5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b',
    radix: 16);

final _m = _curve.curve.decodePoint(fromHex(
    '02886e2f97ace46e55ba9dd7242579f2993b64e16ef3dcab95afd497333d8fa12f'))!;
final _n = _curve.curve.decodePoint(fromHex(
    '03d8bbd6c639c62937b04d997f38c3770719c629d7014d49a24b4f98baa1292b49'))!;

/// The order of P-256, which a password scalar is reduced by.
BigInt get p256Order => _curve.n;

const _pointLength = 65;
const _scalarLength = 32;

/// One side of a SPAKE2 exchange.
class Spake2 {
  Spake2._(this._isA, this._idA, this._idB, this._w, BigInt? scalar)
      : _x = scalar ?? _randomScalar() {
    final own = _isA ? _m : _n;
    message = ((_curve.G * _x)! + (own * _w))!.getEncoded(false);
  }

  /// Party A, who sends first.
  factory Spake2.a(List<int> idA, List<int> idB, BigInt w, {BigInt? scalar}) =>
      Spake2._(true, idA, idB, w, scalar);

  /// Party B, who answers.
  factory Spake2.b(List<int> idA, List<int> idB, BigInt w, {BigInt? scalar}) =>
      Spake2._(false, idA, idB, w, scalar);

  final bool _isA;
  final List<int> _idA, _idB;
  final BigInt _w;
  final BigInt _x;

  /// pA or pB, uncompressed SEC1.
  late final Uint8List message;

  /// Derive the keys from the peer's message. Throws [FormatException] for a
  /// point that is not on the curve.
  Spake2Keys finish(List<int> peer, {List<int> aad = const []}) {
    final peerPoint = decodeCurvePoint(peer);
    final other = _isA ? _n : _m;
    final k = (peerPoint - (other * _w)!)! * _x;
    if (k == null || k.isInfinity) throw const FormatException('degenerate point');

    final pA = _isA ? message : Uint8List.fromList(peer);
    final pB = _isA ? Uint8List.fromList(peer) : message;
    final tt = BytesBuilder();
    writeLengthPrefixed(tt, _idA);
    writeLengthPrefixed(tt, _idB);
    writeLengthPrefixed(tt, pA);
    writeLengthPrefixed(tt, pB);
    writeLengthPrefixed(tt, k.getEncoded(false));
    writeLengthPrefixed(tt, bigIntBytes(_w, _scalarLength));
    final transcript = tt.toBytes();

    final hash = SHA256Digest().process(transcript);
    final ke = hash.sublist(0, 16);
    final ka = hash.sublist(16);
    final info = Uint8List.fromList([...'ConfirmationKeys'.codeUnits, ...aad]);
    final kc = hkdfSha256(ka, info, 32);
    final kcA = kc.sublist(0, 16);
    final kcB = kc.sublist(16);
    return Spake2Keys._(_isA, ke, kcA, kcB, transcript);
  }
}

/// What a finished exchange yields.
class Spake2Keys {
  Spake2Keys._(this._isA, this.ke, this.kcA, this.kcB, this._transcript);

  final bool _isA;
  final Uint8List _transcript;

  /// The shared secret.
  final Uint8List ke;
  final Uint8List kcA, kcB;

  /// cA for party A, cB for party B.
  Uint8List get confirmation => _mac(_isA ? kcA : kcB, _transcript);

  /// Whether [peer] is the other party's confirmation.
  bool verify(List<int> peer) => constantTimeEquals(_mac(_isA ? kcB : kcA, _transcript), peer);
}

/// Decode an uncompressed P-256 point and check it lies on the curve.
ECPoint decodeCurvePoint(List<int> bytes) {
  if (bytes.length != _pointLength || bytes[0] != 0x04) {
    throw const FormatException('not an uncompressed P-256 point');
  }
  final x = bytesBigInt(bytes.sublist(1, 33));
  final y = bytesBigInt(bytes.sublist(33));
  if (x >= _p || y >= _p) throw const FormatException('coordinate out of range');
  final rhs = (x * x * x - BigInt.from(3) * x + _b) % _p;
  if ((y * y) % _p != rhs) throw const FormatException('point not on the curve');
  return _curve.curve.decodePoint(bytes)!;
}

Uint8List hkdfSha256(List<int> ikm, List<int> info, int length) {
  final hkdf = HKDFKeyDerivator(SHA256Digest())
    ..init(HkdfParameters(Uint8List.fromList(ikm), length, null, Uint8List.fromList(info)));
  return hkdf.process(Uint8List(0));
}

Uint8List _mac(List<int> key, List<int> data) {
  final hmac = HMac(SHA256Digest(), 64)..init(KeyParameter(Uint8List.fromList(key)));
  return hmac.process(Uint8List.fromList(data));
}

final _random = Random.secure();

BigInt _randomScalar() {
  final n = _curve.n;
  while (true) {
    final bytes = List<int>.generate(_scalarLength, (_) => _random.nextInt(256));
    final v = bytesBigInt(bytes);
    if (v > BigInt.zero && v < n) return v;
  }
}
