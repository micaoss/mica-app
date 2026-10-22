import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mica_app/protocol/framing.dart';

void main() {
  test('messages survive any chunking', () {
    final a = Uint8List.fromList(List.generate(300, (i) => i % 256));
    final b = Uint8List.fromList([7]);
    final stream = Uint8List.fromList([...frame(a), ...frame(b)]);
    for (final size in [1, 3, 20, 182, 1000]) {
      final deframer = Deframer();
      final out = [for (final c in chunks(stream, size)) ...deframer.add(c)];
      expect(out, [a, b], reason: 'chunk size $size');
    }
  });

  test('a zero or oversized length is refused', () {
    expect(() => Deframer().add([0, 0, 0, 0]), throwsFormatException);
    expect(() => Deframer().add([0, 1, 0, 1]), throwsFormatException);
    expect(() => frame([]), throwsArgumentError);
    expect(() => frame(Uint8List(maxMessageLength + 1)), throwsArgumentError);
  });

  test('a partial message waits for the rest', () {
    final deframer = Deframer();
    expect(deframer.add([0, 0, 0, 2, 9]), isEmpty);
    expect(deframer.add([8]), [
      [9, 8]
    ]);
  });
}
