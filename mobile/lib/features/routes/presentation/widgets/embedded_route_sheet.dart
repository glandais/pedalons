import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/units/unit_system.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/push_location.dart';
import '../../../../keys.dart';
import '../../domain/route_color_mode.dart';
import '../../domain/track_slope_colors.dart';
import '../../domain/track_surfaces.dart';
import '../../domain/track_wind_bars.dart';
import '../../providers/route_detail_provider.dart';
import '../../providers/route_elevation_provider.dart';
import 'route_climbs_section.dart';
import 'route_color_mode_switch.dart';
import 'route_cursor_controller.dart';
import 'route_download_actions.dart';
import 'route_map.dart';
import 'route_surface_section.dart';
import 'route_waypoints_section.dart';
import 'waypoint_selection.dart';
import 'waypoint_sheet.dart';

/// La fiche parcours **embarquée** : en-tête, carte 240 px, profil 140 px,
/// revêtement, trois statistiques, trois exports, cols.
///
/// Extraite de l'écran 13 pour être **réutilisée telle quelle par l'écran 25**
/// (détail d'une étape de voyage). Toute divergence de rendu entre les deux est
/// un défaut, pas une adaptation : c'est le même bloc.
///
/// Contrairement à l'écran 13, la carte n'est pas le fond de l'écran mais une
/// vignette bornée — l'étape a son propre contenu au-dessus et en dessous.
class EmbeddedRouteSheet extends ConsumerStatefulWidget {
  const EmbeddedRouteSheet({
    super.key,
    required this.routeKey,
    this.mapHeight = 240,
    this.showOpenFullAction = true,
    this.mapLayer,
    this.colorBy,
    this.onColorByChanged,
    this.offersWind = false,
    this.windLeg,
    this.colorBySwitchKey,
    this.beforeClimbs,
  });

  final RouteKey routeKey;
  final double mapHeight;

  /// Propose « Voir la fiche complète », qui ouvre l'écran 13.
  final bool showOpenFullAction;

  /// Ce que l'écran hôte pose en plus sur la carte — le mode « Météo » du
  /// détail d'une étape (ledger `MOB-94`) —, transmis au plein écran.
  /// `null` sur l'écran 13 : la fiche y reste identique.
  final RouteMapLayerBuilder? mapLayer;

  /// Le mode choisi par l'écran hôte — partagé avec d'autres cartes (le
  /// détail d'une étape et la carte d'ensemble du voyage) —, avec
  /// [onColorByChanged]. `null` : la fiche garde son propre choix.
  final RouteColorBy? colorBy;
  final ValueChanged<RouteColorBy>? onColorByChanged;

  /// Vrai quand l'écran hôte colore le tracé par le vent en mode Météo (via
  /// [mapLayer]) : l'interrupteur propose alors « Météo ».
  final bool offersWind;

  /// Le leg dont l'écran hôte colore le tracé en mode Météo : le profil,
  /// toujours en pente, gagne alors la bande du vent sous son aire et son
  /// info-bulle le vent du point (ledger `MOB-106`). Ignoré hors mode Météo.
  final WeatherLegDto? windLeg;

  /// La clé de l'interrupteur Pente | Revêtement | Météo sous la carte.
  final Key? colorBySwitchKey;

  /// Ce que l'écran hôte pose juste au-dessus des cols et montées : la météo
  /// d'une étape, sous sa carte (ledger `MOB-118`). Porte son propre espacement.
  final Widget? beforeClimbs;

  @override
  ConsumerState<EmbeddedRouteSheet> createState() => _EmbeddedRouteSheetState();
}

class _EmbeddedRouteSheetState extends ConsumerState<EmbeddedRouteSheet> {
  RouteCursorController? _cursor;
  String? _cursorForSlug;

