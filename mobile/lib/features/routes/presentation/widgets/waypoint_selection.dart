import 'package:flutter/foundation.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../domain/route_waypoints.dart';

/// Le point choisi, et d'où : la carte, le profil ou la liste (ledger `MOB-84`).
@immutable
class WaypointSelection {
  const WaypointSelection({
    required this.key,
    required this.move,
    required this.serial,
  });

  final String key;

  /// Ce que la caméra en fait.
  final PdlWaypointMove move;

  /// Change à chaque choix : choisir deux fois le même point recentre deux fois.
  final int serial;

  PdlWaypointFocus get focus =>
      PdlWaypointFocus(key: key, move: move, serial: serial);

  @override
  bool operator ==(Object other) =>
      other is WaypointSelection &&
      other.key == key &&
      other.move == move &&
      other.serial == serial;

  @override
  int get hashCode => Object.hash(key, move, serial);
}

/// Le point choisi, partagé entre la carte, le profil et la liste.
///
/// Comme `RouteCursorController`, c'est un notifieur possédé par un `State`,
/// pas un provider : la carte écoute sans reconstruire l'écran.
class WaypointSelectionController extends ValueNotifier<WaypointSelection?> {
  WaypointSelectionController() : super(null);

  int _serial = 0;
  bool _disposed = false;

  void select(String key, {PdlWaypointMove move = PdlWaypointMove.none}) {
    if (_disposed) return;
    value = WaypointSelection(key: key, move: move, serial: ++_serial);
  }

  /// Éteint la sélection si c'est encore celle de [serial] : la fermeture d'une
  /// feuille ne doit pas effacer un choix fait entre-temps.
  void clearIf(int serial) {
    if (_disposed) return;
    if (value?.serial == serial) value = null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

PdlWaypointMark waypointMarkOf(WaypointType type) => PdlWaypointMark(
  glyph: type.glyph,
  disc: type.markerDisc,
  onDisc: type.markerGlyph,
);

/// Le pictogramme de la liste et de la feuille : l'aplat du thème
/// (`type.tone`), là où la carte garde le disque clair des deux thèmes.
PdlWaypointMark waypointBadgeMarkOf(WaypointType type, PdlColors c) {
  final PdlTone tone = type.tone(c);
  return PdlWaypointMark(
    glyph: type.glyph,
    disc: tone.fill,
    onDisc: tone.onFill,
  );
}

/// Les points à poser sur la carte : tous ceux qui ont une position, **hors
/// tracé compris**. Les clés viennent de la liste d'origine, avant tout tri.
List<PdlMapWaypoint> mapWaypointsOf(List<WaypointDto> waypoints) =>
    <PdlMapWaypoint>[
      for (int i = 0; i < waypoints.length; i++)
        if (waypointHasPosition(waypoints[i]))
          () {
            final WaypointDto w = waypoints[i];
            final WaypointType type = waypointTypeOf(w.type);
            return PdlMapWaypoint(
              key: waypointKey(w, i),
              lon: w.geometry.coordinates[0],
              lat: w.geometry.coordinates[1],
              iconId: type.json!,
              mark: waypointMarkOf(type),
              label: w.name.isEmpty ? null : w.name,
              priority: type.priority,
            );
          }(),
    ];

/// Les repères du profil : seulement les points **sur le tracé** (avec une
/// distance). Un point hors tracé n'y figure jamais.
List<PdlProfileMarker> profileMarkersOf(List<WaypointDto> waypoints) =>
    <PdlProfileMarker>[
      for (int i = 0; i < waypoints.length; i++)
        if (waypoints[i].distance != null)
          () {
            final WaypointDto w = waypoints[i];
            final WaypointType type = waypointTypeOf(w.type);
            return PdlProfileMarker(
              key: waypointKey(w, i),
              distance: w.distance!,
              mark: waypointMarkOf(type),
              priority: type.priority,
            );
          }(),
    ];

/// Le point de [waypoints] qui porte [key].
WaypointDto? waypointByKey(List<WaypointDto> waypoints, String key) {
  for (int i = 0; i < waypoints.length; i++) {
    if (waypointKey(waypoints[i], i) == key) return waypoints[i];
  }
  return null;
}
