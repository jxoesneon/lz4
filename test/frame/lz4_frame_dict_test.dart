import 'dart:typed_data';

import 'package:dart_lz4/dart_lz4.dart';
import 'package:dart_lz4/src/xxhash/xxh32.dart';
import 'package:test/test.dart';

List<int> _u32le(int v) =>
    <int>[v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff];

Uint8List _frameWithDictId({
  required int dictId,
  required Uint8List blockData,
  required bool blockIndependence,
}) {
  // Magic
  const magic = 0x184D2204;

  // FLG: Version(01)=0x40, ContentChecksum(0)=0, ContentSize(0)=0, DictId(1)=1
  // Independent blocks: blockIndependence ? 0x20 : 0x00
  // Block checksum: 0x00
  final flg = 0x40 | (blockIndependence ? 0x20 : 0x00) | 0x01;

  // BD: MaxSize(64KB=4)=0x40
  const bd = 0x40;

  final descriptorBytes = <int>[flg, bd, ..._u32le(dictId)];
  final hc = (xxh32(Uint8List.fromList(descriptorBytes), seed: 0) >> 8) & 0xff;

  // Frame header
  final builder = BytesBuilder();
  builder.add(_u32le(magic));
  builder.add(descriptorBytes);
  builder.addByte(hc);

  // Block
  // We use uncompressed block for simplicity of testing dictionary handling logic
  // in the decoder (it handles dictionary logic regardless of block compression,
  // but for dependent blocks we need actual compression references which is hard to hand-craft).
  //
  // However, dependent block logic is what we really want to test.
  // The decoder simply copies dictionary to history.
  //
  // If we use uncompressed block, the decoder just emits it.
  // Dictionary is only relevant if we have matches referring to it (which requires compressed block)
  // OR if we are testing the API surface (that it accepts dictId and resolver).

  // To verify functionality, we can just check if it parses successfully with resolver,
  // and fails without it.

  // Block size
  final blockSize = blockData.length | 0x80000000; // Uncompressed
  builder.add(_u32le(blockSize));
  builder.add(blockData);

  // End mark
  builder.add(_u32le(0));

  return builder.toBytes();
}

void main() {
  group('lz4FrameDecode with dictId', () {
    test('throws if dictId present but no resolver provided', () {
      final src = _frameWithDictId(
        dictId: 123,
        blockData: Uint8List.fromList([1, 2, 3]),
        blockIndependence: true,
      );

      expect(
        () => lz4FrameDecode(src),
        throwsA(isA<Lz4UnsupportedFeatureException>()),
      );
    });

    test('throws if resolver returns null', () {
      final src = _frameWithDictId(
        dictId: 123,
        blockData: Uint8List.fromList([1, 2, 3]),
        blockIndependence: true,
      );

      expect(
        () => lz4FrameDecode(src, dictionaryResolver: (id) => null),
        throwsA(isA<Lz4Exception>().having(
            (e) => e.message, 'message', contains('Dictionary not found'))),
      );
    });

    test('succeeds if resolver provides dictionary (independent)', () {
      final src = _frameWithDictId(
        dictId: 123,
        blockData: Uint8List.fromList([1, 2, 3]),
        blockIndependence: true,
      );

      final result = lz4FrameDecode(
        src,
        dictionaryResolver: (id) {
          if (id == 123) return Uint8List(0);
          return null;
        },
      );

      expect(result, [1, 2, 3]);
    });

    test('succeeds if resolver provides dictionary (dependent)', () {
      final src = _frameWithDictId(
        dictId: 123,
        blockData: Uint8List.fromList([1, 2, 3]),
        blockIndependence: false,
      );

      final result = lz4FrameDecode(
        src,
        dictionaryResolver: (id) {
          if (id == 123) return Uint8List(0);
          return null;
        },
      );

      expect(result, [1, 2, 3]);
    });
  });

  group('lz4FrameDecoder (stream) with dictId', () {
    test('throws if dictId present but no resolver provided', () async {
      final src = _frameWithDictId(
        dictId: 123,
        blockData: Uint8List.fromList([1, 2, 3]),
        blockIndependence: true,
      );

      final stream = Stream<List<int>>.value(src).transform(lz4FrameDecoder());

      await expectLater(
        stream.toList(),
        throwsA(isA<Lz4UnsupportedFeatureException>()),
      );
    });

    test('throws if resolver returns null', () async {
      final src = _frameWithDictId(
        dictId: 123,
        blockData: Uint8List.fromList([1, 2, 3]),
        blockIndependence: true,
      );

      final stream = Stream<List<int>>.value(src).transform(
        lz4FrameDecoder(dictionaryResolver: (id) => null),
      );

      await expectLater(
        stream.toList(),
        throwsA(isA<Lz4Exception>().having(
            (e) => e.message, 'message', contains('Dictionary not found'))),
      );
    });

    test('succeeds if resolver provides dictionary', () async {
      final src = _frameWithDictId(
        dictId: 123,
        blockData: Uint8List.fromList([1, 2, 3]),
        blockIndependence: true,
      );

      final stream = Stream<List<int>>.value(src).transform(
        lz4FrameDecoder(
          dictionaryResolver: (id) {
            if (id == 123) return Uint8List(0);
            return null;
          },
        ),
      );

      final result = await stream.toList();
      expect(result.expand((x) => x), [1, 2, 3]);
    });
  });
}
