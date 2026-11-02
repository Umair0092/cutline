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
mixin _$AudioMix {

/// The main track's sound (0 mutes it).
 double get original; double get voiceover;/// Lower the original sound while a voiceover plays ("ducking").
 bool get duck;
/// Create a copy of AudioMix
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioMixCopyWith<AudioMix> get copyWith => _$AudioMixCopyWithImpl<AudioMix>(this as AudioMix, _$identity);

  /// Serializes this AudioMix to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AudioMix;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioMix&&(identical(other.original, _this.original) || other.original == _this.original)&&(identical(other.voiceover, _this.voiceover) || other.voiceover == _this.voiceover)&&(identical(other.duck, _this.duck) || other.duck == _this.duck));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AudioMix;
  return Object.hash(runtimeType,_this.original,_this.voiceover,_this.duck);
}

@override
String toString() {
  final _this = this as AudioMix;
  return 'AudioMix(original: ${_this.original}, voiceover: ${_this.voiceover}, duck: ${_this.duck})';
}


}

/// @nodoc
abstract mixin class $AudioMixCopyWith<$Res>  {
  factory $AudioMixCopyWith(AudioMix value, $Res Function(AudioMix) _then) = _$AudioMixCopyWithImpl;
@useResult
$Res call({
 double original, double voiceover, bool duck
});




}
/// @nodoc
class _$AudioMixCopyWithImpl<$Res>
    implements $AudioMixCopyWith<$Res> {
  _$AudioMixCopyWithImpl(this._self, this._then);

  final AudioMix _self;
  final $Res Function(AudioMix) _then;

/// Create a copy of AudioMix
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? original = null,Object? voiceover = null,Object? duck = null,}) {
  return _then(AudioMix(
original: null == original ? _self.original : original // ignore: cast_nullable_to_non_nullable
as double,voiceover: null == voiceover ? _self.voiceover : voiceover // ignore: cast_nullable_to_non_nullable
as double,duck: null == duck ? _self.duck : duck // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioMix].
extension AudioMixPatterns on AudioMix {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioMix value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioMix() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioMix value)  $default,){
final _that = this;
switch (_that) {
case _AudioMix():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioMix value)?  $default,){
final _that = this;
switch (_that) {
case _AudioMix() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double original,  double voiceover,  bool duck)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioMix() when $default != null:
return $default(_that.original,_that.voiceover,_that.duck);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double original,  double voiceover,  bool duck)  $default,) {final _that = this;
switch (_that) {
case _AudioMix():
return $default(_that.original,_that.voiceover,_that.duck);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double original,  double voiceover,  bool duck)?  $default,) {final _that = this;
switch (_that) {
case _AudioMix() when $default != null:
return $default(_that.original,_that.voiceover,_that.duck);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AudioMix implements AudioMix {
  const _AudioMix({this.original = 1.0, this.voiceover = 1.0, this.duck = true});
  factory _AudioMix.fromJson(Map<String, dynamic> json) => _$AudioMixFromJson(json);

/// The main track's sound (0 mutes it).
@override@JsonKey() final  double original;
@override@JsonKey() final  double voiceover;
/// Lower the original sound while a voiceover plays ("ducking").
@override@JsonKey() final  bool duck;

/// Create a copy of AudioMix
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioMixCopyWith<_AudioMix> get copyWith => __$AudioMixCopyWithImpl<_AudioMix>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AudioMixToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioMix&&(identical(other.original, original) || other.original == original)&&(identical(other.voiceover, voiceover) || other.voiceover == voiceover)&&(identical(other.duck, duck) || other.duck == duck));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,original,voiceover,duck);
}

@override
String toString() {
    return 'AudioMix(original: $original, voiceover: $voiceover, duck: $duck)';
}


}

