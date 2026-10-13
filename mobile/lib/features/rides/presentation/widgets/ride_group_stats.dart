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

/// Les chiffres d'un groupe : départ (dans le fuseau de la sortie, situé par
/// rapport à elle) et arrivée estimée du leg, allure, distance, dénivelé
/// positif. Partagés par l'Aperçu de la page d'un groupe (ledger `MOB-67`) et
/// le détail d'une sortie solo (ledger `MOB-69`).
class RideGroupStats extends ConsumerWidget {
  const RideGroupStats({
    super.key,
    required this.ride,
    required this.group,
    required this.leg,
  });

  final RideDto ride;
  final RideGroupDto group;

  /// Le leg météo du groupe, `null` sans prévision chargée.
  final WeatherLegDto? leg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final WeatherLegDto? leg = this.leg;
    final WeatherStatus? legStatus = leg == null
        ? null
        : WeatherStatus.fromJson(leg.status);
    // L'arrivée estimée n'a de sens que pour un leg prévu.
    final String? arrival =
        leg != null &&
            (legStatus == WeatherStatus.ok || legStatus == WeatherStatus.stale)
        ? 'rides.groupPage.stats.arrival'.tr(
            namedArgs: <String, String>{
              'time': formatWeatherTime(leg.arrivalTime, ride.timezone),
            },
          )
        : null;

    Widget cell(String label, String value, {List<Widget> extra = const []}) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: t.xs),
            const SizedBox(height: 2),
            Text(value, style: t.statBigValue),
            ...extra,
          ],
        );

    final List<Widget> cells = <Widget>[
      // L'heure du groupe se lit dans le fuseau de la sortie, et se situe
      // par rapport à elle (docs/LEDGER_*.md API-60).
      cell(
        'rides.groupPage.stats.departure'.tr(),
        formatGroupStart(group.startAt, ride.timezone),
        extra: <Widget>[
          Text(
            groupStartRelation(group.startAt, ride.dateTime).labelKey.tr(),
            style: t.xs,
          ),
          ?ZoneMentionLine.maybe(group.startAt, ride.timezone),
          if (arrival != null) Text(arrival, style: t.xs),
        ],
      ),
      if (group.averageSpeed != null)
        cell(
          'rides.groupPage.stats.pace'.tr(),
          AppFormatters.formatSpeed(group.averageSpeed!, units),
        ),
      if (group.distance != null)
        cell(
          'rides.groupPage.stats.distance'.tr(),
          AppFormatters.formatDistance(group.distance!, units),
        ),
      if (group.elevationGain != null)
        cell(
          'rides.groupPage.stats.elevation'.tr(),
          AppFormatters.formatElevation(group.elevationGain!, units),
        ),
    ];

    return PdlCard(
      flat: true,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Deux colonnes tant qu'elles restent lisibles, une au-delà.
          final bool twoColumns =
              constraints.maxWidth >= 320 &&
              MediaQuery.textScalerOf(context).scale(14) <= 18;
          if (!twoColumns) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < cells.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: PdlSpacing.meta2V),
                  cells[i],
                ],
              ],
            );
          }
          return Wrap(
            spacing: PdlSpacing.meta2H,
            runSpacing: PdlSpacing.meta2V,
            children: <Widget>[
              for (final Widget c in cells)
                SizedBox(
                  width:
                      (constraints.maxWidth - PdlSpacing.meta2H) / 2 -
                      PdlSpacing.card,
                  child: c,
                ),
            ],
          );
        },
      ),
    );
  }
}
