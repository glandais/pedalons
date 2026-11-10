import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/share_link.dart';
import '../../../../keys.dart';
import '../gps_export_runner.dart';
import 'gps_button.dart';

/// La rangée d'actions d'un parcours : le bouton « GPS » (feuille GPS : vers
/// un appareil, GPX, FIT) et le partage du lien.
///
/// Ne sert plus qu'à [EmbeddedRouteSheet] (l'étape, jusqu'au lot 11 de
/// `MOB-134`) : la fiche parcours pose son « GPS » dans `RouteSection` et
/// son partage dans la barre du haut.
///
/// L'issue d'un export est un **bandeau** ([GpsExportRunner]), pas un
/// snackbar — un `SnackBar` posé en bas d'écran passait sous la barre
/// d'onglets et sous la barre d'actions elle-même.
class RouteDownloadActions extends ConsumerStatefulWidget {
  const RouteDownloadActions({super.key, required this.route});

  final RouteDetailDto route;

  @override
  ConsumerState<RouteDownloadActions> createState() =>
      _RouteDownloadActionsState();
}

class _RouteDownloadActionsState extends ConsumerState<RouteDownloadActions>
    with GpsExportRunner<RouteDownloadActions> {
  RouteDetailDto get route => widget.route;

  @override
  Widget build(BuildContext context) {
    final GpsExportTarget target = GpsExportTarget(
      subtitle: route.name,
      teamSlug: route.team.slug,
      routeSlug: route.slug,
      gpx: route.media.assets.gpx,
      fit: route.media.assets.fit,
    );
    if (!target.offered(watchGpsServices())) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ...gpsExportBanners(gap: PdlSpacing.chipGap),
        Row(
          children: <Widget>[
            Expanded(
              child: GpsButton(
                key: keys.routeDetail.gps,
                loading: gpsExporting,
                onPressed: (BuildContext button) =>
                    openGpsSheet(target, button),
              ),
            ),
            const SizedBox(width: PdlSpacing.chipGap),
            PdlButton(
              label: '',
              icon: PdlIcons.share,
              variant: PdlButtonVariant.outline,
              onPressed: _share,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _share() => shareAppLink(
    context,
    title: route.name,
    path: Paths.route(route.team.slug, route.slug),
  );
}