/// @nodoc
abstract mixin class _$AudioMixCopyWith<$Res> implements $AudioMixCopyWith<$Res> {
  factory _$AudioMixCopyWith(_AudioMix value, $Res Function(_AudioMix) _then) = __$AudioMixCopyWithImpl;
@override @useResult
$Res call({
 double original, double voiceover, bool duck
});




}
/// @nodoc
class __$AudioMixCopyWithImpl<$Res>
    implements _$AudioMixCopyWith<$Res> {
  __$AudioMixCopyWithImpl(this._self, this._then);

  final _AudioMix _self;
  final $Res Function(_AudioMix) _then;

/// Create a copy of AudioMix
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? original = null,Object? voiceover = null,Object? duck = null,}) {
  return _then(_AudioMix(
original: null == original ? _self.original : original // ignore: cast_nullable_to_non_nullable
as double,voiceover: null == voiceover ? _self.voiceover : voiceover // ignore: cast_nullable_to_non_nullable
as double,duck: null == duck ? _self.duck : duck // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$AudioItem {

 String get id; String get mediaId; AudioRole get role;@DurationConverter() Duration get start;@DurationConverter() Duration get sourceStart;@DurationConverter() Duration get sourceEnd; double get volume;@DurationConverter() Duration get fadeIn;@DurationConverter() Duration get fadeOut; VoiceEffect get effect;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.mediaId, _this.mediaId) || other.mediaId == _this.mediaId)&&(identical(other.role, _this.role) || other.role == _this.role)&&(identical(other.start, _this.start) || other.start == _this.start)&&(identical(other.sourceStart, _this.sourceStart) || other.sourceStart == _this.sourceStart)&&(identical(other.sourceEnd, _this.sourceEnd) || other.sourceEnd == _this.sourceEnd)&&(identical(other.volume, _this.volume) || other.volume == _this.volume)&&(identical(other.fadeIn, _this.fadeIn) || other.fadeIn == _this.fadeIn)&&(identical(other.fadeOut, _this.fadeOut) || other.fadeOut == _this.fadeOut)&&(identical(other.effect, _this.effect) || other.effect == _this.effect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AudioItem;
  return Object.hash(runtimeType,_this.id,_this.mediaId,_this.role,_this.start,_this.sourceStart,_this.sourceEnd,_this.volume,_this.fadeIn,_this.fadeOut,_this.effect);
}

@override
String toString() {
  final _this = this as AudioItem;
  return 'AudioItem(id: ${_this.id}, mediaId: ${_this.mediaId}, role: ${_this.role}, start: ${_this.start}, sourceStart: ${_this.sourceStart}, sourceEnd: ${_this.sourceEnd}, volume: ${_this.volume}, fadeIn: ${_this.fadeIn}, fadeOut: ${_this.fadeOut}, effect: ${_this.effect})';
}


}

/// @nodoc
abstract mixin class $AudioItemCopyWith<$Res>  {
  factory $AudioItemCopyWith(AudioItem value, $Res Function(AudioItem) _then) = _$AudioItemCopyWithImpl;
@useResult
$Res call({
 String id, String mediaId, AudioRole role,@DurationConverter() Duration start,@DurationConverter() Duration sourceStart,@DurationConverter() Duration sourceEnd, double volume,@DurationConverter() Duration fadeIn,@DurationConverter() Duration fadeOut, VoiceEffect effect
});


$VoiceEffectCopyWith<$Res> get effect;

}
/// @nodoc
class _$AudioItemCopyWithImpl<$Res>
    implements $AudioItemCopyWith<$Res> {
  _$AudioItemCopyWithImpl(this._self, this._then);

  final AudioItem _self;
  final $Res Function(AudioItem) _then;

/// Create a copy of AudioItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? mediaId = null,Object? role = null,Object? start = null,Object? sourceStart = null,Object? sourceEnd = null,Object? volume = null,Object? fadeIn = null,Object? fadeOut = null,Object? effect = null,}) {
  return _then(AudioItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mediaId: null == mediaId ? _self.mediaId : mediaId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as AudioRole,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,sourceStart: null == sourceStart ? _self.sourceStart : sourceStart // ignore: cast_nullable_to_non_nullable
as Duration,sourceEnd: null == sourceEnd ? _self.sourceEnd : sourceEnd // ignore: cast_nullable_to_non_nullable
as Duration,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,fadeIn: null == fadeIn ? _self.fadeIn : fadeIn // ignore: cast_nullable_to_non_nullable
as Duration,fadeOut: null == fadeOut ? _self.fadeOut : fadeOut // ignore: cast_nullable_to_non_nullable
as Duration,effect: null == effect ? _self.effect : effect // ignore: cast_nullable_to_non_nullable
as VoiceEffect,
  ));
}
/// Create a copy of AudioItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VoiceEffectCopyWith<$Res> get effect {
  
  return $VoiceEffectCopyWith<$Res>(_self.effect, (value) {
    return _then(_self.copyWith(effect: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String mediaId,  AudioRole role, @DurationConverter()  Duration start, @DurationConverter()  Duration sourceStart, @DurationConverter()  Duration sourceEnd,  double volume, @DurationConverter()  Duration fadeIn, @DurationConverter()  Duration fadeOut,  VoiceEffect effect)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioItem() when $default != null:
return $default(_that.id,_that.mediaId,_that.role,_that.start,_that.sourceStart,_that.sourceEnd,_that.volume,_that.fadeIn,_that.fadeOut,_that.effect);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String mediaId,  AudioRole role, @DurationConverter()  Duration start, @DurationConverter()  Duration sourceStart, @DurationConverter()  Duration sourceEnd,  double volume, @DurationConverter()  Duration fadeIn, @DurationConverter()  Duration fadeOut,  VoiceEffect effect)  $default,) {final _that = this;
switch (_that) {
case _AudioItem():
return $default(_that.id,_that.mediaId,_that.role,_that.start,_that.sourceStart,_that.sourceEnd,_that.volume,_that.fadeIn,_that.fadeOut,_that.effect);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String mediaId,  AudioRole role, @DurationConverter()  Duration start, @DurationConverter()  Duration sourceStart, @DurationConverter()  Duration sourceEnd,  double volume, @DurationConverter()  Duration fadeIn, @DurationConverter()  Duration fadeOut,  VoiceEffect effect)?  $default,) {final _that = this;
switch (_that) {
case _AudioItem() when $default != null:
return $default(_that.id,_that.mediaId,_that.role,_that.start,_that.sourceStart,_that.sourceEnd,_that.volume,_that.fadeIn,_that.fadeOut,_that.effect);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AudioItem extends AudioItem {
  const _AudioItem({required this.id, required this.mediaId, required this.role, @DurationConverter() required this.start, @DurationConverter() required this.sourceStart, @DurationConverter() required this.sourceEnd, this.volume = 1.0, @DurationConverter() this.fadeIn = Duration.zero, @DurationConverter() this.fadeOut = Duration.zero, this.effect = const VoiceEffect()}): super._();
  factory _AudioItem.fromJson(Map<String, dynamic> json) => _$AudioItemFromJson(json);

@override final  String id;
@override final  String mediaId;
@override final  AudioRole role;
@override@DurationConverter() final  Duration start;
@override@DurationConverter() final  Duration sourceStart;
@override@DurationConverter() final  Duration sourceEnd;
@override@JsonKey() final  double volume;
@override@JsonKey()@DurationConverter() final  Duration fadeIn;
@override@JsonKey()@DurationConverter() final  Duration fadeOut;
@override@JsonKey() final  VoiceEffect effect;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioItem&&(identical(other.id, id) || other.id == id)&&(identical(other.mediaId, mediaId) || other.mediaId == mediaId)&&(identical(other.role, role) || other.role == role)&&(identical(other.start, start) || other.start == start)&&(identical(other.sourceStart, sourceStart) || other.sourceStart == sourceStart)&&(identical(other.sourceEnd, sourceEnd) || other.sourceEnd == sourceEnd)&&(identical(other.volume, volume) || other.volume == volume)&&(identical(other.fadeIn, fadeIn) || other.fadeIn == fadeIn)&&(identical(other.fadeOut, fadeOut) || other.fadeOut == fadeOut)&&(identical(other.effect, effect) || other.effect == effect));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,mediaId,role,start,sourceStart,sourceEnd,volume,fadeIn,fadeOut,effect);
}

@override
String toString() {
    return 'AudioItem(id: $id, mediaId: $mediaId, role: $role, start: $start, sourceStart: $sourceStart, sourceEnd: $sourceEnd, volume: $volume, fadeIn: $fadeIn, fadeOut: $fadeOut, effect: $effect)';
}


}

