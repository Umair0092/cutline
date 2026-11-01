import 'package:cutline/ui/time_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats minutes, seconds and tenths', () {
    expect(formatPlayerTime(Duration.zero), '0:00.0');
    expect(formatPlayerTime(const Duration(milliseconds: 75490)), '1:15.4');
    expect(formatPlayerTime(const Duration(seconds: 3725)), '1:02:05.0');
  });
}