  /// Ce qui colore la carte et le profil (`MOB-82`, `MOB-105`) quand l'écran
  /// hôte ne le tient pas ; retombe sur la pente si le mode disparaît.
  RouteColorBy _colorBy = RouteColorBy.grade;
  final TrackSurfaceBarColors _barColors = TrackSurfaceBarColors();

  /// Le point de parcours choisi (ledger `MOB-84`).
  final WaypointSelectionController _selection = WaypointSelectionController();

  @override
  void dispose() {
    _cursor?.dispose();
    _selection.dispose();
    super.dispose();
  }

  /// Le réticule dépend de la géométrie : il est reconstruit quand — et
  /// seulement quand — le parcours change.
  RouteCursorController _cursorFor(RouteDetailDto route) {
    if (_cursor != null && _cursorForSlug == route.slug) return _cursor!;
    _cursor?.dispose();
    _cursorForSlug = route.slug;
    return _cursor = RouteCursorController(
      lines: <List<List<double>>>[
        for (final TrackDto t in route.tracks) t.line.coordinates,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<RouteDetailDto> detail = ref.watch(
      routeDetailProvider(widget.routeKey),
    );

    return detail.when(
      loading: () =>
          const PdlSkeletonCard(variant: PdlSkeletonCardVariant.media),
      // Un parcours qu'on n'a pas pu lire n'emporte pas ce que l'écran pose
      // dessous : la météo d'une étape ne dépend pas de lui.
      error: (Object error, StackTrace stack) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PdlEmptyState(
            variant: PdlEmptyVariant.error,
            title: 'routes.loadErrorTitle'.tr(),
            message: 'errors.offline.message'.tr(),
            actions: <Widget>[
              PdlButton(
                label: 'common.retry'.tr(),
                variant: PdlButtonVariant.outline,
                onPressed: () =>
                    ref.invalidate(routeDetailProvider(widget.routeKey)),
              ),
            ],
          ),
          ?widget.beforeClimbs,
        ],
      ),
      data: (RouteDetailDto route) => _body(route),
    );
  }

