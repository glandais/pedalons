import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/units/unit_system.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/detail_section.dart';
import '../../../../core/widgets/detail_source_button.dart';
import '../../../../keys.dart';
import '../../domain/elevation_refresh.dart';
import '../../domain/route_color_mode.dart';
import '../../domain/track_slope_colors.dart';
import '../../domain/track_surfaces.dart';
import '../../domain/track_wind_bars.dart';
import '../../providers/route_detail_provider.dart';
import '../../providers/route_elevation_provider.dart';
import '../gps_export_runner.dart';
import 'gps_button.dart';
import 'route_color_mode_switch.dart';
import 'route_cursor_controller.dart';
import 'route_map.dart';
import 'route_surface_section.dart';
import 'waypoint_selection.dart';
import 'waypoint_sheet.dart';

/// La section « Parcours » d'un écran qui montre **un seul** parcours (ledger
/// `MOB-134`, KIT §8, maquettes `parcours-mobile-cible` et
/// `etape-mobile-cible`) — la fiche parcours, et l'étape d'un voyage (lot 11) :
///
/// 1. le titre [title] s'il est donné (« Parcours » sur l'étape ; la fiche
///    parcours n'en a pas : la carte suit les tuiles) ;
/// 2. la carte pleine largeur, à `PdlMetrics.detailMapHeight`, avec son plein
///    écran ([RouteMap], `allowFullscreen`) ;
/// 3. l'interrupteur Pente | Revêtement (| Météo avec [offersWind]), partagé
///    par la carte, son plein écran et le profil (ledger `MOB-105`) ;
/// 4. « Profil » et son ⓘ (la source des altitudes), la mention « Profil
///    d'altitude provisoire » tant qu'elle vaut (ledger `MOB-76`), le profil à
///    `PdlMetrics.detailElevation` ;
/// 5. la barre de revêtement, sa légende et son ⓘ (OpenStreetMap) ;
/// 6. le bouton « GPS » unique (la feuille GPS, [GpsExportRunner]) et, avec
///    [showDetailsAction], « Détails », qui pousse la fiche du parcours.
///
/// Les points du parcours et les cols ne sont **pas** ici : la fiche les pose
/// en sections dépliées, l'étape en blocs repliés. La sélection d'un point
/// ([selection]) et le réticule ([cursor]) se partagent donc avec l'écran
/// hôte ; sans eux, la section tient les siens.
///
/// Elle a remplacé, sur l'étape, la fiche parcours embarquée
/// (`EmbeddedRouteSheet`, retirée au lot 11 de `MOB-134`).
class RouteSection extends ConsumerStatefulWidget {
  const RouteSection({
    super.key,
    required this.routeKey,
    this.title,
    this.selection,
    this.cursor,
    this.mapLayer,
    this.colorBy,
    this.onColorByChanged,
    this.offersWind = false,
    this.windLeg,
    this.colorBySwitchKey,
    this.showDetailsAction = false,
    this.mapKey,
  });

  final RouteKey routeKey;

  /// Le titre de section ; `null` : aucun, la carte vient d'abord.
  final String? title;

  /// Le point de parcours choisi, partagé par la carte, le profil et la liste
  /// de l'écran hôte (ledger `MOB-84`) ; `null` : la section tient le sien.
  final WaypointSelectionController? selection;

  /// Le réticule partagé par la carte et le profil, que l'écran hôte déplace
  /// aussi (une montée touchée) ; `null` : la section tient le sien. Il doit
  /// être bâti sur la géométrie du parcours de [routeKey].
  final RouteCursorController? cursor;

  /// Ce que l'écran hôte pose en plus sur la carte — le mode « Météo » d'une
  /// étape (ledger `MOB-94`) —, transmis au plein écran.
  final RouteMapLayerBuilder? mapLayer;

  /// Le mode choisi par l'écran hôte, avec [onColorByChanged] ; `null` : la
  /// section garde son propre choix.
  final RouteColorBy? colorBy;
  final ValueChanged<RouteColorBy>? onColorByChanged;

  /// L'interrupteur propose « Météo » : l'écran hôte colore alors le tracé
  /// par le vent (via [mapLayer]).
  final bool offersWind;

  /// Le leg dont l'écran hôte colore le tracé en mode Météo : le profil gagne
  /// la bande du vent (ledger `MOB-106`). Ignoré hors mode Météo.
  final WeatherLegDto? windLeg;

  /// La clé de l'interrupteur ; `keys.routeDetail.surfaceColorBy` par défaut.
  final Key? colorBySwitchKey;

  /// « Détails » à côté de « GPS », qui pousse la fiche du parcours — rien
  /// sur la fiche elle-même.
  final bool showDetailsAction;

  /// Posée sur la carte : l'ancre d'un défilement qui la remonte à l'écran
  /// (un point touché dans la liste de l'écran hôte).
  final Key? mapKey;

