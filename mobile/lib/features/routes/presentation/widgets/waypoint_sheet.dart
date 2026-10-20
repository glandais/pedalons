import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../domain/route_waypoints.dart';
import 'waypoint_selection.dart';

/// « À 12,3 km du départ », ou « Hors tracé ».
String waypointWhere(WaypointDto w, UnitSystem units) => w.distance == null
    ? 'routes.waypoints.offTrack'.tr()
    : 'routes.waypoints.fromStart'.tr(
        namedArgs: <String, String>{
          'distance': AppFormatters.formatDistance(w.distance!, units),
        },
      );

/// Ouvre la fiche d'un point. Le point reste allumé sur la carte et le profil
/// **tant que la feuille est ouverte**. [PdlSheet.show] est le seul appelant
/// autorisé de `showModalBottomSheet`.
Future<void> openWaypoint(
  BuildContext context,
  WaypointDto waypoint,
  WaypointSelectionController selection,
  String key, {
  required UnitSystem units,
  PdlWaypointMove move = PdlWaypointMove.none,
}) async {
  selection.select(key, move: move);
  final int? serial = selection.value?.serial;
  await PdlSheet.show<void>(
    context: context,
    builder: (BuildContext context) =>
        WaypointDetails(waypoint: waypoint, units: units),
  );
  if (serial != null) selection.clearIf(serial);
}

/// Le contenu de la fiche : pictogramme, type, nom, description, distance.
class WaypointDetails extends StatelessWidget {
  const WaypointDetails({
    super.key,
    required this.waypoint,
    required this.units,
  });

  final WaypointDto waypoint;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final WaypointType type = waypointTypeOf(waypoint.type);
    final String typeLabel = type.labelKey.tr();
    final bool named = waypoint.name.isNotEmpty;
    final String? description = waypoint.description;

    return PdlSheet(
      key: keys.routeWaypoints.sheet,
      header: Row(
        children: <Widget>[
          PdlWaypointBadge(mark: waypointBadgeMarkOf(type, c)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (named)
                  Text(typeLabel, style: t.xs.copyWith(color: c.textDimmed)),
                Text(named ? waypoint.name : typeLabel, style: t.sectionTitle),
              ],
            ),
          ),
        ],
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (description != null && description.isNotEmpty) ...<Widget>[
                Text(description, softWrap: true, style: t.body),
                const SizedBox(height: 12),
              ],
              Text(
                waypointWhere(waypoint, units),
                style: t.mono.copyWith(color: c.textDimmed),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
