import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepository(ref.watch(ridesClientProvider));
});

class RideRepository {
  final RidesClient _ridesClient;

  RideRepository(this._ridesClient);

  /// Le détail d'une sortie, groupes peuplés.
  ///
  /// C'est la **seule** source de `groups[]` : une ligne de liste renvoie
  /// `List.of()` côté serveur (`RideDto.fromListItem`), donc rien ne se dérive
  /// d'un item de fil.
  Future<RideDto> getRide(String teamSlug, String rideSlug) {
    return _ridesClient.getRide(teamSlug: teamSlug, rideSlug: rideSlug);
  }

  /// La météo d'une sortie : au départ, puis le long du parcours de chaque
  /// groupe.
  ///
  /// Toujours 200 dès que la sortie est lisible : l'état est dans
  /// `RideWeatherDto.status`, et un 404 signifie que la sortie ne l'est pas.
  /// Le serveur ne lit que son cache, jamais le fournisseur : l'appel est
  /// donc bon marché, et le recharger ne « force » aucune prévision.
  Future<RideWeatherDto> getRideWeather(String teamSlug, String rideSlug) {
    return _ridesClient.getRideWeather(teamSlug: teamSlug, rideSlug: rideSlug);
  }

  /// Rejoindre un groupe.
  Future<RideParticipationDto> joinGroup(
    String teamSlug,
    String rideSlug,
    String groupId,
  ) {
    return _ridesClient.joinGroup(
      teamSlug: teamSlug,
      rideSlug: rideSlug,
      groupId: groupId,
    );
  }

  /// Quitter un groupe. Un **seul** appel : `registeredGroupId` désigne le
  /// groupe à quitter, il n'y a jamais à boucler sur `groups[]`.
  Future<void> leaveGroup(String teamSlug, String rideSlug, String groupId) {
    return _ridesClient.leaveGroup(
      teamSlug: teamSlug,
      rideSlug: rideSlug,
      groupId: groupId,
    );
  }

  // --- Organisateur (docs/LEDGER_*.md MOB-76) ---------------------------
  //
  // Les droits sont ceux du serveur (`RideAccessChecker`) : organisateur ou
  // administrateur de l'équipe, modules sorties **et** parcours actifs. Le
  // client les lit par `canManageRides` (`domain/ride_permissions.dart`)
  // pour ne pas montrer un bouton qui finirait en 403.

  /// Crée une sortie. Les dates de [request] sont des heures murales du
  /// fuseau de la sortie (`RideForm.toRequest`).
  Future<RideDto> createRide(String teamSlug, RideRequest request) {
    return _ridesClient.createRide(teamSlug: teamSlug, body: request);
  }

  /// Réécrit une sortie. Le serveur applique **tous** les champs du PUT,
  /// absents compris : `leaderId`, `startPlaceId`, `endPlaceId` et les groupes
  /// doivent donc y figurer tels qu'ils sont, sinon ils sont effacés.
  Future<RideDto> updateRide(
    String teamSlug,
    String rideSlug,
    RideRequest request,
  ) {
    return _ridesClient.updateRide(
      teamSlug: teamSlug,
      rideSlug: rideSlug,
      body: request,
    );
  }

  /// Publier, dépublier, annuler ou rétablir : le `PATCH /status`, qui ne
  /// touche à rien d'autre — pas même aux tags, qu'un PUT recopié depuis un
  /// détail périmé pourrait renvoyer supprimés (`TAG_INVALID`).
  Future<RideDto> changeStatus(
    String teamSlug,
    String rideSlug,
    Status status,
  ) {
    return _ridesClient.changeRideStatus(
      teamSlug: teamSlug,
      rideSlug: rideSlug,
      body: StatusChangeRequest(status: status.toJson()),
    );
  }

  /// Change l'adresse (le slug) d'une sortie. Les liens vers l'ancienne ne
  /// mènent plus nulle part : l'écran repart de la nouvelle.
  Future<RideDto> changeSlug(String teamSlug, String rideSlug, String slug) {
    return _ridesClient.changeRideSlug(
      teamSlug: teamSlug,
      rideSlug: rideSlug,
      body: SlugChangeRequest(slug: slug),
    );
  }

  /// Suppression **douce** : la sortie reste lisible par les organisateurs,
  /// marquée `deleted`, et [undeleteRide] la ramène.
  Future<void> deleteRide(String teamSlug, String rideSlug) {
    return _ridesClient.deleteRide(teamSlug: teamSlug, rideSlug: rideSlug);
  }

  Future<RideDto> undeleteRide(String teamSlug, String rideSlug) {
    return _ridesClient.undeleteRide(teamSlug: teamSlug, rideSlug: rideSlug);
  }
}
