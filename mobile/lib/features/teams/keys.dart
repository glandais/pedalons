import 'package:flutter/widgets.dart';

class _TeamsPageKey extends ValueKey<String> {
  const _TeamsPageKey(String value) : super('teamsPage_$value');
}

class TeamsPageKeys {
  final discoverButton = const _TeamsPageKey('discoverButton');

  /// La carte d'une équipe de « Mes équipes ».
  ValueKey<String> teamCard(String teamSlug) =>
      _TeamsPageKey('teamCard_$teamSlug');

  /// « Vous avez des invitations en attente », en tête de la liste.
  final pendingInvitationsCard = const _TeamsPageKey('pendingInvitations');

  /// « Accepter », sur la ligne de l'invitation à [teamSlug].
  ValueKey<String> invitationAcceptButton(String teamSlug) =>
      _TeamsPageKey('invitationAccept_$teamSlug');
}

class _TeamsDiscoverKey extends ValueKey<String> {
  const _TeamsDiscoverKey(String value) : super('teamsDiscover_$value');
}

class TeamsDiscoverKeys {
  final searchField = const _TeamsDiscoverKey('searchField');

  ValueKey<String> card(String teamSlug) => _TeamsDiscoverKey('card_$teamSlug');
}

class _TeamPageKey extends ValueKey<String> {
  const _TeamPageKey(String value) : super('teamPage_$value');
}

class TeamPageKeys {
  final loadError = const _TeamPageKey('loadError');

  /// « Réessayer » de l'état d'erreur.
  final loadErrorRetryButton = const _TeamPageKey('loadErrorRetryButton');

  final joinButton = const _TeamPageKey('joinButton');
  final leaveButton = const _TeamPageKey('leaveButton');
  final inviteOnlyButton = const _TeamPageKey('inviteOnlyButton');
  final leaveConfirmButton = const _TeamPageKey('leaveConfirmButton');

  /// La ligne d'une page libre, dans la section « À propos ».
  ValueKey<String> aboutPageRow(String pageSlug) =>
      _TeamPageKey('aboutPageRow_$pageSlug');

  /// L'écran d'une page libre : son titre, son corps.
  final customPageTitle = const _TeamPageKey('customPageTitle');
  final customPageBody = const _TeamPageKey('customPageBody');

  /// La ligne d'un membre dans la section « Membres », par l'identifiant de
  /// l'utilisateur.
  ValueKey<String> memberRow(String userId) =>
      _TeamPageKey('memberRow_$userId');

  /// La recherche de la section « Membres ».
  final membersSearchField = const _TeamPageKey('membersSearchField');
}

class _TeamDashboardKey extends ValueKey<String> {
  const _TeamDashboardKey(String value) : super('teamDashboard_$value');
}

/// Le tableau de bord d'une équipe : une clé par section, pour qu'un test dise
/// ce qu'un rôle voit sans dépendre d'un libellé.
class TeamDashboardKeys {
  final summary = const _TeamDashboardKey('summary');
  final createRideButton = const _TeamDashboardKey('createRideButton');
  final newPostButton = const _TeamDashboardKey('newPostButton');
  final loadError = const _TeamDashboardKey('loadError');

  final todo = const _TeamDashboardKey('todo');
  final todoDrafts = const _TeamDashboardKey('todoDrafts');
  final todoWithoutRoute = const _TeamDashboardKey('todoWithoutRoute');
  final todoFullGroup = const _TeamDashboardKey('todoFullGroup');
  final todoReports = const _TeamDashboardKey('todoReports');

  final myUpcoming = const _TeamDashboardKey('myUpcoming');
  final upcomingRides = const _TeamDashboardKey('upcomingRides');
  final latestPosts = const _TeamDashboardKey('latestPosts');
  final newRoutes = const _TeamDashboardKey('newRoutes');
  final latestAds = const _TeamDashboardKey('latestAds');
  final templates = const _TeamDashboardKey('templates');

  /// « Gérer les modèles » de la section « Créer depuis un modèle » (ledger
  /// `MOB-78`).
  final templatesManageButton = const _TeamDashboardKey(
    'templatesManageButton',
  );
  final admin = const _TeamDashboardKey('admin');

  /// La carte d'une sortie à venir, par son slug.
  ValueKey<String> rideCard(String rideSlug) =>
      _TeamDashboardKey('rideCard_$rideSlug');

  /// « Modifier », sur la carte d'une sortie à venir.
  ValueKey<String> rideEditButton(String rideSlug) =>
      _TeamDashboardKey('rideEdit_$rideSlug');

  /// La ligne d'un modèle de « Créer depuis un modèle », par son slug.
  ValueKey<String> templateRow(String slug) =>
      _TeamDashboardKey('templateRow_$slug');

  /// La ligne d'une de « Vos prochaines sorties », par son slug.
  ValueKey<String> myUpcomingRow(String slug) =>
      _TeamDashboardKey('myUpcoming_$slug');
}

class _TeamAgendaKey extends ValueKey<String> {
  const _TeamAgendaKey(String value) : super('teamAgenda_$value');
}

/// L'Agenda d'une équipe (ledger `MOB-60`) : sa période et sa vue.
class TeamAgendaKeys {
  /// Un segment de la période — `upcoming`, `participating`, `past`.
  ValueKey<String> scope(String name) => _TeamAgendaKey('scope_$name');

  /// Un segment de la vue — `list`, `calendar`.
  ValueKey<String> view(String name) => _TeamAgendaKey('view_$name');

  /// « Voir les passées », dans l'état vide.
  final seePastButton = const _TeamAgendaKey('seePast');
}
