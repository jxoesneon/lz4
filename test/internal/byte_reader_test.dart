import 'dart:typed_data';

import 'package:lz4/src/internal/byte_reader.dart';
import 'package:lz4/src/internal/lz4_exception.dart';
import 'package:test/test.dart';

void main() {
  test('readUint8 advances offset', () {
    final r = ByteReader(Uint8List.fromList([1, 2, 3]));
    expect(r.offset, 0);
    expect(r.readUint8(), 1);
    expect(r.offset, 1);
    expect(r.readUint8(), 2);
    expect(r.offset, 2);
  });

  test('readUint16LE', () {
    final r = ByteReader(Uint8List.fromList([0x34, 0x12]));
    expect(r.readUint16LE(), 0x1234);
    expect(r.isEOF, isTrue);
  });

  test('readUint32LE', () {
    final r = ByteReader(Uint8List.fromList([1, 0, 0, 0]));
    expect(r.readUint32LE(), 1);
    expect(r.isEOF, isTrue);
  });

  test('readBytesView returns view and advances offset', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final r = ByteReader(bytes);

    final view = r.readBytesView(2);
    expect(view, [1, 2]);
    expect(r.offset, 2);

    bytes[0] = 9;
    expect(view[0], 9);
  });

  test('peekUint8 does not advance offset', () {
    final r = ByteReader(Uint8List.fromList([7, 8]));
    expect(r.peekUint8(), 7);
    expect(r.offset, 0);
    expect(r.peekUint8(1), 8);
    expect(r.offset, 0);
  });

  test('bounds checks throw Lz4FormatException', () {
    final r = ByteReader(Uint8List.fromList([1]));
    expect(() => r.readUint16LE(), throwsA(isA<Lz4FormatException>()));
    expect(() => r.peekUint8(1), throwsA(isA<Lz4FormatException>()));
  });
}
