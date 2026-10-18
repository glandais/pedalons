import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../teams/providers/team_providers.dart';
import '../data/ride_editor_repository.dart';
import '../domain/ride_permissions.dart';

/// L'utilisateur peut-il gérer [teamSlug] selon [rule] ? `null` tant que
/// « Mes équipes » n'est pas chargé et qu'il n'est pas admin de plateforme :
/// l'écran n'affiche alors ni bouton ni refus.
///
/// Partagé par les sorties ([canManageRidesProvider]) et les parcours
/// (`canManageRoutesProvider`, ledger `MOB-79`) : seule la règle change.
/// L'admin de plateforme qui n'est pas membre n'a pas l'équipe dans « Mes
/// équipes » : il passe alors, et les modules se relisent sur l'équipe elle-
/// même, à l'écran.
bool? teamManagePermission(
  Ref ref,
  String teamSlug,
  bool Function(
    TeamDetailDto team, {
    required TeamRole? teamRole,
    required bool platformAdmin,
  })
  rule,
) {
  final bool platformAdmin = ref.watch(
    authProvider.select(
      (AuthState s) => s.user?.platformRole == 'PLATFORM_ADMIN',
    ),
  );
  final List<TeamDetailDto>? teams = ref.watch(myTeamsProvider).value;
  final TeamDetailDto? team = teams
      ?.where((TeamDetailDto t) => t.slug == teamSlug)
      .firstOrNull;
  if (team != null) {
    return rule(
      team,
      teamRole: ref.watch(teamRoleProvider(teamSlug)),
      platformAdmin: platformAdmin,
    );
  }
  if (platformAdmin) return true;
  return teams == null ? null : false;
}

/// L'utilisateur peut-il gérer les sorties de [teamSlug] ? `null` tant que
/// « Mes équipes » n'est pas chargé et qu'il n'est pas admin de plateforme :
/// l'écran n'affiche alors ni bouton ni refus (docs/LEDGER_*.md MOB-76).
///
/// La règle est celle du serveur ([canManageTeamRides]) : organisateur ou
/// administrateur, modules sorties **et** parcours actifs.
final canManageRidesProvider = Provider.family<bool?, String>(
  (Ref ref, String teamSlug) =>
      teamManagePermission(ref, teamSlug, canManageTeamRides),
);

typedef TeamItemKey = ({String teamSlug, String id});

/// Un lieu de l'équipe, pour nommer celui qu'un formulaire a choisi et lire
/// son point (le fuseau de la sortie).
final editorPlaceProvider = FutureProvider.autoDispose
    .family<PlaceDetailDto, TeamItemKey>(
      (Ref ref, TeamItemKey key) => ref
          .watch(rideEditorRepositoryProvider)
          .getPlace(key.teamSlug, key.id),
    );

/// Un parcours avec son départ — le résumé du parcours de la sortie, et le
/// second candidat au fuseau.
final editorRouteProvider = FutureProvider.autoDispose
    .family<RouteDetailDto, TeamItemKey>(
      (Ref ref, TeamItemKey key) => ref
          .watch(rideEditorRepositoryProvider)
          .getRoute(key.teamSlug, key.id),
    );

/// Les parcours des groupes, d'un seul appel et sans géométrie. La clé est
/// la liste **triée et dédoublonnée** jointe par des virgules, pour que deux
/// groupes sur le même parcours ou un réordonnancement ne relancent rien.
final editorGroupRoutesProvider = FutureProvider.autoDispose
    .family<Map<String, RouteDetailDto>, ({String teamSlug, String slugs})>((
      Ref ref,
      ({String teamSlug, String slugs}) key,
    ) async {
      if (key.slugs.isEmpty) return const <String, RouteDetailDto>{};
      final List<RouteDetailDto> routes = await ref
          .watch(rideEditorRepositoryProvider)
          .routesBulk(key.teamSlug, key.slugs.split(','));
      return <String, RouteDetailDto>{
        for (final RouteDetailDto r in routes) r.slug: r,
      };
    });

/// La clé de [editorGroupRoutesProvider] pour ces slugs.
String groupRoutesKey(Iterable<String?> slugs) {
  final List<String> sorted = <String>{
    for (final String? s in slugs)
      if (s != null && s.isNotEmpty) s,
  }.toList()..sort();
  return sorted.join(',');
}

/// Le fuseau d'un point, arrondi au millième de degré : à ~100 m près, le
/// fuseau est le même, et la clé ne change pas pour un lieu redéplacé de peu.
final editorTimezoneProvider = FutureProvider.autoDispose
    .family<String, ({String teamSlug, double lat, double lon})>(
      (Ref ref, ({String teamSlug, double lat, double lon}) key) => ref
          .watch(rideEditorRepositoryProvider)
          .timezoneAt(key.teamSlug, key.lat, key.lon),
    );

({String teamSlug, double lat, double lon}) timezoneKey(
  String teamSlug,
  GeoJsonPoint point,
) {
  double round(double v) => (v * 1000).roundToDouble() / 1000;
  // GeoJSON : [longitude, latitude].
  return (
    teamSlug: teamSlug,
    lat: round(point.coordinates[1]),
    lon: round(point.coordinates[0]),
  );
}
