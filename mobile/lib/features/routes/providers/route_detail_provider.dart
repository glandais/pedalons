import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../data/route_repository.dart';
import '../domain/track_key.dart';

export '../domain/track_key.dart';

/// Le détail d'un parcours pour sa fiche.
///
/// **C'est la seule source de la fiche**, tracé *et* profil altimétrique : les
/// coordonnées renvoyées portent `[lon, lat, alt, distance cumulée]`, donc tout
/// ce qu'il faut pour dessiner les deux. Il n'y a plus de second appel à un
/// endpoint de profil, et plus de réconciliation entre deux résolutions
/// différentes — le curseur et l'axe des distances viennent du même tableau.
final routeDetailProvider = FutureProvider.family<RouteDetailDto, RouteKey>((
  Ref ref,
  RouteKey key,
) {
  return ref
      .watch(routeRepositoryProvider)
      .getRouteDetail(key.teamSlug, key.routeSlug);
});

/// Où ce parcours est employé : sorties, publications, étapes de voyage.
///
/// `GET …/usages` **existe depuis longtemps et n'avait jamais été appelé** par
/// le mobile. C'est cet écran qui l'active.
///
/// `autoDispose` : la liste n'a de sens que sur la fiche ouverte.
final routeUsagesProvider =
    FutureProvider.family<List<RouteUsageDto>, RouteKey>((
      Ref ref,
      RouteKey key,
    ) async {
      final RouteUsagesResponse response = await ref
          .watch(routesClientProvider)
          .getRouteUsages(teamSlug: key.teamSlug, routeSlug: key.routeSlug);
      return response.usages;
    }, isAutoDispose: true);

/// Les montées d'un parcours, **toutes pistes confondues, dans l'ordre**.
///
/// Le serveur concatène les pistes pour calculer le profil ; le client doit
/// concaténer dans le **même ordre**, sans quoi les distances des montées ne
/// coïncideraient pas avec l'axe du profil ni avec `PolylineIndex`.
extension RouteClimbs on RouteDetailDto {
  List<ClimbDto> get allClimbs => <ClimbDto>[
    for (final TrackDto t in tracks) ...t.climbs,
  ];

  bool get hasGeometry =>
      tracks.any((TrackDto t) => t.line.coordinates.isNotEmpty);
}
