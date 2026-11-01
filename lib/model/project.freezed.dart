// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'project.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Project {

 int get schemaVersion; String get name; List<MediaAsset> get media; List<VideoClip> get clips; List<OverlayItem> get overlays; List<AudioItem> get audio;
/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProjectCopyWith<Project> get copyWith => _$ProjectCopyWithImpl<Project>(this as Project, _$identity);

  /// Serializes this Project to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Project;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Project&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion)&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.media, _this.media)&&const DeepCollectionEquality().equals(other.clips, _this.clips)&&const DeepCollectionEquality().equals(other.overlays, _this.overlays)&&const DeepCollectionEquality().equals(other.audio, _this.audio));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Project;
  return Object.hash(runtimeType,_this.schemaVersion,_this.name,const DeepCollectionEquality().hash(_this.media),const DeepCollectionEquality().hash(_this.clips),const DeepCollectionEquality().hash(_this.overlays),const DeepCollectionEquality().hash(_this.audio));
}

@override
String toString() {
  final _this = this as Project;
  return 'Project(schemaVersion: ${_this.schemaVersion}, name: ${_this.name}, media: ${_this.media}, clips: ${_this.clips}, overlays: ${_this.overlays}, audio: ${_this.audio})';
}


}

/// @nodoc
abstract mixin class $ProjectCopyWith<$Res>  {
  factory $ProjectCopyWith(Project value, $Res Function(Project) _then) = _$ProjectCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, String name, List<MediaAsset> media, List<VideoClip> clips, List<OverlayItem> overlays, List<AudioItem> audio
});




}
/// @nodoc
class _$ProjectCopyWithImpl<$Res>
    implements $ProjectCopyWith<$Res> {
  _$ProjectCopyWithImpl(this._self, this._then);

  final Project _self;
  final $Res Function(Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? name = null,Object? media = null,Object? clips = null,Object? overlays = null,Object? audio = null,}) {
  return _then(Project(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as List<MediaAsset>,clips: null == clips ? _self.clips : clips // ignore: cast_nullable_to_non_nullable
as List<VideoClip>,overlays: null == overlays ? _self.overlays : overlays // ignore: cast_nullable_to_non_nullable
as List<OverlayItem>,audio: null == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as List<AudioItem>,
  ));
}

}


/// Adds pattern-matching-related methods to [Project].
extension ProjectPatterns on Project {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Project value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Project value)  $default,){
final _that = this;
switch (_that) {
case _Project():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Project value)?  $default,){
final _that = this;
switch (_that) {
case _Project() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  String name,  List<MediaAsset> media,  List<VideoClip> clips,  List<OverlayItem> overlays,  List<AudioItem> audio)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.schemaVersion,_that.name,_that.media,_that.clips,_that.overlays,_that.audio);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  String name,  List<MediaAsset> media,  List<VideoClip> clips,  List<OverlayItem> overlays,  List<AudioItem> audio)  $default,) {final _that = this;
switch (_that) {
case _Project():
return $default(_that.schemaVersion,_that.name,_that.media,_that.clips,_that.overlays,_that.audio);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  String name,  List<MediaAsset> media,  List<VideoClip> clips,  List<OverlayItem> overlays,  List<AudioItem> audio)?  $default,) {final _that = this;
switch (_that) {
case _Project() when $default != null:
return $default(_that.schemaVersion,_that.name,_that.media,_that.clips,_that.overlays,_that.audio);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Project extends Project {
  const _Project({this.schemaVersion = Project.currentSchemaVersion, this.name = 'Untitled',  List<MediaAsset> media = const <MediaAsset>[],  List<VideoClip> clips = const <VideoClip>[],  List<OverlayItem> overlays = const <OverlayItem>[],  List<AudioItem> audio = const <AudioItem>[]}): _media = media,_clips = clips,_overlays = overlays,_audio = audio,super._();
  factory _Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);

@override@JsonKey() final  int schemaVersion;
@override@JsonKey() final  String name;
 final  List<MediaAsset> _media;
@override@JsonKey() List<MediaAsset> get media {
  if (_media is EqualUnmodifiableListView) return _media;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_media);
}

 final  List<VideoClip> _clips;
@override@JsonKey() List<VideoClip> get clips {
  if (_clips is EqualUnmodifiableListView) return _clips;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_clips);
}

 final  List<OverlayItem> _overlays;
@override@JsonKey() List<OverlayItem> get overlays {
  if (_overlays is EqualUnmodifiableListView) return _overlays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_overlays);
}

 final  List<AudioItem> _audio;
@override@JsonKey() List<AudioItem> get audio {
  if (_audio is EqualUnmodifiableListView) return _audio;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_audio);
}


/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProjectCopyWith<_Project> get copyWith => __$ProjectCopyWithImpl<_Project>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProjectToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Project&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.media, _media)&&const DeepCollectionEquality().equals(other.clips, _clips)&&const DeepCollectionEquality().equals(other.overlays, _overlays)&&const DeepCollectionEquality().equals(other.audio, _audio));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,schemaVersion,name,const DeepCollectionEquality().hash(_media),const DeepCollectionEquality().hash(_clips),const DeepCollectionEquality().hash(_overlays),const DeepCollectionEquality().hash(_audio));
}

@override
String toString() {
    return 'Project(schemaVersion: $schemaVersion, name: $name, media: $media, clips: $clips, overlays: $overlays, audio: $audio)';
}


}

/// @nodoc
abstract mixin class _$ProjectCopyWith<$Res> implements $ProjectCopyWith<$Res> {
  factory _$ProjectCopyWith(_Project value, $Res Function(_Project) _then) = __$ProjectCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, String name, List<MediaAsset> media, List<VideoClip> clips, List<OverlayItem> overlays, List<AudioItem> audio
});




}
/// @nodoc
class __$ProjectCopyWithImpl<$Res>
    implements _$ProjectCopyWith<$Res> {
  __$ProjectCopyWithImpl(this._self, this._then);

  final _Project _self;
  final $Res Function(_Project) _then;

/// Create a copy of Project
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? name = null,Object? media = null,Object? clips = null,Object? overlays = null,Object? audio = null,}) {
  return _then(_Project(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self._media : media // ignore: cast_nullable_to_non_nullable
as List<MediaAsset>,clips: null == clips ? _self._clips : clips // ignore: cast_nullable_to_non_nullable
as List<VideoClip>,overlays: null == overlays ? _self._overlays : overlays // ignore: cast_nullable_to_non_nullable
as List<OverlayItem>,audio: null == audio ? _self._audio : audio // ignore: cast_nullable_to_non_nullable
as List<AudioItem>,
  ));
}


}

// dart format on