  Widget _body(RouteDetailDto route) {
    final RouteCursorController cursor = _cursorFor(route);
    final UnitSystem units = ref.watch(unitSystemProvider);
    // L'interrupteur unique sous la carte (ledger `MOB-105`) : la carte, son
    // plein écran et le profil suivent le même choix.
    final List<RouteColorBy> modes = routeColorModes(
      surfaces: hasTrackSurfaces(route.tracks),
      wind: widget.offersWind,
    );
    final RouteColorBy colorBy = resolveRouteColorBy(
      widget.colorBy ?? _colorBy,
      modes,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _EmbeddedRouteHeader(route: route, units: units),
        if (route.hasGeometry) ...<Widget>[
          ClipRRect(
            borderRadius: PdlRadii.mdAll,
            child: SizedBox(
              height: widget.mapHeight,
              child: RouteMap(
                route: route,
                cursor: cursor,
                onMapTapped: cursor.moveTo,
                allowFullscreen: true,
                colorBy: colorBy,
                selection: _selection,
                layer: widget.mapLayer,
              ),
            ),
          ),
          if (modes.length > 1) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            RouteColorModeSwitch(
              key: widget.colorBySwitchKey ?? keys.routeDetail.surfaceColorBy,
              modes: modes,
              value: colorBy,
              onChanged:
                  widget.onColorByChanged ??
                  (RouteColorBy v) => setState(() => _colorBy = v),
            ),
          ],
          const SizedBox(height: PdlSpacing.section),
          _profile(
            route,
            cursor,
            units,
            profileColorBy(colorBy),
            colorBy == RouteColorBy.wind ? widget.windLeg : null,
          ),
          // L'espace n'est posé que si la section rend quelque chose : la
          // plupart des parcours n'ont pas (encore) de revêtement.
          if (hasTrackSurfaces(route.tracks) ||
              trackSurfacesPending(route.tracks)) ...<Widget>[
            const SizedBox(height: PdlSpacing.section),
            RouteSurfaceSection(tracks: route.tracks),
          ],
          if (route.waypoints.isNotEmpty) ...<Widget>[
            const SizedBox(height: PdlSpacing.section),
            RouteWaypointsSection(
              waypoints: route.waypoints,
              selection: _selection,
              // La carte n'est pas interactive, mais une caméra pilotée par le
              // code fonctionne : `PdlMap` ramène la vignette à l'écran.
              onSelect: (String key, WaypointDto _) =>
                  _selection.select(key, move: PdlWaypointMove.center),
            ),
          ],
        ] else
          PdlEmptyState(
            variant: PdlEmptyVariant.empty,
            title: 'routes.noTrackTitle'.tr(),
            message: 'routes.noTrackMessage'.tr(),
          ),
        const SizedBox(height: PdlSpacing.section),
        RouteDownloadActions(route: route),
        ?widget.beforeClimbs,
        if (route.allClimbs.isNotEmpty) ...<Widget>[
          const SizedBox(height: PdlSpacing.section),
          RouteClimbsSection(climbs: route.allClimbs),
        ],
        if (widget.showOpenFullAction) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          PdlButton(
            label: 'routes.openFullSheet'.tr(),
            variant: PdlButtonVariant.outline,
            fullWidth: true,
            onPressed: () => context.push(
              Paths.route(widget.routeKey.teamSlug, widget.routeKey.routeSlug),
            ),
          ),
        ],
      ],
    );
  }

  Widget _withMarkers(
    RouteDetailDto route,
    Widget Function(List<PdlProfileMarker>, String?, ValueChanged<String>?)
    builder,
  ) {
    final List<PdlProfileMarker> markers = profileMarkersOf(route.waypoints);
    if (markers.isEmpty) return builder(markers, null, null);
    return ValueListenableBuilder<WaypointSelection?>(
      valueListenable: _selection,
      builder: (BuildContext context, WaypointSelection? selected, _) =>
          builder(markers, selected?.key, (String key) {
            final WaypointDto? w = waypointByKey(route.waypoints, key);
            if (w == null) return;
            _cursor?.moveTo(w.distance);
            openWaypoint(
              context,
              w,
              _selection,
              key,
              units: ref.read(unitSystemProvider),
              move: PdlWaypointMove.ifHidden,
            );
          }),
    );
  }

  Widget _profile(
    RouteDetailDto route,
    RouteCursorController cursor,
    UnitSystem units,
    RouteColorBy colorBy,
    WeatherLegDto? windLeg,
  ) {
    final List<TrackSurface?>? bars = colorBy == RouteColorBy.surface
        ? ref.watch(routeSurfaceBarsProvider(widget.routeKey)).value
        : null;
    // La pente des montées, barre par barre, comme la carte (ledger
    // `MOB-105`).
    final ClimbBars? climbs = bars == null
        ? ref.watch(routeClimbBarsProvider(widget.routeKey)).value
        : null;
    // Le vent sous le profil, en mode Météo seulement (ledger `MOB-106`).
    final WindBars? wind = windLeg == null
        ? null
        : ref
              .watch(
                routeWindBarsProvider(
                  WindBarsKey<RouteKey>(widget.routeKey, windLeg),
                ),
              )
              .value;

    return ref
        .watch(routeElevationSamplesProvider(widget.routeKey))
        .when(
          // Pas d'altitude exploitable : rien, plutôt qu'un profil plat qui se
          // ferait passer pour un terrain.
          data: (ElevationSamples? samples) => samples == null
              ? const SizedBox.shrink()
              : _withMarkers(
                  route,
                  (
                    List<PdlProfileMarker> markers,
                    String? selectedKey,
                    ValueChanged<String>? onMarker,
                  ) => PdlElevationProfile(
                    markers: markers,
                    selectedMarkerKey: selectedKey,
                    onMarkerTapped: onMarker,
                    credit: 'routes.elevationCredit'.tr(),
                    samples: samples,
                    height: PdlMetrics.elevationLarge,
                    barColors: bars == null
                        ? climbs?.colors
                        : _barColors.of(bars, context.pdl),
                    bandColors: wind?.colors,
                    cursorDistance: cursor.distance,
                    axisLabel: (double meters, {required bool isLast}) => isLast
                        ? AppFormatters.formatDistance(meters, units)
                        : AppFormatters.formatNumber(
                            units.longDistance(meters),
                            fractionDigits: 1,
                          ),
                    tipLabel: (ElevationReading r) => <String>[
                      AppFormatters.formatDistance(r.distance, units),
                      AppFormatters.formatAltitude(r.elevation, units),
                      if (bars != null)
                        ?trackSurfaceTip(samples, bars, r.distance)
                      else
                        ?climbGradeTipLabel(samples, climbs, r),
                      if (wind != null) windTipLabel(samples, wind, r.distance),
                    ].join(' · '),
                  ),
                ),
          loading: () => PdlElevationProfile.loading(
            label: 'routes.profileLoading'.tr(),
            height: PdlMetrics.elevationLarge,
          ),
          error: (Object error, StackTrace stack) => PdlElevationProfile.failed(
            label: 'routes.profileUnavailable'.tr(),
            actionLabel: 'common.retry'.tr(),
            height: PdlMetrics.elevationLarge,
            onRetry: () => ref.invalidate(routeDetailProvider(widget.routeKey)),
          ),
        );
  }
}

