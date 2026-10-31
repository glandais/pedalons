import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/share_file.dart';
import '../../../../core/utils/share_link.dart';
import '../../../../keys.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../routes/presentation/route_export.dart';
import '../../providers/ride_detail_provider.dart';
import '../../providers/ride_group_selection_provider.dart';

/// L'export du parcours d'un groupe — GPX, FIT, envoi vers un appareil —,
/// partagé par la section Groupes du détail et l'aperçu de la page d'un groupe
/// (ledger `MOB-67`).
///
/// L'issue du dernier export s'affiche en bandeau ([exportBanners]), comme sur
/// la fiche parcours, pas en snackbar ; un seul export à la fois.
mixin RouteExportRunner<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Object? _exportError;
  String? _exportSuccess;
  bool _exporting = false;

  /// Télécharge [asset] (GPX ou FIT) et le passe à la feuille de partage.
  Future<void> downloadRouteAsset(AssetDto asset) async {
    await _runExport(() async {
      await downloadAndShareAsset(ref, asset, origin: shareOriginOf(context));
      return null;
    });
  }

  /// Fait choisir un service GPS connecté, puis lui envoie le parcours.
  Future<void> sendRouteToDevice(
    String teamSlug,
    String routeSlug,
    List<GpsServiceConnectionDto> services,
  ) async {
    final GpsServiceConnectionDto? picked = await pickGpsService(
      context,
      services,
    );
    if (picked == null) return;
    await _runExport(() async {
      await uploadRouteToService(
        ref,
        picked,
        teamSlug: teamSlug,
        routeSlug: routeSlug,
      );
      return 'routes.uploadSuccess'.tr();
    });
  }

  /// Un export à la fois : un second tap pendant un téléchargement est ignoré
  /// plutôt que d'empiler deux feuilles de partage.
  Future<void> _runExport(Future<String?> Function() run) async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _exportError = null;
      _exportSuccess = null;
    });
    try {
      final String? success = await run();
      if (mounted) setState(() => _exportSuccess = success);
    } catch (error) {
      if (mounted) setState(() => _exportError = error);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Les bandeaux d'échec et de réussite, chacun suivi de [gap].
  List<Widget> exportBanners({double gap = 10}) => <Widget>[
    if (_exportError != null) ...<Widget>[
      PdlBanner(
        tone: PdlBannerTone.danger,
        message: getErrorMessage(_exportError!),
        onDismiss: () => setState(() => _exportError = null),
        dismissSemanticLabel: 'common.close'.tr(),
      ),
      SizedBox(height: gap),
    ],
    if (_exportSuccess != null) ...<Widget>[
      PdlBanner(
        tone: PdlBannerTone.info,
        message: _exportSuccess!,
        onDismiss: () => setState(() => _exportSuccess = null),
        dismissSemanticLabel: 'common.close'.tr(),
      ),
      SizedBox(height: gap),
    ],
  ];
}

/// « Parcours du groupe » : voir le parcours, GPX, FIT, envoi vers un
/// appareil. Partagé par l'Aperçu de la page d'un groupe et le détail d'une
/// sortie solo (ledgers `MOB-67`, `MOB-69`).
///
/// L'export lui-même et ses bandeaux vivent dans le [RouteExportRunner] de
/// l'appelant : ce bloc ne reçoit que de quoi le lancer.
class RideGroupRouteActions extends ConsumerWidget {
  const RideGroupRouteActions({
    super.key,
    required this.rideKey,
    required this.teamSlug,
    required this.routeSlug,
    required this.onDownload,
    required this.onSendToDevice,
  });

  final RideKey rideKey;
  final String teamSlug;
  final String routeSlug;

  /// Télécharge un GPX ou un FIT ([RouteExportRunner.downloadRouteAsset]).
  final ValueChanged<AssetDto> onDownload;

  /// Envoie le parcours vers l'un des services connectés
  /// ([RouteExportRunner.sendRouteToDevice]).
  final ValueChanged<List<GpsServiceConnectionDto>> onSendToDevice;

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
    final AssetDto? gpx = route?.media.assets.gpx;
    final AssetDto? fit = route?.media.assets.fit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(
          title: 'rides.groupPage.routeTitle'.tr(),
          padding: const EdgeInsets.only(bottom: PdlSpacing.badgeGap),
        ),
        Wrap(
          spacing: PdlSpacing.badgeGap,
          children: <Widget>[
            PdlButton(
              label: 'rides.viewRoute'.tr(),
              icon: PdlIcons.route,
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              onPressed: () => context.push(Paths.route(teamSlug, routeSlug)),
            ),
            if (gpx != null)
              PdlButton(
                key: keys.rideGroup.exportGpx,
                label: 'routes.exportGpx'.tr(),
                icon: PdlIcons.gpx,
                variant: PdlButtonVariant.text,
                size: PdlButtonSize.sm,
                onPressed: () => onDownload(gpx),
              ),
            if (fit != null)
              PdlButton(
                key: keys.rideGroup.exportFit,
                label: 'routes.exportFit'.tr(),
                icon: PdlIcons.gpx,
                variant: PdlButtonVariant.text,
                size: PdlButtonSize.sm,
                onPressed: () => onDownload(fit),
              ),
            if (services.isNotEmpty)
              PdlButton(
                key: keys.rideGroup.sendToDevice,
                label: 'routes.sendToDevice'.tr(),
                icon: PdlIcons.device,
                variant: PdlButtonVariant.text,
                size: PdlButtonSize.sm,
                onPressed: () => onSendToDevice(services),
              ),
          ],
        ),
      ],
    );
  }
}
