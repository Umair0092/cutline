import 'package:json_annotation/json_annotation.dart';

/// Stores a [Duration] as whole microseconds so timings never drift through
/// floating point rounding.
class DurationConverter implements JsonConverter<Duration, int> {
  const DurationConverter();

  @override
  Duration fromJson(int json) => Duration(microseconds: json);

  @override
  int toJson(Duration object) => object.inMicroseconds;
}
