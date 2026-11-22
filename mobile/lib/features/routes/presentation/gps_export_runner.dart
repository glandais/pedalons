import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../config/paths.dart';
import '../../../core/material.dart';
import '../../../core/pdl/pdl.dart';
import '../../../core/utils/api_error_handler.dart';
import '../../../core/utils/push_location.dart';
import '../../../core/utils/share_file.dart';
import '../../../core/utils/share_link.dart';
import '../../../keys.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import 'gps_sheet.dart';
import 'route_export.dart';

/// Le parcours que vise un bouton « GPS » : ce que la feuille nomme et ce
/// qu'elle peut proposer.
class GpsExportTarget {
  const GpsExportTarget({
    required this.subtitle,
    required String this.teamSlug,
    required this.routeSlug,
    this.gpx,
    this.fit,
    this.syncStatuses,
  }) : previewId = null;

  /// Un aperçu des outils GPX (docs/LEDGER_*.md MOB-178) : ni équipe ni
  /// slug, l'envoi vers un appareil passe par l'aperçu lui-même.
  const GpsExportTarget.preview({
    required this.subtitle,
    required String this.previewId,
    this.gpx,
    this.fit,
  }) : teamSlug = null,
       routeSlug = null,
       syncStatuses = null;

  /// Le sous-titre de la feuille : « Groupe B · 78,0 km », le nom du parcours.
  final String subtitle;

  /// L'équipe du parcours ; `null` pour un aperçu.
  final String? teamSlug;

  /// `null` : rien à envoyer vers un appareil, seulement des fichiers —
  /// sauf pour un aperçu ([previewId]).
  final String? routeSlug;

  /// L'aperçu des outils GPX visé, `null` pour un parcours d'équipe.
  final String? previewId;

  /// Quelque chose peut partir vers un appareil connecté.
  bool get canSendToDevice => routeSlug != null || previewId != null;
  final AssetDto? gpx;
  final AssetDto? fit;

  /// Où en est déjà le parcours chez les services de la personne
  /// (docs/LEDGER_*.md MOB-133) : ceux d'un groupe, ou d'une sortie sans
  /// groupe — la route que l'envoi automatique transmet —, sinon ceux de la
  /// route.
  final List<RouteGpsSyncStatusDto>? syncStatuses;

  /// Le bouton a-t-il quelque chose à proposer avec ces [services] ?
  bool offered(List<GpsServiceConnectionDto> services) => gpsExportOffered(
    gpx: gpx,
    fit: fit,
    canSend: canSendToDevice && services.isNotEmpty,
  );
}

/// Les gestes qui font sortir un parcours, tels quels : [deliverAsset]
/// (`core/utils/share_file.dart`), [uploadRouteToService] et, pour un aperçu
/// GPX, [uploadPreviewToService].
///
/// Derrière un provider pour que les tests les remplacent — le sélecteur de
/// fichier et la feuille de partage sont des canaux natifs.
class RouteExportOperations {
  const RouteExportOperations({
    this.deliver = deliverAsset,
    this.upload = uploadRouteToService,
    this.uploadPreview = uploadPreviewToService,
  });

  final Future<bool> Function(
    WidgetRef ref,
    AssetDto asset,
    AssetDestination destination, {
    required Rect origin,
  })
  deliver;

  final Future<void> Function(
    WidgetRef ref,
    GpsServiceConnectionDto service, {
    required String teamSlug,
    required String routeSlug,
  })
  upload;

  final Future<void> Function(
    WidgetRef ref,
    GpsServiceConnectionDto service, {
    required String previewId,
  })
  uploadPreview;
}

final Provider<RouteExportOperations> routeExportOperationsProvider =
    Provider<RouteExportOperations>((Ref ref) => const RouteExportOperations());

