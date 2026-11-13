// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'gpx_preview_copy_request.freezed.dart';
part 'gpx_preview_copy_request.g.dart';

/// GPX preview copy request
@Freezed()
abstract class GpxPreviewCopyRequest with _$GpxPreviewCopyRequest {
  const factory GpxPreviewCopyRequest({
    /// Name of the copy
    required String name,
  }) = _GpxPreviewCopyRequest;

  factory GpxPreviewCopyRequest.fromJson(Map<String, Object?> json) =>
      _$GpxPreviewCopyRequestFromJson(json);
}
