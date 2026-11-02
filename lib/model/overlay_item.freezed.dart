// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'overlay_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OverlayTransform {

 double get x; double get y; double get scale; double get rotation; double get opacity;
/// Create a copy of OverlayTransform
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OverlayTransformCopyWith<OverlayTransform> get copyWith => _$OverlayTransformCopyWithImpl<OverlayTransform>(this as OverlayTransform, _$identity);

  /// Serializes this OverlayTransform to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OverlayTransform;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OverlayTransform&&(identical(other.x, _this.x) || other.x == _this.x)&&(identical(other.y, _this.y) || other.y == _this.y)&&(identical(other.scale, _this.scale) || other.scale == _this.scale)&&(identical(other.rotation, _this.rotation) || other.rotation == _this.rotation)&&(identical(other.opacity, _this.opacity) || other.opacity == _this.opacity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OverlayTransform;
  return Object.hash(runtimeType,_this.x,_this.y,_this.scale,_this.rotation,_this.opacity);
}

@override
String toString() {
  final _this = this as OverlayTransform;
  return 'OverlayTransform(x: ${_this.x}, y: ${_this.y}, scale: ${_this.scale}, rotation: ${_this.rotation}, opacity: ${_this.opacity})';
}


}

/// @nodoc
abstract mixin class $OverlayTransformCopyWith<$Res>  {
  factory $OverlayTransformCopyWith(OverlayTransform value, $Res Function(OverlayTransform) _then) = _$OverlayTransformCopyWithImpl;
@useResult
$Res call({
 double x, double y, double scale, double rotation, double opacity
});




}
/// @nodoc
class _$OverlayTransformCopyWithImpl<$Res>
    implements $OverlayTransformCopyWith<$Res> {
  _$OverlayTransformCopyWithImpl(this._self, this._then);

  final OverlayTransform _self;
  final $Res Function(OverlayTransform) _then;

/// Create a copy of OverlayTransform
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? x = null,Object? y = null,Object? scale = null,Object? rotation = null,Object? opacity = null,}) {
  return _then(OverlayTransform(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,rotation: null == rotation ? _self.rotation : rotation // ignore: cast_nullable_to_non_nullable
as double,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [OverlayTransform].
extension OverlayTransformPatterns on OverlayTransform {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OverlayTransform value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OverlayTransform() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OverlayTransform value)  $default,){
final _that = this;
switch (_that) {
case _OverlayTransform():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OverlayTransform value)?  $default,){
final _that = this;
switch (_that) {
case _OverlayTransform() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double x,  double y,  double scale,  double rotation,  double opacity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OverlayTransform() when $default != null:
return $default(_that.x,_that.y,_that.scale,_that.rotation,_that.opacity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double x,  double y,  double scale,  double rotation,  double opacity)  $default,) {final _that = this;
switch (_that) {
case _OverlayTransform():
return $default(_that.x,_that.y,_that.scale,_that.rotation,_that.opacity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double x,  double y,  double scale,  double rotation,  double opacity)?  $default,) {final _that = this;
switch (_that) {
case _OverlayTransform() when $default != null:
return $default(_that.x,_that.y,_that.scale,_that.rotation,_that.opacity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OverlayTransform implements OverlayTransform {
  const _OverlayTransform({this.x = 0.5, this.y = 0.5, this.scale = 0.3, this.rotation = 0.0, this.opacity = 1.0});
  factory _OverlayTransform.fromJson(Map<String, dynamic> json) => _$OverlayTransformFromJson(json);

@override@JsonKey() final  double x;
@override@JsonKey() final  double y;
@override@JsonKey() final  double scale;
@override@JsonKey() final  double rotation;
@override@JsonKey() final  double opacity;

/// Create a copy of OverlayTransform
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OverlayTransformCopyWith<_OverlayTransform> get copyWith => __$OverlayTransformCopyWithImpl<_OverlayTransform>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OverlayTransformToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OverlayTransform&&(identical(other.x, x) || other.x == x)&&(identical(other.y, y) || other.y == y)&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.rotation, rotation) || other.rotation == rotation)&&(identical(other.opacity, opacity) || other.opacity == opacity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,x,y,scale,rotation,opacity);
}

@override
String toString() {
    return 'OverlayTransform(x: $x, y: $y, scale: $scale, rotation: $rotation, opacity: $opacity)';
}


}

/// @nodoc
abstract mixin class _$OverlayTransformCopyWith<$Res> implements $OverlayTransformCopyWith<$Res> {
  factory _$OverlayTransformCopyWith(_OverlayTransform value, $Res Function(_OverlayTransform) _then) = __$OverlayTransformCopyWithImpl;
@override @useResult
$Res call({
 double x, double y, double scale, double rotation, double opacity
});




}
/// @nodoc
class __$OverlayTransformCopyWithImpl<$Res>
    implements _$OverlayTransformCopyWith<$Res> {
  __$OverlayTransformCopyWithImpl(this._self, this._then);

  final _OverlayTransform _self;
  final $Res Function(_OverlayTransform) _then;

/// Create a copy of OverlayTransform
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? x = null,Object? y = null,Object? scale = null,Object? rotation = null,Object? opacity = null,}) {
  return _then(_OverlayTransform(
x: null == x ? _self.x : x // ignore: cast_nullable_to_non_nullable
as double,y: null == y ? _self.y : y // ignore: cast_nullable_to_non_nullable
as double,scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as double,rotation: null == rotation ? _self.rotation : rotation // ignore: cast_nullable_to_non_nullable
as double,opacity: null == opacity ? _self.opacity : opacity // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$OverlayItem {

 String get id; String get mediaId;@DurationConverter() Duration get start;@DurationConverter() Duration get duration; OverlayTransform get transform; int get layer; OverlayAnimation get animation;/// Loudness of the file's own sound (a meme sound, a video sticker).
 double get volume;
/// Create a copy of OverlayItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OverlayItemCopyWith<OverlayItem> get copyWith => _$OverlayItemCopyWithImpl<OverlayItem>(this as OverlayItem, _$identity);

  /// Serializes this OverlayItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as OverlayItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OverlayItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.mediaId, _this.mediaId) || other.mediaId == _this.mediaId)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&(identical(other.transform, _this.transform) || other.transform == _this.transform)&&(identical(other.layer, _this.layer) || other.layer == _this.layer)&&(identical(other.animation, _this.animation) || other.animation == _this.animation)&&(identical(other.volume, _this.volume) || other.volume == _this.volume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as OverlayItem;
  return Object.hash(runtimeType,_this.id,_this.mediaId,_this.start,_this.duration,_this.transform,_this.layer,_this.animation,_this.volume);
}

@override
String toString() {
  final _this = this as OverlayItem;
  return 'OverlayItem(id: ${_this.id}, mediaId: ${_this.mediaId}, start: ${_this.start}, duration: ${_this.duration}, transform: ${_this.transform}, layer: ${_this.layer}, animation: ${_this.animation}, volume: ${_this.volume})';
}


}

/// @nodoc
abstract mixin class $OverlayItemCopyWith<$Res>  {
  factory $OverlayItemCopyWith(OverlayItem value, $Res Function(OverlayItem) _then) = _$OverlayItemCopyWithImpl;
@useResult
$Res call({
 String id, String mediaId,@DurationConverter() Duration start,@DurationConverter() Duration duration, OverlayTransform transform, int layer, OverlayAnimation animation, double volume
});


$OverlayTransformCopyWith<$Res> get transform;

}
/// @nodoc
class _$OverlayItemCopyWithImpl<$Res>
    implements $OverlayItemCopyWith<$Res> {
  _$OverlayItemCopyWithImpl(this._self, this._then);

  final OverlayItem _self;
  final $Res Function(OverlayItem) _then;

/// Create a copy of OverlayItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? mediaId = null,Object? start = null,Object? duration = null,Object? transform = null,Object? layer = null,Object? animation = null,Object? volume = null,}) {
  return _then(OverlayItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mediaId: null == mediaId ? _self.mediaId : mediaId // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,transform: null == transform ? _self.transform : transform // ignore: cast_nullable_to_non_nullable
as OverlayTransform,layer: null == layer ? _self.layer : layer // ignore: cast_nullable_to_non_nullable
as int,animation: null == animation ? _self.animation : animation // ignore: cast_nullable_to_non_nullable
as OverlayAnimation,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,
  ));
}
/// Create a copy of OverlayItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OverlayTransformCopyWith<$Res> get transform {
  
  return $OverlayTransformCopyWith<$Res>(_self.transform, (value) {
    return _then(_self.copyWith(transform: value));
  });
}
}


/// Adds pattern-matching-related methods to [OverlayItem].
extension OverlayItemPatterns on OverlayItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OverlayItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OverlayItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OverlayItem value)  $default,){
final _that = this;
switch (_that) {
case _OverlayItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OverlayItem value)?  $default,){
final _that = this;
switch (_that) {
case _OverlayItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String mediaId, @DurationConverter()  Duration start, @DurationConverter()  Duration duration,  OverlayTransform transform,  int layer,  OverlayAnimation animation,  double volume)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OverlayItem() when $default != null:
return $default(_that.id,_that.mediaId,_that.start,_that.duration,_that.transform,_that.layer,_that.animation,_that.volume);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String mediaId, @DurationConverter()  Duration start, @DurationConverter()  Duration duration,  OverlayTransform transform,  int layer,  OverlayAnimation animation,  double volume)  $default,) {final _that = this;
switch (_that) {
case _OverlayItem():
return $default(_that.id,_that.mediaId,_that.start,_that.duration,_that.transform,_that.layer,_that.animation,_that.volume);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String mediaId, @DurationConverter()  Duration start, @DurationConverter()  Duration duration,  OverlayTransform transform,  int layer,  OverlayAnimation animation,  double volume)?  $default,) {final _that = this;
switch (_that) {
case _OverlayItem() when $default != null:
return $default(_that.id,_that.mediaId,_that.start,_that.duration,_that.transform,_that.layer,_that.animation,_that.volume);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OverlayItem extends OverlayItem {
  const _OverlayItem({required this.id, required this.mediaId, @DurationConverter() required this.start, @DurationConverter() required this.duration, this.transform = const OverlayTransform(), this.layer = 0, this.animation = OverlayAnimation.pop, this.volume = 1.0}): super._();
  factory _OverlayItem.fromJson(Map<String, dynamic> json) => _$OverlayItemFromJson(json);

@override final  String id;
@override final  String mediaId;
@override@DurationConverter() final  Duration start;
@override@DurationConverter() final  Duration duration;
@override@JsonKey() final  OverlayTransform transform;
@override@JsonKey() final  int layer;
@override@JsonKey() final  OverlayAnimation animation;
/// Loudness of the file's own sound (a meme sound, a video sticker).
@override@JsonKey() final  double volume;

/// Create a copy of OverlayItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OverlayItemCopyWith<_OverlayItem> get copyWith => __$OverlayItemCopyWithImpl<_OverlayItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OverlayItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _OverlayItem&&(identical(other.id, id) || other.id == id)&&(identical(other.mediaId, mediaId) || other.mediaId == mediaId)&&(identical(other.start, start) || other.start == start)&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.transform, transform) || other.transform == transform)&&(identical(other.layer, layer) || other.layer == layer)&&(identical(other.animation, animation) || other.animation == animation)&&(identical(other.volume, volume) || other.volume == volume));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,mediaId,start,duration,transform,layer,animation,volume);
}

@override
String toString() {
    return 'OverlayItem(id: $id, mediaId: $mediaId, start: $start, duration: $duration, transform: $transform, layer: $layer, animation: $animation, volume: $volume)';
}


}

/// @nodoc
abstract mixin class _$OverlayItemCopyWith<$Res> implements $OverlayItemCopyWith<$Res> {
  factory _$OverlayItemCopyWith(_OverlayItem value, $Res Function(_OverlayItem) _then) = __$OverlayItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String mediaId,@DurationConverter() Duration start,@DurationConverter() Duration duration, OverlayTransform transform, int layer, OverlayAnimation animation, double volume
});


@override $OverlayTransformCopyWith<$Res> get transform;

}
/// @nodoc
class __$OverlayItemCopyWithImpl<$Res>
    implements _$OverlayItemCopyWith<$Res> {
  __$OverlayItemCopyWithImpl(this._self, this._then);

  final _OverlayItem _self;
  final $Res Function(_OverlayItem) _then;

/// Create a copy of OverlayItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? mediaId = null,Object? start = null,Object? duration = null,Object? transform = null,Object? layer = null,Object? animation = null,Object? volume = null,}) {
  return _then(_OverlayItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mediaId: null == mediaId ? _self.mediaId : mediaId // ignore: cast_nullable_to_non_nullable
as String,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,transform: null == transform ? _self.transform : transform // ignore: cast_nullable_to_non_nullable
as OverlayTransform,layer: null == layer ? _self.layer : layer // ignore: cast_nullable_to_non_nullable
as int,animation: null == animation ? _self.animation : animation // ignore: cast_nullable_to_non_nullable
as OverlayAnimation,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of OverlayItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OverlayTransformCopyWith<$Res> get transform {
  
  return $OverlayTransformCopyWith<$Res>(_self.transform, (value) {
    return _then(_self.copyWith(transform: value));
  });
}
}

// dart format on
