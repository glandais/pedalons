import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../../core/pdl/pdl.dart';
import '../../../core/theme/pdl_icons.dart';

/// Les exports d'un parcours, partagés par la fiche parcours
/// (`RouteDownloadActions`) et par les cartes de groupe d'une sortie : les
/// mêmes gestes doivent se comporter de la même façon partout.
///
/// Les fonctions lèvent en cas d'échec ; c'est à l'appelant d'afficher son
/// bandeau. Le téléchargement d'un GPX/FIT, lui, est celui de toute pièce
/// jointe : `downloadAndShareAsset` (`core/utils/share_file.dart`).

/// Le choix de l'appareil passe par une `PdlSheet` : `PdlSheet.show` force
/// `useRootNavigator`, donc la feuille passe au-dessus de la barre d'onglets
/// (F-DE-8). `null` si le membre referme la feuille sans choisir.
Future<GpsServiceConnectionDto?> pickGpsService(
  BuildContext context,
  List<GpsServiceConnectionDto> services,
) {
  return PdlSheet.show<GpsServiceConnectionDto>(
    context: context,
    builder: (BuildContext sheetContext) => PdlSheet(
      title: 'routes.sendToDevice'.tr(),
      children: <Widget>[
        for (final GpsServiceConnectionDto s in services)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PdlSettingRow(
              title: s.displayName,
              icon: PdlIcons.device,
              onTap: () => Navigator.of(sheetContext).pop(s),
            ),
          ),
      ],
    ),
  );
}

/// Envoie le parcours [routeSlug] de [teamSlug] vers [service].
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
