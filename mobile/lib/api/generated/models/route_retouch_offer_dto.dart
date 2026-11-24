// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'route_generator_type.dart';
import 'route_retouch_operation.dart';
import 'route_retouch_unavailable.dart';

part 'route_retouch_offer_dto.freezed.dart';
part 'route_retouch_offer_dto.g.dart';

/// Whether a route can be retouched by the caller now, and within which bounds. Nothing is computed to answer: the engine's capabilities and the heads of the route's stored documents
@Freezed()
abstract class RouteRetouchOfferDto with _$RouteRetouchOfferDto {
  const factory RouteRetouchOfferDto({
    /// The retouch can be asked for now
    required bool available,

    /// The operations offered; empty when not available
    required List<RouteRetouchOperation> operations,

    /// Why not. NOT_ALLOWED and ENGINE_UNAVAILABLE: show nothing. NOT_READY: the route is still being analysed (show the action disabled). UNSUPPORTED: show nothing. Absent when available
    String? unavailableReason,

    /// Length of the route's raw track in metres. Absent when not available
    double? originalDistanceM,

    /// Smallest total distance of a RESIZE, in kilometres, rounded inwards to the tenth
    double? minDistanceKm,

    /// Largest total distance of a RESIZE, in kilometres, rounded inwards to the tenth
    double? maxDistanceKm,

    /// Smallest change of a RESIZE, in kilometres, above or below the route's length
    double? minChangeKm,

    /// Largest change of a RESIZE as a share of the route's length, 0 to 1
    double? maxChangeShare,

    /// How far from a way of the ride type the new finish may be, in metres
    double? endSnapM,

    /// Proposals returned at most
    int? proposalsMax,

    /// The ride type the engine is asked for, from the route's surface type
    String? rideType,
  }) = _RouteRetouchOfferDto;

  factory RouteRetouchOfferDto.fromJson(Map<String, Object?> json) =>
      _$RouteRetouchOfferDtoFromJson(json);
}
