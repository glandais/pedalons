// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'instant.dart';
import 'media_dto.dart';
import 'surface_type.dart';
import 'tag_dto.dart';
import 'team_publication_dto.dart';
import 'visibility.dart';

part 'route_dto.freezed.dart';
part 'route_dto.g.dart';

/// Route summary data
@Freezed()
abstract class RouteDto with _$RouteDto {
  const factory RouteDto({
    /// Route ID (TSID)
    required String id,

    /// Route slug
    required String slug,

    /// Team
    required TeamPublicationDto team,

    /// Route name
    required String name,

    /// Route description
    required MediaDto media,

    /// Distance in meters
    required double distance,

    /// Total elevation gain in meters
    required double elevationGain,

    /// Total elevation loss in meters
    required double elevationLoss,

    /// Surface type
    required String surfaceType,

    /// Whether the route is public
    required String visibility,

    /// Creation timestamp
    required String createdAt,

    /// Whether the route is soft-deleted
    required bool deleted,

    /// The team's ROUTE tags the route carries, sorted by label. Empty when it carries none.
    required List<TagDto> tags,

    /// Plain-text opening of the description, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the description holds no text. Lets a list row render its two lines without the description being sent at all — see the 'view' parameter.
    String? excerpt,

    /// URL template of the route's thumbnail, light variant if there is one, else dark. Saves a compact row from carrying media.assets just to find the map preview. Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailUrl,

    /// Number of comments, replies included. Absent when the caller may not read the comments of this route — comments are members-only, so an outsider is told nothing, not even zero.
    int? commentCount,
  }) = _RouteDto;

  factory RouteDto.fromJson(Map<String, Object?> json) =>
      _$RouteDtoFromJson(json);
}
