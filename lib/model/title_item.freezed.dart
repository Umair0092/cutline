// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'title_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TitleSpec {

 String get templateId; Map<String, String> get fields;@DurationConverter() Duration get duration;
/// Create a copy of TitleSpec
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TitleSpecCopyWith<TitleSpec> get copyWith => _$TitleSpecCopyWithImpl<TitleSpec>(this as TitleSpec, _$identity);

  /// Serializes this TitleSpec to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TitleSpec;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TitleSpec&&(identical(other.templateId, _this.templateId) || other.templateId == _this.templateId)&&const DeepCollectionEquality().equals(other.fields, _this.fields)&&(identical(other.duration, _this.duration) || other.duration == _this.duration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TitleSpec;
  return Object.hash(runtimeType,_this.templateId,const DeepCollectionEquality().hash(_this.fields),_this.duration);
}

@override
String toString() {
  final _this = this as TitleSpec;
  return 'TitleSpec(templateId: ${_this.templateId}, fields: ${_this.fields}, duration: ${_this.duration})';
}


}

/// @nodoc
abstract mixin class $TitleSpecCopyWith<$Res>  {
  factory $TitleSpecCopyWith(TitleSpec value, $Res Function(TitleSpec) _then) = _$TitleSpecCopyWithImpl;
@useResult
$Res call({
 String templateId, Map<String, String> fields,@DurationConverter() Duration duration
});




}
/// @nodoc
class _$TitleSpecCopyWithImpl<$Res>
    implements $TitleSpecCopyWith<$Res> {
  _$TitleSpecCopyWithImpl(this._self, this._then);

  final TitleSpec _self;
  final $Res Function(TitleSpec) _then;

/// Create a copy of TitleSpec
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? templateId = null,Object? fields = null,Object? duration = null,}) {
  return _then(TitleSpec(
templateId: null == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String,fields: null == fields ? _self.fields : fields // ignore: cast_nullable_to_non_nullable
as Map<String, String>,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

}


/// Adds pattern-matching-related methods to [TitleSpec].
extension TitleSpecPatterns on TitleSpec {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TitleSpec value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TitleSpec() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TitleSpec value)  $default,){
final _that = this;
switch (_that) {
case _TitleSpec():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TitleSpec value)?  $default,){
final _that = this;
switch (_that) {
case _TitleSpec() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String templateId,  Map<String, String> fields, @DurationConverter()  Duration duration)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TitleSpec() when $default != null:
return $default(_that.templateId,_that.fields,_that.duration);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String templateId,  Map<String, String> fields, @DurationConverter()  Duration duration)  $default,) {final _that = this;
switch (_that) {
case _TitleSpec():
return $default(_that.templateId,_that.fields,_that.duration);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String templateId,  Map<String, String> fields, @DurationConverter()  Duration duration)?  $default,) {final _that = this;
switch (_that) {
case _TitleSpec() when $default != null:
return $default(_that.templateId,_that.fields,_that.duration);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TitleSpec implements TitleSpec {
  const _TitleSpec({required this.templateId,  Map<String, String> fields = const <String, String>{}, @DurationConverter() required this.duration}): _fields = fields;
  factory _TitleSpec.fromJson(Map<String, dynamic> json) => _$TitleSpecFromJson(json);

@override final  String templateId;
 final  Map<String, String> _fields;
@override@JsonKey() Map<String, String> get fields {
  if (_fields is EqualUnmodifiableMapView) return _fields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_fields);
}

@override@DurationConverter() final  Duration duration;

/// Create a copy of TitleSpec
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TitleSpecCopyWith<_TitleSpec> get copyWith => __$TitleSpecCopyWithImpl<_TitleSpec>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TitleSpecToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TitleSpec&&(identical(other.templateId, templateId) || other.templateId == templateId)&&const DeepCollectionEquality().equals(other.fields, _fields)&&(identical(other.duration, duration) || other.duration == duration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,templateId,const DeepCollectionEquality().hash(_fields),duration);
}

@override
String toString() {
    return 'TitleSpec(templateId: $templateId, fields: $fields, duration: $duration)';
}


}

