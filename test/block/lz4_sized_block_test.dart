import 'dart:typed_data';

import 'package:dart_lz4/dart_lz4.dart';
import 'package:test/test.dart';

void main() {
  group('lz4CompressWithSize / lz4DecompressWithSize', () {
    test('round trip', () {
      final src = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final compressed = lz4CompressWithSize(src);

      // Header check
      final view = ByteData.view(compressed.buffer);
      expect(view.getUint32(0, Endian.little), src.length);
      expect(compressed.length, greaterThan(4));

      final decompressed = lz4DecompressWithSize(compressed);
      expect(decompressed, src);
    });

    test('round trip (empty)', () {
      final src = Uint8List(0);
      final compressed = lz4CompressWithSize(src);

      expect(compressed.length, 4); // Just header
      final view = ByteData.view(compressed.buffer);
      expect(view.getUint32(0, Endian.little), 0);

      final decompressed = lz4DecompressWithSize(compressed);
      expect(decompressed, isEmpty);
    });

    test('round trip (HC)', () {
      final src = Uint8List.fromList(List.generate(1000, (i) => i % 10));
      final compressed =
          lz4CompressWithSize(src, level: Lz4CompressionLevel.hc);

      final decompressed = lz4DecompressWithSize(compressed);
      expect(decompressed, src);
    });

    test('throws on truncated input', () {
      final src = Uint8List.fromList([1, 2, 3]);
      expect(
          () => lz4DecompressWithSize(src), throwsA(isA<Lz4FormatException>()));
    });

    test('throws on truncated compressed data', () {
      final src = Uint8List.fromList(List.generate(100, (i) => i));
      final compressed = lz4CompressWithSize(src);
      final truncated = compressed.sublist(0, compressed.length - 1);

      // The underlying lz4BlockDecompress should throw on truncation
      expect(() => lz4DecompressWithSize(truncated),
          throwsA(isA<Lz4FormatException>()));
    });
  });
}