/// L'export d'un parcours, pour tout écran qui porte un bouton « GPS » : la
/// feuille, l'export choisi, l'état « en cours », et l'issue en bandeau
/// ([gpsExportBanners]) — jamais en snackbar, qui passait sous la barre
/// d'onglets.
///
/// Un mixin d'état et non un provider : l'attente et les bandeaux sont
/// l'affaire de l'écran qui a lancé l'export (RULES.md, « l'état éphémère
/// reste dans le widget »). Un provider partagé les aurait affichés sur
/// chaque écran ouvert qui l'écoute — la fiche parcours sous la feuille de
/// parcours d'une étape —, et aurait survécu à l'écran fermé en plein
/// téléchargement.
///
/// **Un export à la fois** par écran : un second appui pendant un
/// téléchargement est ignoré, plutôt que d'empiler deux feuilles de partage.
mixin GpsExportRunner<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Object? _gpsError;
  String? _gpsSuccess;
  bool _gpsBusy = false;
  Object? _gpsBusyTag;

  /// Un export est en cours sur cet écran.
  bool get gpsExporting => _gpsBusy;

  /// Un export lancé avec [tag] est en cours — le bouton d'une carte parmi
  /// d'autres (`openGpsSheet(tag:)`).
  bool gpsExportingFor(Object? tag) => _gpsBusy && _gpsBusyTag == tag;

  /// Les services connectés de la personne, à lire dans `build()` pour la
  /// visibilité du bouton ([GpsExportTarget.offered]).
  List<GpsServiceConnectionDto> watchGpsServices() => ref.watch(
    authProvider.select((AuthState s) => s.user?.connectedServices ?? const []),
  );

  /// Ouvre la feuille GPS pour [target], puis exécute le choix, feuille
  /// refermée. [buttonContext] est celui du bouton « GPS » : l'ancre de la
  /// feuille de partage sur iPad.
  Future<void> openGpsSheet(
    GpsExportTarget target,
    BuildContext buttonContext, {
    Object? tag,
  }) async {
    if (_gpsBusy) return;
    final List<GpsServiceConnectionDto> services =
        ref.read(authProvider).user?.connectedServices ?? const [];
    final GpsChoice? choice = await showGpsSheet(
      context,
      subtitle: target.subtitle,
      services: target.canSendToDevice ? services : const [],
      offerConnect: services.isEmpty,
      gpx: target.gpx,
      fit: target.fit,
      syncStatuses: target.syncStatuses,
    );
    if (choice == null || !mounted) return;
    final RouteExportOperations ops = ref.read(routeExportOperationsProvider);
    switch (choice) {
      case GpsConnectDevice():
        // Pas `context.push` : les fiches (sortie, parcours, étape…) sont
        // plein écran, et y pousser une page de l'onglet Profil laissait un
        // écran vide (docs/LEDGER_*.md MOB-138, même cause que MOB-46).
        pushLocation(context, Paths.profileDevices());
      case GpsDeliverFile(
        :final AssetDto asset,
        :final AssetDestination destination,
      ):
        await _run(tag, () async {
          final bool saved = await ops.deliver(
            ref,
            asset,
            destination,
            origin: buttonContext.mounted
                ? shareOriginOf(buttonContext)
                : Rect.zero,
          );
          return saved ? 'media.saved'.tr() : null;
        });
      case GpsSendToService(:final GpsServiceConnectionDto service):
        await _run(tag, () async {
          final String? previewId = target.previewId;
          if (previewId != null) {
            await ops.uploadPreview(ref, service, previewId: previewId);
          } else {
            await ops.upload(
              ref,
              service,
              teamSlug: target.teamSlug!,
              routeSlug: target.routeSlug!,
            );
          }
          return 'routes.uploadSuccess'.tr();
        });
    }
  }

  Future<void> _run(Object? tag, Future<String?> Function() run) async {
    if (_gpsBusy) return;
    setState(() {
      _gpsBusy = true;
      _gpsBusyTag = tag;
      _gpsError = null;
      _gpsSuccess = null;
    });
    try {
      final String? success = await run();
      if (mounted) setState(() => _gpsSuccess = success);
    } catch (error) {
      if (mounted) setState(() => _gpsError = error);
    } finally {
      if (mounted) {
        setState(() {
          _gpsBusy = false;
          _gpsBusyTag = null;
        });
      }
    }
  }

  /// Les bandeaux d'échec et de réussite du dernier export. [gap] les sépare
  /// de ce qui suit, ou de ce qui précède avec [gapBefore] (bandeaux posés
  /// sous les boutons).
  List<Widget> gpsExportBanners({double gap = 10, bool gapBefore = false}) {
    Widget spaced(Widget banner) => gapBefore
        ? Padding(
            padding: EdgeInsets.only(top: gap),
            child: banner,
          )
        : Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: banner,
          );
    return <Widget>[
      if (_gpsError != null)
        spaced(
          PdlBanner(
            key: keys.gpsSheet.errorBanner,
            tone: PdlBannerTone.danger,
            message: getErrorMessage(_gpsError!),
            onDismiss: () => setState(() => _gpsError = null),
            dismissSemanticLabel: 'common.close'.tr(),
          ),
        ),
      if (_gpsSuccess != null)
        spaced(
          PdlBanner(
            key: keys.gpsSheet.successBanner,
            tone: PdlBannerTone.info,
            message: _gpsSuccess!,
            onDismiss: () => setState(() => _gpsSuccess = null),
            dismissSemanticLabel: 'common.close'.tr(),
          ),
        ),
    ];
  }
}
