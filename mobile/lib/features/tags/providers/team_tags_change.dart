import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../ads/providers/ad_list_provider.dart';
import '../../ads/providers/ad_providers.dart';
import '../../feed/providers/publication_feed_provider.dart';
import '../../posts/providers/post_providers.dart';
import '../../rides/providers/ride_detail_provider.dart';
import '../../rides/providers/ride_template_providers.dart';
import '../../routes/providers/route_count_provider.dart';
import '../../routes/providers/route_detail_provider.dart';
import '../../routes/providers/route_list_provider.dart';
import '../../teams/providers/team_dashboard_provider.dart';
import '../../trips/providers/trip_detail_provider.dart';
import 'team_tags_provider.dart';

/// Ce qui vient d'arriver à un tag de [TeamTagChange.teamSlug].
enum TeamTagChangeKind { created, updated, deleted }

/// Un tag créé, renommé ou recoloré, ou supprimé — ce que
/// [notifyTeamTagsChanged] annonce.
@immutable
class TeamTagChange {
  const TeamTagChange.created(this.teamSlug, this.type)
    : kind = TeamTagChangeKind.created;

  const TeamTagChange.updated(this.teamSlug, this.type)
    : kind = TeamTagChangeKind.updated;

  const TeamTagChange.deleted(this.teamSlug, this.type)
    : kind = TeamTagChangeKind.deleted;

  final String teamSlug;

  /// Le type de contenu du tag — il ne change jamais.
  final TagTarget type;
  final TeamTagChangeKind kind;
}

/// **Le** point où l'app dit « le vocabulaire de tags d'une équipe vient de
/// changer » (docs/LEDGER_*.md MOB-169) — le pendant de `invalidateTeamTags`
/// du site.
///
/// Sont relus, pour l'équipe et le type du tag seulement :
///
/// * le vocabulaire entier que lit l'écran d'administration
///   ([teamAllTagsProvider]) — ses lignes restent à l'écran pendant la
///   relecture, l'écran ne repart pas d'un chargement ;
/// * le vocabulaire du type, que lisent les filtres et les éditeurs
///   ([teamTagsProvider]) ;
/// * après un renommage, une nouvelle couleur ou une suppression, **les
///   contenus de ce type déjà lus** : leurs cartes et leurs fiches montrent le
///   tag (une carte garderait sinon un tag supprimé, et un éditeur ouvert
///   depuis ce cache en renverrait l'id, que le serveur refuse —
///   `TAG_INVALID`), et les comptes de liste qu'un filtre par tag restreint.
///   Un tag **créé** n'est porté par aucun contenu : rien d'autre à relire.
///
/// Prend le **conteneur**, comme `notifyTeamChanged` : l'écriture est une
/// requête, et l'écran qui l'a lancée peut être quitté avant sa réponse.
void notifyTeamTagsChanged(ProviderContainer container, TeamTagChange change) {
  container.invalidate(teamAllTagsProvider(change.teamSlug));
  container.invalidate(
    teamTagsProvider((teamSlug: change.teamSlug, type: change.type)),
  );
  if (change.kind == TeamTagChangeKind.created) return;

  container.invalidate(teamDashboardProvider(change.teamSlug));
  switch (change.type) {
    case TagTarget.ride:
      _invalidateFeed(container);
      container.invalidate(rideDetailProvider);
      // Un modèle de sortie porte des tags de sortie.
      container.invalidate(rideTemplateListProvider);
      container.invalidate(rideTemplateDetailProvider);
    case TagTarget.post:
      _invalidateFeed(container);
      container.invalidate(postDetailProvider);
    case TagTarget.trip:
      _invalidateFeed(container);
      container.invalidate(tripDetailProvider);
    case TagTarget.route:
      container.invalidate(routeListProvider);
      container.invalidate(routeCountProvider);
      container.invalidate(routeDetailProvider);
    case TagTarget.ad:
      container.invalidate(adListProvider);
      container.invalidate(adCountProvider);
      container.invalidate(adDetailProvider);
      container.invalidate(adEditProvider);
    case TagTarget.$unknown:
      break;
  }
}

void _invalidateFeed(ProviderContainer container) {
  container.invalidate(publicationFeedProvider);
  container.invalidate(publicationFeedCountProvider);
}
