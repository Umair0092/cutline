/// An editor timecode with hundredths: 83.12 s -> "01:23.12", and
/// "1:02:05.00" past an hour. Fixed width, for the mono font.
String formatTimecode(Duration d) {
  final cs = (d.inMilliseconds / 10).floor();
  final hours = cs ~/ 360000;
  final minutes = (cs ~/ 6000) % 60;
  final seconds = (cs ~/ 100) % 60;
  final hundredths = cs % 100;
  String two(int n) => n.toString().padLeft(2, '0');
  final rest = '${two(minutes)}:${two(seconds)}.${two(hundredths)}';
  return hours > 0 ? '$hours:$rest' : rest;
}
