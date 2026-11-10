import 'package:easy_localization/easy_localization.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/utils/formatters.dart';
import '../../../routes/presentation/gps_export_runner.dart';
import '../../domain/group_title.dart';

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