/// L'en-tête de la fiche embarquée : l'équipe, le titre, le revêtement et la
/// visibilité, Distance · D+ · D−. Repris de l'ancien en-tête de feuille de
/// l'écran 13 (`RouteSheetHeader`, retiré au lot 10 de `MOB-134` : la fiche
/// parcours défile désormais) ; il part avec cette fiche au lot 11.
class _EmbeddedRouteHeader extends StatelessWidget {
  const _EmbeddedRouteHeader({required this.route, required this.units});

  final RouteDetailDto route;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PdlTeamLine(
            label: route.team.name,
            imageUrl: route.team.logoUrl,
            onTap: () => pushLocation(context, Paths.team(route.team.slug)),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  route.name,
                  style: t.screenTitle.copyWith(fontSize: 20),
                ),
              ),
              const SizedBox(width: PdlSpacing.chipGap),
              PdlBadgeStack(
                badges: <Widget>[
                  PdlBadge(
                    label: AppFormatters.surfaceName(route.surfaceType),
                    tone: SurfaceType.fromJson(route.surfaceType).tone(c),
                  ),
                  PdlBadge(
                    label: 'visibility.${route.visibility.toLowerCase()}'.tr(),
                    tone: Visibility.fromJson(route.visibility).tone(c),
                    icon: switch (route.visibility) {
                      'PUBLIC' => PdlIcons.visibilityPublic,
                      'PUBLIC_UNLISTED' => PdlIcons.visibilityUnlisted,
                      _ => PdlIcons.visibilityTeam,
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              PdlStat(
                value: AppFormatters.formatDistance(route.distance, units),
                icon: PdlIcons.distance,
                label: 'routes.distance'.tr(),
                big: true,
              ),
              PdlStat(
                value: AppFormatters.formatElevation(
                  route.elevationGain,
                  units,
                ),
                icon: PdlIcons.elevationUp,
                label: 'units.elevationGainLong'.tr(),
                big: true,
                trend: PdlStatTrend.up,
              ),
              // Le serveur rend `elevationLoss` négatif : sa valeur absolue
              // derrière notre propre « − ».
              PdlStat(
                value:
                    '−${AppFormatters.formatElevation(route.elevationLoss.abs(), units)}',
                icon: PdlIcons.elevationDown,
                label: 'units.elevationLossLong'.tr(),
                big: true,
                trend: PdlStatTrend.down,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
