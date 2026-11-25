import 'package:flutter/widgets.dart';

class _TeamsPageKey extends ValueKey<String> {
  const _TeamsPageKey(String value) : super('teamsPage_$value');
}

class TeamsPageKeys {
  final discoverButton = const _TeamsPageKey('discoverButton');

  /// « Créer une équipe », dans la barre (ledger `MOB-165`).
  final createButton = const _TeamsPageKey('createButton');

  /// « Créer une équipe », dans l'état vide de qui n'a aucune équipe.
  final emptyCreateButton = const _TeamsPageKey('emptyCreateButton');

  /// La recherche de « Mes équipes », toujours visible (règle RL6).
  final searchField = const _TeamsPageKey('searchField');

  /// La carte d'une équipe de « Mes équipes ».
  ValueKey<String> teamCard(String teamSlug) =>
      _TeamsPageKey('teamCard_$teamSlug');

  /// « Équipe uniquement » sur la carte d'une équipe privée (règle R1).
  ValueKey<String> teamCardVisibility(String teamSlug) =>
      _TeamsPageKey('teamCardVisibility_$teamSlug');

  /// Le rôle de la personne sur la carte d'une équipe (règle R12).
  ValueKey<String> teamCardRole(String teamSlug) =>
      _TeamsPageKey('teamCardRole_$teamSlug');

  /// « Vous avez des invitations en attente », en tête de la liste.
  final pendingInvitationsCard = const _TeamsPageKey('pendingInvitations');

  /// « Accepter », sur la ligne de l'invitation à [teamSlug].
  ValueKey<String> invitationAcceptButton(String teamSlug) =>
      _TeamsPageKey('invitationAccept_$teamSlug');

  /// L'état d'erreur de la liste.
  final loadError = const _TeamsPageKey('loadError');

  /// « 5 équipes · triées par nom », sous la barre (règles RL5 et RL8).
  final resultCount = const _TeamsPageKey('resultCount');
}

class _TeamsDiscoverKey extends ValueKey<String> {
  const _TeamsDiscoverKey(String value) : super('teamsDiscover_$value');
}

class TeamsDiscoverKeys {
  final searchField = const _TeamsDiscoverKey('searchField');

  ValueKey<String> card(String teamSlug) => _TeamsDiscoverKey('card_$teamSlug');

  /// « Équipe uniquement » sur la carte d'une équipe privée (règle R1).
  ValueKey<String> cardVisibility(String teamSlug) =>
      _TeamsDiscoverKey('cardVisibility_$teamSlug');

  /// Le rôle réel de la personne sur la carte d'une équipe dont elle est
  /// membre (« Organisateur »…), à la place d'un « Membre » générique (règle
  /// R12).
  ValueKey<String> cardRole(String teamSlug) =>
      _TeamsDiscoverKey('cardRole_$teamSlug');
}

class _TeamPageKey extends ValueKey<String> {
  const _TeamPageKey(String value) : super('teamPage_$value');
}

class TeamPageKeys {
  final loadError = const _TeamPageKey('loadError');

  /// « Gérer l'équipe », dans la barre de l'en-tête — organisateurs
  /// seulement (ledger `MOB-165`).
  final manageButton = const _TeamPageKey('manageButton');

  /// « Réessayer » de l'état d'erreur.
  final loadErrorRetryButton = const _TeamPageKey('loadErrorRetryButton');

  /// Avatar et nom de l'en-tête : un tap ouvre « Mes équipes », ou mène au
  /// tableau de bord quand il n'y a pas d'autre équipe où aller.
  final headerIdentity = const _TeamPageKey('headerIdentity');

  /// La feuille « Mes équipes » ouverte depuis l'en-tête.
  final switcherSheet = const _TeamPageKey('switcherSheet');

  /// Une équipe de la feuille « Mes équipes », par son slug.
  ValueKey<String> switcherRow(String teamSlug) =>
      _TeamPageKey('switcherRow_$teamSlug');

