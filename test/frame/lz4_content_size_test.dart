import 'dart:typed_data';

import 'package:dart_lz4/dart_lz4.dart';
import 'package:dart_lz4/src/xxhash/xxh32.dart';
import 'package:test/test.dart';

void main() {
  group('lz4FrameInfo contentSize', () {
    test('reads valid 64-bit content size > 4GB', () {
      final base = lz4FrameEncodeWithOptions(
        Uint8List(0),
        options: Lz4FrameOptions(contentSize: 0, contentChecksum: false),
      );

      final patched = Uint8List.fromList(base);
      // Set size to 5GB: 0x0000000140000000 (Little Endian)
      // 00 00 00 40 01 00 00 00
      patched[6] = 0x00;
      patched[7] = 0x00;
      patched[8] = 0x00;
      patched[9] = 0x40;
      patched[10] = 0x01;
      patched[11] = 0x00;
      patched[12] = 0x00;
      patched[13] = 0x00;

      // Recompute HC
      // Descriptor is from offset 4 to 14 (exclusive of HC at 14)
      // Length = 1 (FLG) + 1 (BD) + 8 (Size) = 10 bytes.
      final descriptor = patched.sublist(4, 14);
      final hc = (xxh32(descriptor, seed: 0) >> 8) & 0xFF;
      patched[14] = hc;

      final info = lz4FrameInfo(patched);
      // 5 * 1024^3 = 5368709120
      expect(info.contentSize, 5368709120);
    });
  });
}
