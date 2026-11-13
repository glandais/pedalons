// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'json_node.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JsonNode {

 bool? get empty; bool? get valueNode; bool? get containerNode; bool? get missingNode; bool? get array;@JsonKey(name: 'object') bool? get objectField; JsonNodeType? get nodeType; bool? get pojo; bool? get number; bool? get integralNumber; bool? get floatingPointNumber; bool? get short;@JsonKey(name: 'int') bool? get intField; bool? get long; bool? get float;@JsonKey(name: 'double') bool? get doubleField; bool? get bigDecimal; bool? get bigInteger; bool? get textual; bool? get boolean;@JsonKey(name: 'null') bool? get nullField; bool? get binary;
/// Create a copy of JsonNode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JsonNodeCopyWith<JsonNode> get copyWith => _$JsonNodeCopyWithImpl<JsonNode>(this as JsonNode, _$identity);

  /// Serializes this JsonNode to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as JsonNode;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JsonNode&&(identical(other.empty, _this.empty) || other.empty == _this.empty)&&(identical(other.valueNode, _this.valueNode) || other.valueNode == _this.valueNode)&&(identical(other.containerNode, _this.containerNode) || other.containerNode == _this.containerNode)&&(identical(other.missingNode, _this.missingNode) || other.missingNode == _this.missingNode)&&(identical(other.array, _this.array) || other.array == _this.array)&&(identical(other.objectField, _this.objectField) || other.objectField == _this.objectField)&&(identical(other.nodeType, _this.nodeType) || other.nodeType == _this.nodeType)&&(identical(other.pojo, _this.pojo) || other.pojo == _this.pojo)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.integralNumber, _this.integralNumber) || other.integralNumber == _this.integralNumber)&&(identical(other.floatingPointNumber, _this.floatingPointNumber) || other.floatingPointNumber == _this.floatingPointNumber)&&(identical(other.short, _this.short) || other.short == _this.short)&&(identical(other.intField, _this.intField) || other.intField == _this.intField)&&(identical(other.long, _this.long) || other.long == _this.long)&&(identical(other.float, _this.float) || other.float == _this.float)&&(identical(other.doubleField, _this.doubleField) || other.doubleField == _this.doubleField)&&(identical(other.bigDecimal, _this.bigDecimal) || other.bigDecimal == _this.bigDecimal)&&(identical(other.bigInteger, _this.bigInteger) || other.bigInteger == _this.bigInteger)&&(identical(other.textual, _this.textual) || other.textual == _this.textual)&&(identical(other.boolean, _this.boolean) || other.boolean == _this.boolean)&&(identical(other.nullField, _this.nullField) || other.nullField == _this.nullField)&&(identical(other.binary, _this.binary) || other.binary == _this.binary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as JsonNode;
  return Object.hashAll([runtimeType,_this.empty,_this.valueNode,_this.containerNode,_this.missingNode,_this.array,_this.objectField,_this.nodeType,_this.pojo,_this.number,_this.integralNumber,_this.floatingPointNumber,_this.short,_this.intField,_this.long,_this.float,_this.doubleField,_this.bigDecimal,_this.bigInteger,_this.textual,_this.boolean,_this.nullField,_this.binary]);
}

@override
String toString() {
  final _this = this as JsonNode;
  return 'JsonNode(empty: ${_this.empty}, valueNode: ${_this.valueNode}, containerNode: ${_this.containerNode}, missingNode: ${_this.missingNode}, array: ${_this.array}, objectField: ${_this.objectField}, nodeType: ${_this.nodeType}, pojo: ${_this.pojo}, number: ${_this.number}, integralNumber: ${_this.integralNumber}, floatingPointNumber: ${_this.floatingPointNumber}, short: ${_this.short}, intField: ${_this.intField}, long: ${_this.long}, float: ${_this.float}, doubleField: ${_this.doubleField}, bigDecimal: ${_this.bigDecimal}, bigInteger: ${_this.bigInteger}, textual: ${_this.textual}, boolean: ${_this.boolean}, nullField: ${_this.nullField}, binary: ${_this.binary})';
}


}

