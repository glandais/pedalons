import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/adaptive/content_width_constraint.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../rides/presentation/ride_editor_location.dart';
import '../../providers/team_dashboard_provider.dart';
import '../widgets/dashboard/dashboard_admin.dart';
import '../widgets/dashboard/dashboard_content.dart';
import '../widgets/dashboard/dashboard_rides.dart';
import '../widgets/dashboard/dashboard_todo.dart';
import '../widgets/team_sections.dart';

/// Le tableau de bord d'une équipe — la section par défaut, **pour tout le
/// monde** (ledger `API-86`) : un visiteur y lit les prochaines sorties, les
/// dernières publications et les nouveaux parcours, chacun avec « Voir tout ».
///
/// **Un appel, un écran, trois rôles.** `GET /api/teams/{slug}/dashboard`
/// renvoie toutes les sections d'un coup, déjà découpées par le rôle de
/// l'appelant : le bloc `organizer` n'arrive qu'à un organisateur ou un
/// administrateur, le bloc `admin` qu'à un administrateur, et une section dont
/// le module est désactivé arrive `null`. L'écran rend ce qui est là et ne
/// déduit rien du rôle par lui-même — il n'y a donc qu'un endroit, le serveur,
/// où « qui voit quoi » se décide.
///
/// Comme l'Agenda et « À propos », c'est une liste de slivers : l'en-tête
/// d'équipe interpolé et la rangée de sections lui sont passés par
/// `TeamHomePage`, qui garde la charge et l'erreur de l'équipe.
class TeamDashboardPage extends ConsumerWidget {
  const TeamDashboardPage({
    super.key,
    required this.team,
    this.toolbar,
    this.leadingSlivers = const <Widget>[],
  });

  /// L'équipe telle que la page la tient — celle du contrôleur d'adhésion.
  final TeamDetailDto team;

  /// La rangée de sections, épinglée.
  final Widget? toolbar;

  /// L'en-tête d'équipe et le bandeau d'adhésion.
  final List<Widget> leadingSlivers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TeamDashboardDto> dashboard = ref.watch(
      teamDashboardProvider(team.slug),
    );

