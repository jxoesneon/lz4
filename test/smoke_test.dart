import 'package:lz4/lz4.dart';
import 'package:test/test.dart';

void main() {
  test('public API is importable', () {
    expect(Lz4CompressionLevel.values, isNotEmpty);
  });
}
