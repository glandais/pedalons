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

    /// Whether GET team answers the caller: the team is not private, or the caller is a member of it or a platform admin. A client loads the team, links to it or shows its header only when true; otherwise it renders this summary. The public content of a private team is read by link with this false.
    required bool accessible,

    /// URL template of the team's logo (with a {size} placeholder), when it has one and the caller may download it. Same value as TeamDetailDto.logoUrl, so a publication can show its team's logo without loading the team. Absent when accessible is false and the private team does not publish content by link: its logo is then closed to the caller. Opaque URL: may carry a query string; substitute {size} only.
    String? logoUrl,
  }) = _TeamPublicationDto;

  factory TeamPublicationDto.fromJson(Map<String, Object?> json) =>
      _$TeamPublicationDtoFromJson(json);
}
