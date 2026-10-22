import 'dart:typed_data';

// Every message on session, command and event travels as fragments: a 3-byte
// header (seq, big-endian; flags, bit 0 = last) and up to size - 3 bytes.

const maxMessage = 16384;
const _header = 3;

List<Uint8List> fragment(List<int> message, int size) {
  final body = size - _header;
  if (body < 1) throw ArgumentError('fragment size $size is too small');
  if (message.length > maxMessage) throw ArgumentError('message too long');
  final out = <Uint8List>[];
  for (var seq = 0, off = 0; seq == 0 || off < message.length; seq++, off += body) {
    final end = off + body >= message.length ? message.length : off + body;
    out.add(
      Uint8List(_header + end - off)
        ..[0] = seq >> 8
        ..[1] = seq & 0xff
        ..[2] = end == message.length ? 1 : 0
        ..setRange(_header, _header + end - off, message, off),
    );
  }
  return out;
}

/// Joins one direction's fragments back into messages.
class Reassembler {
  final _parts = BytesBuilder();
  int _next = 0;

  /// The whole message once its last fragment arrives, otherwise null.
  /// Throws [FormatException] for a broken stream and starts over.
  Uint8List? push(List<int> f) {
    if (f.length < _header || f[2] & ~1 != 0) _fail('malformed fragment');
    final seq = f[0] << 8 | f[1];
    if (seq != _next) _fail('fragment $seq out of order');
    if (_parts.length + f.length - _header > maxMessage) _fail('message too long');
    _parts.add(f.sublist(_header));
    _next++;
    if (f[2] & 1 == 0) return null;
    _next = 0;
    return _parts.takeBytes();
  }

  Never _fail(String why) {
    _parts.clear();
    _next = 0;
    throw FormatException(why);
  }
}
