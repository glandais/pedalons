import 'package:easy_localization/easy_localization.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/detail_stat_tiles.dart';
import '../../domain/group_start.dart';
import '../../domain/ride_weather_display.dart';

/// « Arrivée estimée 13:10 » : l'arrivée du leg météo [leg] d'un groupe, dans
/// le fuseau [timezone] de sa sortie — seulement pour un leg prévu ; `null`
/// sinon.
String? groupLegArrival(WeatherLegDto? leg, String timezone) {
  if (leg == null) return null;
  final WeatherStatus status = WeatherStatus.fromJson(leg.status);
  if (status != WeatherStatus.ok && status != WeatherStatus.stale) return null;
  return 'rides.groupPage.stats.arrival'.tr(
    namedArgs: <String, String>{
      'time': formatWeatherTime(leg.arrivalTime, timezone),
    },
  );
}

/// « Arrivée estimée 12:18 » du bloc de départ d'un groupe — la page d'un
/// groupe, la sortie solo (ledger `MOB-134`) : l'arrivée du groupe
/// (`estimatedArrival`, ledger `API-172`), à défaut celle de son leg météo
/// [leg] ; `null` sinon.
String? rideGroupArrivalLine(
  RideDto ride,
  RideGroupDto group,
  WeatherLegDto? leg,
) {
  final String? at = group.estimatedArrival;
  if (at != null) {
    return 'rides.groupPage.stats.arrival'.tr(
      namedArgs: <String, String>{'time': formatGroupStart(at, ride.timezone)},
    );
  }
  return groupLegArrival(leg, ride.timezone);
}

/// Les tuiles d'un groupe, dans l'ordre du KIT §8 : Distance | Dénivelé
/// positif, puis Durée estimée | Vitesse moyenne ; une tuile sans donnée
/// disparaît. La page d'un groupe et la sortie solo (ledger `MOB-134`).
List<DetailStatTile> rideGroupStatTiles(RideGroupDto group, UnitSystem units) =>
    <DetailStatTile>[
      if (group.distance != null)
        DetailStatTile(
          label: 'rides.groupPage.stats.distance'.tr(),
          value: AppFormatters.formatDistance(group.distance!, units),
        ),
      if (group.elevationGain != null)
        DetailStatTile(
          label: 'rides.groupPage.stats.elevation'.tr(),
          value: AppFormatters.formatElevation(group.elevationGain!, units),
        ),
      if (group.estimatedDurationMinutes != null)
        DetailStatTile(
          label: 'rides.groupPage.stats.estimatedDuration'.tr(),
          value: AppFormatters.formatDurationMinutes(
            group.estimatedDurationMinutes!,
          ),
        ),
      if (group.averageSpeed != null)
        DetailStatTile(
          label: 'rides.groupPage.stats.pace'.tr(),
          value: AppFormatters.formatSpeed(group.averageSpeed!, units),
        ),
    ];

/// Les tuiles d'une sortie sans groupe : Distance | Dénivelé positif, sur une
/// ligne — sans groupe, ni durée ni vitesse (KIT §8, maquette
/// `sortie-sans-groupe-mobile-cible`).
List<DetailStatTile> rideStatTiles(RideDto ride, UnitSystem units) =>
    <DetailStatTile>[
      if (ride.distance != null)
        DetailStatTile(
          label: 'rides.groupPage.stats.distance'.tr(),
          value: AppFormatters.formatDistance(ride.distance!, units),
        ),
      if (ride.elevationGain != null)
        DetailStatTile(
          label: 'rides.groupPage.stats.elevation'.tr(),
          value: AppFormatters.formatElevation(ride.elevationGain!, units),
        ),
    ];
