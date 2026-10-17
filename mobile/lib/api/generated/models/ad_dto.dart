// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'ad_dto_location_geometry.dart';
import 'ad_type.dart';
import 'instant.dart';
import 'media_dto.dart';
import 'rental_period.dart';
import 'status.dart';
import 'tag_dto.dart';
import 'team_publication_dto.dart';
import 'visibility.dart';

part 'ad_dto.freezed.dart';
part 'ad_dto.g.dart';

/// Ad data
@Freezed()
abstract class AdDto with _$AdDto {
  const factory AdDto({
    /// Team
    required TeamPublicationDto team,

    /// Ad ID (TSID)
    required String id,

    /// Ad URL slug
    required String slug,

    /// Ad name
    required String name,

    /// Ad media
    required MediaDto media,

    /// URL templates of every picture on the ad, in editor order — the gallery. Present whatever the 'view', so a compact row can show a carousel without pulling media.assets. The first entry is the same picture as 'thumbnailUrl'.
    required List<String> images,

    /// Ad status
    required String status,

    /// Visibility level
    required String visibility,

    /// Ad type
    required String adType,

    /// Creation timestamp
    required String createdAt,

    /// Creation timestamp
    required String updatedAt,

    /// Creator ID (TSID)
    required String createdById,

    /// Display name of the member who posted the ad. The only thing about them this DTO carries: there is no contact channel on an Ad, and inventing one (an email, a phone number) is a product decision, not a serialisation one.
    required String createdByDisplayName,

    /// Whether the ad is soft-deleted
    required bool deleted,

    /// The team's AD tags the ad carries, sorted by label. Empty when it carries none.
    required List<TagDto> tags,

    /// Plain-text opening of the description, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the description holds no text. Lets a list row render its two lines without the description being sent at all — see the 'view' parameter.
    String? excerpt,

    /// URL template of the ad's first picture, the one a card shows. Saves a compact row from carrying media.assets just to find it. Opaque URL: may carry a query string; substitute {size} only.
    String? thumbnailUrl,

    /// Price
    num? price,

    /// Period the price applies to, for a rental — render as 'price / period'. Null for a sale, and for a rental whose period has not been set.
    String? rentalPeriod,

    /// Location description
    String? locationDescription,

    /// Approximate location of the ad, deliberately blurred: the point is the centre of a fixed cell about 1 km across, not the seller's address. Enough to tell a nearby ad from a distant one, and the same value on every read so repeated calls cannot be averaged back to the exact position. Null when the ad has no location. The exact point stays on AdEditDto, and only for the seller: the team's admins get this blurred point there too. Proximity filters measure from this blurred point too, never from the exact one.
    AdDtoLocationGeometry? locationGeometry,
  }) = _AdDto;

  factory AdDto.fromJson(Map<String, Object?> json) => _$AdDtoFromJson(json);
}
