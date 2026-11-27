// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_gps_service_stats_dto.freezed.dart';
part 'admin_gps_service_stats_dto.g.dart';

/// Connections to one GPS service and the routes sent through them
@Freezed()
abstract class AdminGpsServiceStatsDto with _$AdminGpsServiceStatsDto {
  const factory AdminGpsServiceStatsDto({
    /// The service (GARMIN, HAMMERHEAD)
    required String service,

    /// Connections
    required int connections,

    /// Accounts with at least one connection
    required int users,

    /// Connections with automatic sending on
    required int autoSync,

    /// Connections that must be reconnected
    required int reconnectRequired,

    /// Connections used during the last 30 days
    required int usedLast30Days,

    /// Routes sent or to send through these connections
    required int routeSyncs,

    /// Of which delivered
    required int routeSyncsSucceeded,

    /// Of which in error
    required int routeSyncsFailed,
  }) = _AdminGpsServiceStatsDto;

  factory AdminGpsServiceStatsDto.fromJson(Map<String, Object?> json) =>
      _$AdminGpsServiceStatsDtoFromJson(json);
}
