import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';

/// Les trois portées de la découverte d'équipes.
///
/// Elles sont alimentables depuis 1.5.0 : `joinable` (nouveau) porte la
/// deuxième, `minRole=MEMBER` la troisième. Avant, la chip aurait été un
/// réglage sans effet.
enum TeamDiscoveryScope {
  /// Toutes les équipes visibles sur ce domaine.
  all,

  /// Celles qui acceptent une demande d'adhésion.
  joinable,

  /// Celles dont on est déjà membre.
  mine,
}

/// L'ordre d'une liste d'équipes **selon sa portée** (règle RL5 des listes,
/// KIT §10) : « Mes équipes » par le nom, de A à Z — un carnet d'adresses —,
/// toutes les équipes par nombre de membres, les plus peuplées d'abord — une
/// découverte (`sortBy=MEMBER_COUNT`, `docs/LEDGER_*.md API-13`). Le serveur
/// départage les ex æquo par identifiant.
///
/// **Une seule source** pour la requête (`TeamRepository.fetchTeams`) et pour
/// la mention « triées par … » de l'écran : l'écran n'annonce un tri que parce
/// que c'est celui qu'il demande.
TeamSortBy teamSortFor(TeamDiscoveryScope scope) =>
    scope == TeamDiscoveryScope.mine ? TeamSortBy.name : TeamSortBy.memberCount;

/// Le sens de [sort] : A à Z pour le nom, décroissant pour le nombre.
SortDirection teamSortDirection(TeamSortBy sort) =>
    sort == TeamSortBy.name ? SortDirection.asc : SortDirection.desc;

/// Ce qui identifie un jeu de résultats de la découverte.
@immutable
class TeamDiscoveryFilters {
  const TeamDiscoveryFilters({
    this.scope = TeamDiscoveryScope.all,
    this.search,
  });

  final TeamDiscoveryScope scope;
  final String? search;

  /// L'ordre demandé, celui que l'écran annonce.
  TeamSortBy get sortBy => teamSortFor(scope);

  bool get isFiltered =>
      (search?.trim().isNotEmpty ?? false) || scope != TeamDiscoveryScope.all;

  TeamDiscoveryFilters get cleared => const TeamDiscoveryFilters();

  TeamDiscoveryFilters copyWith({
    TeamDiscoveryScope? scope,
    String? search,
    bool clearSearch = false,
  }) => TeamDiscoveryFilters(
    scope: scope ?? this.scope,
    search: clearSearch ? null : (search ?? this.search),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeamDiscoveryFilters &&
          other.scope == scope &&
          other.search == search;

  @override
  int get hashCode => Object.hash(scope, search);
}