    return PdlRefresh(
      onRefresh: () => ref.refresh(teamDashboardProvider(team.slug).future),
      child: CustomScrollView(
        // Défileur primaire de la route : le tap sur la barre d'état remonte
        // en haut, et le geste de rafraîchissement marche sur une page courte.
        primary: true,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          ...leadingSlivers,
          ?toolbar,
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              0,
              PdlSpacing.section,
              PdlSpacing.section * 2,
            ),
            sliver: SliverToBoxAdapter(
              child: ContentWidthConstraint(
                child: _body(context, ref, dashboard),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Les données dès qu'il y en a — un rafraîchissement garde l'écran en
  /// place —, l'erreur sinon, et des gabarits le temps du premier appel.
  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<TeamDashboardDto> dashboard,
  ) {
    final TeamDashboardDto? value = dashboard.value;
    if (value != null) return TeamDashboardBody(dashboard: value);
    if (dashboard.hasError) {
      return Padding(
        padding: const EdgeInsets.only(top: PdlSpacing.section),
        child: PdlEmptyState(
          key: keys.teamDashboard.loadError,
          variant: PdlEmptyVariant.error,
          title: 'teams.dashboard.loadError'.tr(),
          message: getErrorMessage(dashboard.error!),
          actions: <Widget>[
            PdlButton(
              label: 'common.retry'.tr(),
              onPressed: () => ref.invalidate(teamDashboardProvider(team.slug)),
            ),
          ],
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.only(top: PdlSpacing.section),
      child: PdlSkeletonCardList(count: 3),
    );
  }
}

/// Le corps du tableau de bord, données en main. Public pour les tests : le
/// découpage par rôle s'y vérifie sans réseau.
///
/// L'ordre est celui de la maquette : l'en-tête et ses actions, « À traiter »,
/// ce qui concerne le membre lui-même, la vie de l'équipe, l'administration,
/// puis les parcours et les annonces.
class TeamDashboardBody extends StatelessWidget {
  const TeamDashboardBody({super.key, required this.dashboard});

  final TeamDashboardDto dashboard;

  @override
  Widget build(BuildContext context) {
    final TeamDashboardDto d = dashboard;
    final TeamDetailDto team = d.team;
    final TeamDashboardOrganizerDto? organizer = d.organizer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _Summary(team: team, role: d.role, organizer: organizer != null),
        if (organizer != null)
          DashboardTodo(teamSlug: team.slug, data: organizer),
        // « Voir tout » mène à l'Agenda et aux Publications, comme au site
        // (ledger `MOB-60`) : « Je participe » pour « Mes prochaines ».
        if (d.myUpcoming != null)
          DashboardMyUpcoming(
            list: d.myUpcoming!,
            onViewAll: () => context.go(
              '${Paths.teamAgenda(team.slug)}?$kAgendaScopeParam=me',
            ),
          ),
        if (d.upcomingRides != null)
          DashboardUpcomingRides(
            list: d.upcomingRides!,
            canEdit: organizer != null,
            onViewAll: () => context.go(Paths.teamAgenda(team.slug)),
          ),
        if (d.latestPosts != null)
          DashboardLatestPosts(
            list: d.latestPosts!,
            onViewAll: () => context.go(Paths.teamPosts(team.slug)),
          ),
        if (d.admin != null) DashboardAdmin(team: team, data: d.admin!),
        if (organizer?.rideTemplates != null)
          DashboardTemplates(
            teamSlug: team.slug,
            list: organizer!.rideTemplates!,
          ),
        if (d.newRoutes != null)
          DashboardNewRoutes(
            list: d.newRoutes!,
            onViewAll: () => context.go(Paths.routes(team.slug)),
          ),
        if (d.latestAds != null)
          DashboardLatestAds(
            list: d.latestAds!,
            onViewAll: () => context.go(Paths.teamAds(team.slug)),
          ),
      ],
    );
  }
}

/// Le rôle, le nombre de membres, et le geste de tête pour qui organise :
/// « Créer une sortie », et tout le reste derrière le chevron.
class _Summary extends StatelessWidget {
  const _Summary({
    required this.team,
    required this.role,
    required this.organizer,
  });

  final TeamDetailDto team;

  /// Nul pour un visiteur, qui reçoit la partie publique (ledger `API-86`) :
  /// pas de badge de rôle.
  final String? role;
  final bool organizer;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final String? role = this.role;
    final List<_CreateAction> actions = organizer
        ? _createActions(team)
        : const <_CreateAction>[];

    return Padding(
      key: keys.teamDashboard.summary,
      padding: const EdgeInsets.only(top: PdlSpacing.cardTight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (role != null) ...<Widget>[
                PdlBadge(
                  label: 'teams.dashboard.role.$role'.tr(),
                  tone: TeamRole.fromJson(role).tone(c),
                  icon: role == 'MEMBER' ? null : PdlIcons.admin,
                ),
                const SizedBox(width: PdlSpacing.chipGap),
              ],
              Expanded(
                child: Text(
                  'teams.membersList.count'.plural(team.memberCount),
                  style: context.pdlText.sub,
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            _CreateSplitButton(actions: actions),
          ],
        ],
      ),
    );
  }
}

/// Une création proposée par le tableau de bord.
class _CreateAction {
  const _CreateAction({
    required this.key,
    required this.label,
    required this.icon,
    required this.location,
    this.subtitle,
    this.group,
  });

  final Key key;
  final String label;
  final IconData icon;
  final String location;
  final String? subtitle;

