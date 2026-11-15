import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../ads/providers/ad_list_provider.dart';
import '../../ads/providers/ad_providers.dart';
import '../../calendar/providers/calendar_month_provider.dart';
import '../../comments/providers/comment_thread_provider.dart';
import '../../feed/providers/publication_feed_provider.dart';
import '../../home/providers/next_ride_provider.dart';
import '../../home/providers/week_events_provider.dart';
import '../../posts/providers/post_providers.dart';
import '../../profile/providers/profile_summary_provider.dart';
import '../../rides/providers/ride_detail_provider.dart';
import '../../routes/providers/route_count_provider.dart';
import '../../routes/providers/route_detail_provider.dart';
import '../../routes/providers/route_list_provider.dart';
import '../../teams/providers/team_dashboard_provider.dart';
import '../../trips/providers/trip_detail_provider.dart';
import '../data/moderation_repository.dart';
import 'team_reports_provider.dart';

/// Relit les listes d'où un signalement retire la cible.
///
/// Le serveur retire aussitôt ce qu'on a signalé **des listes** du signaleur ;
/// le détail, lui, reste lisible par lien. C'est donc aux listes encore montées
/// sous l'écran courant de se recharger, et à elles seules : un commentaire
/// signalé n'a aucune raison de faire recharger la parcothèque.
///
/// Prend le conteneur et non un `WidgetRef` : l'écran qui a ouvert le menu
/// peut être dépilé juste après, et son `ref` avec lui.
void refreshAfterReport(ProviderContainer container, ReportTargetType type) {
  switch (type) {
    case ReportTargetType.comment:
      container.invalidate(commentThreadProvider);
    case ReportTargetType.post:
      _invalidateFeed(container);
    case ReportTargetType.ride:
    case ReportTargetType.trip:
      _invalidateFeed(container);
      container.invalidate(calendarMonthProvider);
      container.invalidate(weekEventsProvider);
      container.invalidate(nextRideProvider);
    case ReportTargetType.ad:
      container.invalidate(adListProvider);
    case ReportTargetType.route:
      container.invalidate(routeListProvider);
      container.invalidate(routeCountProvider);
    // Un membre signalé ne disparaît d'aucune liste : seul son contenu le fait,
    // quand on le bloque.
    case ReportTargetType.member:
    case ReportTargetType.$unknown:
      break;
  }
}

/// Relit ce qu'une décision de modération vient de changer
/// (docs/LEDGER_*.md MOB-168) — et rien d'autre :
///
/// * la file de l'équipe, ses deux onglets : la cible quitte « À traiter » et
///   entre dans « Traités ». La file à l'écran garde ses cartes pendant sa
///   relecture ;
/// * le tableau de bord de l'équipe, dont « À traiter » compte les
///   signalements ouverts. Lui seul : ni la fiche, ni « Mes équipes », ni la
///   découverte ne dépendent d'un signalement ;
/// * le contenu concerné, quand il a changé pour ses lecteurs : supprimé, il
///   quitte ses listes et son détail ; rejeté alors que les signalements
///   l'avaient masqué ([ModerationItemDto.hidden]), il y revient.
///
/// Prend le conteneur : l'écran peut être quitté avant la réponse.
void refreshAfterModerationDecision(
  ProviderContainer container, {
  required String teamSlug,
  required ModerationItemDto item,
  required ModerationAction action,
}) {
  for (final ReportQueueStatus status in ReportQueueStatus.$valuesDefined) {
    container.invalidate(
      teamReportsProvider((teamSlug: teamSlug, status: status)),
    );
  }
  container.invalidate(teamDashboardProvider(teamSlug));

  final bool removed = action == ModerationAction.removeContent;
  if (!removed && !item.hidden) return;
  final ReportTargetType type = ReportTargetType.fromJson(item.targetType);
  refreshAfterReport(container, type);
  if (!removed) return;
  // Un détail déjà lu montrerait encore le contenu supprimé.
  switch (type) {
    case ReportTargetType.post:
      container.invalidate(postDetailProvider);
    case ReportTargetType.ride:
      container.invalidate(rideDetailProvider);
    case ReportTargetType.trip:
      container.invalidate(tripDetailProvider);
    case ReportTargetType.route:
      container.invalidate(routeDetailProvider);
    case ReportTargetType.ad:
      container.invalidate(adDetailProvider);
    // Un commentaire n'a pas de détail : son fil est relu par
    // [refreshAfterReport].
    case ReportTargetType.comment:
    case ReportTargetType.member:
    case ReportTargetType.$unknown:
      break;
  }
}

/// Relit ce qu'un blocage masque : commentaires, publications et annonces de
/// la personne bloquée — et la liste des bloqués elle-même.
///
/// Sorties, voyages et parcours ne changent pas : ce sont des objets
/// d'organisation, et un blocage ne les touche pas.
void refreshAfterBlockChange(ProviderContainer container) {
  container.invalidate(blockedUsersProvider);
  // Le compteur « personnes bloquées » de la vue d'ensemble du profil.
  container.invalidate(profileSummaryProvider);
  container.invalidate(commentThreadProvider);
  container.invalidate(adListProvider);
  _invalidateFeed(container);
}

void _invalidateFeed(ProviderContainer container) {
  container.invalidate(publicationFeedProvider);
  container.invalidate(publicationFeedCountProvider);
}
