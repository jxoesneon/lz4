import 'dart:typed_data';

import 'package:dart_lz4/dart_lz4.dart';
import 'package:test/test.dart';

void main() {
  group('lz4SkippableEncode', () {
    test('encodes empty data', () {
      final data = Uint8List(0);
      final frame = lz4SkippableEncode(data);

      expect(frame.length, equals(8));
      // Magic: 0x184D2A50 (little endian)
      expect(frame[0], equals(0x50));
      expect(frame[1], equals(0x2A));
      expect(frame[2], equals(0x4D));
      expect(frame[3], equals(0x18));
      // Size: 0
      expect(frame[4], equals(0));
      expect(frame[5], equals(0));
      expect(frame[6], equals(0));
      expect(frame[7], equals(0));
    });

    test('encodes data with default index 0', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final frame = lz4SkippableEncode(data);

      expect(frame.length, equals(8 + 5));
      // Magic: 0x184D2A50
      expect(frame[0], equals(0x50));
      expect(frame[1], equals(0x2A));
      expect(frame[2], equals(0x4D));
      expect(frame[3], equals(0x18));
      // Size: 5
      expect(frame[4], equals(5));
      expect(frame[5], equals(0));
      expect(frame[6], equals(0));
      expect(frame[7], equals(0));
      // Data
      expect(frame.sublist(8), equals([1, 2, 3, 4, 5]));
    });

    test('encodes data with custom index', () {
      final data = Uint8List.fromList([0xAB, 0xCD]);
      final frame = lz4SkippableEncode(data, index: 15);

      expect(frame.length, equals(8 + 2));
      // Magic: 0x184D2A5F (base + 15)
      expect(frame[0], equals(0x5F));
      expect(frame[1], equals(0x2A));
      expect(frame[2], equals(0x4D));
      expect(frame[3], equals(0x18));
      // Size: 2
      expect(frame[4], equals(2));
      // Data
      expect(frame.sublist(8), equals([0xAB, 0xCD]));
    });

    test('throws on invalid index < 0', () {
      final data = Uint8List(0);
      expect(() => lz4SkippableEncode(data, index: -1), throwsRangeError);
    });

    test('throws on invalid index > 15', () {
      final data = Uint8List(0);
      expect(() => lz4SkippableEncode(data, index: 16), throwsRangeError);
    });

    test('decoder skips skippable frame and decodes following frame', () {
      final metadata = Uint8List.fromList([0x01, 0x02, 0x03]);
      final payload = Uint8List.fromList('Hello, World!'.codeUnits);

      final skippable = lz4SkippableEncode(metadata, index: 5);
      final regularFrame = lz4FrameEncode(payload);

      // Concatenate skippable + regular frame
      final combined = Uint8List(skippable.length + regularFrame.length);
      combined.setRange(0, skippable.length, skippable);
      combined.setRange(skippable.length, combined.length, regularFrame);

      // Decode should skip the skippable frame and return payload
      final decoded = lz4FrameDecode(combined);
      expect(decoded, equals(payload));
    });

    test('lz4FrameInfo recognizes skippable frame', () {
      final data = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final frame = lz4SkippableEncode(data, index: 7);

      final info = lz4FrameInfo(frame);
      expect(info.isSkippable, isTrue);
      expect(info.isLegacy, isFalse);
      expect(info.skippableSize, equals(4));
      expect(info.headerSize, equals(8));
      // Magic should be 0x184D2A57
      expect(info.magic, equals(0x184D2A57));
    });
  });
}