/// @nodoc
abstract mixin class _$AudioItemCopyWith<$Res> implements $AudioItemCopyWith<$Res> {
  factory _$AudioItemCopyWith(_AudioItem value, $Res Function(_AudioItem) _then) = __$AudioItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String mediaId, AudioRole role,@DurationConverter() Duration start,@DurationConverter() Duration sourceStart,@DurationConverter() Duration sourceEnd, double volume,@DurationConverter() Duration fadeIn,@DurationConverter() Duration fadeOut, VoiceEffect effect
});


@override $VoiceEffectCopyWith<$Res> get effect;

}
/// @nodoc
class __$AudioItemCopyWithImpl<$Res>
    implements _$AudioItemCopyWith<$Res> {
  __$AudioItemCopyWithImpl(this._self, this._then);

  final _AudioItem _self;
  final $Res Function(_AudioItem) _then;

/// Create a copy of AudioItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? mediaId = null,Object? role = null,Object? start = null,Object? sourceStart = null,Object? sourceEnd = null,Object? volume = null,Object? fadeIn = null,Object? fadeOut = null,Object? effect = null,}) {
  return _then(_AudioItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,mediaId: null == mediaId ? _self.mediaId : mediaId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as AudioRole,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,sourceStart: null == sourceStart ? _self.sourceStart : sourceStart // ignore: cast_nullable_to_non_nullable
as Duration,sourceEnd: null == sourceEnd ? _self.sourceEnd : sourceEnd // ignore: cast_nullable_to_non_nullable
as Duration,volume: null == volume ? _self.volume : volume // ignore: cast_nullable_to_non_nullable
as double,fadeIn: null == fadeIn ? _self.fadeIn : fadeIn // ignore: cast_nullable_to_non_nullable
as Duration,fadeOut: null == fadeOut ? _self.fadeOut : fadeOut // ignore: cast_nullable_to_non_nullable
as Duration,effect: null == effect ? _self.effect : effect // ignore: cast_nullable_to_non_nullable
as VoiceEffect,
  ));
}

/// Create a copy of AudioItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VoiceEffectCopyWith<$Res> get effect {
  
  return $VoiceEffectCopyWith<$Res>(_self.effect, (value) {
    return _then(_self.copyWith(effect: value));
  });
}
}

// dart format on
