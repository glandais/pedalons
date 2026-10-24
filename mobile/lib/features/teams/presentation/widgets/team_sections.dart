import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/locale_context.dart';
import '../../../../config/paths.generated.dart';
import '../../../../core/theme/pdl_icons.dart';

/// The sections a team can show. The router names one per route, which is what
/// lets the chip row highlight the right one without re-parsing the URL.
///
/// Dans l'ordre du site (plan `2026-10-06-team-agenda.md` §2, ledger `MOB-60`) :
/// le fil d'équipe et le calendrier ont cédé la place à l'**Agenda** (sorties
/// et voyages, dont le calendrier est une vue) et aux **Publications**.
enum TeamSectionKind { dashboard, agenda, posts, routes, ads, members, about }

/// La période de l'Agenda (plan §2.2) : « À venir » par défaut, « Je
/// participe », « Passées ». Pas de « Tout » : trié dans un sens, il
/// commençait par la sortie la plus lointaine et finissait dans l'archive.
enum AgendaScope { upcoming, participating, past }

/// La vue de l'Agenda : la liste de cartes, ou le calendrier du mois — réservé
/// aux membres (plan §7.2).
enum AgendaView { list, calendar }

/// Ce qu'une adresse d'équipe demande : une section et, pour l'Agenda, son
/// type, sa période et sa vue de départ.
typedef TeamSectionTarget = ({
  TeamSectionKind kind,
  PublicationType? type,
  AgendaScope scope,
  AgendaView view,
});

/// Le paramètre de requête de l'ancien fil d'équipe, `?tab=publications` —
/// l'onglet « Publications » d'avant `WEB-68`, que portent encore des liens
/// partagés et des notifications anciennes.
const String kTeamTabParam = 'tab';
const String kTeamTabFeed = 'publications';

/// La période de l'Agenda dans son URL (`?w=me`, `?w=past`), comme au site.
const String kAgendaScopeParam = 'w';

/// Le type de l'Agenda dans son URL (`?type=ride`, `?type=trip`).
const String kAgendaTypeParam = 'type';

PublicationType? _agendaType(String? value) => switch (value) {
  'ride' => PublicationType.ride,
  'trip' => PublicationType.trip,
  _ => null,
};

AgendaScope _agendaScope(String? value) => switch (value) {
  'me' => AgendaScope.participating,
  'past' => AgendaScope.past,
  _ => AgendaScope.upcoming,
};

/// L'Agenda tel que le demande [query] — `?type=` et `?w=`, ce qu'écrivent le
/// site et le tableau de bord (« Voir tout » de « Mes prochaines » :
/// `?w=me`). Un type inconnu, `post` compris, vaut « Tout ».
TeamSectionTarget agendaTarget(
  Map<String, String> query, {
  PublicationType? type,
  AgendaView view = AgendaView.list,
}) => (
  kind: TeamSectionKind.agenda,
  type: type ?? _agendaType(query[kAgendaTypeParam]),
  scope: _agendaScope(query[kAgendaScopeParam]),
  view: view,
);

/// La section à rendre sous l'adresse nue d'une équipe.
///
/// **Le tableau de bord, pour tout le monde** (ledger `API-86`) : un visiteur
/// y voit la partie publique. Les adresses de l'ancien fil restent lues, avec
/// les redirections du site (`teamHomeRedirect`,
/// `frontend/src/pages/team/teamLegacyRedirects.ts`) :
///
/// | Ancienne adresse | Section |
/// |---|---|
/// | `?tab=publications&type=post` | Publications |
/// | `?tab=publications&type=ride\|trip` | Agenda, sur ce type |
/// | `?w=me` / `?w=upcoming` / `?w=all` | Agenda, « Je participe » / « À venir » |
/// | `?tab=publications` seul | le tableau de bord |
TeamSectionTarget resolveTeamRootSection(Map<String, String> query) {
  final String? type = query[kAgendaTypeParam];
  final String? scope = query[kAgendaScopeParam];
  final TeamSectionTarget dashboard = (
    kind: TeamSectionKind.dashboard,
    type: null,
    scope: AgendaScope.upcoming,
    view: AgendaView.list,
  );
  final bool isFeed =
      query[kTeamTabParam] == kTeamTabFeed || type != null || scope != null;
  if (!isFeed) return dashboard;
  if (type == 'post') {
    return (
      kind: TeamSectionKind.posts,
      type: PublicationType.post,
      scope: AgendaScope.upcoming,
      view: AgendaView.list,
    );
  }
  if (type == 'ride' || type == 'trip') return agendaTarget(query);
  if (scope == 'me' || scope == 'upcoming' || scope == 'all') {
    // `w=all`, que l'Agenda n'a plus, vaut « À venir ».
    return agendaTarget(query);
  }
  return dashboard;
}

/// One section of a team — Dashboard, Agenda, Publications, Routes, Ads,
/// Members, About.
///
/// Sections used to be the destinations of a second `NavigationBar` stacked
/// under the app one (`TeamShell`). They are now **content**: a chip row
/// pinned under the team header, so the five global tabs stay visible inside a
/// team. Hence a model of its own rather than the app-level `AppDestination` —
/// nothing here drives a branch of the shell.
class TeamSection {
  final TeamSectionKind kind;

