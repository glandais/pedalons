import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

/// L'envoi d'un parcours vers un service GPS connecté.
///
/// Le geste vit dans la feuille GPS (`gps_sheet.dart`), exécuté par le
/// `GpsExportRunner` de l'écran (`gps_export_runner.dart`) ; le
/// téléchargement d'un GPX/FIT, lui, est celui de toute pièce jointe :
/// `deliverAsset` (`core/utils/share_file.dart`).
///
/// Lève en cas d'échec ; c'est au runner d'afficher son bandeau.
Future<void> uploadRouteToService(
  WidgetRef ref,
  GpsServiceConnectionDto service, {
  required String teamSlug,
  required String routeSlug,
}) {
  return ref
      .read(gpsServicesClientProvider)
      .uploadRoute(
        serviceType: GpsServiceType.fromJson(service.serviceType),
        teamSlug: teamSlug,
        routeSlug: routeSlug,
      );
}
