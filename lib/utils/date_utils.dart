/// Extension for converting Unix timestamps to DateTime.
extension UnixTimestampExtension on int {
  /// Converts a Unix timestamp (seconds since epoch) to DateTime.
  DateTime toDateTime() => DateTime.fromMillisecondsSinceEpoch(this * 1000);
}