/// @nodoc
abstract mixin class _$TitleSpecCopyWith<$Res> implements $TitleSpecCopyWith<$Res> {
  factory _$TitleSpecCopyWith(_TitleSpec value, $Res Function(_TitleSpec) _then) = __$TitleSpecCopyWithImpl;
@override @useResult
$Res call({
 String templateId, Map<String, String> fields,@DurationConverter() Duration duration
});




}
/// @nodoc
class __$TitleSpecCopyWithImpl<$Res>
    implements _$TitleSpecCopyWith<$Res> {
  __$TitleSpecCopyWithImpl(this._self, this._then);

  final _TitleSpec _self;
  final $Res Function(_TitleSpec) _then;

/// Create a copy of TitleSpec
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? templateId = null,Object? fields = null,Object? duration = null,}) {
  return _then(_TitleSpec(
templateId: null == templateId ? _self.templateId : templateId // ignore: cast_nullable_to_non_nullable
as String,fields: null == fields ? _self._fields : fields // ignore: cast_nullable_to_non_nullable
as Map<String, String>,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}


/// @nodoc
mixin _$TitleItem {

 String get id; TitleSpec get spec;@DurationConverter() Duration get start;
/// Create a copy of TitleItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TitleItemCopyWith<TitleItem> get copyWith => _$TitleItemCopyWithImpl<TitleItem>(this as TitleItem, _$identity);

  /// Serializes this TitleItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TitleItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TitleItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.spec, _this.spec) || other.spec == _this.spec)&&(identical(other.start, _this.start) || other.start == _this.start));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TitleItem;
  return Object.hash(runtimeType,_this.id,_this.spec,_this.start);
}

@override
String toString() {
  final _this = this as TitleItem;
  return 'TitleItem(id: ${_this.id}, spec: ${_this.spec}, start: ${_this.start})';
}


}

/// @nodoc
abstract mixin class $TitleItemCopyWith<$Res>  {
  factory $TitleItemCopyWith(TitleItem value, $Res Function(TitleItem) _then) = _$TitleItemCopyWithImpl;
@useResult
$Res call({
 String id, TitleSpec spec,@DurationConverter() Duration start
});


$TitleSpecCopyWith<$Res> get spec;

}
/// @nodoc
class _$TitleItemCopyWithImpl<$Res>
    implements $TitleItemCopyWith<$Res> {
  _$TitleItemCopyWithImpl(this._self, this._then);

  final TitleItem _self;
  final $Res Function(TitleItem) _then;

/// Create a copy of TitleItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? spec = null,Object? start = null,}) {
  return _then(TitleItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,spec: null == spec ? _self.spec : spec // ignore: cast_nullable_to_non_nullable
as TitleSpec,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}
/// Create a copy of TitleItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TitleSpecCopyWith<$Res> get spec {
  
  return $TitleSpecCopyWith<$Res>(_self.spec, (value) {
    return _then(_self.copyWith(spec: value));
  });
}
}


/// Adds pattern-matching-related methods to [TitleItem].
extension TitleItemPatterns on TitleItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TitleItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TitleItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TitleItem value)  $default,){
final _that = this;
switch (_that) {
case _TitleItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TitleItem value)?  $default,){
final _that = this;
switch (_that) {
case _TitleItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  TitleSpec spec, @DurationConverter()  Duration start)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TitleItem() when $default != null:
return $default(_that.id,_that.spec,_that.start);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  TitleSpec spec, @DurationConverter()  Duration start)  $default,) {final _that = this;
switch (_that) {
case _TitleItem():
return $default(_that.id,_that.spec,_that.start);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  TitleSpec spec, @DurationConverter()  Duration start)?  $default,) {final _that = this;
switch (_that) {
case _TitleItem() when $default != null:
return $default(_that.id,_that.spec,_that.start);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TitleItem extends TitleItem {
  const _TitleItem({required this.id, required this.spec, @DurationConverter() required this.start}): super._();
  factory _TitleItem.fromJson(Map<String, dynamic> json) => _$TitleItemFromJson(json);

@override final  String id;
@override final  TitleSpec spec;
@override@DurationConverter() final  Duration start;

/// Create a copy of TitleItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TitleItemCopyWith<_TitleItem> get copyWith => __$TitleItemCopyWithImpl<_TitleItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TitleItemToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TitleItem&&(identical(other.id, id) || other.id == id)&&(identical(other.spec, spec) || other.spec == spec)&&(identical(other.start, start) || other.start == start));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,spec,start);
}

@override
String toString() {
    return 'TitleItem(id: $id, spec: $spec, start: $start)';
}


}

/// @nodoc
abstract mixin class _$TitleItemCopyWith<$Res> implements $TitleItemCopyWith<$Res> {
  factory _$TitleItemCopyWith(_TitleItem value, $Res Function(_TitleItem) _then) = __$TitleItemCopyWithImpl;
@override @useResult
$Res call({
 String id, TitleSpec spec,@DurationConverter() Duration start
});


@override $TitleSpecCopyWith<$Res> get spec;

}
/// @nodoc
class __$TitleItemCopyWithImpl<$Res>
    implements _$TitleItemCopyWith<$Res> {
  __$TitleItemCopyWithImpl(this._self, this._then);

  final _TitleItem _self;
  final $Res Function(_TitleItem) _then;

/// Create a copy of TitleItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? spec = null,Object? start = null,}) {
  return _then(_TitleItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,spec: null == spec ? _self.spec : spec // ignore: cast_nullable_to_non_nullable
as TitleSpec,start: null == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

/// Create a copy of TitleItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TitleSpecCopyWith<$Res> get spec {
  
  return $TitleSpecCopyWith<$Res>(_self.spec, (value) {
    return _then(_self.copyWith(spec: value));
  });
}
}

// dart format on
