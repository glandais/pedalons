import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../auth/domain/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../calendar/providers/calendar_month_provider.dart';
import '../../home/providers/next_ride_provider.dart';
import '../../home/providers/week_events_provider.dart';
import '../../participants/providers/participant_list_provider.dart';
import '../../profile/providers/profile_summary_provider.dart';
import '../../teams/providers/team_dashboard_provider.dart';

/// **Le** point où l'app dit « une de mes participations vient de changer ».
///
/// Une inscription ne modifie pas qu'un écran : l'accueil (« Ma prochaine
/// sortie », « Cette semaine »), le profil (compteur et liste « Mes sorties
/// à venir ») et le calendrier (badge « Inscrit ») en sont tous des vues
/// dérivées, chacune dans son propre cache. Avant ce point, seul le détail de
/// la sortie était invalidé et ces vues restaient périmées jusqu'à un
/// pull-to-refresh — ou jusqu'au redémarrage pour le compteur du profil, qui
/// n'est jamais libéré.
///
/// Les contrôleurs d'inscription (sortie **et** voyage) l'appellent après
/// chaque appel réussi ; une nouvelle vue qui affiche une participation
/// s'ajoute **ici**, pas dans chaque contrôleur. Le détail de l'objet lui-même
/// (`rideDetailProvider`, `tripDetailProvider`) reste l'affaire du contrôleur,
/// qui en connaît la clé.
///
/// Invalider un provider que personne n'écoute ne coûte rien : il sera
/// simplement reconstruit à sa prochaine lecture. Seules les vues montées
/// refont un appel.
///
/// Les fils (`publicationFeedProvider`) portent aussi un badge « Inscrit »,
/// mais ce sont des listes paginées : les invalider remettrait le défilement à
/// zéro sous l'écran de détail. Ils lisent donc [registrationOverridesProvider],
/// que [publicationId] et [registered] renseignent : l'inscription que l'app
/// vient de faire, sur la publication qu'elle concerne. `registered` nul
/// oublie ce qu'on croyait savoir — le serveur a démenti la vue de l'app.
void notifyParticipationChanged(
  Ref ref, {
  String? publicationId,
  bool? registered,
}) {
  if (publicationId != null) {
    final StateController<Map<String, bool>> overrides = ref.read(
      registrationOverridesProvider.notifier,
    );
    overrides.state = <String, bool>{
      for (final MapEntry<String, bool> e in overrides.state.entries)
        if (e.key != publicationId) e.key: e.value,
      publicationId: ?registered,
    };
  }

  // Accueil.
  ref.invalidate(nextRideProvider);
  ref.invalidate(weekEventsProvider);

  // Profil : son résumé porte les compteurs de participations.
  ref.invalidate(profileSummaryProvider);

  // Calendrier : chaque événement porte `registered`.
  ref.invalidate(calendarMonthProvider);

  // Tableau de bord d'équipe : il reste monté sous la fiche de la sortie, donc
  // jamais libéré. « Vos prochaines sorties » est une liste que seul le serveur
  // sait remplir — une inscription doit y apparaître, une désinscription en
  // sortir —, d'où un rechargement plutôt que [registrationOverridesProvider].
  ref.invalidate(teamDashboardProvider);

  // Listes de participants : la page d'un groupe montre la sienne **à côté**
  // de sa barre d'inscription — rejoindre ou quitter doit m'y faire paraître
  // ou disparaître sans attendre (ledger `MOB-67`). Toute la famille : une
  // liste par source et par recherche, seules les montées rechargent.
  ref.invalidate(participantListProvider);
}

/// Ce que l'app sait de mes inscriptions **depuis** le chargement des listes,
/// par identifiant de sortie ou de voyage : la carte d'un fil le préfère au
/// `registered` de sa page, chargée avant le geste.
///
/// Propre à la session : il repart vide quand l'utilisateur change.
final registrationOverridesProvider = StateProvider<Map<String, bool>>((
  Ref ref,
) {
  ref.watch(authProvider.select((AuthState s) => s.user?.id));
  return const <String, bool>{};
});
