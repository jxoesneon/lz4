final class Lz4HcOptions {
  final int maxSearchDepth;

  Lz4HcOptions({
    this.maxSearchDepth = 64,
  }) {
    if (maxSearchDepth < 1) {
      throw RangeError.value(maxSearchDepth, 'maxSearchDepth');
    }
  }
}
