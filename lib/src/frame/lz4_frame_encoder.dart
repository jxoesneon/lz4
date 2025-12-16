import 'dart:typed_data';

import '../block/lz4_block_encoder.dart';
import '../internal/byte_writer.dart';
import '../xxhash/xxh32.dart';

const _lz4FrameMagic = 0x184D2204;

Uint8List lz4FrameEncodeBytes(
  Uint8List src, {
  int acceleration = 1,
}) {
  const flg = 0x60; // version=01, block independence=1
  const bd = 0x70; // 4MB max block size
  const blockMaxSize = 4 * 1024 * 1024;

  final writer = ByteWriter(initialCapacity: src.length + 64);

  writer.writeUint32LE(_lz4FrameMagic);

  writer.writeUint8(flg);
  writer.writeUint8(bd);

  final descriptor = Uint8List.fromList([flg, bd]);
  final hc = (xxh32(descriptor, seed: 0) >> 8) & 0xff;
  writer.writeUint8(hc);

  var offset = 0;
  while (offset < src.length) {
    var end = offset + blockMaxSize;
    if (end > src.length) {
      end = src.length;
    }

    final chunk = Uint8List.sublistView(src, offset, end);
    final compressed = lz4BlockCompress(chunk, acceleration: acceleration);

    final useCompressed = compressed.length < chunk.length;
    final payload = useCompressed ? compressed : chunk;

    final blockSizeRaw = (useCompressed ? 0 : 0x80000000) | payload.length;
    writer.writeUint32LE(blockSizeRaw);
    writer.writeBytes(payload);

    offset = end;
  }

  writer.writeUint32LE(0);

  return writer.toBytes();
}
