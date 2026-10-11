import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/units/unit_system.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/route_detail_provider.dart';
import '../../providers/route_elevation_provider.dart';
import 'route_climbs_section.dart';
import 'route_cursor_controller.dart';
import 'route_download_actions.dart';
import 'route_map.dart';
import 'route_sheet_header.dart';

/// La fiche parcours **embarquée** : en-tête, carte 240 px, profil 140 px,
/// trois statistiques, trois exports, cols.
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
  });

  final RouteKey routeKey;
  final double mapHeight;

  /// Propose « Voir la fiche complète », qui ouvre l'écran 13.
  final bool showOpenFullAction;

  @override
  ConsumerState<EmbeddedRouteSheet> createState() => _EmbeddedRouteSheetState();
}

class _EmbeddedRouteSheetState extends ConsumerState<EmbeddedRouteSheet> {
  RouteCursorController? _cursor;
  String? _cursorForSlug;

  @override
  void dispose() {
    _cursor?.dispose();
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
      data: (RouteDetailDto route) => _body(route),
    );
  }

  Widget _body(RouteDetailDto route) {
    final RouteCursorController cursor = _cursorFor(route);
    final UnitSystem units = ref.watch(unitSystemProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // L'en-tête déployé : c'est le même widget que la feuille de
        // l'écran 13, figé au cran haut.
        RouteSheetHeader(route: route, extent: 1),
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
              ),
            ),
          ),
          const SizedBox(height: PdlSpacing.section),
          _profile(route, cursor, units),
        ] else
          PdlEmptyState(
            variant: PdlEmptyVariant.empty,
            title: 'routes.noTrackTitle'.tr(),
            message: 'routes.noTrackMessage'.tr(),
          ),
        const SizedBox(height: PdlSpacing.section),
        RouteDownloadActions(route: route),
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

  Widget _profile(
    RouteDetailDto route,
    RouteCursorController cursor,
    UnitSystem units,
  ) {
    return ref
        .watch(routeElevationSamplesProvider(widget.routeKey))
        .when(
          // Pas d'altitude exploitable : rien, plutôt qu'un profil plat qui se
          // ferait passer pour un terrain.
          data: (ElevationSamples? samples) => samples == null
              ? const SizedBox.shrink()
              : PdlElevationProfile(
                  samples: samples,
                  height: PdlMetrics.elevationLarge,
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
                    if (r.grade != null) AppFormatters.formatGrade(r.grade!),
                  ].join(' · '),
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
