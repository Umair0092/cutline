/// 75.4s -> "1:15.4", 3725s -> "1:02:05.0". Tenths are shown because
/// editing needs more precision than a normal player.
String formatPlayerTime(Duration d) {
  final tenths = (d.inMilliseconds / 100).floor();
  final hours = tenths ~/ 36000;
  final minutes = (tenths ~/ 600) % 60;
  final seconds = (tenths ~/ 10) % 60;
  final t = tenths % 10;
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$ss.$t';
  }
  return '$minutes:$ss.$t';
}
