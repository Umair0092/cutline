import 'dart:typed_data';

import 'package:cutline/media/media_previews.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one peak per 10 samples (10 ms at 1 kHz)', () {
    final samples = Int16List(25);
    samples[3] = 16384; // half volume
    samples[12] = -32768; // full volume, negative
    final peaks = computePeaks(samples.buffer.asUint8List());
    expect(peaks, hasLength(3));
    expect(peaks[0], 0.5);
    expect(peaks[1], 1.0);
    expect(peaks[2], 0.0);
  });
}
