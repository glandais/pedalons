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
import '../../../../core/widgets/publication_stats_line.dart';
import '../../../rides/presentation/widgets/ride_weather_summary_line.dart';
import '../../providers/trip_detail_provider.dart';
import '../../../routes/presentation/gps_export_runner.dart';
import '../../../routes/presentation/widgets/gps_button.dart';
import '../../../teams/domain/publication_timing.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../../keys.dart';

/// Une étape dans la liste du voyage (ledger `MOB-134`, lot 9, KIT §8,
/// maquettes `voyage-etapes-mobile-cible`, `voyage-une-etape-mobile-cible`) :
///
/// 1. le rang, le titre de l'étape et le repère de couleur de son tracé ;
/// 2. le départ « ven. 20 nov. · 08:30 », horloge devant, dans le fuseau de
///    l'étape, et la mention de fuseau quand le lecteur est ailleurs ;
/// 3. la ligne de chiffres ([PublicationStatsLine]) : distance · D+ · vitesse ;
/// 4. la ligne météo ([RideWeatherSummaryLine]), au format de la carte de
///    groupe : plage de températures · vent (flèche) · « Pluie N % ».
///
/// **Ni nom de parcours ni vignette** (KIT §8) : le titre de l'étape dit déjà
/// où elle va, et la carte du voyage, juste au-dessus, la dessine.
///
/// La couleur du repère est celle du tracé sur la carte, indexée sur le
/// **rang** de l'étape (`stageIndex`), pas sur sa géographie : la carte n'a
/// pas de légende, c'est ce repère qui la remplace (KIT §8).
///
/// Au-delà de dix étapes la palette cycle. Ce n'est pas idéal — deux étapes
/// portent alors la même couleur — mais la maquette ne dit rien de ce cas et
/// inventer une onzième teinte hors charte serait pire.
///
/// **« GPS »** ([exportable]) : sur l'étape d'un voyage auquel la personne
/// participe, jusqu'à l'arrivée de l'étape (règle R7, KIT §9, docs/LEDGER_*.md
/// MOB-139). La même feuille que sur la carte de son groupe : appareils
/// connectés, puis GPX et FIT du parcours de l'étape.
class StageCard extends ConsumerStatefulWidget {
  const StageCard({
    super.key,
    required this.stage,
    required this.selected,
    required this.onTap,
    this.onSelect,
    this.weather,
    this.exportable = false,
  });

  final TripStageDto stage;

  /// Le résumé météo de l'étape (`TripStageWeatherDto.summary`), apparié par
  /// `stageId` par l'écran du voyage. Absent — ou sans rien à montrer —, la
  /// carte ne réserve aucune place.
  final RideWeatherSummaryDto? weather;

  /// Sélectionnée depuis la carte : la carte s'entoure d'indigo.
  final bool selected;

  /// Ouvrir l'étape.
  final VoidCallback onTap;

  /// Sélectionner sans naviguer — la moitié « liste » de la sélection croisée.
  final VoidCallback? onSelect;

  /// Offrir « GPS » : la personne participe au voyage, il n'est pas annulé,
  /// l'étape n'est pas arrivée (`stageExportable`). L'étape doit encore avoir
  /// un parcours, et la feuille quelque chose à proposer.
  final bool exportable;

  @override
  ConsumerState<StageCard> createState() => _StageCardState();
}

/// « GPS » sur l'étape (règle R7) : la personne participe au voyage, il est
/// maintenu, l'étape n'est pas encore arrivée. [now] ne sert qu'aux tests.
bool stageExportable(TripDto trip, TripStageDto stage, {DateTime? now}) =>
    trip.registered &&
    !trip.isCancelled &&
    stage.route != null &&
    tripStagePhase(trip, stage, now: now) != PublicationPhase.finished;

class _StageCardState extends ConsumerState<StageCard>
    with GpsExportRunner<StageCard> {
  @override
  Widget build(BuildContext context) {
    final TripStageDto stage = widget.stage;
    final RideWeatherSummaryDto? weather = widget.weather;
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final RouteDto? route = stage.route;
    final DateTime? instant = DateTime.tryParse(stage.dateTime);

    final GpsExportTarget? gps = widget.exportable && route != null
        ? GpsExportTarget(
            subtitle: route.distance > 0
                ? '${stage.name} · ${AppFormatters.formatDistance(route.distance, units)}'
                : stage.name,
            teamSlug: route.team.slug,
            routeSlug: route.slug,
            gpx: route.media.assets.gpx,
            fit: route.media.assets.fit,
          )
        : null;
    final bool showGps = gps != null && gps.offered(watchGpsServices());

    return PdlCard(
      selected: widget.selected,
      onTap: widget.onTap,
      onLongPress: widget.onSelect,
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
                if (instant != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Row(
                    key: keys.trip.stageDeparture(stage.slug),
                    children: <Widget>[
                      Icon(PdlIcons.time, size: 14, color: c.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          AppFormatters.formatDeparture(
                            instant,
                            stage.timezone,
                          ),
                          style: t.statValue,
                        ),
                      ),
                    ],
                  ),
                ],
                // L'étape dans son fuseau, et la mention en seconde ligne
                // quand le lecteur est ailleurs (docs/LEDGER_*.md API-60).
                ?ZoneMentionLine.maybe(stage.dateTime, stage.timezone),
                if (route != null || stage.averageSpeed != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: PublicationStatsLine(
                      distanceMeters: route?.distance,
                      elevationGainMeters: route?.elevationGain,
                      speedKmh: stage.averageSpeed,
                      units: units,
                    ),
                  ),
                if (RideWeatherSummaryLine.shows(weather))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: RideWeatherSummaryLine(
                      summary: weather,
                      timezone: stage.timezone,
                      units: units,
                    ),
                  ),
                if (showGps) ...<Widget>[
                  const SizedBox(height: PdlSpacing.chipGap),
                  GpsButton(
                    key: keys.trip.stageGps(stage.slug),
                    compact: true,
                    loading: gpsExporting,
                    onPressed: (BuildContext button) =>
                        openGpsSheet(gps, button),
                  ),
                ],
                ...gpsExportBanners(gap: PdlSpacing.chipGap, gapBefore: true),
              ],
            ),
          ),
          const SizedBox(width: PdlSpacing.chipGap),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(PdlIcons.chevronRight, size: 20, color: c.textDimmed),
          ),
        ],
      ),
    );
  }
}
