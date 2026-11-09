import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/zone_mention_line.dart';
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

/// Les chiffres d'un groupe : départ (dans le fuseau de la sortie, situé par
/// rapport à elle) et arrivée estimée du leg, allure, distance, dénivelé
/// positif. Partagés par l'Aperçu de la page d'un groupe (ledger `MOB-67`) et
/// le détail d'une sortie solo (ledger `MOB-69`).
///
/// L'Aperçu passe [showDeparture] à faux : son bloc de départ, en tête de
/// page, porte déjà l'heure, la relation à la sortie et l'arrivée estimée
/// (ledger `MOB-113`). Sans aucun chiffre, rien n'est rendu.
class RideGroupStats extends ConsumerWidget {
  const RideGroupStats({
    super.key,
    required this.ride,
    required this.group,
    required this.leg,
    this.showDeparture = true,
  });

  final RideDto ride;
  final RideGroupDto group;

  /// Le leg météo du groupe, `null` sans prévision chargée.
  final WeatherLegDto? leg;

  final bool showDeparture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final String? arrival = groupLegArrival(leg, ride.timezone);

    final List<Widget> cells = <Widget>[
      // L'heure du groupe se lit dans le fuseau de la sortie
      // (docs/LEDGER_*.md API-60).
      if (showDeparture)
        PdlMetaCell(
          label: 'rides.groupPage.stats.departure'.tr(),
          value: formatGroupStart(group.startAt, ride.timezone),
          extra: <Widget>[
            ?ZoneMentionLine.maybe(group.startAt, ride.timezone),
            if (arrival != null) Text(arrival, style: t.xs),
          ],
        ),
      if (group.averageSpeed != null)
        PdlMetaCell(
          label: 'rides.groupPage.stats.pace'.tr(),
          value: AppFormatters.formatSpeed(group.averageSpeed!, units),
        ),
      if (group.distance != null)
        PdlMetaCell(
          label: 'rides.groupPage.stats.distance'.tr(),
          value: AppFormatters.formatDistance(group.distance!, units),
        ),
      if (group.elevationGain != null)
        PdlMetaCell(
          label: 'rides.groupPage.stats.elevation'.tr(),
          value: AppFormatters.formatElevation(group.elevationGain!, units),
        ),
    ];
    if (cells.isEmpty) return const SizedBox.shrink();

    return PdlCard(
      flat: true,
      // Deux colonnes tant qu'elles restent lisibles, une au-delà.
      child: PdlMetaGrid(cells: cells, columnInset: PdlSpacing.card),
    );
  }
}