  /// « Toutes les équipes », au pied de la feuille.
  final switcherAllTeams = const _TeamPageKey('switcherAllTeams');

  final joinButton = const _TeamPageKey('joinButton');
  final leaveButton = const _TeamPageKey('leaveButton');
  final inviteOnlyButton = const _TeamPageKey('inviteOnlyButton');
  final leaveConfirmButton = const _TeamPageKey('leaveConfirmButton');

  /// La ligne d'une page libre, dans la section « À propos ».
  ValueKey<String> aboutPageRow(String pageSlug) =>
      _TeamPageKey('aboutPageRow_$pageSlug');

  /// Le badge d'une page libre dans « À propos » (docs/LEDGER_*.md WEB-120).
  ValueKey<String> aboutPageBadge(String pageSlug) =>
      _TeamPageKey('aboutPageBadge_$pageSlug');

  /// L'écran d'une page libre : son titre, son corps.
  final customPageTitle = const _TeamPageKey('customPageTitle');
  final customPageBody = const _TeamPageKey('customPageBody');

  /// La ligne d'un membre dans la section « Membres », par l'identifiant de
  /// l'utilisateur.
  ValueKey<String> memberRow(String userId) =>
      _TeamPageKey('memberRow_$userId');

  /// Le `⋯` en bout de ligne d'un membre : Signaler, Bloquer (règle R13).
  ValueKey<String> memberMore(String userId) =>
      _TeamPageKey('memberMore_$userId');

  /// La recherche de la section « Membres ».
  final membersSearchField = const _TeamPageKey('membersSearchField');

  /// « Gérer les membres », au-dessus de la liste, pour qui administre.
  final membersManageButton = const _TeamPageKey('membersManageButton');

  /// « Liste des membres non partagée » : le serveur a refusé la liste (403).
  final membersForbiddenState = const _TeamPageKey('membersForbiddenState');

  /// Le rôle de la personne sous le nom de l'équipe, dans son en-tête.
  final headerRole = const _TeamPageKey('headerRole');

  /// « Aucun membre pour ces filtres » (règle RL10).
  final membersFilteredEmptyState = const _TeamPageKey(
    'membersFilteredEmptyState',
  );
}

class _TeamDashboardKey extends ValueKey<String> {
  const _TeamDashboardKey(String value) : super('teamDashboard_$value');
}

/// Le tableau de bord d'une équipe : une clé par section, pour qu'un test dise
/// ce qu'un rôle voit sans dépendre d'un libellé.
class TeamDashboardKeys {
  final summary = const _TeamDashboardKey('summary');

  /// « Premières étapes », sa croix, et chacune de ses étapes (`invite`,
  /// `ride`, `route`) — docs/LEDGER_*.md WEB-195.
  final firstSteps = const _TeamDashboardKey('firstSteps');
  final firstStepsDismiss = const _TeamDashboardKey('firstStepsDismiss');
  ValueKey<String> firstStep(String step) =>
      _TeamDashboardKey('firstStep_$step');
  final createRideButton = const _TeamDashboardKey('createRideButton');
  final newPostButton = const _TeamDashboardKey('newPostButton');
  final createTripButton = const _TeamDashboardKey('createTripButton');
  final createRouteButton = const _TeamDashboardKey('createRouteButton');

  /// « Générer un parcours » dans la feuille « Créer » (docs/LEDGER_*.md MOB-154).
  final createGeneratedRouteButton = const _TeamDashboardKey(
    'createGeneratedRouteButton',
  );

  /// Le bouton de tête, quelle que soit l'action qu'il porte ; les lignes de
  /// la feuille ont la clé de leur action.
  final createPrimaryButton = const _TeamDashboardKey('createPrimaryButton');
  final createMenuButton = const _TeamDashboardKey('createMenuButton');
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

  /// « 24 / 25 membres » quand l'équipe a une limite, sinon « 24 membres ».
  final memberCount = const _TeamDashboardKey('memberCount');

  /// Le pourquoi d'une invitation désactivée, à la limite de l'offre gratuite.
  final memberLimitReached = const _TeamDashboardKey('memberLimitReached');