  /// URL variants per locale, straight from [PathVariants].
  final Map<String, String> paths;

  final IconData icon;

  /// Translation key.
  final String label;

  const TeamSection({
    required this.kind,
    required this.paths,
    required this.icon,
    required this.label,
  });

  /// URL in the current locale — use for `context.go(...)`.
  String get currentPath => paths[getCurrentLocale()] ?? paths.values.first;
}

/// The sections visible for [team], given its feature switches and the current
/// user's membership.
///
/// Order is the reading order of the chip row, the site's (`useTeamNavItems`):
/// Tableau de bord, Agenda, Publications, Parcours, Annonces, Membres, À
/// propos. The dashboard and About are always there — the dashboard for a
/// visitor too, in its public part (ledger `API-86`) —, so the row is never
/// empty. Each section only when the team has its module, and an agenda needs
/// the routes too: a ride is created on a route. The icons are the brand's
/// (`docs/BRANDING.md` §6, ledger `BRAND-6`), each section's `PdlIcons`
/// equivalent of the site's Tabler icon.
///
/// [platformAdmin] is the reader's platform role (`/me`): `team.role` is their
/// real membership, null for a platform admin who is not a member
/// (docs/LEDGER_*.md API-137), so the rights that role grants come from here.
List<TeamSection> buildTeamSections(
  TeamDetailDto team, {
  bool platformAdmin = false,
}) {
  final isMember = team.role != null;
  // Organisers and admins read the roster whatever the team decided; everyone
  // else needs the team to have opened it. Mirrors UserTeamAccessChecker: the
  // chip has to disappear when the server would answer 403, because an entry
  // that always leads to an error is worse than no entry at all. A platform
  // admin passes every access check.
  final canSeeMembers =
      platformAdmin ||
      (isMember &&
          (team.role == 'ORGANIZER' ||
              team.role == 'ADMIN' ||
              team.enableMemberDirectory));
  final hasAgenda = (team.enableRides || team.enableTrips) && team.enableRoutes;
  final slug = team.slug;

  return [
    // Dashboard — everyone, at the team's own address (`IconLayoutDashboard`).
    TeamSection(
      kind: TeamSectionKind.dashboard,
      paths: PathVariants.team(slug),
      icon: PdlIcons.dashboard,
      label: 'teams.tabs.dashboard',
    ),
    // Agenda — rides and trips (`IconCalendarEvent`).
    if (hasAgenda)
      TeamSection(
        kind: TeamSectionKind.agenda,
        paths: PathVariants.teamAgenda(slug),
        icon: PdlIcons.agenda,
        label: 'teams.tabs.agenda',
      ),
    // Publications — posts only (`IconArticle`).
    if (team.enablePosts)
      TeamSection(
        kind: TeamSectionKind.posts,
        paths: PathVariants.teamPosts(slug),
        icon: PdlIcons.post,
        label: 'teams.tabs.posts',
      ),
    // Routes — if enabled (`IconRoute`).
    if (team.enableRoutes)
      TeamSection(
        kind: TeamSectionKind.routes,
        paths: PathVariants.routes(slug),
        icon: PdlIcons.route,
        label: 'teams.tabs.routes',
      ),
    // Ads — members only, and only if classifieds are enabled (`IconTag`).
    if (isMember && team.enableAds)
      TeamSection(
        kind: TeamSectionKind.ads,
        paths: PathVariants.teamAds(slug),
        icon: PdlIcons.ad,
        label: 'teams.tabs.ads',
      ),
    // Members — never public, and not even every member: see [canSeeMembers]
    // (`IconUsers`).
    if (canSeeMembers)
      TeamSection(
        kind: TeamSectionKind.members,
        paths: PathVariants.teamMembers(slug),
        icon: PdlIcons.people,
        label: 'teams.tabs.members',
      ),
    // About — always visible (`IconInfoCircle`).
    TeamSection(
      kind: TeamSectionKind.about,
      paths: PathVariants.teamAbout(slug),
      icon: PdlIcons.info,
      label: 'teams.tabs.about',
    ),
  ];
}

/// Index of [kind] in [sections], or `-1` when that section is not visible for
/// this team — the members section reached by a link while not a member, say.
/// No chip is then highlighted, which is truer than highlighting another.
///
/// The active section follows the URL because the router names the section of
/// every team route: no second parsing of the location, and therefore no way
/// for the row and the page below it to disagree.
int indexOfSection(TeamSectionKind kind, List<TeamSection> sections) {
  for (int i = 0; i < sections.length; i++) {
    if (sections[i].kind == kind) return i;
  }
  return -1;
}

/// Où mène « Mes équipes » vers [team], depuis la section [current] d'une
/// autre (ledgers `MOB-87`, `WEB-111`) : la même section si [team] l'a, son
/// tableau de bord sinon. L'adresse est nue — ni période, ni type, ni vue de
/// l'Agenda ne passent d'une équipe à l'autre. Pendant du site :
/// `teamSwitchPath` (`frontend/src/hooks/useNavItems.ts`).
TeamSection switchTargetSection(TeamDetailDto team, TeamSectionKind current) {
  final List<TeamSection> sections = buildTeamSections(team);
  final int i = indexOfSection(current, sections);
  // Le tableau de bord est toujours la première section.
  return sections[i < 0 ? 0 : i];
}
