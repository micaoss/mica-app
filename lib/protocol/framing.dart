import 'dart:typed_data';

const maxMessageLength = 65536;

/// A message with its 4-byte big-endian length in front.
Uint8List frame(List<int> message) {
  if (message.isEmpty || message.length > maxMessageLength) {
    throw ArgumentError('message length ${message.length} out of range');
  }
  final out = Uint8List(4 + message.length);
  ByteData.sublistView(out).setUint32(0, message.length);
  out.setRange(4, out.length, message);
  return out;
}

/// Cut [bytes] into chunks of at most [size].
Iterable<Uint8List> chunks(Uint8List bytes, int size) sync* {
  for (var i = 0; i < bytes.length; i += size) {
    yield Uint8List.sublistView(bytes, i, i + size > bytes.length ? bytes.length : i + size);
  }
}

/// Reassembles messages from chunks cut at arbitrary points.
class Deframer {
  final _buffer = BytesBuilder();

  /// Add a chunk; returns the messages it completes. Throws
  /// [FormatException] for a length out of range.
  List<Uint8List> add(List<int> chunk) {
    _buffer.add(chunk);
    final messages = <Uint8List>[];
    var data = _buffer.takeBytes();
    var offset = 0;
    while (data.length - offset >= 4) {
      final length = ByteData.sublistView(data, offset, offset + 4).getUint32(0);
      if (length == 0 || length > maxMessageLength) {
        throw FormatException('message length $length out of range');
      }
      if (data.length - offset - 4 < length) break;
      messages.add(Uint8List.fromList(data.sublist(offset + 4, offset + 4 + length)));
      offset += 4 + length;
    }
    _buffer.add(data.sublist(offset));
    return messages;
  }
}
