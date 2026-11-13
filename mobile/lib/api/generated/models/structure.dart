// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'structure.freezed.dart';
part 'structure.g.dart';

@Freezed()
abstract class Structure with _$Structure {
  const factory Structure({
    String? kind,
    @JsonKey(name: 'from_m') double? fromM,
    @JsonKey(name: 'to_m') double? toM,
    @JsonKey(name: 'length_m') double? lengthM,
    @JsonKey(name: 'structure_source') String? structureSource,
    String? method,
  }) = _Structure;

  factory Structure.fromJson(Map<String, Object?> json) =>
      _$StructureFromJson(json);
}
