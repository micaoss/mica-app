import 'dart:convert';
import 'dart:typed_data';

String hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Uint8List fromHex(String text) {
  if (text.length.isOdd) throw const FormatException('odd hex length');
  final out = Uint8List(text.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(text.substring(2 * i, 2 * i + 2), radix: 16);
  }
  return out;
}

Uint8List utf8Bytes(String text) => Uint8List.fromList(utf8.encode(text));

Uint8List concat(List<List<int>> parts) {
  final out = BytesBuilder(copy: false);
  for (final p in parts) {
    out.add(p);
  }
  return out.toBytes();
}

/// Big-endian bytes of [value], left-padded to [length].
Uint8List bigIntBytes(BigInt value, int length) {
  final out = Uint8List(length);
  var v = value;
  for (var i = length - 1; i >= 0; i--) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  if (v != BigInt.zero) throw ArgumentError('value does not fit in $length bytes');
  return out;
}

BigInt bytesBigInt(List<int> bytes) {
  var v = BigInt.zero;
  for (final b in bytes) {
    v = (v << 8) | BigInt.from(b);
  }
  return v;
}

/// `len(S) || S`: an 8-byte little-endian length, then the bytes.
Uint8List len8(List<int> bytes) {
  final len = ByteData(8)..setUint64(0, bytes.length, Endian.little);
  return concat([len.buffer.asUint8List(), bytes]);
}

/// Compares in time independent of where the first difference is.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