  /// « Inviter » et « Gérer les membres » du bloc Administration : l'écran
  /// des membres de l'app (ledger `MOB-167`).
  final inviteButton = const _TeamDashboardKey('inviteButton');
  final manageMembersButton = const _TeamDashboardKey('manageMembersButton');

  /// La carte d'une sortie à venir, par son slug.
  ValueKey<String> rideCard(String rideSlug) =>
      _TeamDashboardKey('rideCard_$rideSlug');

  /// « Modifier », sur la carte d'une sortie à venir.
  ValueKey<String> rideEditButton(String rideSlug) =>
      _TeamDashboardKey('rideEdit_$rideSlug');

  /// « Complet » désactivé, à la place de « S'inscrire », sur la carte d'une
  /// sortie à venir dont tous les groupes sont pleins.
  ValueKey<String> rideFullButton(String rideSlug) =>
      _TeamDashboardKey('rideFull_$rideSlug');

  /// L'heure « départ 09:00 » d'une ligne de groupe de la carte d'une sortie
  /// à venir.
  ValueKey<String> groupFillDeparture(String groupId) =>
      _TeamDashboardKey('groupFillDeparture_$groupId');

  /// La ligne d'un modèle de « Créer depuis un modèle », par son slug.
  ValueKey<String> templateRow(String slug) =>
      _TeamDashboardKey('templateRow_$slug');

  /// La ligne d'une de « Vos prochaines sorties », par son slug.
  ValueKey<String> myUpcomingRow(String slug) =>
      _TeamDashboardKey('myUpcoming_$slug');

  /// La ligne de départ d'une de « Vos prochaines sorties », par son slug
  /// (ledger `BRAND-8`).
  ValueKey<String> myUpcomingDeparture(String slug) =>
      _TeamDashboardKey('myUpcomingDeparture_$slug');

  /// « Groupe B · Place de la Mairie » sous ce départ (règle R11).
  ValueKey<String> myUpcomingGroupPlace(String slug) =>
      _TeamDashboardKey('myUpcomingGroupPlace_$slug');

  /// Le bouton « GPS » d'une ligne de « Vos prochaines sorties ».
  ValueKey<String> myUpcomingGps(String slug) =>
      _TeamDashboardKey('myUpcomingGps_$slug');
}

class _TeamAgendaKey extends ValueKey<String> {
  const _TeamAgendaKey(String value) : super('teamAgenda_$value');
}

/// L'Agenda d'une équipe (ledger `MOB-60`) : sa période et sa vue.
class TeamAgendaKeys {
  /// Un segment de la vue — `cards`, `rows`, `calendar`.
  ValueKey<String> view(String name) => _TeamAgendaKey('view_$name');

  /// « Créer » dans la barre (règle RL13).
  final createButton = const _TeamAgendaKey('create');

  /// « Créer une sortie » dans l'état vide simple.
  final emptyCreateButton = const _TeamAgendaKey('emptyCreate');
}

class _TeamAdminKey extends ValueKey<String> {
  const _TeamAdminKey(String value) : super('teamAdmin_$value');
}

/// Le hub « Gestion de l'équipe » (ledger `MOB-165`).
class TeamAdminKeys {
  final loadError = const _TeamAdminKey('loadError');

  /// Le refus rendu à qui n'organise pas l'équipe, et son bouton « Retour ».
  final forbidden = const _TeamAdminKey('forbidden');
  final forbiddenBack = const _TeamAdminKey('forbiddenBack');

  // Les lignes, dans l'ordre des onglets du site.
  final rideTemplates = const _TeamAdminKey('rideTemplates');
  final places = const _TeamAdminKey('places');
  final tags = const _TeamAdminKey('tags');
  final pages = const _TeamAdminKey('pages');
  final members = const _TeamAdminKey('members');
  final reports = const _TeamAdminKey('reports');
  final settings = const _TeamAdminKey('settings');
}

class _TeamPagesKey extends ValueKey<String> {
  const _TeamPagesKey(String value) : super('teamPages_$value');
}

