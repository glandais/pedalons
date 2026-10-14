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
import '../../../../core/units/unit_system.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/trip_detail_provider.dart';
import '../../providers/trip_elevation_provider.dart';
import '../../providers/trip_tracks_provider.dart';

/// Le profil altimétrique global du voyage.
///
/// **Sans réticule** : sur 600 km concaténés, un curseur au pixel désignerait
/// une position à deux kilomètres près et ne dirait rien d'utile. Le profil de
/// l'étape, lui, en a un — c'est l'écran 25 qui le porte.
///
/// C'est un enrichissement : son échec ne produit pas d'écran d'erreur, et un
/// trou dans le tracé est **signalé** plutôt que masqué.
class TripElevationSection extends ConsumerWidget {
  const TripElevationSection({
    super.key,
    required this.tripKey,
    required this.trip,
  });

  final TripKey tripKey;
  final TripDto trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);
    final AsyncValue<TripElevation?> profile = ref.watch(
      tripElevationProvider(tripKey),
    );

    // Rien à profiler : le bloc n'existe pas, il ne s'affiche pas vide.
    if (profile.value == null && !profile.isLoading && !profile.hasError) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'trips.globalProfile'.tr(),
                style: t.xs.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_summary(units) != null) Text(_summary(units)!, style: t.xs),
          ],
        ),
        const SizedBox(height: 6),
        profile.when(
          data: (TripElevation? data) => data == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PdlElevationProfile(
                      credit: 'routes.elevationCredit'.tr(),
                      samples: data.samples,
                      height: PdlMetrics.elevationMedium,
                      // Le dernier repère porte l'unité, les autres le seul
                      // nombre (§1.3.1) ; l'axe se lit en quarts de la distance
                      // totale du voyage.
                      axisLabel: (double meters, {required bool isLast}) =>
                          isLast
                          ? AppFormatters.formatDistance(meters, units)
                          : AppFormatters.formatNumber(
                              units.longDistance(meters),
                            ),
                      tipLabel: (ElevationReading r) => <String>[
                        AppFormatters.formatDistance(r.distance, units),
                        AppFormatters.formatAltitude(r.elevation, units),
                      ].join(' · '),
                    ),
                    if (data.hasGaps)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              PdlIcons.warning,
                              size: 15,
                              color: c.textDimmed,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'trips.profileGaps'.tr(
                                  namedArgs: <String, String>{
                                    'stages': data.gaps.join(', '),
                                  },
                                ),
                                style: t.xs,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
          loading: () => PdlElevationProfile.loading(
            label: 'routes.profileLoading'.tr(),
            height: PdlMetrics.elevationMedium,
          ),
          error: (Object error, StackTrace stack) => PdlElevationProfile.failed(
            label: 'routes.profileUnavailable'.tr(),
            actionLabel: 'common.retry'.tr(),
            height: PdlMetrics.elevationMedium,
            onRetry: () => ref.invalidate(tripTracksProvider(tripKey)),
          ),
        ),
      ],
    );
  }

  String? _summary(UnitSystem units) {
    final List<String> parts = <String>[
      if (trip.totalDistance != null)
        AppFormatters.formatDistance(trip.totalDistance!, units),
      if (trip.totalElevationGain != null)
        AppFormatters.formatElevationGain(trip.totalElevationGain!, units),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
