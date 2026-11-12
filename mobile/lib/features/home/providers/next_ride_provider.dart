import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../rides/providers/ride_detail_provider.dart' show RideTiming;
import '../../teams/domain/publication_timing.dart';

/// Ma prochaine participation, avec le groupe que j'ai rejoint.
@immutable
class NextRide {
  const NextRide({required this.ride, required this.group});

  final RideDto ride;

  /// Le groupe rejoint, tel que la ligne de liste le porte
  /// (`registeredGroup`). `null` s'il manque — la carte se replie alors sur
  /// les informations de la sortie plutôt que d'inventer un horaire.
  final RideGroupDto? group;
}

/// « Ma prochaine sortie », détail du groupe compris.
///
/// **Un seul appel** : `GET /api/users/me/participations` — l'endpoint qui rend
/// ce bloc possible (sans lui, il faudrait parcourir toutes les équipes et
/// toutes leurs sorties pour retrouver celle où l'on est inscrit). La plus
/// proche qui n'est pas terminée — en cours comprise ; `view: COMPACT` : la ligne compacte porte
/// tout ce que la carte rend.
///
/// La ligne de liste n'a pas de `groups[]`, mais elle porte le **groupe
/// rejoint en entier**, `registeredGroup` (`docs/LEDGER_*.md API-4`) : nom,
/// horaire, parcours et vignette, places, aperçu des inscrits. Le `getRide`
/// qui ne servait qu'à le retrouver a disparu ; ne pas le réintroduire. Taper
/// « Voir la sortie » charge le détail, comme depuis n'importe quelle carte.
///
/// L'identité de la sortie n'est **pas** mise en cache à part : invalider
/// [nextRideProvider] suffit à tout reprendre ; c'est ce que fait
/// `notifyParticipationChanged`.
///
/// Un échec **masque le bloc** sans propager d'erreur : l'accueil est
/// consultable sans lui, et le brief refuse qu'un enrichissement casse un
/// écran.
final nextRideProvider = FutureProvider<NextRide?>((Ref ref) async {
  final DateTime now = DateTime.now().toUtc();
  final PublicationListResponse response = await ref
      .watch(usersClientProvider)
      .listMyParticipations(
        // `from` filtre sur le **départ** : une sortie partie depuis une heure
        // en sortait, et avec elle « Se désinscrire » et « GPS », qui restent
        // offerts jusqu'à la fin de la sortie (règles R6 et R7, KIT §9). On
        // remonte d'une journée et on écarte ce qui est terminé.
        from: now.subtract(kNextRideLookBack).toIso8601String(),
        status: Status.published,
        size: kNextRidePageSize,
        view: ListViewMode.compact,
      );

  for (final PublicationDto publication in response.publications) {
    // Les voyages remontent aussi dans les participations ; ce bloc-ci parle
    // de sorties. « Cette semaine » montre les deux.
    if (publication is PublicationDtoRide) {
      final RideDto ride = rideFromListRow(publication);
      // Terminée — arrivée estimée passée (`endDateTime`, le serveur) : la
      // suivante, s'il y en a une dans la page.
      if (ridePhase(ride, now: now) == PublicationPhase.finished) continue;
      return NextRide(ride: ride, group: ride.joinedGroup);
    }
  }
  return null;
});

/// Jusqu'où « Ma prochaine sortie » remonte pour garder une sortie en cours.
const Duration kNextRideLookBack = Duration(days: 1);

/// Les lignes lues pour trouver la première sortie pas encore terminée : les
/// sorties terminées de la dernière journée passent devant elle.
const int kNextRidePageSize = 5;

/// Reconstruit un `RideDto` depuis une ligne de fil, champ pour champ.
///
/// `groups` reste vide (une ligne de liste n'en porte pas) : le groupe rejoint
/// est dans `registeredGroup`.
@visibleForTesting
RideDto rideFromListRow(PublicationDtoRide p) => RideDto(
  permissions: p.permissions,
  tags: p.tags,
  type: 'RIDE',
  team: p.team,
  id: p.id,
  slug: p.slug,
  name: p.name,
  media: p.media,
  dateTime: p.dateTime,
  timezone: p.timezone,
  endDateTime: p.endDateTime,
  status: p.status,
  finished: p.finished,
  visibility: p.visibility,
  participantCount: p.participantCount,
  groupCount: p.groupCount,
  groups: p.groups,
  groupSummaries: p.groupSummaries,
  distance: p.distance,
  elevationGain: p.elevationGain,
  surfaceType: p.surfaceType,
  topParticipants: p.topParticipants,
  deleted: p.deleted,
  registered: p.registered,
  full: p.full,
  excerpt: p.excerpt,
  publishAt: p.publishAt,
  createdAt: p.createdAt,
  routeSlug: p.routeSlug,
  startPlace: p.startPlace,
  endPlace: p.endPlace,
  thumbnailLightUrl: p.thumbnailLightUrl,
  thumbnailDarkUrl: p.thumbnailDarkUrl,
  thumbnailUrl: p.thumbnailUrl,
  registeredGroupId: p.registeredGroupId,
  registeredGroup: p.registeredGroup,
  maxParticipants: p.maxParticipants,
  commentCount: p.commentCount,
  weather: p.weather,
);