/// @nodoc
abstract mixin class $JsonNodeCopyWith<$Res>  {
  factory $JsonNodeCopyWith(JsonNode value, $Res Function(JsonNode) _then) = _$JsonNodeCopyWithImpl;
@useResult
$Res call({
 bool? empty, bool? valueNode, bool? containerNode, bool? missingNode, bool? array,@JsonKey(name: 'object') bool? objectField, JsonNodeType? nodeType, bool? pojo, bool? number, bool? integralNumber, bool? floatingPointNumber, bool? short,@JsonKey(name: 'int') bool? intField, bool? long, bool? float,@JsonKey(name: 'double') bool? doubleField, bool? bigDecimal, bool? bigInteger, bool? textual, bool? boolean,@JsonKey(name: 'null') bool? nullField, bool? binary
});




}
/// @nodoc
class _$JsonNodeCopyWithImpl<$Res>
    implements $JsonNodeCopyWith<$Res> {
  _$JsonNodeCopyWithImpl(this._self, this._then);

  final JsonNode _self;
  final $Res Function(JsonNode) _then;

/// Create a copy of JsonNode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? empty = freezed,Object? valueNode = freezed,Object? containerNode = freezed,Object? missingNode = freezed,Object? array = freezed,Object? objectField = freezed,Object? nodeType = freezed,Object? pojo = freezed,Object? number = freezed,Object? integralNumber = freezed,Object? floatingPointNumber = freezed,Object? short = freezed,Object? intField = freezed,Object? long = freezed,Object? float = freezed,Object? doubleField = freezed,Object? bigDecimal = freezed,Object? bigInteger = freezed,Object? textual = freezed,Object? boolean = freezed,Object? nullField = freezed,Object? binary = freezed,}) {
  return _then(JsonNode(
empty: freezed == empty ? _self.empty : empty // ignore: cast_nullable_to_non_nullable
as bool?,valueNode: freezed == valueNode ? _self.valueNode : valueNode // ignore: cast_nullable_to_non_nullable
as bool?,containerNode: freezed == containerNode ? _self.containerNode : containerNode // ignore: cast_nullable_to_non_nullable
as bool?,missingNode: freezed == missingNode ? _self.missingNode : missingNode // ignore: cast_nullable_to_non_nullable
as bool?,array: freezed == array ? _self.array : array // ignore: cast_nullable_to_non_nullable
as bool?,objectField: freezed == objectField ? _self.objectField : objectField // ignore: cast_nullable_to_non_nullable
as bool?,nodeType: freezed == nodeType ? _self.nodeType : nodeType // ignore: cast_nullable_to_non_nullable
as JsonNodeType?,pojo: freezed == pojo ? _self.pojo : pojo // ignore: cast_nullable_to_non_nullable
as bool?,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as bool?,integralNumber: freezed == integralNumber ? _self.integralNumber : integralNumber // ignore: cast_nullable_to_non_nullable
as bool?,floatingPointNumber: freezed == floatingPointNumber ? _self.floatingPointNumber : floatingPointNumber // ignore: cast_nullable_to_non_nullable
as bool?,short: freezed == short ? _self.short : short // ignore: cast_nullable_to_non_nullable
as bool?,intField: freezed == intField ? _self.intField : intField // ignore: cast_nullable_to_non_nullable
as bool?,long: freezed == long ? _self.long : long // ignore: cast_nullable_to_non_nullable
as bool?,float: freezed == float ? _self.float : float // ignore: cast_nullable_to_non_nullable
as bool?,doubleField: freezed == doubleField ? _self.doubleField : doubleField // ignore: cast_nullable_to_non_nullable
as bool?,bigDecimal: freezed == bigDecimal ? _self.bigDecimal : bigDecimal // ignore: cast_nullable_to_non_nullable
as bool?,bigInteger: freezed == bigInteger ? _self.bigInteger : bigInteger // ignore: cast_nullable_to_non_nullable
as bool?,textual: freezed == textual ? _self.textual : textual // ignore: cast_nullable_to_non_nullable
as bool?,boolean: freezed == boolean ? _self.boolean : boolean // ignore: cast_nullable_to_non_nullable
as bool?,nullField: freezed == nullField ? _self.nullField : nullField // ignore: cast_nullable_to_non_nullable
as bool?,binary: freezed == binary ? _self.binary : binary // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [JsonNode].
extension JsonNodePatterns on JsonNode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JsonNode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JsonNode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JsonNode value)  $default,){
final _that = this;
switch (_that) {
case _JsonNode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JsonNode value)?  $default,){
final _that = this;
switch (_that) {
case _JsonNode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool? empty,  bool? valueNode,  bool? containerNode,  bool? missingNode,  bool? array, @JsonKey(name: 'object')  bool? objectField,  JsonNodeType? nodeType,  bool? pojo,  bool? number,  bool? integralNumber,  bool? floatingPointNumber,  bool? short, @JsonKey(name: 'int')  bool? intField,  bool? long,  bool? float, @JsonKey(name: 'double')  bool? doubleField,  bool? bigDecimal,  bool? bigInteger,  bool? textual,  bool? boolean, @JsonKey(name: 'null')  bool? nullField,  bool? binary)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JsonNode() when $default != null:
return $default(_that.empty,_that.valueNode,_that.containerNode,_that.missingNode,_that.array,_that.objectField,_that.nodeType,_that.pojo,_that.number,_that.integralNumber,_that.floatingPointNumber,_that.short,_that.intField,_that.long,_that.float,_that.doubleField,_that.bigDecimal,_that.bigInteger,_that.textual,_that.boolean,_that.nullField,_that.binary);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool? empty,  bool? valueNode,  bool? containerNode,  bool? missingNode,  bool? array, @JsonKey(name: 'object')  bool? objectField,  JsonNodeType? nodeType,  bool? pojo,  bool? number,  bool? integralNumber,  bool? floatingPointNumber,  bool? short, @JsonKey(name: 'int')  bool? intField,  bool? long,  bool? float, @JsonKey(name: 'double')  bool? doubleField,  bool? bigDecimal,  bool? bigInteger,  bool? textual,  bool? boolean, @JsonKey(name: 'null')  bool? nullField,  bool? binary)  $default,) {final _that = this;
switch (_that) {
case _JsonNode():
return $default(_that.empty,_that.valueNode,_that.containerNode,_that.missingNode,_that.array,_that.objectField,_that.nodeType,_that.pojo,_that.number,_that.integralNumber,_that.floatingPointNumber,_that.short,_that.intField,_that.long,_that.float,_that.doubleField,_that.bigDecimal,_that.bigInteger,_that.textual,_that.boolean,_that.nullField,_that.binary);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool? empty,  bool? valueNode,  bool? containerNode,  bool? missingNode,  bool? array, @JsonKey(name: 'object')  bool? objectField,  JsonNodeType? nodeType,  bool? pojo,  bool? number,  bool? integralNumber,  bool? floatingPointNumber,  bool? short, @JsonKey(name: 'int')  bool? intField,  bool? long,  bool? float, @JsonKey(name: 'double')  bool? doubleField,  bool? bigDecimal,  bool? bigInteger,  bool? textual,  bool? boolean, @JsonKey(name: 'null')  bool? nullField,  bool? binary)?  $default,) {final _that = this;
switch (_that) {
case _JsonNode() when $default != null:
return $default(_that.empty,_that.valueNode,_that.containerNode,_that.missingNode,_that.array,_that.objectField,_that.nodeType,_that.pojo,_that.number,_that.integralNumber,_that.floatingPointNumber,_that.short,_that.intField,_that.long,_that.float,_that.doubleField,_that.bigDecimal,_that.bigInteger,_that.textual,_that.boolean,_that.nullField,_that.binary);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _JsonNode implements JsonNode {
  const _JsonNode({this.empty, this.valueNode, this.containerNode, this.missingNode, this.array, @JsonKey(name: 'object') this.objectField, this.nodeType, this.pojo, this.number, this.integralNumber, this.floatingPointNumber, this.short, @JsonKey(name: 'int') this.intField, this.long, this.float, @JsonKey(name: 'double') this.doubleField, this.bigDecimal, this.bigInteger, this.textual, this.boolean, @JsonKey(name: 'null') this.nullField, this.binary});
  factory _JsonNode.fromJson(Map<String, dynamic> json) => _$JsonNodeFromJson(json);

@override final  bool? empty;
@override final  bool? valueNode;
@override final  bool? containerNode;
@override final  bool? missingNode;
@override final  bool? array;
@override@JsonKey(name: 'object') final  bool? objectField;
@override final  JsonNodeType? nodeType;
@override final  bool? pojo;
@override final  bool? number;
@override final  bool? integralNumber;
@override final  bool? floatingPointNumber;
@override final  bool? short;
@override@JsonKey(name: 'int') final  bool? intField;
@override final  bool? long;
@override final  bool? float;
@override@JsonKey(name: 'double') final  bool? doubleField;
@override final  bool? bigDecimal;
@override final  bool? bigInteger;
@override final  bool? textual;
@override final  bool? boolean;
@override@JsonKey(name: 'null') final  bool? nullField;
@override final  bool? binary;

/// Create a copy of JsonNode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JsonNodeCopyWith<_JsonNode> get copyWith => __$JsonNodeCopyWithImpl<_JsonNode>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JsonNodeToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _JsonNode&&(identical(other.empty, empty) || other.empty == empty)&&(identical(other.valueNode, valueNode) || other.valueNode == valueNode)&&(identical(other.containerNode, containerNode) || other.containerNode == containerNode)&&(identical(other.missingNode, missingNode) || other.missingNode == missingNode)&&(identical(other.array, array) || other.array == array)&&(identical(other.objectField, objectField) || other.objectField == objectField)&&(identical(other.nodeType, nodeType) || other.nodeType == nodeType)&&(identical(other.pojo, pojo) || other.pojo == pojo)&&(identical(other.number, number) || other.number == number)&&(identical(other.integralNumber, integralNumber) || other.integralNumber == integralNumber)&&(identical(other.floatingPointNumber, floatingPointNumber) || other.floatingPointNumber == floatingPointNumber)&&(identical(other.short, short) || other.short == short)&&(identical(other.intField, intField) || other.intField == intField)&&(identical(other.long, long) || other.long == long)&&(identical(other.float, float) || other.float == float)&&(identical(other.doubleField, doubleField) || other.doubleField == doubleField)&&(identical(other.bigDecimal, bigDecimal) || other.bigDecimal == bigDecimal)&&(identical(other.bigInteger, bigInteger) || other.bigInteger == bigInteger)&&(identical(other.textual, textual) || other.textual == textual)&&(identical(other.boolean, boolean) || other.boolean == boolean)&&(identical(other.nullField, nullField) || other.nullField == nullField)&&(identical(other.binary, binary) || other.binary == binary));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,empty,valueNode,containerNode,missingNode,array,objectField,nodeType,pojo,number,integralNumber,floatingPointNumber,short,intField,long,float,doubleField,bigDecimal,bigInteger,textual,boolean,nullField,binary]);
}

@override
String toString() {
    return 'JsonNode(empty: $empty, valueNode: $valueNode, containerNode: $containerNode, missingNode: $missingNode, array: $array, objectField: $objectField, nodeType: $nodeType, pojo: $pojo, number: $number, integralNumber: $integralNumber, floatingPointNumber: $floatingPointNumber, short: $short, intField: $intField, long: $long, float: $float, doubleField: $doubleField, bigDecimal: $bigDecimal, bigInteger: $bigInteger, textual: $textual, boolean: $boolean, nullField: $nullField, binary: $binary)';
}


}

/// @nodoc
abstract mixin class _$JsonNodeCopyWith<$Res> implements $JsonNodeCopyWith<$Res> {
  factory _$JsonNodeCopyWith(_JsonNode value, $Res Function(_JsonNode) _then) = __$JsonNodeCopyWithImpl;
@override @useResult
$Res call({
 bool? empty, bool? valueNode, bool? containerNode, bool? missingNode, bool? array,@JsonKey(name: 'object') bool? objectField, JsonNodeType? nodeType, bool? pojo, bool? number, bool? integralNumber, bool? floatingPointNumber, bool? short,@JsonKey(name: 'int') bool? intField, bool? long, bool? float,@JsonKey(name: 'double') bool? doubleField, bool? bigDecimal, bool? bigInteger, bool? textual, bool? boolean,@JsonKey(name: 'null') bool? nullField, bool? binary
});




}
/// @nodoc
class __$JsonNodeCopyWithImpl<$Res>
    implements _$JsonNodeCopyWith<$Res> {
  __$JsonNodeCopyWithImpl(this._self, this._then);

  final _JsonNode _self;
  final $Res Function(_JsonNode) _then;

/// Create a copy of JsonNode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? empty = freezed,Object? valueNode = freezed,Object? containerNode = freezed,Object? missingNode = freezed,Object? array = freezed,Object? objectField = freezed,Object? nodeType = freezed,Object? pojo = freezed,Object? number = freezed,Object? integralNumber = freezed,Object? floatingPointNumber = freezed,Object? short = freezed,Object? intField = freezed,Object? long = freezed,Object? float = freezed,Object? doubleField = freezed,Object? bigDecimal = freezed,Object? bigInteger = freezed,Object? textual = freezed,Object? boolean = freezed,Object? nullField = freezed,Object? binary = freezed,}) {
  return _then(_JsonNode(
empty: freezed == empty ? _self.empty : empty // ignore: cast_nullable_to_non_nullable
as bool?,valueNode: freezed == valueNode ? _self.valueNode : valueNode // ignore: cast_nullable_to_non_nullable
as bool?,containerNode: freezed == containerNode ? _self.containerNode : containerNode // ignore: cast_nullable_to_non_nullable
as bool?,missingNode: freezed == missingNode ? _self.missingNode : missingNode // ignore: cast_nullable_to_non_nullable
as bool?,array: freezed == array ? _self.array : array // ignore: cast_nullable_to_non_nullable
as bool?,objectField: freezed == objectField ? _self.objectField : objectField // ignore: cast_nullable_to_non_nullable
as bool?,nodeType: freezed == nodeType ? _self.nodeType : nodeType // ignore: cast_nullable_to_non_nullable
as JsonNodeType?,pojo: freezed == pojo ? _self.pojo : pojo // ignore: cast_nullable_to_non_nullable
as bool?,number: freezed == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as bool?,integralNumber: freezed == integralNumber ? _self.integralNumber : integralNumber // ignore: cast_nullable_to_non_nullable
as bool?,floatingPointNumber: freezed == floatingPointNumber ? _self.floatingPointNumber : floatingPointNumber // ignore: cast_nullable_to_non_nullable
as bool?,short: freezed == short ? _self.short : short // ignore: cast_nullable_to_non_nullable
as bool?,intField: freezed == intField ? _self.intField : intField // ignore: cast_nullable_to_non_nullable
as bool?,long: freezed == long ? _self.long : long // ignore: cast_nullable_to_non_nullable
as bool?,float: freezed == float ? _self.float : float // ignore: cast_nullable_to_non_nullable
as bool?,doubleField: freezed == doubleField ? _self.doubleField : doubleField // ignore: cast_nullable_to_non_nullable
as bool?,bigDecimal: freezed == bigDecimal ? _self.bigDecimal : bigDecimal // ignore: cast_nullable_to_non_nullable
as bool?,bigInteger: freezed == bigInteger ? _self.bigInteger : bigInteger // ignore: cast_nullable_to_non_nullable
as bool?,textual: freezed == textual ? _self.textual : textual // ignore: cast_nullable_to_non_nullable
as bool?,boolean: freezed == boolean ? _self.boolean : boolean // ignore: cast_nullable_to_non_nullable
as bool?,nullField: freezed == nullField ? _self.nullField : nullField // ignore: cast_nullable_to_non_nullable
as bool?,binary: freezed == binary ? _self.binary : binary // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
