import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/units/unit_system.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/detail_source_button.dart';
import '../../../../keys.dart';
import '../../providers/trip_detail_provider.dart';
import '../../providers/trip_elevation_provider.dart';
import '../../providers/trip_tracks_provider.dart';

/// Le profil altimétrique global du voyage, sous la carte de la section
/// « Parcours » (ledger `MOB-134`, lot 9) : « Profil » et son ⓘ (la source des
/// altitudes, comme la sortie), le profil à `PdlMetrics.detailElevation`. Les
/// totaux ne s'y répètent pas : les tuiles du voyage les donnent.
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
            Flexible(
              child: Text(
                'rides.routeSection.profile'.tr(),
                style: t.bodyStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DetailSourceButton(
              key: keys.trip.profileSource,
              semanticLabel: 'rides.routeSection.profileSourceTitle'.tr(),
              onPressed: () => showDetailSourceSheet(
                context,
                title: 'rides.routeSection.profileSourceTitle'.tr(),
                text: 'routes.elevationCredit'.tr(),
              ),
            ),
          ],
        ),
        profile.when(
          data: (TripElevation? data) => data == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PdlElevationProfile(
                      samples: data.samples,
                      height: PdlMetrics.detailElevation,
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
            height: PdlMetrics.detailElevation,
          ),
          error: (Object error, StackTrace stack) => PdlElevationProfile.failed(
            label: 'routes.profileUnavailable'.tr(),
            actionLabel: 'common.retry'.tr(),
            height: PdlMetrics.detailElevation,
            onRetry: () => ref.invalidate(tripTracksProvider(tripKey)),
          ),
        ),
      ],
    );
  }
}
