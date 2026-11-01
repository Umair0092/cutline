// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_clip.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VideoClip {

 String get id; String get mediaId;@DurationConverter() Duration get sourceStart;@DurationConverter() Duration get sourceEnd; double get volume;
/// Create a copy of VideoClip
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoClipCopyWith<VideoClip> get copyWith => _$VideoClipCopyWithImpl<VideoClip>(this as VideoClip, _$identity);

  /// Serializes this VideoClip to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VideoClip;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoClip&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.mediaId, _this.mediaId) || other.mediaId == _this.mediaId)&&(identical(other.sourceStart, _this.sourceStart) || other.sourceStart == _this.sourceStart)&&(identical(other.sourceEnd, _this.sourceEnd) || other.sourceEnd == _this.sourceEnd)&&(identical(other.volume, _this.volume) || other.volume == _this.volume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VideoClip;
  return Object.hash(runtimeType,_this.id,_this.mediaId,_this.sourceStart,_this.sourceEnd,_this.volume);
}

@override
String toString() {
  final _this = this as VideoClip;
  return 'VideoClip(id: ${_this.id}, mediaId: ${_this.mediaId}, sourceStart: ${_this.sourceStart}, sourceEnd: ${_this.sourceEnd}, volume: ${_this.volume})';
}


}

/// @nodoc
abstract mixin class $VideoClipCopyWith<$Res>  {
  factory $VideoClipCopyWith(VideoClip value, $Res Function(VideoClip) _then) = _$VideoClipCopyWithImpl;
@useResult
$Res call({
 String id, String mediaId,@DurationConverter() Duration sourceStart,@DurationConverter() Duration sourceEnd, double volume
});




}
/// @nodoc
class _$VideoClipCopyWithImpl<$Res>
    implements $VideoClipCopyWith<$Res> {
  _$VideoClipCopyWithImpl(this._self, this._then);

  final VideoClip _self;
  final $Res Function(VideoClip) _then;

/// Create a copy of VideoClip
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? mediaId = null,Object? sourceStart = null,Object? sourceEnd = null,Object? volume = null,}) {
  return _then(VideoClip(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mediaId: null == mediaId ? _self.mediaId : mediaId // ignore: cast_nullable_to_non_nullable
as String,sourceStart: null == sourceStart ? _self.sourceStart : sourceStart // ignore: cast_nullable_to_non_nullable
as Duration,sourceEnd: null == sourceEnd ? _self.sourceEnd : sourceEnd // ignore: cast_nullable_to_non_nullable
as Duration,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoClip].
extension VideoClipPatterns on VideoClip {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoClip value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoClip() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoClip value)  $default,){
final _that = this;
switch (_that) {
case _VideoClip():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoClip value)?  $default,){
final _that = this;
switch (_that) {
case _VideoClip() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String mediaId, @DurationConverter()  Duration sourceStart, @DurationConverter()  Duration sourceEnd,  double volume)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoClip() when $default != null:
return $default(_that.id,_that.mediaId,_that.sourceStart,_that.sourceEnd,_that.volume);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String mediaId, @DurationConverter()  Duration sourceStart, @DurationConverter()  Duration sourceEnd,  double volume)  $default,) {final _that = this;
switch (_that) {
case _VideoClip():
return $default(_that.id,_that.mediaId,_that.sourceStart,_that.sourceEnd,_that.volume);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String mediaId, @DurationConverter()  Duration sourceStart, @DurationConverter()  Duration sourceEnd,  double volume)?  $default,) {final _that = this;
switch (_that) {
case _VideoClip() when $default != null:
return $default(_that.id,_that.mediaId,_that.sourceStart,_that.sourceEnd,_that.volume);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VideoClip extends VideoClip {
  const _VideoClip({required this.id, required this.mediaId, @DurationConverter() required this.sourceStart, @DurationConverter() required this.sourceEnd, this.volume = 1.0}): super._();
  factory _VideoClip.fromJson(Map<String, dynamic> json) => _$VideoClipFromJson(json);

@override final  String id;
@override final  String mediaId;
@override@DurationConverter() final  Duration sourceStart;
@override@DurationConverter() final  Duration sourceEnd;
@override@JsonKey() final  double volume;

/// Create a copy of VideoClip
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoClipCopyWith<_VideoClip> get copyWith => __$VideoClipCopyWithImpl<_VideoClip>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VideoClipToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoClip&&(identical(other.id, id) || other.id == id)&&(identical(other.mediaId, mediaId) || other.mediaId == mediaId)&&(identical(other.sourceStart, sourceStart) || other.sourceStart == sourceStart)&&(identical(other.sourceEnd, sourceEnd) || other.sourceEnd == sourceEnd)&&(identical(other.volume, volume) || other.volume == volume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,mediaId,sourceStart,sourceEnd,volume);
}

@override
String toString() {
    return 'VideoClip(id: $id, mediaId: $mediaId, sourceStart: $sourceStart, sourceEnd: $sourceEnd, volume: $volume)';
}


}

/// @nodoc
abstract mixin class _$VideoClipCopyWith<$Res> implements $VideoClipCopyWith<$Res> {
  factory _$VideoClipCopyWith(_VideoClip value, $Res Function(_VideoClip) _then) = __$VideoClipCopyWithImpl;
@override @useResult
$Res call({
 String id, String mediaId,@DurationConverter() Duration sourceStart,@DurationConverter() Duration sourceEnd, double volume
});




}
/// @nodoc
class __$VideoClipCopyWithImpl<$Res>
    implements _$VideoClipCopyWith<$Res> {
  __$VideoClipCopyWithImpl(this._self, this._then);

  final _VideoClip _self;
  final $Res Function(_VideoClip) _then;

/// Create a copy of VideoClip
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? mediaId = null,Object? sourceStart = null,Object? sourceEnd = null,Object? volume = null,}) {
  return _then(_VideoClip(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mediaId: null == mediaId ? _self.mediaId : mediaId // ignore: cast_nullable_to_non_nullable
as String,sourceStart: null == sourceStart ? _self.sourceStart : sourceStart // ignore: cast_nullable_to_non_nullable
as Duration,sourceEnd: null == sourceEnd ? _self.sourceEnd : sourceEnd // ignore: cast_nullable_to_non_nullable
as Duration,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
