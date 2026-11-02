// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'speech_spec.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SpeechSpec {

 String get text; VoiceEngine get engine;/// A voice name for the engine; empty for its default.
 String get voice;/// 1 is normal; 0.75 to 1.5.
 double get speed;
/// Create a copy of SpeechSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SpeechSpecCopyWith<SpeechSpec> get copyWith => _$SpeechSpecCopyWithImpl<SpeechSpec>(this as SpeechSpec, _$identity);

  /// Serializes this SpeechSpec to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SpeechSpec;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SpeechSpec&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.engine, _this.engine) || other.engine == _this.engine)&&(identical(other.voice, _this.voice) || other.voice == _this.voice)&&(identical(other.speed, _this.speed) || other.speed == _this.speed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SpeechSpec;
  return Object.hash(runtimeType,_this.text,_this.engine,_this.voice,_this.speed);
}

@override
String toString() {
  final _this = this as SpeechSpec;
  return 'SpeechSpec(text: ${_this.text}, engine: ${_this.engine}, voice: ${_this.voice}, speed: ${_this.speed})';
}


}

/// @nodoc
abstract mixin class $SpeechSpecCopyWith<$Res>  {
  factory $SpeechSpecCopyWith(SpeechSpec value, $Res Function(SpeechSpec) _then) = _$SpeechSpecCopyWithImpl;
@useResult
$Res call({
 String text, VoiceEngine engine, String voice, double speed
});




}
/// @nodoc
class _$SpeechSpecCopyWithImpl<$Res>
    implements $SpeechSpecCopyWith<$Res> {
  _$SpeechSpecCopyWithImpl(this._self, this._then);

  final SpeechSpec _self;
  final $Res Function(SpeechSpec) _then;

/// Create a copy of SpeechSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? engine = null,Object? voice = null,Object? speed = null,}) {
  return _then(SpeechSpec(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,engine: null == engine ? _self.engine : engine // ignore: cast_nullable_to_non_nullable
as VoiceEngine,voice: null == voice ? _self.voice : voice // ignore: cast_nullable_to_non_nullable
as String,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [SpeechSpec].
extension SpeechSpecPatterns on SpeechSpec {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SpeechSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SpeechSpec() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SpeechSpec value)  $default,){
final _that = this;
switch (_that) {
case _SpeechSpec():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SpeechSpec value)?  $default,){
final _that = this;
switch (_that) {
case _SpeechSpec() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  VoiceEngine engine,  String voice,  double speed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SpeechSpec() when $default != null:
return $default(_that.text,_that.engine,_that.voice,_that.speed);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  VoiceEngine engine,  String voice,  double speed)  $default,) {final _that = this;
switch (_that) {
case _SpeechSpec():
return $default(_that.text,_that.engine,_that.voice,_that.speed);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  VoiceEngine engine,  String voice,  double speed)?  $default,) {final _that = this;
switch (_that) {
case _SpeechSpec() when $default != null:
return $default(_that.text,_that.engine,_that.voice,_that.speed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SpeechSpec implements SpeechSpec {
  const _SpeechSpec({required this.text, this.engine = VoiceEngine.system, this.voice = '', this.speed = 1.0});
  factory _SpeechSpec.fromJson(Map<String, dynamic> json) => _$SpeechSpecFromJson(json);

@override final  String text;
@override@JsonKey() final  VoiceEngine engine;
/// A voice name for the engine; empty for its default.
@override@JsonKey() final  String voice;
/// 1 is normal; 0.75 to 1.5.
@override@JsonKey() final  double speed;

/// Create a copy of SpeechSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SpeechSpecCopyWith<_SpeechSpec> get copyWith => __$SpeechSpecCopyWithImpl<_SpeechSpec>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SpeechSpecToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SpeechSpec&&(identical(other.text, text) || other.text == text)&&(identical(other.engine, engine) || other.engine == engine)&&(identical(other.voice, voice) || other.voice == voice)&&(identical(other.speed, speed) || other.speed == speed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,text,engine,voice,speed);
}

@override
String toString() {
    return 'SpeechSpec(text: $text, engine: $engine, voice: $voice, speed: $speed)';
}


}

/// @nodoc
abstract mixin class _$SpeechSpecCopyWith<$Res> implements $SpeechSpecCopyWith<$Res> {
  factory _$SpeechSpecCopyWith(_SpeechSpec value, $Res Function(_SpeechSpec) _then) = __$SpeechSpecCopyWithImpl;
@override @useResult
$Res call({
 String text, VoiceEngine engine, String voice, double speed
});




}
/// @nodoc
class __$SpeechSpecCopyWithImpl<$Res>
    implements _$SpeechSpecCopyWith<$Res> {
  __$SpeechSpecCopyWithImpl(this._self, this._then);

  final _SpeechSpec _self;
  final $Res Function(_SpeechSpec) _then;

/// Create a copy of SpeechSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? engine = null,Object? voice = null,Object? speed = null,}) {
  return _then(_SpeechSpec(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,engine: null == engine ? _self.engine : engine // ignore: cast_nullable_to_non_nullable
as VoiceEngine,voice: null == voice ? _self.voice : voice // ignore: cast_nullable_to_non_nullable
as String,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