/// « Pages de l'équipe » : la liste des pages personnalisées, dans la gestion
/// de l'équipe (ledger `MOB-169`).
class TeamPagesAdminKeys {
  final loadError = const _TeamPagesKey('loadError');

  /// Le refus rendu à qui n'administre pas l'équipe, et son « Retour ».
  final forbidden = const _TeamPagesKey('forbidden');
  final forbiddenBack = const _TeamPagesKey('forbiddenBack');

  /// Ce que le serveur a refusé à une écriture.
  final errorBanner = const _TeamPagesKey('errorBanner');

  /// « n pages sur 3 maximum ».
  final count = const _TeamPagesKey('count');

  /// « Créer une page », en tête de liste (absent à trois pages) et dans
  /// l'état vide.
  final addButton = const _TeamPagesKey('addButton');
  final emptyAddButton = const _TeamPagesKey('emptyAddButton');

  final empty = const _TeamPagesKey('empty');
  final listError = const _TeamPagesKey('listError');

  /// La ligne d'une page, par son id : titre, visibilité, « Supprimé », et
  /// ses gestes.
  ValueKey<String> row(String pageId) => _TeamPagesKey('row_$pageId');
  ValueKey<String> rowTitle(String pageId) => _TeamPagesKey('rowTitle_$pageId');
  ValueKey<String> rowVisibility(String pageId) =>
      _TeamPagesKey('rowVisibility_$pageId');
  ValueKey<String> rowDeleted(String pageId) =>
      _TeamPagesKey('rowDeleted_$pageId');
  ValueKey<String> rowMoveUp(String pageId) =>
      _TeamPagesKey('rowMoveUp_$pageId');
  ValueKey<String> rowMoveDown(String pageId) =>
      _TeamPagesKey('rowMoveDown_$pageId');
  ValueKey<String> rowEdit(String pageId) => _TeamPagesKey('rowEdit_$pageId');
  ValueKey<String> rowDelete(String pageId) =>
      _TeamPagesKey('rowDelete_$pageId');
  ValueKey<String> rowRestore(String pageId) =>
      _TeamPagesKey('rowRestore_$pageId');

  /// Pourquoi « Restaurer » est inactif : l'équipe a déjà ses trois pages.
  ValueKey<String> rowRestoreHint(String pageId) =>
      _TeamPagesKey('rowRestoreHint_$pageId');
}

class _TeamPageEditorKey extends ValueKey<String> {
  const _TeamPageEditorKey(String value) : super('teamPageEditor_$value');
}

/// L'éditeur d'une page personnalisée de l'équipe (ledger `MOB-169`).
class TeamPageEditorKeys {
  final loadError = const _TeamPageEditorKey('loadError');

  /// Le refus rendu à qui n'administre pas l'équipe, ou ne peut pas modifier
  /// cette page, et son « Retour ».
  final forbidden = const _TeamPageEditorKey('forbidden');
  final forbiddenBack = const _TeamPageEditorKey('forbiddenBack');

  final errorBanner = const _TeamPageEditorKey('errorBanner');
  final titleField = const _TeamPageEditorKey('titleField');

  /// La ligne d'adresse (modification seulement), et sa feuille.
  final slugRow = const _TeamPageEditorKey('slugRow');
  final slugField = const _TeamPageEditorKey('slugField');
  final slugSave = const _TeamPageEditorKey('slugSave');

  final markdownField = const _TeamPageEditorKey('markdownField');
  final visibility = const _TeamPageEditorKey('visibility');
  final visibilityHint = const _TeamPageEditorKey('visibilityHint');
  final saveButton = const _TeamPageEditorKey('saveButton');
}

class _TeamEditorKey extends ValueKey<String> {
  const _TeamEditorKey(String value) : super('teamEditor_$value');
}

