// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_style_dto.freezed.dart';
part 'map_style_dto.g.dart';

/// A basemap style the clients may offer
@Freezed()
abstract class MapStyleDto with _$MapStyleDto {
  const factory MapStyleDto({
    /// Stable style identifier, e.g. 'cycling'
    required String id,

    /// Human-readable label for the style switcher
    required String label,

    /// Section the switcher should list this style under — 'vector', 'satellite' or 'raster'. Clients group consecutive styles sharing a value and localise the heading themselves; an unknown value is rendered as its own section rather than dropped.
    required String group,

    /// URL of the MapLibre style document to load in light mode (or at all times when darkVariant is null). Either a third-party style document or, for a raster basemap the server wraps itself, a URL on /api/map/styles/{id}.json.
    required String url,

    /// URL of the style document to load instead of 'url' when the client renders in dark mode. Null when the style has no dark counterpart — the client then keeps using 'url'.
    String? darkVariant,

    /// Credit the style document does not declare itself, to be displayed IN ADDITION to the attribution the map engine derives from that document — not instead of it. Null for a style that credits itself (most of them) and for a raster basemap, whose credit is already on the source of the wrapper served at /api/map/styles/{id}.json. Non-null only where the provider ships no attribution at all, which would otherwise render the basemap uncredited.
    String? attribution,
  }) = _MapStyleDto;

  factory MapStyleDto.fromJson(Map<String, Object?> json) =>
      _$MapStyleDtoFromJson(json);
}
