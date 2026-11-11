import 'module.dart';
import 'navigation.dart';

/// Finding a team, and joining or leaving it from its header.
final class Teams extends Module {
  Teams(super.$);

  late final _navigation = Navigation($);

  /// Teams tab → « Découvrir » → search for [name] → the team's card.
  Future<void> openFromDiscovery({
    required String slug,
    required String name,
  }) async {
    await _navigation.goToTeams();
    await $(keys.teams.discoverButton).tap();
    await $(keys.teamsDiscover.searchField).enterText(name);
    await $(keys.teamsDiscover.card(slug)).tap();
    await waitUntilTeamIsShown();
  }

  /// Searches discovery for [name] and tells whether [slug]'s card came up.
  Future<bool> discoveryFinds({
    required String slug,
    required String name,
  }) async {
    await _navigation.goToTeams();
    await $(keys.teams.discoverButton).tap();
    await $(keys.teamsDiscover.searchField).enterText(name);
    // The search is debounced, then answered by the API.
    await $.pump(const Duration(seconds: 2));
    await $.pumpAndTrySettle();
    return isShown(keys.teamsDiscover.card(slug));
  }

  /// The team's header, with its membership action, whichever it is.
  Future<void> waitUntilTeamIsShown() async {
    await waitUntilAnyIsShown([
      keys.team.joinButton,
      keys.team.leaveButton,
      keys.team.inviteOnlyButton,
    ]);
  }

  Future<void> join() async {
    await $(keys.team.joinButton).tap();
    await $(keys.team.leaveButton).waitUntilVisible();
  }

  Future<void> leave() async {
    await $(keys.team.leaveButton).tap();
    await $(keys.team.leaveConfirmButton).tap();
    await $(keys.team.joinButton).waitUntilVisible();
  }

  bool get offersJoin => isShown(keys.team.joinButton);

  bool get offersLeave => isShown(keys.team.leaveButton);

  bool get saysInviteOnly => isShown(keys.team.inviteOnlyButton);

  /// Taps « Sur invitation », a disabled button: nothing may happen.
  Future<void> tapInviteOnly() async {
    await $(keys.team.inviteOnlyButton).tap();
    await $.pump(const Duration(seconds: 1));
  }

  /// Waits for the team's error state, and returns how long it took to come — see
  /// [Ride.waitUntilLoadErrorIsShown].
  Future<Duration> waitUntilLoadErrorIsShown({
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final start = DateTime.now();
    await $(keys.team.loadError).waitUntilExists(timeout: timeout);
    return DateTime.now().difference(start);
  }

  /// Waits for the teams tab — « Mes équipes », with its « Découvrir » button.
  Future<void> waitUntilTeamsListIsShown() async {
    await $(keys.teams.discoverButton).waitUntilVisible();
  }

  /// Whether a team's error state (« Équipe indisponible ») is built, on screen or under it.
  bool get showsLoadError => $(keys.team.loadError).exists;

  /// « Réessayer » of the team's error state.
  Future<void> retryLoad() async {
    await $(keys.team.loadErrorRetryButton).tap();
  }

  // ── « Mes équipes » and its pending invitations ────────────────────────

  /// Waits for « Accepter » on the invitation to [teamSlug], in the card atop « Mes équipes ».
  Future<void> waitUntilInvitationIsShown(String teamSlug) async {
    await $(keys.teams.invitationAcceptButton(teamSlug)).waitUntilVisible();
  }

  bool get showsPendingInvitations =>
      isShown(keys.teams.pendingInvitationsCard);

  /// Whether the invitation card names [text] (the team, the inviter).
  bool pendingInvitationsShow(String text) =>
      shows(keys.teams.pendingInvitationsCard, text);

  bool showsMyTeam(String teamSlug) => isShown(keys.teams.teamCard(teamSlug));

  /// « Accepter »: the invitation leaves the card — the last one takes the card with it — and the
  /// team enters the list.
  Future<void> acceptInvitation(String teamSlug) async {
    await $(keys.teams.invitationAcceptButton(teamSlug)).tap();
    await waitUntilGone(keys.teams.invitationAcceptButton(teamSlug));
    await $(keys.teams.teamCard(teamSlug)).waitUntilVisible();
  }

  Future<void> openMyTeam(String teamSlug) async {
    await $(keys.teams.teamCard(teamSlug)).tap();
    await waitUntilTeamIsShown();
  }

  // ── « À propos » and its free pages ────────────────────────────────────

  /// Waits for [pageSlug]'s row in the team's « À propos » section.
  Future<void> waitUntilAboutPageRowIsShown(String pageSlug) async {
    await scrolledTo(keys.team.aboutPageRow(pageSlug));
  }

  bool showsAboutPageRow(String pageSlug) =>
      isShown(keys.team.aboutPageRow(pageSlug));

  /// Taps [pageSlug]'s row, and waits for the page's title.
  Future<void> openAboutPage(String pageSlug) async {
    await (await scrolledTo(keys.team.aboutPageRow(pageSlug))).tap();
    await $(keys.team.customPageTitle).waitUntilVisible();
  }

  String? get customPageTitle => $(keys.team.customPageTitle).exists
      ? $(keys.team.customPageTitle).text
      : null;

  bool customPageBodyShows(String text) =>
      shows(keys.team.customPageBody, text);
}