/// Le formulaire d'équipe : création (ledger `MOB-165`), puis paramètres
/// (ledger `MOB-166`).
class TeamEditorKeys {
  final errorBanner = const _TeamEditorKey('errorBanner');
  final nameField = const _TeamEditorKey('nameField');
  final markdownField = const _TeamEditorKey('markdownField');
  final locationRow = const _TeamEditorKey('locationRow');
  final locationClear = const _TeamEditorKey('locationClear');
  final timezoneRow = const _TeamEditorKey('timezoneRow');
  final enableRoutes = const _TeamEditorKey('enableRoutes');
  final enableRides = const _TeamEditorKey('enableRides');
  final enableTrips = const _TeamEditorKey('enableTrips');
  final enablePosts = const _TeamEditorKey('enablePosts');
  final enableAds = const _TeamEditorKey('enableAds');
  final enableMemberDirectory = const _TeamEditorKey('enableMemberDirectory');
  final postsAsTeamByDefault = const _TeamEditorKey('postsAsTeamByDefault');
  final saveButton = const _TeamEditorKey('saveButton');

  // ── Paramètres (ledger `MOB-166`) ──

  /// La fiche de l'équipe n'a pas pu être lue.
  final loadError = const _TeamEditorKey('loadError');

  /// Le refus rendu à qui n'administre pas l'équipe, et son « Retour ».
  final forbidden = const _TeamEditorKey('forbidden');
  final forbiddenBack = const _TeamEditorKey('forbiddenBack');

  /// L'adresse (slug) : sa ligne, puis le champ et le bouton de sa feuille.
  final slugRow = const _TeamEditorKey('slugRow');
  final slugField = const _TeamEditorKey('slugField');
  final slugSave = const _TeamEditorKey('slugSave');

  /// La visibilité : sa ligne, son badge quand elle ne se modifie pas, et
  /// les choix de sa feuille (`TEAM`, `PUBLIC_UNLISTED`, `PUBLIC`).
  final visibilityRow = const _TeamEditorKey('visibilityRow');
  final visibilityBadge = const _TeamEditorKey('visibilityBadge');
  ValueKey<String> visibilityOption(String visibility) =>
      _TeamEditorKey('visibilityOption_$visibility');

  /// La feuille « Changer le fuseau horaire » : ce qu'elle annonce, son
  /// échec, et ses boutons.
  final timezoneChangeSheet = const _TeamEditorKey('timezoneChangeSheet');
  final timezoneChangeUpcoming = const _TeamEditorKey('timezoneChangeUpcoming');
  final timezoneChangeError = const _TeamEditorKey('timezoneChangeError');
  final timezoneChangeRetry = const _TeamEditorKey('timezoneChangeRetry');
  final timezoneChangeConfirm = const _TeamEditorKey('timezoneChangeConfirm');

  final webhookRow = const _TeamEditorKey('webhookRow');

  /// « Supprimer l'équipe », dans la zone de danger.
  final deleteButton = const _TeamEditorKey('deleteButton');
}

class _TeamWebhookKey extends ValueKey<String> {
  const _TeamWebhookKey(String value) : super('teamWebhook_$value');
}

/// La feuille du webhook d'une équipe (ledger `MOB-166`).
class TeamWebhookKeys {
  final sheet = const _TeamWebhookKey('sheet');

  /// « Fermer », dans l'en-tête de la feuille.
  final closeButton = const _TeamWebhookKey('closeButton');
  final loadError = const _TeamWebhookKey('loadError');

  /// L'adresse actuelle, **masquée** — jamais l'URL entière.
  final maskedUrl = const _TeamWebhookKey('maskedUrl');
  final urlField = const _TeamWebhookKey('urlField');

  /// Un segment de la langue — `fr`, `en`.
  ValueKey<String> language(String code) => _TeamWebhookKey('language_$code');
  final enabledSwitch = const _TeamWebhookKey('enabledSwitch');

  /// Le dernier envoi : son statut.
  final lastStatus = const _TeamWebhookKey('lastStatus');

  /// Ce que le serveur a refusé, ou ce qui n'a pas pu être lu.
  final errorBanner = const _TeamWebhookKey('errorBanner');

