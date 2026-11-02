// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'voice_effect.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VoiceEffect {

/// Semitones up (positive) or down (negative), -12 to 12. Speed and
/// length stay the same.
 double get pitch;/// How fast it plays, 0.5 to 2, without changing pitch. Only for audio
/// on the audio track (the main track's video can't change speed).
 double get speed;/// A metallic, monotone "robot" sound.
 bool get robot;/// Take out steady background noise (hiss, hum, fans).
 bool get denoise;/// Even out the loudness to a standard level.
 bool get normalize;
/// Create a copy of VoiceEffect
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VoiceEffectCopyWith<VoiceEffect> get copyWith => _$VoiceEffectCopyWithImpl<VoiceEffect>(this as VoiceEffect, _$identity);

  /// Serializes this VoiceEffect to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VoiceEffect;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VoiceEffect&&(identical(other.pitch, _this.pitch) || other.pitch == _this.pitch)&&(identical(other.speed, _this.speed) || other.speed == _this.speed)&&(identical(other.robot, _this.robot) || other.robot == _this.robot)&&(identical(other.denoise, _this.denoise) || other.denoise == _this.denoise)&&(identical(other.normalize, _this.normalize) || other.normalize == _this.normalize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VoiceEffect;
  return Object.hash(runtimeType,_this.pitch,_this.speed,_this.robot,_this.denoise,_this.normalize);
}

@override
String toString() {
  final _this = this as VoiceEffect;
  return 'VoiceEffect(pitch: ${_this.pitch}, speed: ${_this.speed}, robot: ${_this.robot}, denoise: ${_this.denoise}, normalize: ${_this.normalize})';
}


}

/// @nodoc
abstract mixin class $VoiceEffectCopyWith<$Res>  {
  factory $VoiceEffectCopyWith(VoiceEffect value, $Res Function(VoiceEffect) _then) = _$VoiceEffectCopyWithImpl;
@useResult
$Res call({
 double pitch, double speed, bool robot, bool denoise, bool normalize
});




}
/// @nodoc
class _$VoiceEffectCopyWithImpl<$Res>
    implements $VoiceEffectCopyWith<$Res> {
  _$VoiceEffectCopyWithImpl(this._self, this._then);

  final VoiceEffect _self;
  final $Res Function(VoiceEffect) _then;

/// Create a copy of VoiceEffect
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pitch = null,Object? speed = null,Object? robot = null,Object? denoise = null,Object? normalize = null,}) {
  return _then(VoiceEffect(
pitch: null == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,robot: null == robot ? _self.robot : robot // ignore: cast_nullable_to_non_nullable
as bool,denoise: null == denoise ? _self.denoise : denoise // ignore: cast_nullable_to_non_nullable
as bool,normalize: null == normalize ? _self.normalize : normalize // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VoiceEffect].
extension VoiceEffectPatterns on VoiceEffect {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VoiceEffect value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VoiceEffect() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VoiceEffect value)  $default,){
final _that = this;
switch (_that) {
case _VoiceEffect():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VoiceEffect value)?  $default,){
final _that = this;
switch (_that) {
case _VoiceEffect() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double pitch,  double speed,  bool robot,  bool denoise,  bool normalize)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VoiceEffect() when $default != null:
return $default(_that.pitch,_that.speed,_that.robot,_that.denoise,_that.normalize);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double pitch,  double speed,  bool robot,  bool denoise,  bool normalize)  $default,) {final _that = this;
switch (_that) {
case _VoiceEffect():
return $default(_that.pitch,_that.speed,_that.robot,_that.denoise,_that.normalize);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double pitch,  double speed,  bool robot,  bool denoise,  bool normalize)?  $default,) {final _that = this;
switch (_that) {
case _VoiceEffect() when $default != null:
return $default(_that.pitch,_that.speed,_that.robot,_that.denoise,_that.normalize);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VoiceEffect extends VoiceEffect {
  const _VoiceEffect({this.pitch = 0.0, this.speed = 1.0, this.robot = false, this.denoise = false, this.normalize = false}): super._();
  factory _VoiceEffect.fromJson(Map<String, dynamic> json) => _$VoiceEffectFromJson(json);

/// Semitones up (positive) or down (negative), -12 to 12. Speed and
/// length stay the same.
@override@JsonKey() final  double pitch;
/// How fast it plays, 0.5 to 2, without changing pitch. Only for audio
/// on the audio track (the main track's video can't change speed).
@override@JsonKey() final  double speed;
/// A metallic, monotone "robot" sound.
@override@JsonKey() final  bool robot;
/// Take out steady background noise (hiss, hum, fans).
@override@JsonKey() final  bool denoise;
/// Even out the loudness to a standard level.
@override@JsonKey() final  bool normalize;

/// Create a copy of VoiceEffect
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VoiceEffectCopyWith<_VoiceEffect> get copyWith => __$VoiceEffectCopyWithImpl<_VoiceEffect>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VoiceEffectToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VoiceEffect&&(identical(other.pitch, pitch) || other.pitch == pitch)&&(identical(other.speed, speed) || other.speed == speed)&&(identical(other.robot, robot) || other.robot == robot)&&(identical(other.denoise, denoise) || other.denoise == denoise)&&(identical(other.normalize, normalize) || other.normalize == normalize));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,pitch,speed,robot,denoise,normalize);
}

@override
String toString() {
    return 'VoiceEffect(pitch: $pitch, speed: $speed, robot: $robot, denoise: $denoise, normalize: $normalize)';
}


}

/// @nodoc
abstract mixin class _$VoiceEffectCopyWith<$Res> implements $VoiceEffectCopyWith<$Res> {
  factory _$VoiceEffectCopyWith(_VoiceEffect value, $Res Function(_VoiceEffect) _then) = __$VoiceEffectCopyWithImpl;
@override @useResult
$Res call({
 double pitch, double speed, bool robot, bool denoise, bool normalize
});




}
/// @nodoc
class __$VoiceEffectCopyWithImpl<$Res>
    implements _$VoiceEffectCopyWith<$Res> {
  __$VoiceEffectCopyWithImpl(this._self, this._then);

  final _VoiceEffect _self;
  final $Res Function(_VoiceEffect) _then;

/// Create a copy of VoiceEffect
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pitch = null,Object? speed = null,Object? robot = null,Object? denoise = null,Object? normalize = null,}) {
  return _then(_VoiceEffect(
pitch: null == pitch ? _self.pitch : pitch // ignore: cast_nullable_to_non_nullable
as double,speed: null == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double,robot: null == robot ? _self.robot : robot // ignore: cast_nullable_to_non_nullable
as bool,denoise: null == denoise ? _self.denoise : denoise // ignore: cast_nullable_to_non_nullable
as bool,normalize: null == normalize ? _self.normalize : normalize // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
