import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../domain/route_waypoints.dart';
import 'waypoint_selection.dart';
import 'waypoint_sheet.dart';

/// « Points du parcours » : la liste des points, triée le long du parcours, les
/// points hors tracé à la fin. Toucher une ligne centre la carte sur le point.
///
/// Rien quand le parcours n'en a pas. Au-delà de [foldAfter] lignes, la liste se
/// replie.
class RouteWaypointsSection extends ConsumerStatefulWidget {
  const RouteWaypointsSection({
    super.key,
    required this.waypoints,
    required this.selection,
    required this.onSelect,
  });

  /// Les points **dans l'ordre d'origine** : les clés s'y calculent, avant tout
  /// tri, et sont celles de la carte et du profil.
  final List<WaypointDto> waypoints;

  final WaypointSelectionController selection;

  /// Toucher d'une ligne.
  final void Function(String key, WaypointDto waypoint) onSelect;

  static const int foldAfter = 10;

  @override
  ConsumerState<RouteWaypointsSection> createState() =>
      _RouteWaypointsSectionState();
}

class _RouteWaypointsSectionState extends ConsumerState<RouteWaypointsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final List<WaypointDto> waypoints = widget.waypoints;
    if (waypoints.isEmpty) return const SizedBox.shrink();
    final UnitSystem units = ref.watch(unitSystemProvider);

    final List<int> order = sortedWaypointIndices(waypoints);
    final int shown = _expanded
        ? order.length
        : order.length.clamp(0, RouteWaypointsSection.foldAfter);
    final int hidden = order.length - shown;

    return Column(
      key: keys.routeWaypoints.section,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(
          title: 'routes.waypoints.title'.tr(),
          count: '${order.length}',
        ),
        ValueListenableBuilder<WaypointSelection?>(
          valueListenable: widget.selection,
          builder: (BuildContext context, WaypointSelection? selected, _) =>
              Column(
                children: <Widget>[
                  for (int n = 0; n < shown; n++)
                    _row(order[n], n == shown - 1, selected?.key, units),
                ],
              ),
        ),
        if (hidden > 0)
          PdlButton(
            label: 'routes.waypoints.showMore'.plural(hidden),
            variant: PdlButtonVariant.text,
            onPressed: () => setState(() => _expanded = true),
          )
        else if (_expanded && order.length > RouteWaypointsSection.foldAfter)
          PdlButton(
            label: 'routes.waypoints.showLess'.tr(),
            variant: PdlButtonVariant.text,
            onPressed: () => setState(() => _expanded = false),
          ),
      ],
    );
  }

  Widget _row(int index, bool last, String? selectedKey, UnitSystem units) {
    final WaypointDto w = widget.waypoints[index];
    final String key = waypointKey(w, index);
    final WaypointType type = waypointTypeOf(w.type);
    final String typeLabel = type.labelKey.tr();
    final bool named = w.name.isNotEmpty;
    final String where = waypointWhere(w, units);
    return PdlWaypointRow(
      key: keys.routeWaypoints.row(key),
      mark: waypointBadgeMarkOf(type, context.pdl),
      distanceLabel: w.distance == null
          ? 'routes.waypoints.offTrack'.tr()
          : AppFormatters.formatDistance(w.distance!, units),
      title: named ? w.name : typeLabel,
      subtitle: named ? typeLabel : null,
      description: w.description,
      semanticLabel: named
          ? 'routes.waypoints.rowLabel'.tr(
              namedArgs: <String, String>{
                'type': typeLabel,
                'name': w.name,
                'where': where,
              },
            )
          : 'routes.waypoints.rowLabelUnnamed'.tr(
              namedArgs: <String, String>{'type': typeLabel, 'where': where},
            ),
      selected: selectedKey == key,
      showDivider: !last,
      onTap: () => widget.onSelect(key, w),
    );
  }
}
