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
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_group_selection_provider.dart';

/// Le profil altimétrique du groupe sélectionné (écran 12), en 110 px.
///
/// C'est un **enrichissement** : son chargement n'empêche rien, son échec ne
/// produit pas d'écran d'erreur mais une ligne discrète et un « Réessayer ».
/// Le reste de la sortie reste lisible et interactif dans les deux cas.
class RideElevationSection extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);

    final RouteRef routeRef = RouteRef(
      teamSlug: teamSlug,
      rideSlug: rideSlug,
      routeSlug: routeSlug,
    );
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
                    if (r.grade != null) AppFormatters.formatGrade(r.grade!),
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
                RideKey(teamSlug: teamSlug, rideSlug: rideSlug),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _summary(UnitSystem units) {
    final List<String> parts = <String>[
      if (distance != null) AppFormatters.formatDistance(distance!, units),
      if (elevationGain != null)
        AppFormatters.formatElevationGain(elevationGain!, units),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
