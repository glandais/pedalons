import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';

/// Le parcours que roule un groupe : le sien, à défaut celui de la sortie.
///
/// C'est la même règle que le bouton « Voir le parcours » et que le web
/// (`group.routeSlug || ride.routeSlug`).
String? effectiveRouteSlug(RideDto ride, RideGroupDto group) =>
    group.routeSlug ?? ride.routeSlug;

/// Une couche de la carte d'une sortie : **un parcours**, jamais un groupe.
@immutable
class RideRouteLayer {
  const RideRouteLayer({
    required this.routeSlug,
    required this.colorIndex,
    required this.groupIds,
    required this.groupNames,
  });

  final String routeSlug;

  /// L'indice de la couleur dans `kMultiTrackPalette` — l'ordre d'apparition
  /// du parcours, pas le `sortOrder` d'un groupe.
  final int colorIndex;

  /// Les groupes qui roulent ce parcours, dans l'ordre des groupes. Vide pour
  /// le parcours de la sortie quand aucun groupe ne le roule.
  final List<String> groupIds;
  final List<String> groupNames;

  /// Le nom de la couche : ses groupes joints par « · », à défaut
  /// [mainRouteLabel] (le parcours principal de la sortie, que personne ne
  /// roule).
  String label(String mainRouteLabel) =>
      groupNames.isEmpty ? mainRouteLabel : groupNames.join(' · ');
}

/// Les couches de la carte d'une sortie : **une par parcours distinct**.
///
/// Celui de la sortie d'abord quand elle en a un, puis ceux des groupes dans
/// leur ordre — l'ordre du web (`rideMapRoutes`), qui numérote les couleurs :
/// une sortie doit montrer les mêmes teintes sur les deux clients. Plusieurs
/// groupes sur un même parcours partagent une couche, donc une couleur.
List<RideRouteLayer> rideRouteLayers(RideDto ride) {
  final Map<String, List<RideGroupDto>> bySlug = <String, List<RideGroupDto>>{};
  final String? main = ride.routeSlug;
  if (main != null) bySlug[main] = <RideGroupDto>[];
  for (final RideGroupDto group in ride.groups) {
    final String? slug = effectiveRouteSlug(ride, group);
    if (slug == null) continue;
    (bySlug[slug] ??= <RideGroupDto>[]).add(group);
  }
  return <RideRouteLayer>[
    for (final (int i, MapEntry<String, List<RideGroupDto>> e)
        in bySlug.entries.indexed)
      RideRouteLayer(
        routeSlug: e.key,
        colorIndex: i,
        groupIds: <String>[for (final RideGroupDto g in e.value) g.id],
        groupNames: <String>[for (final RideGroupDto g in e.value) g.name],
      ),
  ];
}

/// L'indice de couleur du parcours d'un groupe — celui de sa couche. Le
/// `sortOrder` en repli pour un groupe sans aucun parcours, qui n'a pas de
/// trace à rappeler.
int groupTrackColorIndex(RideDto ride, RideGroupDto group) {
  final String? slug = effectiveRouteSlug(ride, group);
  if (slug == null) return group.sortOrder;
  for (final RideRouteLayer layer in rideRouteLayers(ride)) {
    if (layer.routeSlug == slug) return layer.colorIndex;
  }
  return group.sortOrder;
}

/// Le groupe à sélectionner quand on touche le parcours [routeSlug] : le
/// groupe [current] s'il le roule déjà, sinon le premier qui le roule, sinon
/// `null` (le parcours principal, que personne ne roule).
String? groupForRoute(RideDto ride, String routeSlug, {String? current}) {
  String? first;
  for (final RideGroupDto g in ride.groups) {
    if (effectiveRouteSlug(ride, g) != routeSlug) continue;
    if (g.id == current) return g.id;
    first ??= g.id;
  }
  return first;
}
