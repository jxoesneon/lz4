import 'dart:math';
import 'dart:typed_data';

import 'package:dart_lz4/dart_lz4.dart';

Future<void> main() async {
  final random1MiB = _randomBytes(1024 * 1024, seed: 1234);
  final repeat1MiB = _repeatingBytes(1024 * 1024);

  await _bench('random 1MiB', random1MiB);
  await _bench('repeating 1MiB', repeat1MiB);
}

Future<void> _bench(String name, Uint8List input) async {
  print('--- $name ---');
  print('input: ${input.length} bytes');

  _benchCodec('fast', input, () => lz4Compress(input));
  _benchCodec(
    'hc',
    input,
    () => lz4Compress(input, level: Lz4CompressionLevel.hc),
  );

  _benchFrameCodec(
    'frame-fast',
    input,
    options: Lz4FrameOptions(
      blockSize: Lz4FrameBlockSize.k64KB,
      compression: Lz4FrameCompression.fast,
      acceleration: 1,
    ),
  );

  _benchFrameCodec(
    'frame-hc',
    input,
    options: Lz4FrameOptions(
      blockSize: Lz4FrameBlockSize.k64KB,
      compression: Lz4FrameCompression.hc,
    ),
  );

  await _benchFrameStreamingCodec(
    'stream-frame-fast',
    input,
    options: Lz4FrameOptions(
      blockSize: Lz4FrameBlockSize.k64KB,
      compression: Lz4FrameCompression.fast,
      acceleration: 1,
    ),
  );

  await _benchFrameStreamingCodec(
    'stream-frame-hc',
    input,
    options: Lz4FrameOptions(
      blockSize: Lz4FrameBlockSize.k64KB,
      compression: Lz4FrameCompression.hc,
    ),
  );

  print('');
}

void _benchCodec(
  String label,
  Uint8List input,
  Uint8List Function() compressFn,
) {
  final compressed = compressFn();
  final decompressed =
      lz4Decompress(compressed, decompressedSize: input.length);
  if (!_bytesEqual(decompressed, input)) {
    throw StateError('roundtrip mismatch ($label)');
  }

  final ratio = input.isEmpty ? 1.0 : compressed.length / input.length;
  print(
      '[$label] compressed: ${compressed.length} bytes (ratio: ${ratio.toStringAsFixed(3)})');

  final compressMbPerSec = _throughput(
    compressFn,
    bytesProcessed: input.length,
  );

  final decompressMbPerSec = _throughput(
    () => lz4Decompress(compressed, decompressedSize: input.length),
    bytesProcessed: input.length,
  );

  print('[$label] compress: ${compressMbPerSec.toStringAsFixed(1)} MiB/s');
  print('[$label] decompress: ${decompressMbPerSec.toStringAsFixed(1)} MiB/s');
}

void _benchFrameCodec(
  String label,
  Uint8List input, {
  required Lz4FrameOptions options,
}) {
  final encoded = lz4FrameEncodeWithOptions(input, options: options);
  final decoded = lz4FrameDecode(encoded);
  if (!_bytesEqual(decoded, input)) {
    throw StateError('roundtrip mismatch ($label)');
  }

  final ratio = input.isEmpty ? 1.0 : encoded.length / input.length;
  print(
      '[$label] compressed: ${encoded.length} bytes (ratio: ${ratio.toStringAsFixed(3)})');

  final encodeMbPerSec = _throughput(
    () => lz4FrameEncodeWithOptions(input, options: options),
    bytesProcessed: input.length,
  );

  final decodeMbPerSec = _throughput(
    () => lz4FrameDecode(encoded),
    bytesProcessed: input.length,
  );

  print('[$label] encode: ${encodeMbPerSec.toStringAsFixed(1)} MiB/s');
  print('[$label] decode: ${decodeMbPerSec.toStringAsFixed(1)} MiB/s');
}

