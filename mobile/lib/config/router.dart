import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/generated/export.dart';
import '../features/apps/presentation/pages/apps_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/reset_password_page.dart';
import '../features/auth/presentation/pages/verify_email_page.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/providers/pending_sign_in_link.dart';
import '../features/device/presentation/pages/device_verify_page.dart';
import '../features/calendar/presentation/pages/calendar_page.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/legal/presentation/pages/legal_page.dart';
import '../features/navigation/presentation/shell/main_shell.dart';
import '../features/notifications/presentation/pages/notifications_page.dart';
import '../features/moderation/presentation/pages/blocked_users_page.dart';
import '../features/profile/presentation/pages/my_participations_page.dart';
import '../features/profile/presentation/pages/profile_account_page.dart';
import '../features/profile/presentation/pages/profile_devices_page.dart';
import '../features/profile/presentation/pages/profile_help_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';
import '../features/profile/presentation/pages/profile_preferences_page.dart';
import '../features/profile/presentation/pages/profile_privacy_page.dart';
import '../features/profile/presentation/pages/profile_security_page.dart';
import '../features/notifications/presentation/pages/notification_settings_page.dart';
import '../core/logging/client_context.dart';
import '../core/pdl/pdl.dart';
import '../core/utils/link_launcher.dart';
import '../features/ads/presentation/pages/ad_detail_page.dart';
import '../features/posts/domain/post_neighbours.dart';
import '../features/posts/presentation/pages/post_detail_page.dart';
import '../features/rides/presentation/pages/ride_detail_page.dart';
import '../features/rides/presentation/pages/ride_editor_page.dart';
import '../features/rides/domain/ride_group_tab.dart';
import '../features/rides/presentation/pages/ride_group_page.dart';
import '../features/trips/presentation/pages/stage_detail_page.dart';
import '../features/trips/presentation/pages/trip_detail_page.dart';
import '../features/routes/presentation/pages/all_routes_map_page.dart';
import '../features/routes/presentation/pages/all_routes_page.dart';
import '../features/routes/presentation/pages/route_detail_page.dart';
import '../features/teams/presentation/pages/team_custom_page.dart';
import '../features/teams/presentation/pages/team_home_page.dart';
import '../features/teams/presentation/pages/teams_discover_page.dart';
import '../features/teams/presentation/widgets/team_sections.dart';
import '../features/teams/presentation/pages/teams_page.dart';
import 'paths.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// One navigator per branch of the shell — that is what gives each tab its own
/// back stack. Order matches [kAppDestinations] and the branch list below.
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _teamsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'teams');
final _calendarNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'calendar');
final _routesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'routes');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profile');

/// Provider for the initial deep link path (set in main.dart)
final initialDeepLinkProvider = Provider<String?>((ref) => null);

typedef _AncestorBuilder =
    String Function(Map<String, String> params, String locale);

/// Hierarchies for deep-linked pages. Each entry pairs a route's locale
/// variants with the list of ancestor URL builders (root → parent), used by
/// [ancestorsForDeepLink] to reconstruct a back stack on cold start.
class _DeepLinkHierarchy {
  final Map<String, String> patterns;
  final List<_AncestorBuilder> ancestors;
  const _DeepLinkHierarchy({required this.patterns, required this.ancestors});
}

String _homeAncestor(Map<String, String> p, String locale) =>
    PathVariants.home()[locale]!;
String _teamsAncestor(Map<String, String> p, String locale) =>
    PathVariants.teams()[locale]!;
String _teamAncestor(Map<String, String> p, String locale) =>
    PathVariants.team(p['teamSlug']!)[locale]!;
String _tripAncestor(Map<String, String> p, String locale) =>
    PathVariants.trip(p['teamSlug']!, p['tripSlug']!)[locale]!;
String _rideAncestor(Map<String, String> p, String locale) =>
    PathVariants.ride(p['teamSlug']!, p['rideSlug']!)[locale]!;
String _profileAncestor(Map<String, String> p, String locale) =>
    PathVariants.profile()[locale]!;
String _profilePrivacyAncestor(Map<String, String> p, String locale) =>
    PathVariants.profilePrivacy()[locale]!;
String _teamAgendaAncestor(Map<String, String> p, String locale) =>
    PathVariants.teamAgenda(p['teamSlug']!)[locale]!;
String _teamPostsAncestor(Map<String, String> p, String locale) =>
    PathVariants.teamPosts(p['teamSlug']!)[locale]!;
