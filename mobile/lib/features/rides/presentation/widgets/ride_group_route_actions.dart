import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../routes/presentation/gps_export_runner.dart';
import '../../../routes/presentation/widgets/gps_button.dart';
import '../../domain/group_title.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_group_selection_provider.dart';

/// Le sous-titre de la feuille GPS d'un groupe : « Groupe B · 78,0 km », le
/// nom seul quand la distance n'est pas connue.
String gpsSubtitleOfGroup(RideGroupDto group, UnitSystem units) {
  final String title = groupTitle(group.name, 'rides.groupPage.title'.tr());
  final double? distance = group.distance;
  return distance == null
      ? title
      : '$title · ${AppFormatters.formatDistance(distance, units)}';
}

/// La cible GPS du parcours [routeSlug] d'un groupe, ses fichiers pris dans
/// [route] (chargé en lot pour la carte, sans appel de plus).
GpsExportTarget gpsTargetOfGroup({
  required String subtitle,
  required String teamSlug,
  required String? routeSlug,
  required RouteDetailDto? route,
}) => GpsExportTarget(
  subtitle: subtitle,
  teamSlug: teamSlug,
  routeSlug: routeSlug,
  gpx: route?.media.assets.gpx,
  fit: route?.media.assets.fit,
);

/// « Parcours du groupe » : voir le parcours, et le bouton « GPS ». Partagé
/// par l'Aperçu de la page d'un groupe et le détail d'une sortie solo
/// (ledgers `MOB-67`, `MOB-69`).
///
/// L'export lui-même et ses bandeaux vivent dans le [GpsExportRunner] de
/// l'appelant : ce bloc ne reçoit que de quoi le lancer.
class RideGroupRouteActions extends ConsumerWidget {
  const RideGroupRouteActions({
    super.key,
    required this.rideKey,
    required this.teamSlug,
    required this.routeSlug,
    required this.subtitle,
    required this.onOpenGps,
    this.gpsLoading = false,
  });

  final RideKey rideKey;
  final String teamSlug;
  final String routeSlug;

  /// Le sous-titre de la feuille GPS ([gpsSubtitleOfGroup]).
  final String subtitle;

  /// Ouvre la feuille GPS ([GpsExportRunner.openGpsSheet]) : la cible, puis
  /// le contexte du bouton, ancre du partage sur iPad.
  final void Function(GpsExportTarget target, BuildContext button) onOpenGps;

  final bool gpsLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Les parcours sont déjà chargés en lot pour la carte : leurs assets
    // GPX/FIT viennent de là, sans appel de plus.
    final RouteDetailDto? route = ref.watch(
      rideRouteGeometriesProvider(rideKey)
          .select((RideRouteGeometriesState s) => s.geometries[routeSlug]),
    );
    final List<GpsServiceConnectionDto> services = ref.watch(
      authProvider.select(
        (AuthState s) => s.user?.connectedServices ?? const [],
      ),
    );
    final GpsExportTarget target = gpsTargetOfGroup(
      subtitle: subtitle,
      teamSlug: teamSlug,
      routeSlug: routeSlug,
      route: route,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(
          title: 'rides.groupPage.routeTitle'.tr(),
          padding: const EdgeInsets.only(bottom: PdlSpacing.badgeGap),
        ),
        Wrap(
          spacing: PdlSpacing.badgeGap,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (target.offered(services))
              GpsButton(
                key: keys.rideGroup.gps,
                compact: true,
                loading: gpsLoading,
                onPressed: (BuildContext button) => onOpenGps(target, button),
              ),
            PdlButton(
              label: 'rides.viewRoute'.tr(),
              icon: PdlIcons.route,
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              onPressed: () => context.push(Paths.route(teamSlug, routeSlug)),
            ),
          ],
        ),
      ],
    );
  }
}
