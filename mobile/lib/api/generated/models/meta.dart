// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'json_node.dart';

part 'meta.freezed.dart';
part 'meta.g.dart';

@Freezed()
abstract class Meta with _$Meta {
  const factory Meta({
    @JsonKey(name: 'api_version') String? apiVersion,
    @JsonKey(name: 'rules_version') String? rulesVersion,
    String? profile,
    @JsonKey(name: 'data_versions') JsonNode? dataVersions,
  }) = _Meta;

  factory Meta.fromJson(Map<String, Object?> json) => _$MetaFromJson(json);
}
