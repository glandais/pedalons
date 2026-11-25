// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'unpaved_span.freezed.dart';
part 'unpaved_span.g.dart';

/// Half-open run of unpaved edges [from, to) of a line; edge i joins points i and i + 1
@Freezed()
abstract class UnpavedSpan with _$UnpavedSpan {
  const factory UnpavedSpan({
    required int from,
    required int to,
  }) = _UnpavedSpan;

  factory UnpavedSpan.fromJson(Map<String, Object?> json) =>
      _$UnpavedSpanFromJson(json);
}
