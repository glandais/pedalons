import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../rides/presentation/widgets/ride_weather_summary_line.dart';
import '../../providers/trip_detail_provider.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../../keys.dart';

/// Une étape dans la liste du voyage.
///
/// La couleur du trait est celle du tracé sur la carte, indexée sur le **rang**
/// de l'étape (`stageIndex`), pas sur sa géographie : c'est ce qui fait de la
/// légende, de la carte et de cette liste trois vues du même objet.
///
/// Au-delà de dix étapes la palette cycle. Ce n'est pas idéal — deux étapes
/// portent alors la même couleur — mais la maquette ne dit rien de ce cas et
/// inventer une onzième teinte hors charte serait pire.
class StageCard extends ConsumerWidget {
  const StageCard({
    super.key,
    required this.stage,
    required this.selected,
    required this.onTap,
    this.onSelect,
    this.weather,
  });

  final TripStageDto stage;

  /// Le résumé météo de l'étape (`TripStageWeatherDto.summary`), apparié par
  /// `stageId` par l'écran 24. Absent — ou sans rien à montrer —, la carte
  /// ne réserve aucune place.
  final RideWeatherSummaryDto? weather;

  /// Sélectionnée depuis la carte ou la légende : la carte s'entoure d'indigo.
  final bool selected;

  /// Ouvrir l'étape (écran 25).
  final VoidCallback onTap;

  /// Sélectionner sans naviguer — la moitié « liste » de la sélection croisée.
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final RouteDto? route = stage.route;
    final DateTime? start = stage.startsAt;
    final DateTime? instant = DateTime.tryParse(stage.dateTime);

    return PdlCard(
      selected: selected,
      onTap: onTap,
      onLongPress: onSelect,
      padding: PdlCardPadding.tight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PdlNumberPill(
            value: stage.stageIndex,
            semanticLabel: 'trips.stage.numberOf'.tr(
              namedArgs: <String, String>{
                'index': '${stage.stageIndex}',
                'total': '${stage.stageCount}',
              },
            ),
          ),
          const SizedBox(width: PdlSpacing.chipGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        stage.name,
                        style: t.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    PdlColorTrack(
                      color: multiTrackColor(stage.paletteIndex),
                      shape: PdlColorTrackShape.legend,
                    ),
                  ],
                ),
                // « 09:00 » d'abord, en 700, puis « sam. 12 avr. » atténué
                // (ledger `MOB-114`) : la ligne « date longue · heure » en
                // `xs` tronquait l'heure la première.
                if (start != null && instant != null) ...<Widget>[
                  const SizedBox(height: 2),
                  PdlDepartureLine(
                    key: keys.trip.stageDeparture(stage.slug),
                    headline: AppFormatters.formatTime(start),
                    trailing: AppFormatters.formatDepartureDate(
                      instant,
                      stage.timezone,
                    ),
                    semanticLabel: AppFormatters.formatDeparture(
                      instant,
                      stage.timezone,
                    ),
                  ),
                ],
                // L'étape dans son fuseau, et la mention en seconde ligne
                // quand le lecteur est ailleurs (docs/LEDGER_*.md API-60).
                ?ZoneMentionLine.maybe(stage.dateTime, stage.timezone),
                if (_journey() != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _journey()!,
                      style: t.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (route != null || stage.averageSpeed != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: PdlSpacing.statsNowrap,
                      runSpacing: PdlSpacing.statsWrapV,
                      children: <Widget>[
                        if (route != null) ...<Widget>[
                          _stat(
                            context,
                            PdlIcons.distance,
                            AppFormatters.formatDistance(route.distance, units),
                          ),
                          _stat(
                            context,
                            PdlIcons.elevationUp,
                            AppFormatters.formatElevationGain(
                              route.elevationGain,
                              units,
                            ),
                          ),
                        ],
                        if (stage.averageSpeed != null)
                          _stat(
                            context,
                            PdlIcons.speed,
                            AppFormatters.formatSpeed(
                              stage.averageSpeed!,
                              units,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (RideWeatherSummaryLine.shows(weather))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: RideWeatherSummaryLine(
                      summary: weather,
                      timezone: stage.timezone,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: PdlSpacing.chipGap),
          PdlThumb(
            imageUrl: stage.route?.thumbnailUrl,
            size: PdlMetrics.thumbLg,
            fallbackIcon: PdlIcons.stage,
          ),
          Icon(PdlIcons.chevronRight, size: 20, color: c.textDimmed),
        ],
      ),
    );
  }

  /// « Clermont-Ferrand → Issoire », et rien du tout si l'un des deux lieux
  /// manque : une flèche qui part de nulle part n'informe pas.
  String? _journey() {
    final String? from = stage.startPlace?.name;
    final String? to = stage.endPlace?.name;
    if (from == null || to == null) return from ?? to;
    return '$from → $to';
  }

  Widget _stat(BuildContext context, IconData icon, String value) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: c.textDimmed),
        const SizedBox(width: 4),
        Text(value, style: t.statValue),
      ],
    );
  }
}
