import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import '../../../core/geo/polyline_index.dart';

/// Ce que la carte d'aperçu montre d'un tracé dessiné : `done.stats` du
/// planificateur embarqué (docs/LEDGER_*.md MOB-170).
@immutable
class PlannerStats {
  const PlannerStats({
    required this.distance,
    required this.ascend,
    required this.pointCount,
    required this.line,
  });

  /// Mètres.
  final double distance;

  /// Mètres de dénivelé positif.
  final double ascend;

  /// Points de contrôle posés.
  final int pointCount;

  /// Le tracé, décodé de la polyligne de précision 6 (latitude d'abord) que
  /// la page envoie.
  final List<LngLat> line;
}

/// Le résultat de « Terminer » dans le planificateur : le fragment de requête
/// que calcule **la règle du site** (`plannerSubmit.ts`, jamais réécrite ici),
/// et de quoi dessiner l'aperçu.
///
/// Au plus un de [plannerState], [points] et [file] est posé ; aucun veut dire
/// « n'envoie pas de tracé » (un parcours existant laissé tel quel). [waypoints]
/// n'est là que si les points du parcours ont été touchés.
@immutable
class PlannerResult {
  const PlannerResult({
    required this.stats,
    this.plannerState,
    this.points,
    this.file = false,
    this.fileId,
    this.waypoints,
    this.dirty = false,
    this.nameSuggestion,
    this.tooLarge = false,
  });

  /// Lit le message `done` de la page. Lève (`TypeError`, `FormatException`)
  /// sur un message qui n'a pas la forme du contrat : l'appelant le journalise
  /// et garde le résultat précédent.
  factory PlannerResult.fromMessage(Map<String, dynamic> message) {
    final Map<String, dynamic> payload =
        (message['payload'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final Map<String, dynamic> stats =
        (message['stats'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final Object? state = payload['plannerState'];
    final Object? points = payload['points'];
    final Object? waypoints = payload['waypoints'];
    final String? name = (message['nameSuggestion'] as String?)?.trim();
    return PlannerResult(
      plannerState: state is Map<String, dynamic>
          ? PlannerState.fromJson(state)
          : null,
      // L'état gagne : jamais les deux (400 PLANNER_STATE_INVALID).
      points: state == null && points is List
          ? <GeoPoint>[
              for (final Object? p in points)
                GeoPoint.fromJson(p! as Map<String, dynamic>),
            ]
          : null,
      file: payload['file'] == true,
      fileId: payload['fileId'] as String?,
      waypoints: waypoints is List
          ? <WaypointRequest>[
              for (final Object? w in waypoints)
                WaypointRequest.fromJson(w! as Map<String, dynamic>),
            ]
          : null,
      stats: PlannerStats(
        distance: (stats['distance'] as num?)?.toDouble() ?? 0,
        ascend: (stats['ascend'] as num?)?.toDouble() ?? 0,
        pointCount: (stats['pointCount'] as num?)?.toInt() ?? 0,
        line: decodePolyline6(stats['line'] as String? ?? ''),
      ),
      dirty: message['dirty'] == true,
      nameSuggestion: name == null || name.isEmpty ? null : name,
      tooLarge: message['notice'] == 'tooLarge',
    );
  }

  final PlannerStats stats;
  final PlannerState? plannerState;
  final List<GeoPoint>? points;

  /// Le parcours est, intact, un fichier que l'app a choisi : c'est ce
  /// fichier qui part, en `gpxFile`.
  final bool file;

  /// Lequel des fichiers gardés par le pont ; nul, le dernier choisi.
  final String? fileId;
  final List<WaypointRequest>? waypoints;

  /// Quelque chose a changé depuis l'ouverture du planificateur.
  final bool dirty;

  /// Le nom du dernier fichier importé, pour un champ de nom encore vide.
  final String? nameSuggestion;

  /// L'état dépassait ses bornes : les points partent, et le tracé enregistré
  /// perd ses points de contrôle — à dire une fois l'enregistrement réussi.
  final bool tooLarge;

  /// Le résultat porte un tracé à envoyer.
  bool get hasTrack => plannerState != null || points != null || file;

  /// Rien à envoyer du tout : ni tracé, ni points du parcours.
  bool get isEmpty => !hasTrack && waypoints == null;
}

/// Décode une polyligne encodée de précision 6, latitude puis longitude
/// (`encode2` du site). Une chaîne tronquée rend les points lus jusque-là.
List<LngLat> decodePolyline6(String encoded) {
  final List<LngLat> out = <LngLat>[];
  int index = 0;
  int lat = 0;
  int lng = 0;

  int? next() {
    int result = 0;
    int shift = 0;
    while (index < encoded.length) {
      final int byte = encoded.codeUnitAt(index++) - 63;
      if (byte < 0) return null;
      result |= (byte & 0x1f) << shift;
      shift += 5;
      if (byte < 0x20) {
        return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      }
    }
    return null;
  }

  while (index < encoded.length) {
    final int? dLat = next();
    final int? dLng = next();
    if (dLat == null || dLng == null) break;
    lat += dLat;
    lng += dLng;
    out.add(LngLat(lng / 1e6, lat / 1e6));
  }
  return out;
}