Future<void> _benchFrameStreamingCodec(
  String label,
  Uint8List input, {
  required Lz4FrameOptions options,
}) async {
  final encoded = await _frameEncodeStream(input, options: options);
  final decoded = await _frameDecodeStream(encoded);
  if (!_bytesEqual(decoded, input)) {
    throw StateError('roundtrip mismatch ($label)');
  }

  final ratio = input.isEmpty ? 1.0 : encoded.length / input.length;
  print(
      '[$label] compressed: ${encoded.length} bytes (ratio: ${ratio.toStringAsFixed(3)})');

  final encodeMbPerSec = await _throughputAsync(
    () => _frameEncodeStream(input, options: options),
    bytesProcessed: input.length,
  );

  final decodeMbPerSec = await _throughputAsync(
    () => _frameDecodeStream(encoded),
    bytesProcessed: input.length,
  );

  print('[$label] encode: ${encodeMbPerSec.toStringAsFixed(1)} MiB/s');
  print('[$label] decode: ${decodeMbPerSec.toStringAsFixed(1)} MiB/s');
}

double _throughput(
  Uint8List Function() fn, {
  required int bytesProcessed,
}) {
  const warmupIters = 8;
  const targetMs = 500;

  for (var i = 0; i < warmupIters; i++) {
    fn();
  }

  var iters = 1;
  while (true) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < iters; i++) {
      fn();
    }
    sw.stop();

    final elapsedMs = sw.elapsedMicroseconds / 1000.0;
    if (elapsedMs >= targetMs) {
      final bytesTotal = bytesProcessed * iters;
      final mib = bytesTotal / (1024.0 * 1024.0);
      final seconds = sw.elapsedMicroseconds / 1e6;
      return mib / seconds;
    }

    iters *= 2;
  }
}

Future<double> _throughputAsync(
  Future<Uint8List> Function() fn, {
  required int bytesProcessed,
}) async {
  const warmupIters = 4;
  const targetMs = 500;

  for (var i = 0; i < warmupIters; i++) {
    await fn();
  }

  var iters = 1;
  while (true) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < iters; i++) {
      await fn();
    }
    sw.stop();

    final elapsedMs = sw.elapsedMicroseconds / 1000.0;
    if (elapsedMs >= targetMs) {
      final bytesTotal = bytesProcessed * iters;
      final mib = bytesTotal / (1024.0 * 1024.0);
      final seconds = sw.elapsedMicroseconds / 1e6;
      return mib / seconds;
    }

    iters *= 2;
  }
}

Iterable<List<int>> _chunk(Uint8List bytes) sync* {
  const sizes = [1024, 4096, 16384, 8192, 123];
  var offset = 0;
  var i = 0;
  while (offset < bytes.length) {
    final size = sizes[i % sizes.length];
    final end = (offset + size) > bytes.length ? bytes.length : (offset + size);
    yield bytes.sublist(offset, end);
    offset = end;
    i++;
  }
}

Uint8List _concat(List<List<int>> chunks) {
  final builder = BytesBuilder(copy: false);
  for (final c in chunks) {
    builder.add(c);
  }
  return builder.takeBytes();
}

Future<Uint8List> _frameEncodeStream(
  Uint8List input, {
  required Lz4FrameOptions options,
}) async {
  final outChunks = await Stream<List<int>>.fromIterable(_chunk(input))
      .transform(lz4FrameEncoderWithOptions(options: options))
      .toList();
  return _concat(outChunks);
}

Future<Uint8List> _frameDecodeStream(Uint8List encoded) async {
  final outChunks = await Stream<List<int>>.fromIterable(_chunk(encoded))
      .transform(lz4FrameDecoder())
      .toList();
  return _concat(outChunks);
}

Uint8List _randomBytes(int length, {required int seed}) {
  final r = Random(seed);
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = r.nextInt(256);
  }
  return out;
}

Uint8List _repeatingBytes(int length) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = i & 0x1f;
  }
  return out;
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