String _teamAdsAncestor(Map<String, String> p, String locale) =>
    PathVariants.teamAds(p['teamSlug']!)[locale]!;
String _teamRoutesAncestor(Map<String, String> p, String locale) =>
    PathVariants.routes(p['teamSlug']!)[locale]!;
String _allRoutesAncestor(Map<String, String> p, String locale) =>
    PathVariants.allRoutes()[locale]!;

final List<_DeepLinkHierarchy> _deepLinkHierarchies = [
  // Standalone pages outside any shell: without an ancestor they would be the
  // only entry in the stack, leaving no way back into the app.
  _DeepLinkHierarchy(patterns: PathVariants.apps(), ancestors: [_homeAncestor]),
  _DeepLinkHierarchy(
    patterns: PathVariants.privacy(),
    ancestors: [_homeAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.terms(),
    ancestors: [_homeAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.deviceVerifyGarmin(),
    ancestors: [_homeAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.deviceVerifyKaroo(),
    ancestors: [_homeAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.deviceHammerhead(),
    ancestors: [_homeAncestor],
  ),

  // La boîte de réception vit sous l'accueil, d'où sa cloche l'ouvre : un lien
  // froid doit retrouver l'accueil dessous plutôt que la seule boîte.
  _DeepLinkHierarchy(
    patterns: PathVariants.notifications(),
    ancestors: [_homeAncestor],
  ),

  // Les sous-pages du profil vivent sous sa vue d'ensemble : ouvertes par un
  // lien froid (un e-mail mène à `/profile/notifications`), elles doivent
  // trouver le profil dessous. « Utilisateurs bloqués » est une sous-page de
  // « Confidentialité » (`/profil/vie-privee/bloques`) : les deux sont dessous,
  // Profil › Confidentialité › Bloqués, comme le fil d'Ariane du site.
  _DeepLinkHierarchy(
    patterns: PathVariants.myParticipations(),
    ancestors: [_profileAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.profilePreferences(),
    ancestors: [_profileAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.profileNotifications(),
    ancestors: [_profileAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.profileDevices(),
    ancestors: [_profileAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.profileSecurity(),
    ancestors: [_profileAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.profilePrivacy(),
    ancestors: [_profileAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.blockedUsers(),
    ancestors: [_profileAncestor, _profilePrivacyAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.profileAccount(),
    ancestors: [_profileAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.profileHelp(),
    ancestors: [_profileAncestor],
  ),

  // Pages of the Routes branch. Its root carries the tab bar, the map does not.
  _DeepLinkHierarchy(
    patterns: PathVariants.allRoutesMap(),
    ancestors: [_allRoutesAncestor],
  ),

  // Team pages. The chain starts at the teams tab rather than home — pushing
  // one branch root over another merges them into a single shell match whose
  // state stays on the first one, which would light up the wrong tab. The teams
  // tab still has the bottom navigation to reach home.
  _DeepLinkHierarchy(
    patterns: PathVariants.teamsDiscover(),
    ancestors: [_teamsAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.team(':teamSlug'),
    ancestors: [_teamsAncestor],
  ),

  // Team sections. They used to stop at the teams list because `TeamShell`
  // provided the navigation between them; with the shell gone they are ordinary
  // pages of the Teams branch, so a cold start on one of them must find the
  // team itself underneath — otherwise going back would skip straight past the
  // team the section belongs to.
  _DeepLinkHierarchy(
    patterns: PathVariants.teamAbout(':teamSlug'),
    ancestors: [_teamsAncestor, _teamAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.teamCalendar(':teamSlug'),
    ancestors: [_teamsAncestor, _teamAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.routes(':teamSlug'),
    ancestors: [_teamsAncestor, _teamAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.teamAds(':teamSlug'),
    ancestors: [_teamsAncestor, _teamAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.teamMembers(':teamSlug'),
    ancestors: [_teamsAncestor, _teamAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.teamAgenda(':teamSlug'),
    ancestors: [_teamsAncestor, _teamAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.teamPosts(':teamSlug'),
    ancestors: [_teamsAncestor, _teamAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.teamRides(':teamSlug'),
    ancestors: [_teamsAncestor, _teamAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.teamTrips(':teamSlug'),
    ancestors: [_teamsAncestor, _teamAncestor],
  ),

  // Detail pages.
  _DeepLinkHierarchy(
    patterns: PathVariants.teamPage(':teamSlug', ':pageSlug'),
    ancestors: [_teamsAncestor, _teamAncestor],
  ),
  // Une sortie et un voyage sont rangés sous l'Agenda, une publication sous
  // les Publications — comme le fil d'Ariane du site (ledger `MOB-60`).
  _DeepLinkHierarchy(
    patterns: PathVariants.ride(':teamSlug', ':rideSlug'),
    ancestors: [_teamsAncestor, _teamAncestor, _teamAgendaAncestor],
  ),
  // La page d'un groupe sous sa sortie : le détail se reconstruit dessous,
  // et le groupe y reste sélectionné au retour (ledger `MOB-67`).
  _DeepLinkHierarchy(
    patterns: PathVariants.rideGroup(':teamSlug', ':rideSlug', ':groupId'),
    ancestors: [
      _teamsAncestor,
      _teamAncestor,
      _teamAgendaAncestor,
      _rideAncestor,
    ],
  ),
  // L'éditeur d'une sortie : une création sous l'Agenda, une modification
  // sous la fiche qu'elle réécrit (ledger `MOB-76`).
  _DeepLinkHierarchy(
    patterns: PathVariants.rideNew(':teamSlug'),
    ancestors: [_teamsAncestor, _teamAncestor, _teamAgendaAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.rideEdit(':teamSlug', ':rideSlug'),
    ancestors: [
      _teamsAncestor,
      _teamAncestor,
      _teamAgendaAncestor,
      _rideAncestor,
    ],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.post(':teamSlug', ':postSlug'),
    ancestors: [_teamsAncestor, _teamAncestor, _teamPostsAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.trip(':teamSlug', ':tripSlug'),
    ancestors: [_teamsAncestor, _teamAncestor, _teamAgendaAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.stage(':teamSlug', ':tripSlug', ':stageSlug'),
    ancestors: [
      _teamsAncestor,
      _teamAncestor,
      _teamAgendaAncestor,
      _tripAncestor,
    ],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.ad(':teamSlug', ':adSlug'),
    ancestors: [_teamsAncestor, _teamAncestor, _teamAdsAncestor],
  ),
  _DeepLinkHierarchy(
    patterns: PathVariants.route(':teamSlug', ':routeSlug'),
    ancestors: [_teamsAncestor, _teamAncestor, _teamRoutesAncestor],
  ),
];

Map<String, String>? _matchPattern(String pattern, String actualPath) {
  final patternSegs = pattern.split('/');
  final actualSegs = actualPath.split('/');
  if (patternSegs.length != actualSegs.length) return null;
  final params = <String, String>{};
  for (int i = 0; i < patternSegs.length; i++) {
    if (patternSegs[i].startsWith(':')) {
      params[patternSegs[i].substring(1)] = actualSegs[i];
    } else if (patternSegs[i] != actualSegs[i]) {
      return null;
    }
  }
  return params;
}

/// Returns the ancestor URLs (root → immediate parent) for a deep-linked path,
/// in the same locale the path was authored in. Empty when the target already
/// carries its own navigation (home, main shell tabs, auth pages) — the deep
/// link handler then just [GoRouter.go]es to it.
List<String> ancestorsForDeepLink(String path) {
  final barePath = path.split('?').first;
  for (final hierarchy in _deepLinkHierarchies) {
    for (final entry in hierarchy.patterns.entries) {
      final params = _matchPattern(entry.value, barePath);
      if (params != null) {
        return hierarchy.ancestors.map((fn) => fn(params, entry.key)).toList();
      }
    }
  }
  return const [];
}

/// Paths considered "auth-adjacent" — visits to these skip the
/// `not authenticated → /login` redirect. Includes every locale variant.
final Set<String> _authAdjacentPaths = <String>{
  ...PathVariants.login().values,
  ...PathVariants.register().values,
  ...PathVariants.verifyEmail().values,
  ...PathVariants.forgotPassword().values,
  ...PathVariants.resetPassword().values,
  ...PathVariants.privacy().values,
  ...PathVariants.terms().values,
  ...PathVariants.apps().values,
};

final Set<String> _loginPaths = PathVariants.login().values.toSet();

bool isAuthAdjacent(String location) {
  for (final p in _authAdjacentPaths) {
    if (location == p ||
        location.startsWith('$p?') ||
        location.startsWith('$p/')) {
      return true;
    }
  }
  return false;
}

/// Opens [path] with its ancestor stack ([ancestorsForDeepLink]) underneath, so
/// back walks the logical hierarchy instead of closing the app. The query string
/// travels with the target (`/garmin?code=…`).
void openWithHierarchy(GoRouter router, String path) {
  final ancestors = ancestorsForDeepLink(path);
  if (ancestors.isEmpty) {
    router.go(path);
    return;
  }
  router.go(ancestors.first);
  for (final p in ancestors.skip(1)) {
    router.push(p);
  }
  router.push(path);
}

/// Ouvre un lien profond — web, QR code, notification — une fois l'app
/// navigable.
///
/// Hors session, un lien vers une page protégée n'est pas perdu : il est gardé
/// dans [pending] et l'app passe par la connexion, qui le reprend
/// ([resumeAfterSignIn]). Le mémoriser ici plutôt que dans `redirect` est
/// délibéré : la redirection voit aussi l'écran quitté par une déconnexion, qui
/// se rejouerait alors pour le membre suivant. Une page ouverte sans session
/// (connexion, CGU, apps…) s'ouvre directement et n'est jamais mise en attente.
void openDeepLink(
  GoRouter router,
  String path, {
  required bool signedIn,
  required PendingSignInLink pending,
}) {
  // Une page du site que le manifeste Android n'a pas su exclure : au
  // navigateur, sans session requise ni pile touchée (docs/LEDGER_*.md MOB-59).
  if (isSitePageLocation(path)) {
    unawaited(openWebPage(path));
    return;
  }
  if (!signedIn && !isAuthAdjacent(path)) {
    pending.location = path;
    router.go(Paths.login());
    return;
  }
  openWithHierarchy(router, path);
}

/// Où aller une fois connecté — mot de passe, passkey, vérification de
/// l'e-mail, réinitialisation : le lien ouvert hors session s'il y en a un,
/// avec ses ancêtres comme tout lien profond, sinon l'accueil. Le lien est
/// consommé : il ne sert qu'une fois.
void resumeAfterSignIn(GoRouter router, PendingSignInLink pending) {
  final location = pending.take();
  if (location == null) {
    router.go(Paths.home());
    return;
  }
  openWithHierarchy(router, location);
}

/// [resumeAfterSignIn] depuis une page de l'authentification.
void goAfterSignIn(WidgetRef ref) => resumeAfterSignIn(
  ref.read(routerProvider),
  ref.read(pendingSignInLinkProvider),
);

/// Register one [GoRoute] per unique locale variant of [variants].
/// [asPage] wraps the child in a [NoTransitionPage] (required for shell children
/// so tab switches don't animate).
List<GoRoute> _perLocale(
  Map<String, String> variants,
  Widget Function(BuildContext, GoRouterState) builder, {
  bool asPage = false,
}) {
  final seen = <String>{};
  final routes = <GoRoute>[];
  for (final path in variants.values) {
    if (!seen.add(path)) continue;
    routes.add(
      GoRoute(
        path: path,
        builder: asPage ? null : builder,
        pageBuilder: asPage
            ? (ctx, st) => NoTransitionPage(child: builder(ctx, st))
            : null,
      ),
    );
  }
  return routes;
}

/// « Confidentialité » et, imbriquée dessous, « Utilisateurs bloqués » — son
/// adresse prolonge la sienne (`/profil/vie-privee/bloques`). Ouverte par `go`
/// (un lien froid, la boîte de réception), la liste trouve donc
/// « Confidentialité » sous elle : son retour suit la même hiérarchie que le
/// fil d'Ariane du site, sans repli à part.
List<GoRoute> _profilePrivacyRoutes() {
  final seen = <String>{};
  final routes = <GoRoute>[];
  for (final MapEntry<String, String> entry
      in PathVariants.profilePrivacy().entries) {
    if (!seen.add(entry.value)) continue;
    final blocked = PathVariants.blockedUsers()[entry.key]!;
    assert(
      blocked.startsWith('${entry.value}/'),
      'Expected "$blocked" to start with "${entry.value}/"',
    );
    routes.add(
      GoRoute(
        path: entry.value,
        builder: (ctx, st) => const ProfilePrivacyPage(),
        routes: [
          GoRoute(
            path: blocked.substring(entry.value.length + 1),
            builder: (ctx, st) => const BlockedUsersPage(),
          ),
        ],
      ),
    );
  }
  return routes;
}

String _underTeam(
  Map<String, String> variants,
  String locale,
  String teamBase,
) {
  final full = variants[locale]!;
  assert(
    full.startsWith('$teamBase/'),
    'Expected "$full" to start with "$teamBase/"',
  );
  return full.substring(teamBase.length + 1);
}

/// La page d'une équipe sur la section que l'adresse demande.
Widget _teamPage(GoRouterState state, TeamSectionTarget target) => TeamHomePage(
  teamSlug: state.pathParameters['teamSlug']!,
  section: target.kind,
  agendaType: target.type,
  agendaScope: target.scope,
  agendaView: target.view,
);

/// Build the team subtree for a single locale, grafted under the Teams branch.
/// Segments are derived from [PathVariants] so no hand-maintained segment map
/// is needed — which is why moving the tree from its own shell to a branch did
/// not change a single URL.
GoRoute _teamTree(String locale) {
  final teamBase = PathVariants.team(':teamSlug')[locale]!;

  /// Every section of a team is the **same page** with another section: one
  /// owner of the team's loading and error state, and a row of sections that
  /// is content rather than a second navigation bar.
  GoRoute section(
    Map<String, String> variants,
    TeamSectionTarget Function(Map<String, String> query) target,
  ) => GoRoute(
    path: _underTeam(variants, locale, teamBase),
    pageBuilder: (context, state) => NoTransitionPage(
      child: _teamPage(state, target(state.uri.queryParameters)),
    ),
  );

  TeamSectionTarget plain(TeamSectionKind kind) => (
    kind: kind,
    type: null,
    scope: AgendaScope.upcoming,
    view: AgendaView.list,
  );

  return GoRoute(
    path: teamBase,
    // L'adresse nue d'une équipe : le tableau de bord, pour tout le monde
    // (ledger `API-86`). Les adresses de l'ancien fil (`?tab=publications`,
    // `?type=`, `?w=`) mènent à l'Agenda ou aux Publications, comme au site —
    // voir `resolveTeamRootSection`.
    pageBuilder: (context, state) => NoTransitionPage(
      child: _teamPage(
        state,
        resolveTeamRootSection(state.uri.queryParameters),
      ),
    ),
    routes: [
      section(
        PathVariants.routes(':teamSlug'),
        (_) => plain(TeamSectionKind.routes),
      ),
      section(
        PathVariants.teamAds(':teamSlug'),
        (_) => plain(TeamSectionKind.ads),
      ),
      section(
        PathVariants.teamAbout(':teamSlug'),
        (_) => plain(TeamSectionKind.about),
      ),
      section(
        PathVariants.teamMembers(':teamSlug'),
        (_) => plain(TeamSectionKind.members),
      ),
      // L'Agenda (sorties et voyages) et les Publications (ledger `MOB-60`).
      section(PathVariants.teamAgenda(':teamSlug'), agendaTarget),
      section(
        PathVariants.teamPosts(':teamSlug'),
        (_) => plain(TeamSectionKind.posts),
      ),
      // `teamCalendar` reste au contrat : c'est l'Agenda en vue Calendrier.
      section(
        PathVariants.teamCalendar(':teamSlug'),
        (Map<String, String> query) =>
            agendaTarget(query, view: AgendaView.calendar),
      ),
      // Les anciens onglets « Sorties » et « Voyages » du site (ledger
      // `WEB-64`), redirigés vers l'Agenda au site : l'app ouvre l'Agenda, sur
      // les voyages pour le second. Sans eux, les motifs de lien profond de
      // l'équipe les capteraient et le lien finirait sur la page d'erreur.
      section(PathVariants.teamRides(':teamSlug'), agendaTarget),
      section(
        PathVariants.teamTrips(':teamSlug'),
        (Map<String, String> query) =>
            agendaTarget(query, type: PublicationType.trip),
      ),
      GoRoute(
        path: _underTeam(
          PathVariants.teamPage(':teamSlug', ':pageSlug'),
          locale,
          teamBase,
        ),
        builder: (context, state) => TeamCustomPage(
          teamSlug: state.pathParameters['teamSlug']!,
          pageSlug: state.pathParameters['pageSlug']!,
        ),
      ),
      GoRoute(
        path: _underTeam(
          PathVariants.route(':teamSlug', ':routeSlug'),
          locale,
          teamBase,
        ),
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => RouteDetailPage(
          teamSlug: state.pathParameters['teamSlug']!,
          routeSlug: state.pathParameters['routeSlug']!,
        ),
      ),
      // Avant le détail : `…/sorties/nouvelle` est aussi la sortie de slug
      // `nouvelle`, et c'est l'éditeur qui est visé (ledger `MOB-76`).
      GoRoute(
        path: _underTeam(PathVariants.rideNew(':teamSlug'), locale, teamBase),
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => RideEditorPage(
          teamSlug: state.pathParameters['teamSlug']!,
          templateSlug: state.uri.queryParameters['template'],
        ),
      ),
      GoRoute(
        path: _underTeam(
          PathVariants.ride(':teamSlug', ':rideSlug'),
          locale,
          teamBase,
        ),
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => RideDetailPage(
          teamSlug: state.pathParameters['teamSlug']!,
          rideSlug: state.pathParameters['rideSlug']!,
        ),
        routes: [_rideGroupRoute(locale), _rideEditRoute(locale)],
      ),
      GoRoute(
        path: _underTeam(
          PathVariants.post(':teamSlug', ':postSlug'),
          locale,
          teamBase,
        ),
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => PostDetailPage(
          teamSlug: state.pathParameters['teamSlug']!,
          postSlug: state.pathParameters['postSlug']!,
          // Les voisins viennent du fil déjà chargé et voyagent dans `extra`,
          // hors de l'URL : ils n'appartiennent pas à l'identité de la
          // publication, et un lien partagé n'en a donc aucun.
          neighbours: state.extra is PostNeighbours
              ? state.extra! as PostNeighbours
              : null,
        ),
      ),
      GoRoute(
        path: _underTeam(
          PathVariants.ad(':teamSlug', ':adSlug'),
          locale,
          teamBase,
        ),
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => AdDetailPage(
          teamSlug: state.pathParameters['teamSlug']!,
          adSlug: state.pathParameters['adSlug']!,
        ),
      ),
      _tripShellRoute(locale, teamBase),
    ],
  );
}

/// La page d'un groupe de sortie, sous le détail de la sortie (ledger
/// `MOB-67`). L'onglet ouvert vient de `?tab=` (`overview`, `weather`,
/// `participants`) : hors contrat, il ne sert qu'aux liens internes — « la
/// météo de ce groupe » ouvre `?tab=weather`.
/// L'éditeur d'une sortie, sous son détail : ouvert par un lien, la fiche se
/// reconstruit dessous et l'enregistrement y revient (ledger `MOB-76`).
GoRoute _rideEditRoute(String locale) {
  final rideBase = PathVariants.ride(':teamSlug', ':rideSlug')[locale]!;
  return GoRoute(
    path: _underTeam(
      PathVariants.rideEdit(':teamSlug', ':rideSlug'),
      locale,
      rideBase,
    ),
    parentNavigatorKey: _rootNavigatorKey,
    builder: (context, state) => RideEditorPage(
      teamSlug: state.pathParameters['teamSlug']!,
      rideSlug: state.pathParameters['rideSlug']!,
    ),
  );
}

GoRoute _rideGroupRoute(String locale) {
  final rideBase = PathVariants.ride(':teamSlug', ':rideSlug')[locale]!;
  return GoRoute(
    path: _underTeam(
      PathVariants.rideGroup(':teamSlug', ':rideSlug', ':groupId'),
      locale,
      rideBase,
    ),
    parentNavigatorKey: _rootNavigatorKey,
    builder: (context, state) => RideGroupPage(
      teamSlug: state.pathParameters['teamSlug']!,
      rideSlug: state.pathParameters['rideSlug']!,
      groupId: state.pathParameters['groupId']!,
      initialTab: RideGroupTab.fromQuery(state.uri.queryParameters['tab']),
    ),
  );
}

GoRoute _tripShellRoute(String locale, String teamBase) {
  final tripBase = PathVariants.trip(':teamSlug', ':tripSlug')[locale]!;
  return GoRoute(
    path: _underTeam(
      PathVariants.trip(':teamSlug', ':tripSlug'),
      locale,
      teamBase,
    ),
    parentNavigatorKey: _rootNavigatorKey,
    builder: (context, state) => TripDetailPage(
      teamSlug: state.pathParameters['teamSlug']!,
      tripSlug: state.pathParameters['tripSlug']!,
    ),
    routes: [
      GoRoute(
        path: _underTeam(
          PathVariants.stage(':teamSlug', ':tripSlug', ':stageSlug'),
          locale,
          tripBase,
        ),
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => StageDetailPage(
          teamSlug: state.pathParameters['teamSlug']!,
          tripSlug: state.pathParameters['tripSlug']!,
          stageSlug: state.pathParameters['stageSlug']!,
        ),
      ),
    ],
  );
}

/// Built once at module load. The router provider can rebuild on auth changes;
/// caching avoids re-walking [PathVariants] and re-allocating the closures.
final List<GoRoute> _teamTreesCache = _buildTeamTrees();

List<GoRoute> _buildTeamTrees() {
  final seenBases = <String>{};
  final trees = <GoRoute>[];
  final teamBases = PathVariants.team(':teamSlug');
  for (final locale in teamBases.keys) {
    if (seenBases.add(teamBases[locale]!)) {
      trees.add(_teamTree(locale));
    }
  }
  return trees;
}

/// Provider for the app router.
///
/// The [GoRouter] is built **once**: watching auth state here would recreate it
/// on every auth change and restart the navigator from [GoRouter.initialLocation],
/// wiping the back stack the deep link handler builds at startup (see main.dart).
/// Auth changes only re-run [GoRouter.redirect], through [refreshListenable].
final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = ValueNotifier<int>(0);
  ref.listen(
    authProvider.select((s) => (s.isInitialized, s.isAuthenticated)),
    (_, _) => authRefresh.value++,
  );
  ref.onDispose(authRefresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    // Deep links are always replayed by the handler in main.dart, which also
    // rebuilds the ancestor stack. Overriding the platform default keeps that
    // the single entry point, whatever the OS passes as initial route.
    initialLocation: Paths.home(),
    overridePlatformDefaultLocation: true,
    refreshListenable: authRefresh,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (!auth.isInitialized) return null;

      final location = state.matchedLocation;

      if (!auth.isAuthenticated && !isAuthAdjacent(location)) {
        return Paths.login();
      }

      if (auth.isAuthenticated && _loginPaths.contains(location)) {
        return Paths.home();
      }

      return null;
    },
    routes: [
      // Auth routes (outside shell)
      ..._perLocale(PathVariants.login(), (ctx, st) => const LoginPage()),
      ..._perLocale(
        PathVariants.register(),
        (ctx, st) => const LoginPage(initialRegister: true),
      ),
      ..._perLocale(
        PathVariants.verifyEmail(),
        (ctx, st) => VerifyEmailPage(token: st.uri.queryParameters['token']),
      ),
      ..._perLocale(
        PathVariants.forgotPassword(),
        (ctx, st) => const ForgotPasswordPage(),
      ),
      ..._perLocale(
        PathVariants.resetPassword(),
        (ctx, st) =>
            ResetPasswordPage(token: st.uri.queryParameters['token'] ?? ''),
      ),

      // Device verification routes (brand names, no fr variants)
      ..._perLocale(
        PathVariants.deviceVerifyGarmin(),
        (ctx, st) => DeviceVerifyPage(code: st.uri.queryParameters['code']),
      ),
      ..._perLocale(
        PathVariants.deviceVerifyKaroo(),
        (ctx, st) => DeviceVerifyPage(
          code: st.uri.queryParameters['code'],
          // The return of the Hammerhead OAuth (docs/LEDGER_*.md API-63).
          hammerheadStep:
              st.uri.queryParameters.containsKey('gps_connected') ||
              st.uri.queryParameters.containsKey('gps_error'),
          gpsError: st.uri.queryParameters['gps_error'],
        ),
      ),
      ..._perLocale(
        PathVariants.deviceHammerhead(),
        (ctx, st) => DeviceVerifyPage(
          hammerheadStep: true,
          gpsError: st.uri.queryParameters['gps_error'],
        ),
      ),

      // The single navigation shell: five fixed tabs, one branch each, one
      // navigator per branch so every tab keeps its own back stack. A team is
      // content of the Teams branch, not a shell of its own — the tab bar never
      // disappears. Full-screen detail pages opt out through
      // `parentNavigatorKey: _rootNavigatorKey`.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(state: state, navigationShell: navigationShell),
        branches: [
          // 0 · Home, et la boîte de réception que sa cloche ouvre. Elle vit
          // ici plutôt que sous le profil parce que `getDestinationIndex`
          // retombe sur l'accueil pour une URL qu'aucune destination ne
          // réclame : l'onglet allumé et la branche active disent alors la
          // même chose, sans règle supplémentaire.
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              ..._perLocale(
                PathVariants.home(),
                (ctx, st) => const HomePage(),
                asPage: true,
              ),
              ..._perLocale(
                PathVariants.notifications(),
                (ctx, st) => const NotificationsPage(),
              ),
            ],
          ),
          // 1 · Teams, and the whole team tree under it — same URLs as before,
          // only the graft point changed. `/teams/discover` is declared before
          // `/teams/:teamSlug` so the literal segment wins over the parameter.
          StatefulShellBranch(
            navigatorKey: _teamsNavigatorKey,
            routes: [
              ..._perLocale(
                PathVariants.teams(),
                (ctx, st) => const TeamsPage(),
                asPage: true,
              ),
              ..._perLocale(
                PathVariants.teamsDiscover(),
                (ctx, st) => const TeamsDiscoverPage(),
              ),
              ..._teamTreesCache,
            ],
          ),
          // 2 · Calendar
          StatefulShellBranch(
            navigatorKey: _calendarNavigatorKey,
            routes: _perLocale(
              PathVariants.calendar(),
              (ctx, st) => const CalendarPage(),
              asPage: true,
            ),
          ),
          // 3 · Routes, across every team.
          StatefulShellBranch(
            navigatorKey: _routesNavigatorKey,
            routes: [
              ..._perLocale(
                PathVariants.allRoutes(),
                (ctx, st) => const AllRoutesPage(),
                asPage: true,
              ),
              ..._perLocale(
                PathVariants.allRoutesMap(),
                (ctx, st) => const AllRoutesMapPage(),
              ),
            ],
          ),
          // 4 · Profile : la vue d'ensemble, racine de l'onglet, et une
          // sous-page par sujet — les mêmes adresses que le site.
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              ..._perLocale(
                PathVariants.profile(),
                (ctx, st) => const ProfilePage(),
                asPage: true,
              ),
              ..._perLocale(
                PathVariants.myParticipations(),
                (ctx, st) => MyParticipationsPage(
                  initialUpcoming: st.extra is bool ? st.extra! as bool : true,
                ),
              ),
              ..._perLocale(
                PathVariants.profilePreferences(),
                (ctx, st) => const ProfilePreferencesPage(),
              ),
              ..._perLocale(
                PathVariants.profileNotifications(),
                (ctx, st) => const NotificationSettingsPage(),
              ),
              ..._perLocale(
                PathVariants.profileDevices(),
                (ctx, st) => const ProfileDevicesPage(),
              ),
              ..._perLocale(
                PathVariants.profileSecurity(),
                (ctx, st) => const ProfileSecurityPage(),
              ),
              ..._profilePrivacyRoutes(),
              ..._perLocale(
                PathVariants.profileAccount(),
                (ctx, st) => const ProfileAccountPage(),
              ),
              ..._perLocale(
                PathVariants.profileHelp(),
                (ctx, st) => const ProfileHelpPage(),
              ),
            ],
          ),
        ],
      ),

      // Companion apps page (outside shell, accessible without auth)
      ..._perLocale(PathVariants.apps(), (ctx, st) => const AppsPage()),

      // Legal pages (outside shell, accessible without auth)
      ..._perLocale(
        PathVariants.privacy(),
        (ctx, st) => const LegalPage(type: LegalPageType.privacy),
      ),
      ..._perLocale(
        PathVariants.terms(),
        (ctx, st) => const LegalPage(type: LegalPageType.terms),
      ),
    ],
    // The only screen that used to carry hard-coded French. It is also a
    // screen a user reaches by accident, so it says what happened, quotes the
    // address, and offers the one way out.
    errorBuilder: (context, state) => Scaffold(
      appBar: PdlAppBar(title: 'errors.notFound.title'.tr()),
      body: Center(
        child: SingleChildScrollView(
          child: PdlEmptyState(
            variant: PdlEmptyVariant.notFound,
            title: 'errors.notFound.title'.tr(),
            message: 'errors.notFound.message'.tr(
              namedArgs: {'path': state.matchedLocation},
            ),
            actions: [
              PdlButton(
                label: 'errors.notFound.action'.tr(),
                onPressed: () => context.go(Paths.home()),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // Le journal de l'app note chaque écran affiché — chemin seul, sans query
  // string — et le contexte d'un rapport sait ainsi où était le membre.
  // L'écoute du délégué voit aussi les changements d'onglet du shell, qu'un
  // `NavigatorObserver` de la pile racine ne verrait pas.
  final contextBuilder = ref.read(clientContextBuilderProvider);
  void recordNavigation() {
    final configuration = router.routerDelegate.currentConfiguration;
    if (configuration.isEmpty) return;
    contextBuilder.recordNavigation(configuration.uri.path);
  }

  router.routerDelegate.addListener(recordNavigation);
  ref.onDispose(() => router.routerDelegate.removeListener(recordNavigation));

  return router;
});
