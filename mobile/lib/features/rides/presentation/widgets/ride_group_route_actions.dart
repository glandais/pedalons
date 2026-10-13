import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../routes/presentation/route_export.dart';

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
      await downloadAndShareRouteAsset(
        ref,
        asset,
        origin: shareOriginOf(context),
      );
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