  /// La section de la feuille ; des actions consécutives du même groupe
  /// partagent son titre.
  final String? group;
}

/// Ce qu'un organisateur peut créer d'ici, dans l'ordre de la feuille :
/// l'agenda (sortie, voyage), les parcours, puis une publication — chacun
/// seulement quand l'équipe a le module. Comme le site
/// (`DashboardHeaderActions`), sauf le générateur de parcours, que l'app n'a
/// pas (ledger `MOB-154`).
List<_CreateAction> _createActions(TeamDetailDto team) {
  final String agenda = 'teams.tabs.agenda'.tr();
  return <_CreateAction>[
    // Une sortie se crée sur un parcours, il faut donc les deux modules.
    if (team.enableRides && team.enableRoutes)
      _CreateAction(
        key: keys.teamDashboard.createRideButton,
        label: 'teams.dashboard.createRide'.tr(),
        icon: PdlIcons.ride,
        location: rideNewLocation(team.slug),
        group: agenda,
      ),
    // Un voyage aussi (ledger `MOB-162`).
    if (team.enableTrips && team.enableRoutes)
      _CreateAction(
        key: keys.teamDashboard.createTripButton,
        label: 'teams.dashboard.createTrip'.tr(),
        icon: PdlIcons.trip,
        location: Paths.tripNew(team.slug),
        group: agenda,
      ),
    if (team.enableRoutes)
      _CreateAction(
        key: keys.teamDashboard.createRouteButton,
        label: 'lists.createLabel.route'.tr(),
        icon: PdlIcons.route,
        location: Paths.routeNew(team.slug),
        // Tracer sur la carte passe par le planificateur (ledger `MOB-170`).
        subtitle: team.enableRoutePlanner
            ? 'teams.dashboard.create.routeHint'.tr()
            : null,
        group: 'teams.tabs.routes'.tr(),
      ),
    if (team.enablePosts)
      _CreateAction(
        key: keys.teamDashboard.newPostButton,
        label: 'teams.dashboard.newPost'.tr(),
        icon: PdlIcons.post,
        location: Paths.postNew(team.slug),
      ),
  ];
}

/// « Créer une sortie ▾ », comme l'agenda du site : la première action en
/// bouton, toutes derrière le chevron, dans une feuille. Une seule action :
/// le bouton seul.
class _CreateSplitButton extends StatelessWidget {
  const _CreateSplitButton({required this.actions});

  final List<_CreateAction> actions;

  @override
  Widget build(BuildContext context) {
    final _CreateAction primary = actions.first;
    return Row(
      children: <Widget>[
        Expanded(
          child: PdlButton(
            key: keys.teamDashboard.createPrimaryButton,
            label: primary.label,
            icon: PdlIcons.add,
            fullWidth: true,
            onPressed: () => context.push(primary.location),
          ),
        ),
        if (actions.length > 1) ...<Widget>[
          const SizedBox(width: PdlSpacing.chipGap),
          Semantics(
            label: 'teams.dashboard.create.other'.tr(),
            child: PdlButton(
              key: keys.teamDashboard.createMenuButton,
              label: '',
              icon: PdlIcons.chevronDown,
              onPressed: () => _openSheet(context),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final String? location = await PdlSheet.show<String>(
      context: context,
      builder: (BuildContext sheetContext) {
        final PdlTypography t = sheetContext.pdlText;
        final List<Widget> rows = <Widget>[];
        for (int i = 0; i < actions.length; i++) {
          final _CreateAction action = actions[i];
          final String? group = action.group;
          if (group != null && (i == 0 || actions[i - 1].group != group)) {
            rows.add(
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(group, style: t.sub),
              ),
            );
          }
          rows.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PdlSettingRow(
                key: action.key,
                title: action.label,
                subtitle: action.subtitle,
                icon: action.icon,
                showDivider:
                    i < actions.length - 1 && actions[i + 1].group == group,
                onTap: () => Navigator.of(sheetContext).pop(action.location),
              ),
            ),
          );
        }
        return PdlSheet(
          title: 'teams.dashboard.create.title'.tr(),
          children: rows,
        );
      },
    );
    if (location != null && context.mounted) context.push(location);
  }
}
