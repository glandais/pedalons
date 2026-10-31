import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/units/unit_system.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../routes/domain/route_color_mode.dart';
import '../../../routes/domain/track_slope_colors.dart';
import '../../../routes/domain/track_surfaces.dart';
import '../../../routes/presentation/widgets/route_color_mode_switch.dart';
import '../../../routes/presentation/widgets/route_surface_section.dart';
import '../../../routes/presentation/widgets/route_waypoints_section.dart';
import '../../../routes/presentation/widgets/waypoint_selection.dart';
import '../../../routes/presentation/widgets/waypoint_sheet.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_group_selection_provider.dart';

/// Le profil altimétrique du groupe sélectionné (écran 12), en 110 px.
///
/// C'est un **enrichissement** : son chargement n'empêche rien, son échec ne
/// produit pas d'écran d'erreur mais une ligne discrète et un « Réessayer ».
/// Le reste de la sortie reste lisible et interactif dans les deux cas.
class RideElevationSection extends ConsumerStatefulWidget {
  const RideElevationSection({
    super.key,
    required this.teamSlug,
    required this.rideSlug,
    required this.routeSlug,
    this.distance,
    this.elevationGain,
    this.colorBy = RouteColorBy.grade,
    this.profileColorByKey,
  });

  final String teamSlug;
  final String rideSlug;

  /// Le parcours du groupe sélectionné. Change avec la sélection, mais aucun
  /// appel réseau ne s'ensuit : la géométrie de tous les groupes est déjà dans
  /// le lot chargé pour la carte, profil compris.
  final String routeSlug;

  final double? distance;
  final double? elevationGain;

  /// Ce que la personne a choisi sous la carte (`RouteColorModeSwitch`,
  /// ledger `MOB-105`) : le profil suit Pente | Revêtement, et reste sur la
  /// pente en Météo ou quand ce parcours n'a pas de revêtement.
  ///
  /// `null` quand la carte garde une couleur par couche — une sortie à
  /// plusieurs groupes, une sortie solo à deux parcours : la section pose
  /// alors **son propre** Pente | Revêtement au-dessus du profil, qui ne
  /// colore que lui et vit avec elle (le choix partagé de la carte,
  /// `rideMapColorModeProvider`, n'est ni lu ni écrit).
  final RouteColorBy? colorBy;

  /// La clé de cet interrupteur propre au profil.
  final Key? profileColorByKey;

  @override
  ConsumerState<RideElevationSection> createState() =>
      _RideElevationSectionState();
}

class _RideElevationSectionState extends ConsumerState<RideElevationSection> {
  final TrackSurfaceBarColors _barColors = TrackSurfaceBarColors();