  /// « Webhook enregistré », « Webhook supprimé ».
  final noticeBanner = const _TeamWebhookKey('noticeBanner');

  /// Le résultat du message de test, avec son code HTTP.
  final testResult = const _TeamWebhookKey('testResult');

  final saveButton = const _TeamWebhookKey('saveButton');
  final testButton = const _TeamWebhookKey('testButton');
  final removeButton = const _TeamWebhookKey('removeButton');
}

class _TeamAdminMembersKey extends ValueKey<String> {
  const _TeamAdminMembersKey(String value) : super('teamAdminMembers_$value');
}

/// « Membres » : la liste, les invitations en attente et la
/// feuille d'invitation (ledger `MOB-167`).
class TeamAdminMembersKeys {
  final loadError = const _TeamAdminMembersKey('loadError');

  /// Le refus rendu à qui n'administre pas l'équipe, et son « Retour ».
  final forbidden = const _TeamAdminMembersKey('forbidden');
  final forbiddenBack = const _TeamAdminMembersKey('forbiddenBack');

  /// « 24 / 25 membres », quand l'équipe a un plafond.
  final counter = const _TeamAdminMembersKey('counter');

  /// « Inviter par e-mail ».
  final inviteButton = const _TeamAdminMembersKey('inviteButton');

  /// L'équipe est pleine : la notice de l'offre gratuite, et son lien de
  /// contact.
  final fullNotice = const _TeamAdminMembersKey('fullNotice');
  final contactLink = const _TeamAdminMembersKey('contactLink');

  /// Ce que le serveur a refusé (`LAST_ADMIN`…).
  final errorBanner = const _TeamAdminMembersKey('errorBanner');

  final searchField = const _TeamAdminMembersKey('searchField');

  /// Une puce de rôle — `all`, `MEMBER`, `ORGANIZER`, `ADMIN`.
  ValueKey<String> roleChip(String role) =>
      _TeamAdminMembersKey('roleChip_$role');

  final resultCount = const _TeamAdminMembersKey('resultCount');
  final empty = const _TeamAdminMembersKey('empty');
  final filteredEmpty = const _TeamAdminMembersKey('filteredEmpty');

  /// La ligne d'un membre, par l'identifiant de la **personne**, son badge de
  /// rôle et son `⋯`.
  ValueKey<String> row(String userId) => _TeamAdminMembersKey('row_$userId');
  ValueKey<String> rowRole(String userId) =>
      _TeamAdminMembersKey('rowRole_$userId');
  ValueKey<String> rowMore(String userId) =>
      _TeamAdminMembersKey('rowMore_$userId');

  /// Les deux entrées de la feuille d'une ligne, avant Signaler / Bloquer.
  final changeRoleAction = const _TeamAdminMembersKey('changeRoleAction');
  final removeAction = const _TeamAdminMembersKey('removeAction');

  /// Un choix de la feuille de rôle — `ADMIN`, `ORGANIZER`, `MEMBER`.
  ValueKey<String> roleOption(String role) =>
      _TeamAdminMembersKey('roleOption_$role');

  // ── Invitations en attente ──
  final pendingSection = const _TeamAdminMembersKey('pendingSection');
  ValueKey<String> invitation(String id) =>
      _TeamAdminMembersKey('invitation_$id');
  ValueKey<String> invitationResend(String id) =>
      _TeamAdminMembersKey('invitationResend_$id');
  ValueKey<String> invitationRevoke(String id) =>
      _TeamAdminMembersKey('invitationRevoke_$id');

  // ── Feuille d'invitation ──
  final inviteSheet = const _TeamAdminMembersKey('inviteSheet');
  final inviteEmailField = const _TeamAdminMembersKey('inviteEmailField');
  ValueKey<String> inviteRole(String role) =>
      _TeamAdminMembersKey('inviteRole_$role');
  final inviteErrorBanner = const _TeamAdminMembersKey('inviteErrorBanner');
  final inviteSubmit = const _TeamAdminMembersKey('inviteSubmit');
}