  @override
  ConsumerState<RouteSection> createState() => _RouteSectionState();
}

class _RouteSectionState extends ConsumerState<RouteSection>
    with GpsExportRunner<RouteSection> {
  RouteCursorController? _ownCursor;
  String? _ownCursorForSlug;
  RouteColorBy _colorBy = RouteColorBy.grade;
  final TrackSurfaceBarColors _barColors = TrackSurfaceBarColors();
  WaypointSelectionController? _ownSelection;

  WaypointSelectionController get _selection =>
      widget.selection ?? (_ownSelection ??= WaypointSelectionController());

  @override
  void dispose() {
    _ownCursor?.dispose();
    _ownSelection?.dispose();
    super.dispose();
  }

  /// Le réticule de l'écran hôte, sinon le sien, reconstruit quand — et
  /// seulement quand — le parcours change.
  RouteCursorController _cursorFor(RouteDetailDto route) {
    if (widget.cursor != null) return widget.cursor!;
    if (_ownCursor != null && _ownCursorForSlug == route.slug) {
      return _ownCursor!;
    }
    _ownCursor?.dispose();
    _ownCursorForSlug = route.slug;
    return _ownCursor = RouteCursorController(
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
    final Widget body = detail.when(
      data: _body,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        child: PdlSkeletonCard(variant: PdlSkeletonCardVariant.media),
      ),
      error: (Object error, StackTrace stack) => PdlEmptyState(
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
    );

    final String? title = widget.title;
    if (title != null) {
      return DetailSection(title: title, bleed: true, child: body);
    }
    return Padding(
      padding: const EdgeInsets.only(top: PdlSpacing.section),
      child: body,
    );
  }

  Widget _body(RouteDetailDto route) {
    final RouteCursorController cursor = _cursorFor(route);
    final List<RouteColorBy> modes = routeColorModes(
      surfaces: hasTrackSurfaces(route.tracks),
      wind: widget.offersWind,
    );
    final RouteColorBy colorBy = resolveRouteColorBy(
      widget.colorBy ?? _colorBy,
      modes,
    );
    const EdgeInsets side = EdgeInsets.symmetric(
      horizontal: PdlSpacing.section,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (route.hasGeometry) ...<Widget>[
          KeyedSubtree(
            key: widget.mapKey,
            child: SizedBox(
              key: keys.routeDetail.map,
              height: PdlMetrics.detailMapHeight(
                MediaQuery.sizeOf(context).height,
              ),
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
          if (modes.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PdlSpacing.section,
                PdlSpacing.chipGap,
                PdlSpacing.section,
                0,
              ),
              child: RouteColorModeSwitch(
                key: widget.colorBySwitchKey ?? keys.routeDetail.surfaceColorBy,
                modes: modes,
                value: colorBy,
                onChanged:
                    widget.onColorByChanged ??
                    (RouteColorBy v) => setState(() => _colorBy = v),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              PdlSpacing.section,
              PdlSpacing.section,
              0,
            ),
            child: _profileBlock(
              route,
              cursor,
              profileColorBy(colorBy),
              colorBy == RouteColorBy.wind ? widget.windLeg : null,
            ),
          ),
          // L'espace n'est posé que si la section rend quelque chose : la
          // plupart des parcours n'ont pas (encore) de revêtement.
          if (hasTrackSurfaces(route.tracks) ||
              trackSurfacesPending(route.tracks))
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PdlSpacing.section,
                PdlSpacing.section,
                PdlSpacing.section,
                0,
              ),
              child: RouteSurfaceSection(
                tracks: route.tracks,
                sourceInfoKey: keys.routeDetail.surfaceSource,
              ),
            ),
        ] else
          PdlEmptyState(
            variant: PdlEmptyVariant.empty,
            icon: PdlIcons.route,
            title: 'routes.noTrackTitle'.tr(),
            message: 'routes.noTrackMessage'.tr(),
          ),
        Padding(
          padding: side,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ...gpsExportBanners(gapBefore: true),
              ?_actions(route),
            ],
          ),
        ),
      ],
    );
  }

  /// « GPS » et, sur l'étape, « Détails ». Rien sans l'un ni l'autre.
  Widget? _actions(RouteDetailDto route) {
    final GpsExportTarget target = GpsExportTarget(
      subtitle: route.name,
      teamSlug: route.team.slug,
      routeSlug: route.slug,
      gpx: route.media.assets.gpx,
      fit: route.media.assets.fit,
    );
    final bool gps = target.offered(watchGpsServices());
    if (!gps && !widget.showDetailsAction) return null;
    return Padding(
      padding: const EdgeInsets.only(top: PdlSpacing.section),
      child: Wrap(
        spacing: PdlSpacing.chipGap,
        runSpacing: PdlSpacing.badgeGap,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (gps)
            GpsButton(
              key: keys.routeDetail.gps,
              compact: true,
              loading: gpsExporting,
              onPressed: (BuildContext button) => openGpsSheet(target, button),
            ),
          if (widget.showDetailsAction)
            PdlButton(
              key: keys.routeDetail.details,
              label: 'common.details'.tr(),
              icon: PdlIcons.route,
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              onPressed: () => context.push(
                Paths.route(
                  widget.routeKey.teamSlug,
                  widget.routeKey.routeSlug,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// « Profil » et son ⓘ, la mention provisoire, puis le profil.
  Widget _profileBlock(
    RouteDetailDto route,
    RouteCursorController cursor,
    RouteColorBy colorBy,
    WeatherLegDto? windLeg,
  ) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                'rides.routeSection.profile'.tr(),
                style: t.bodyStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DetailSourceButton(
              key: keys.routeDetail.profileSource,
              semanticLabel: 'rides.routeSection.profileSourceTitle'.tr(),
              onPressed: () => showDetailSourceSheet(
                context,
                key: keys.routeDetail.profileSourceSheet,
                title: 'rides.routeSection.profileSourceTitle'.tr(),
                text: 'routes.elevationCredit'.tr(),
              ),
            ),
          ],
        ),
        // « Profil d'altitude provisoire » tant que c'est l'altitude rapide
        // (`PENDING`) : comme au site, la mention se tait en `FAST` et `HD`.
        if (isElevationPending(route.elevationState))
          Padding(
            key: keys.routeDetail.elevationRefining,
            padding: const EdgeInsets.only(bottom: PdlSpacing.badgeGap),
            child: Text(
              'routes.elevationRefining'.tr(),
              style: t.xs.copyWith(color: c.textDimmed),
            ),
          ),
        _profile(route, cursor, colorBy, windLeg),
      ],
    );
  }

  Widget _withMarkers(
    RouteDetailDto route,
    RouteCursorController cursor,
    Widget Function(List<PdlProfileMarker>, String?, ValueChanged<String>?)
    builder,
  ) {
    final List<PdlProfileMarker> markers = profileMarkersOf(route.waypoints);
    if (markers.isEmpty) return builder(markers, null, null);
    final WaypointSelectionController selection = _selection;
    return ValueListenableBuilder<WaypointSelection?>(
      valueListenable: selection,
      builder: (BuildContext context, WaypointSelection? selected, _) =>
          builder(markers, selected?.key, (String key) {
            final WaypointDto? w = waypointByKey(route.waypoints, key);
            if (w == null) return;
            if (w.distance != null) cursor.moveTo(w.distance);
            openWaypoint(
              context,
              w,
              selection,
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
    RouteColorBy colorBy,
    WeatherLegDto? windLeg,
  ) {
    final UnitSystem units = ref.watch(unitSystemProvider);
    final RouteKey key = widget.routeKey;
    final List<TrackSurface?>? bars = colorBy == RouteColorBy.surface
        ? ref.watch(routeSurfaceBarsProvider(key)).value
        : null;
    // La pente des montées, barre par barre, comme la carte (ledger
    // `MOB-105`).
    final ClimbBars? climbs = bars == null
        ? ref.watch(routeClimbBarsProvider(key)).value
        : null;
    // Le vent sous le profil, en mode Météo seulement (ledger `MOB-106`).
    final WindBars? wind = windLeg == null
        ? null
        : ref
              .watch(routeWindBarsProvider(WindBarsKey<RouteKey>(key, windLeg)))
              .value;

    return ref
        .watch(routeElevationSamplesProvider(key))
        .when(
          // Pas d'altitude exploitable : rien, plutôt qu'un profil plat qui se
          // ferait passer pour un terrain.
          data: (ElevationSamples? samples) => samples == null
              ? const SizedBox.shrink()
              : _withMarkers(
                  route,
                  cursor,
                  (
                    List<PdlProfileMarker> markers,
                    String? selectedKey,
                    ValueChanged<String>? onMarker,
                  ) => PdlElevationProfile(
                    key: keys.routeDetail.elevationProfile,
                    markers: markers,
                    selectedMarkerKey: selectedKey,
                    onMarkerTapped: onMarker,
                    samples: samples,
                    height: PdlMetrics.detailElevation,
                    // Le seul état partagé avec la carte, hors Riverpod : le
                    // réticule bouge à chaque image du glissé.
                    barColors: bars == null
                        ? climbs?.colors
                        : _barColors.of(bars, context.pdl),
                    bandColors: wind?.colors,
                    cursorDistance: cursor.distance,
                    // Seule la dernière graduation porte l'unité.
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
            height: PdlMetrics.detailElevation,
          ),
          error: (Object error, StackTrace stack) => PdlElevationProfile.failed(
            label: 'routes.profileUnavailable'.tr(),
            actionLabel: 'common.retry'.tr(),
            height: PdlMetrics.detailElevation,
            onRetry: () => ref.invalidate(routeDetailProvider(key)),
          ),
        );
  }
}