  /// Le choix de l'interrupteur propre au profil, quand la carte n'en donne
  /// pas ([RideElevationSection.colorBy] `null`) ; il se lit comme la pente
  /// sur un parcours sans revêtement.
  RouteColorBy _ownColorBy = RouteColorBy.grade;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);

    final RouteRef routeRef = RouteRef(
      teamSlug: widget.teamSlug,
      rideSlug: widget.rideSlug,
      routeSlug: widget.routeSlug,
    );
    final RouteDetailDto? route = ref
        .watch(rideRouteGeometryProvider(routeRef))
        .value;
    final List<TrackDto> tracks = route?.tracks ?? const <TrackDto>[];
    final List<WaypointDto> waypoints =
        route?.waypoints ?? const <WaypointDto>[];
    final WaypointSelectionController selection = ref.watch(
      rideWaypointSelectionProvider(
        RideKey(teamSlug: widget.teamSlug, rideSlug: widget.rideSlug),
      ),
    );
    final List<PdlProfileMarker> markers = profileMarkersOf(waypoints);
    final RouteColorBy? shared = widget.colorBy;
    // L'interrupteur propre au profil : Pente | Revêtement, pour le parcours
    // qu'il montre.
    final List<RouteColorBy> ownModes = shared != null
        ? const <RouteColorBy>[]
        : routeColorModes(surfaces: hasTrackSurfaces(tracks), wind: false);
    final RouteColorBy colorBy = !hasTrackSurfaces(tracks)
        ? RouteColorBy.grade
        : shared != null
        ? profileColorBy(shared)
        : resolveRouteColorBy(_ownColorBy, ownModes);
    final List<TrackSurface?>? bars = colorBy == RouteColorBy.surface
        ? ref.watch(rideRouteSurfaceBarsProvider(routeRef)).value
        : null;
    // La pente des montées, barre par barre, comme la carte (ledger
    // `MOB-105`).
    final ClimbBars? climbs = bars == null
        ? ref.watch(rideRouteClimbBarsProvider(routeRef)).value
        : null;
    final AsyncValue<ElevationSamples?> samples = ref.watch(
      rideRouteElevationProvider(routeRef),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'rides.selectedGroupProfile'.tr(),
                style: t.xs.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_summary(units) != null) Text(_summary(units)!, style: t.xs),
          ],
        ),
        if (ownModes.length > 1) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          RouteColorModeSwitch(
            key: widget.profileColorByKey,
            modes: ownModes,
            value: colorBy,
            semanticLabel: 'routes.surfaceDetail.profileColorBy'.tr(),
            onChanged: (RouteColorBy v) => setState(() => _ownColorBy = v),
          ),
          const SizedBox(height: PdlSpacing.chipGap),
        ] else
          const SizedBox(height: 6),
        samples.when(
          // Pas d'altitude exploitable : rien, plutôt qu'un profil plat qui se
          // ferait passer pour un terrain.
          data: (ElevationSamples? data) => data == null
              ? const SizedBox.shrink()
              : ValueListenableBuilder<WaypointSelection?>(
                  valueListenable: selection,
                  builder:
                      (
                        BuildContext context,
                        WaypointSelection? picked,
                        _,
                      ) => PdlElevationProfile(
                        markers: markers,
                        selectedMarkerKey: picked?.key,
                        onMarkerTapped: markers.isEmpty
                            ? null
                            : (String key) {
                                final WaypointDto? w = waypointByKey(
                                  waypoints,
                                  key,
                                );
                                if (w == null) return;
                                openWaypoint(
                                  context,
                                  w,
                                  selection,
                                  key,
                                  units: units,
                                  move: PdlWaypointMove.ifHidden,
                                );
                              },
                        credit: 'routes.elevationCredit'.tr(),
                        samples: data,
                        height: PdlMetrics.elevationMedium,
                        barColors: bars == null
                            ? climbs?.colors
                            : _barColors.of(bars, context.pdl),
                        // Seule la dernière graduation porte l'unité (§1.3.1).
                        axisLabel: (double meters, {required bool isLast}) =>
                            isLast
                            ? AppFormatters.formatDistance(meters, units)
                            : AppFormatters.formatNumber(
                                units.longDistance(meters),
                                fractionDigits: 1,
                              ),
                        tipLabel: (ElevationReading r) => <String>[
                          AppFormatters.formatDistance(r.distance, units),
                          AppFormatters.formatAltitude(r.elevation, units),
                          if (bars != null)
                            ?trackSurfaceTip(data, bars, r.distance)
                          else
                            ?climbGradeTipLabel(data, climbs, r),
                        ].join(' · '),
                      ),
                ),
          loading: () => PdlElevationProfile.loading(
            label: 'routes.profileLoading'.tr(),
            height: PdlMetrics.elevationMedium,
          ),
          error: (Object error, StackTrace stack) => PdlElevationProfile.failed(
            label: 'routes.profileUnavailable'.tr(),
            actionLabel: 'common.retry'.tr(),
            height: PdlMetrics.elevationMedium,
            onRetry: () => ref.invalidate(
              rideRouteGeometriesProvider(
                RideKey(teamSlug: widget.teamSlug, rideSlug: widget.rideSlug),
              ),
            ),
          ),
        ),
        // L'espace n'est posé que si la section rend quelque chose.
        if (hasTrackSurfaces(tracks) ||
            trackSurfacesPending(tracks)) ...<Widget>[
          const SizedBox(height: PdlSpacing.section),
          RouteSurfaceSection(tracks: tracks),
        ],
        if (waypoints.isNotEmpty) ...<Widget>[
          const SizedBox(height: PdlSpacing.section),
          RouteWaypointsSection(
            waypoints: waypoints,
            selection: selection,
            onSelect: (String key, WaypointDto _) =>
                selection.select(key, move: PdlWaypointMove.center),
          ),
        ],
      ],
    );
  }

  String? _summary(UnitSystem units) {
    final List<String> parts = <String>[
      if (widget.distance != null)
        AppFormatters.formatDistance(widget.distance!, units),
      if (widget.elevationGain != null)
        AppFormatters.formatElevationGain(widget.elevationGain!, units),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
