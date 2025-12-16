import 'dart:math';
import 'dart:typed_data';

import 'package:dart_lz4/dart_lz4.dart';
import 'package:dart_lz4/src/internal/lz4_exception.dart';
import 'package:test/test.dart';

void main() {
  test('lz4FrameEncode round-trips empty input', () {
    final src = Uint8List(0);
    final encoded = lz4FrameEncode(src);
    final decoded = lz4FrameDecode(encoded);
    expect(decoded, src);
  });

  test('lz4FrameEncode round-trips small input', () {
    final src = Uint8List.fromList('Hello world'.codeUnits);
    final encoded = lz4FrameEncode(src);
    final decoded = lz4FrameDecode(encoded);
    expect(decoded, src);
  });

  test('lz4FrameEncode round-trips >4MiB input (multi-block)', () {
    const size = (4 * 1024 * 1024) + 123;

    final rng = Random(1);
    final src = Uint8List(size);
    for (var i = 0; i < src.length; i++) {
      src[i] = rng.nextInt(256);
    }

    final encoded = lz4FrameEncode(src, acceleration: 1);
    final decoded = lz4FrameDecode(encoded);
    expect(decoded, src);
  });

  test('lz4FrameEncodeWithOptions round-trips with checksums and content size',
      () {
    final src = Uint8List.fromList('Hello with checksums'.codeUnits);

    final options = Lz4FrameOptions(
      blockSize: Lz4FrameBlockSize.k64KB,
      blockChecksum: true,
      contentChecksum: true,
      contentSize: src.length,
    );

    final encoded = lz4FrameEncodeWithOptions(src, options: options);
    final decoded = lz4FrameDecode(encoded);
    expect(decoded, src);
  });

  test('lz4FrameEncodeWithOptions supports hc compression', () {
    final src = Uint8List.fromList(List<int>.filled(128 * 1024, 0x41));

    final encoded = lz4FrameEncodeWithOptions(
      src,
      options: Lz4FrameOptions(
        compression: Lz4FrameCompression.hc,
        blockSize: Lz4FrameBlockSize.k64KB,
      ),
    );
    final decoded = lz4FrameDecode(encoded);
    expect(decoded, src);
  });

  test('lz4FrameEncodeWithOptions rejects contentSize mismatch', () {
    final src = Uint8List.fromList('Hello'.codeUnits);

    expect(
      () => lz4FrameEncodeWithOptions(
        src,
        options: Lz4FrameOptions(contentSize: src.length + 1),
      ),
      throwsA(isA<Lz4FormatException>()),
    );
  });

  test('lz4FrameEncodeWithOptions rejects dependent-block encoding', () {
    final src = Uint8List.fromList('Hello'.codeUnits);

    expect(
      () => lz4FrameEncodeWithOptions(
        src,
        options: Lz4FrameOptions(blockIndependence: false),
      ),
      throwsA(isA<Lz4UnsupportedFeatureException>()),
    );
  });
}
