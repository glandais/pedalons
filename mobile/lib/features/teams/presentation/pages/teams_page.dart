import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/team_providers.dart';
import '../widgets/pending_invitations_card.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../../keys.dart';
import '../../../../core/utils/push_location.dart';
import '../../../visibility/presentation/visibility_badge.dart';

/// The teams the user belongs to.
///
/// The magnifier used to be an icon-action with neither effect nor tooltip —
/// the accessibility defect named in the brief §5. It now opens a real search
/// over the loaded list, and the search is deliberately **local**: the endpoint
/// returns *my* teams, a handful of them, already in memory. Finding a team one
/// is not a member of is another job, and it has its own screen — which is
/// where the empty state's call to action leads.
class TeamsPage extends ConsumerStatefulWidget {
  const TeamsPage({super.key});

  @override
  ConsumerState<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends ConsumerState<TeamsPage> {
  /// Whether the search field is shown. Hidden by default: over three teams, a
  /// permanent field would cost more room than it gives.
  bool _searching = false;

  /// Current query, lower-cased by [_onQueryChanged], `null` when empty.
  String? _query;

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _query = null;
    });
  }

  void _clearSearch() => setState(() {
    _searching = false;
    _query = null;
  });

  void _onQueryChanged(String? value) =>
      setState(() => _query = value?.toLowerCase());

  List<TeamDetailDto> _filter(List<TeamDetailDto> teams) {
    final String? query = _query;
    if (query == null || query.isEmpty) return teams;
    return teams
        .where((TeamDetailDto team) => team.name.toLowerCase().contains(query))
        .toList();
  }

  /// Tirer pour rafraîchir recharge aussi les invitations : c'est le geste
  /// naturel après avoir été prévenu d'une invitation hors de l'app.
  Future<void> _refresh() {
    ref.invalidate(myInvitationsProvider);
    return ref.refresh(myTeamsProvider.future);
  }

  void _openDiscover() => context.push(Paths.teamsDiscover());

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(myTeamsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('teams.title'.tr()),
        actions: [
          IconButton(
            icon: Icon(_searching ? PdlIcons.close : PdlIcons.search),
            tooltip: _searching
                ? 'teams.search.close'.tr()
                : 'teams.search.open'.tr(),
            onPressed: _toggleSearch,
          ),
          IconButton(
            key: keys.teams.discoverButton,
            icon: const Icon(Icons.travel_explore_outlined),
            tooltip: 'teams.discover'.tr(),
            onPressed: _openDiscover,
          ),
        ],
      ),
      body: Column(
        children: [
          const PendingInvitationsCard(),
          if (_searching)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PdlSpacing.section,
                vertical: PdlSpacing.feedGap,
              ),
              child: PdlSearchField(
                value: _query,
                autofocus: true,
                onChanged: _onQueryChanged,
                hintText: 'teams.search.hint'.tr(),
                clearTooltip: 'teams.search.clear'.tr(),
              ),
            ),
          Expanded(
            child: teamsAsync.when(
              data: _buildList,
              loading: () => Padding(
                padding: const EdgeInsets.all(PdlSpacing.section),
                child: Column(
                  children: List.generate(
                    3,
                    (index) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ShimmerTeamCard(),
                    ),
                  ),
                ),
              ),
              error: (error, stack) => Center(
                child: SingleChildScrollView(
                  child: PdlEmptyState(
                    variant: PdlEmptyVariant.error,
                    title: 'teams.loadError.title'.tr(),
                    message: getErrorMessage(error),
                    actions: [
                      PdlButton(
                        label: 'common.retry'.tr(),
                        onPressed: () => ref.invalidate(myTeamsProvider),
                      ),
                      ReportProblemButton(error: error, stackTrace: stack),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<TeamDetailDto> teams) {
    final List<TeamDetailDto> visible = _filter(teams);

    // The two empties do not say the same thing: belonging to no team calls
    // for joining one, while a search that matches nothing calls for dropping
    // the search — never for joining a team.
    if (visible.isEmpty) {
      return PdlRefresh(
        onRefresh: _refresh,
        child: ListView(
          children: [
            if (teams.isEmpty)
              PdlEmptyState(
                variant: PdlEmptyVariant.empty,
                icon: PdlIcons.team,
                title: 'teams.empty'.tr(),
                message: 'teams.joinPrompt'.tr(),
                actions: [
                  PdlButton(
                    label: 'teams.discover'.tr(),
                    icon: PdlIcons.search,
                    onPressed: _openDiscover,
                  ),
                ],
              )
            else
              PdlEmptyState(
                variant: PdlEmptyVariant.filtered,
                title: 'teams.searchEmpty.title'.tr(),
                message: 'teams.searchEmpty.message'.tr(
                  namedArgs: {'search': _query ?? ''},
                ),
                actions: [
                  PdlButton(
                    label: 'teams.search.clear'.tr(),
                    onPressed: _clearSearch,
                  ),
                ],
              ),
          ],
        ),
      );
    }

    return PdlRefresh(
      onRefresh: _refresh,
      child: AnimatedResponsiveGrid(
        padding: const EdgeInsets.all(PdlSpacing.section),
        itemCount: visible.length,
        childAspectRatio: 2.5,
        itemBuilder: (context, index) => _TeamCard(team: visible[index]),
      ),
    );
  }
}

/// Une équipe de l'onglet Équipes : logo, nom, nombre de membres et rôle.
///
/// Les jetons et composants Pdl de « Mes équipes » (`HomeTeamRow`), le logo
/// lu dans `team.logoUrl` comme les autres cartes d'équipe (ledger `MOB-139`,
/// D9). Le contenu reste celui d'avant : il relève d'une règle encore ouverte.
class _TeamCard extends StatelessWidget {
  final TeamDetailDto team;

  const _TeamCard({required this.team});

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final String? role = team.role;

    return PdlCard(
      key: keys.teams.teamCard(team.slug),
      onTap: () => pushLocation(context, Paths.team(team.slug)),
      child: Row(
        children: <Widget>[
          PdlAvatar(name: team.name, imageUrl: team.logoUrl, size: 56),
          const SizedBox(width: PdlSpacing.card),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  team.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.cardTitle.copyWith(color: c.text),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: PdlSpacing.cardTight,
                  runSpacing: PdlSpacing.badgeGap,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    // Accordé : « 1 membre » (ledger `MOB-139`, D3).
                    PdlStat(
                      value: 'teams.membersList.count'.plural(team.memberCount),
                      icon: PdlIcons.people,
                    ),
                    // « Équipe uniquement » sur une équipe privée, rien sur
                    // une équipe publique (règle R1, KIT §9).
                    ...teamVisibilityBadges(
                      team.visibility,
                      key: keys.teams.teamCardVisibility(team.slug),
                    ),
                    if (role != null)
                      PdlBadge(
                        label: AppFormatters.roleName(role),
                        tone: TeamRole.fromJson(role).tone(c),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(PdlIcons.chevronRight, size: 18, color: c.textDimmed),
        ],
      ),
    );
  }
}
