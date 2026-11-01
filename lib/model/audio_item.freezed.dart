// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AudioItem {

 String get id; String get mediaId; AudioRole get role;@DurationConverter() Duration get start;@DurationConverter() Duration get sourceStart;@DurationConverter() Duration get sourceEnd; double get volume;
/// Create a copy of AudioItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioItemCopyWith<AudioItem> get copyWith => _$AudioItemCopyWithImpl<AudioItem>(this as AudioItem, _$identity);

  /// Serializes this AudioItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AudioItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.mediaId, _this.mediaId) || other.mediaId == _this.mediaId)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.sourceStart, _this.sourceStart) || other.sourceStart == _this.sourceStart)&&(identical(other.sourceEnd, _this.sourceEnd) || other.sourceEnd == _this.sourceEnd)&&(identical(other.volume, _this.volume) || other.volume == _this.volume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AudioItem;
  return Object.hash(runtimeType,_this.id,_this.mediaId,_this.role,_this.start,_this.sourceStart,_this.sourceEnd,_this.volume);
}

@override
String toString() {
  final _this = this as AudioItem;
  return 'AudioItem(id: ${_this.id}, mediaId: ${_this.mediaId}, role: ${_this.role}, start: ${_this.start}, sourceStart: ${_this.sourceStart}, sourceEnd: ${_this.sourceEnd}, volume: ${_this.volume})';
}


}

/// @nodoc
abstract mixin class $AudioItemCopyWith<$Res>  {
  factory $AudioItemCopyWith(AudioItem value, $Res Function(AudioItem) _then) = _$AudioItemCopyWithImpl;
@useResult
$Res call({
 String id, String mediaId, AudioRole role,@DurationConverter() Duration start,@DurationConverter() Duration sourceStart,@DurationConverter() Duration sourceEnd, double volume
});




}
/// @nodoc
class _$AudioItemCopyWithImpl<$Res>
    implements $AudioItemCopyWith<$Res> {
  _$AudioItemCopyWithImpl(this._self, this._then);

  final AudioItem _self;
  final $Res Function(AudioItem) _then;

/// Create a copy of AudioItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? mediaId = null,Object? role = null,Object? start = null,Object? sourceStart = null,Object? sourceEnd = null,Object? volume = null,}) {
  return _then(AudioItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mediaId: null == mediaId ? _self.mediaId : mediaId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as AudioRole,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,sourceStart: null == sourceStart ? _self.sourceStart : sourceStart // ignore: cast_nullable_to_non_nullable
as Duration,sourceEnd: null == sourceEnd ? _self.sourceEnd : sourceEnd // ignore: cast_nullable_to_non_nullable
as Duration,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioItem].
extension AudioItemPatterns on AudioItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioItem value)  $default,){
final _that = this;
switch (_that) {
case _AudioItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioItem value)?  $default,){
final _that = this;
switch (_that) {
case _AudioItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String mediaId,  AudioRole role, @DurationConverter()  Duration start, @DurationConverter()  Duration sourceStart, @DurationConverter()  Duration sourceEnd,  double volume)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioItem() when $default != null:
return $default(_that.id,_that.mediaId,_that.role,_that.start,_that.sourceStart,_that.sourceEnd,_that.volume);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String mediaId,  AudioRole role, @DurationConverter()  Duration start, @DurationConverter()  Duration sourceStart, @DurationConverter()  Duration sourceEnd,  double volume)  $default,) {final _that = this;
switch (_that) {
case _AudioItem():
return $default(_that.id,_that.mediaId,_that.role,_that.start,_that.sourceStart,_that.sourceEnd,_that.volume);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String mediaId,  AudioRole role, @DurationConverter()  Duration start, @DurationConverter()  Duration sourceStart, @DurationConverter()  Duration sourceEnd,  double volume)?  $default,) {final _that = this;
switch (_that) {
case _AudioItem() when $default != null:
return $default(_that.id,_that.mediaId,_that.role,_that.start,_that.sourceStart,_that.sourceEnd,_that.volume);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AudioItem extends AudioItem {
  const _AudioItem({required this.id, required this.mediaId, required this.role, @DurationConverter() required this.start, @DurationConverter() required this.sourceStart, @DurationConverter() required this.sourceEnd, this.volume = 1.0}): super._();
  factory _AudioItem.fromJson(Map<String, dynamic> json) => _$AudioItemFromJson(json);

@override final  String id;
@override final  String mediaId;
@override final  AudioRole role;
@override@DurationConverter() final  Duration start;
@override@DurationConverter() final  Duration sourceStart;
@override@DurationConverter() final  Duration sourceEnd;
@override@JsonKey() final  double volume;

/// Create a copy of AudioItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioItemCopyWith<_AudioItem> get copyWith => __$AudioItemCopyWithImpl<_AudioItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AudioItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioItem&&(identical(other.id, id) || other.id == id)&&(identical(other.mediaId, mediaId) || other.mediaId == mediaId)&&(identical(other.role, role) || other.role == role)&&(identical(other.start, start) || other.start == start)&&(identical(other.sourceStart, sourceStart) || other.sourceStart == sourceStart)&&(identical(other.sourceEnd, sourceEnd) || other.sourceEnd == sourceEnd)&&(identical(other.volume, volume) || other.volume == volume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,mediaId,role,start,sourceStart,sourceEnd,volume);
}

@override
String toString() {
    return 'AudioItem(id: $id, mediaId: $mediaId, role: $role, start: $start, sourceStart: $sourceStart, sourceEnd: $sourceEnd, volume: $volume)';
}


}

/// @nodoc
abstract mixin class _$AudioItemCopyWith<$Res> implements $AudioItemCopyWith<$Res> {
  factory _$AudioItemCopyWith(_AudioItem value, $Res Function(_AudioItem) _then) = __$AudioItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String mediaId, AudioRole role,@DurationConverter() Duration start,@DurationConverter() Duration sourceStart,@DurationConverter() Duration sourceEnd, double volume
});




}
/// @nodoc
class __$AudioItemCopyWithImpl<$Res>
    implements _$AudioItemCopyWith<$Res> {
  __$AudioItemCopyWithImpl(this._self, this._then);

  final _AudioItem _self;
  final $Res Function(_AudioItem) _then;

/// Create a copy of AudioItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? mediaId = null,Object? role = null,Object? start = null,Object? sourceStart = null,Object? sourceEnd = null,Object? volume = null,}) {
  return _then(_AudioItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mediaId: null == mediaId ? _self.mediaId : mediaId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as AudioRole,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,sourceStart: null == sourceStart ? _self.sourceStart : sourceStart // ignore: cast_nullable_to_non_nullable
as Duration,sourceEnd: null == sourceEnd ? _self.sourceEnd : sourceEnd // ignore: cast_nullable_to_non_nullable
as Duration,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
