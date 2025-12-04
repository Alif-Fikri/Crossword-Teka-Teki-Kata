String formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = duration.inHours;
  if (hours > 0) {
    final hourStr = hours.toString().padLeft(2, '0');
    return '$hourStr:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
