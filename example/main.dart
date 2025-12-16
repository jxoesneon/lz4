import 'dart:typed_data';

import 'package:dart_lz4/dart_lz4.dart';

Iterable<List<int>> _chunk(Uint8List bytes, List<int> sizes) sync* {
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

Future<void> main() async {
  final src = Uint8List.fromList('Hello streaming LZ4 frame'.codeUnits);

  final encodedChunks = await Stream<List<int>>.fromIterable(
    _chunk(src, [1, 2, 3, 1, 5, 8]),
  ).transform(lz4FrameEncoder()).toList();

  final decodedChunks = await Stream<List<int>>.fromIterable(encodedChunks)
      .transform(lz4FrameDecoder())
      .toList();

  final decoded = _concat(decodedChunks);
  if (decoded.length != src.length) {
    throw StateError('Round-trip failed');
  }
  for (var i = 0; i < src.length; i++) {
    if (decoded[i] != src[i]) {
      throw StateError('Round-trip failed');
    }
  }
}
