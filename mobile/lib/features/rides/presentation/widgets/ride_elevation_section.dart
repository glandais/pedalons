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
import '../../../routes/domain/track_surfaces.dart';
import '../../../routes/presentation/widgets/route_surface_section.dart';
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
  });

  final String teamSlug;
  final String rideSlug;

  /// Le parcours du groupe sélectionné. Change avec la sélection, mais aucun
  /// appel réseau ne s'ensuit : la géométrie de tous les groupes est déjà dans
  /// le lot chargé pour la carte, profil compris.
  final String routeSlug;

  final double? distance;
  final double? elevationGain;

  @override
  ConsumerState<RideElevationSection> createState() =>
      _RideElevationSectionState();
}

class _RideElevationSectionState extends ConsumerState<RideElevationSection> {
  /// Ce que la pente / le revêtement colorent (`MOB-81`) ; retombe sur la
  /// pente quand le parcours du groupe sélectionné n'a pas de revêtement.
  RouteColorBy _colorBy = RouteColorBy.grade;
  final TrackSurfaceBarColors _barColors = TrackSurfaceBarColors();

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
    final List<TrackDto> tracks =
        ref.watch(rideRouteGeometryProvider(routeRef)).value?.tracks ??
        const <TrackDto>[];
    final RouteColorBy colorBy = hasTrackSurfaces(tracks)
        ? _colorBy
        : RouteColorBy.grade;
    final List<TrackSurface?>? bars = colorBy == RouteColorBy.surface
        ? ref.watch(rideRouteSurfaceBarsProvider(routeRef)).value
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
        const SizedBox(height: 6),
        samples.when(
          // Pas d'altitude exploitable : rien, plutôt qu'un profil plat qui se
          // ferait passer pour un terrain.
          data: (ElevationSamples? data) => data == null
              ? const SizedBox.shrink()
              : PdlElevationProfile(
                  credit: 'routes.elevationCredit'.tr(),
                  samples: data,
                  height: PdlMetrics.elevationMedium,
                  barColors: bars == null
                      ? null
                      : _barColors.of(bars, context.pdl),
                  // Seule la dernière graduation porte l'unité (§1.3.1).
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
                      ?trackSurfaceTip(data, bars, r.distance)
                    else if (r.grade != null)
                      AppFormatters.formatGrade(r.grade!),
                  ].join(' · '),
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
          RouteSurfaceSection(
            tracks: tracks,
            colorBy: colorBy,
            onColorByChanged: (RouteColorBy v) => setState(() => _colorBy = v),
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
