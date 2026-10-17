// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'visibility.dart';

part 'team_publication_dto.freezed.dart';
part 'team_publication_dto.g.dart';

/// Team information
@Freezed()
abstract class TeamPublicationDto with _$TeamPublicationDto {
  const factory TeamPublicationDto({
    /// Team ID (TSID)
    required String id,

    /// Team name
    required String name,

    /// Team URL slug
    required String slug,

    /// Whether the team is public
    required String visibility,

    /// URL template of the team's logo (with a {size} placeholder), when it has one. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team. Opaque URL: may carry a query string; substitute {size} only.
    String? logoUrl,
  }) = _TeamPublicationDto;

  factory TeamPublicationDto.fromJson(Map<String, Object?> json) =>
      _$TeamPublicationDtoFromJson(json);
}
