import 'dart:typed_data';

import 'package:dart_lz4/dart_lz4.dart';
import 'package:test/test.dart';

void main() {
  group('lz4FrameInfo', () {
    test('parses standard frame header', () {
      // Magic (4) + FLG (1) + BD (1) + HC (1) = 7 bytes minimum
      // FLG: Version(01)=0x40, Independent(1)=0x20, ContentChecksum(0)=0, ContentSize(0)=0, DictId(0)=0
      //      -> 0x60
      // BD: MaxSize(64KB=4)=0x40 -> 0x40
      // Descriptor: 60 40
      // HC: xxh32(60 40) >> 8 & 0xFF

      // Calculate valid HC
      // xxh32([0x60, 0x40]) -> 
      // Manual check or let the code run.
      // Wait, I need a valid frame.
      // Let's use lz4FrameEncode to generate one.

      final encoded = lz4FrameEncodeWithOptions(Uint8List(0),
          options: Lz4FrameOptions(
            blockIndependence: true,
            contentChecksum: false,
            contentSize: null,
            blockChecksum: false,
          ));

      final info = lz4FrameInfo(encoded);
      expect(info.isSkippable, isFalse);
      expect(info.isLegacy, isFalse);
      expect(info.magic, 0x184D2204);
      expect(info.blockIndependence, isTrue);
      expect(info.contentChecksum, isFalse);
      expect(info.contentSize, isNull);
      expect(info.dictId, isNull);
      expect(info.headerSize, 7);
    });

    test('parses frame with content size and checksum', () {
      final encoded = lz4FrameEncodeWithOptions(
        Uint8List(100),
        options: Lz4FrameOptions(
          contentSize: 100,
          contentChecksum: true,
        ),
      );

      final info = lz4FrameInfo(encoded);
      expect(info.contentSize, 100);
      expect(info.contentChecksum, isTrue);
      // Header size: 4 (magic) + 1 (FLG) + 1 (BD) + 8 (size) + 1 (HC) = 15
      expect(info.headerSize, 15);
    });

    test('detects skippable frame', () {
      final src = Uint8List.fromList([
        0x50, 0x2A, 0x4D, 0x18, // Magic 0x184D2A50
        0x04, 0x00, 0x00, 0x00, // Size 4
        0x01, 0x02, 0x03, 0x04, // User data
      ]);

      final info = lz4FrameInfo(src);
      expect(info.isSkippable, isTrue);
      expect(info.isLegacy, isFalse);
      expect(info.skippableSize, 4);
      expect(info.headerSize, 8);
    });

    test('detects legacy frame', () {
      final src = Uint8List.fromList([
        0x02, 0x21, 0x4C, 0x18, // Legacy Magic
        // ... subsequent data ...
      ]);

      final info = lz4FrameInfo(src);
      expect(info.isLegacy, isTrue);
      expect(info.isSkippable, isFalse);
      expect(info.headerSize, 4);
    });

    test('throws on truncated input', () {
      expect(
          () => lz4FrameInfo(Uint8List(3)), throwsA(isA<Lz4FormatException>()));
    });

    test('throws on invalid magic', () {
      final src = Uint8List.fromList([0x00, 0x00, 0x00, 0x00]);
      expect(() => lz4FrameInfo(src), throwsA(isA<Lz4FormatException>()));
    });
  });
}
