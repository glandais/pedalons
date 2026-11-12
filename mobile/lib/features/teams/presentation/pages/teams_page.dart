import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pagination/pagination.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/widgets/widgets.dart';
import '../../providers/my_teams_list_provider.dart';
import '../../providers/team_providers.dart';
import '../widgets/pending_invitations_card.dart';
import '../widgets/team_discovery_card.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../../keys.dart';

/// The teams the user belongs to.
///
/// The magnifier used to be an icon-action with neither effect nor tooltip —
/// the accessibility defect named in the brief §5. It opens a real search,
/// and the search is now **server-side** (`search` of `GET /api/teams`, on the
/// name and the presentation), like Découvrir's: the list is paginated, so a
/// search over what happens to be loaded would miss the teams of the next
/// pages. Finding a team one is not a member of is another job, and it has its
/// own screen — which is where the empty state's call to action leads.
class TeamsPage extends ConsumerStatefulWidget {
  const TeamsPage({super.key});

  @override
  ConsumerState<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends ConsumerState<TeamsPage> {
  /// Whether the search field is shown. Hidden by default: over three teams, a
  /// permanent field would cost more room than it gives.
  bool _searching = false;

  /// Current query, as [PdlSearchField] hands it over (trimmed, debounced),
  /// `null` when empty.
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

  void _onQueryChanged(String? value) => setState(() => _query = value);

  /// Tirer pour rafraîchir recharge aussi les invitations : c'est le geste
  /// naturel après avoir été prévenu d'une invitation hors de l'app. Et
  /// « Mes équipes » transverse (rôles, accès), que la liste ne remplace pas.
  Future<void> _refresh(MyTeamsListNotifier notifier) {
    final Future<void> list = notifier.refresh();
    ref.invalidate(myInvitationsProvider);
    ref.invalidate(myTeamsProvider);
    return list;
  }

  void _openDiscover() => context.push(Paths.teamsDiscover());

  @override
  Widget build(BuildContext context) {
    final PagedListState<TeamDetailDto> state = ref.watch(
      myTeamsListProvider(_query),
    );
    final MyTeamsListNotifier notifier = ref.read(
      myTeamsListProvider(_query).notifier,
    );

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
          Expanded(child: _body(state, notifier)),
        ],
      ),
    );
  }

  Widget _body(
    PagedListState<TeamDetailDto> state,
    MyTeamsListNotifier notifier,
  ) {
    if (state.showsSkeletons) {
      return Padding(
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
      );
    }

    final Object? error = state.initialError;
    if (error != null) {
      // Le titre d'erreur des listes, pas celui de la page d'une équipe
      // (« Équipe indisponible ») : c'est la liste qui n'a pas chargé.
      return Center(
        child: SingleChildScrollView(
          child: PdlEmptyState(
            key: keys.teams.loadError,
            variant: PdlEmptyVariant.error,
            title: 'common.loadError'.tr(),
            message: getErrorMessage(error),
            actions: [
              PdlButton(
                label: 'common.retry'.tr(),
                onPressed: notifier.loadFirstPage,
              ),
              ReportProblemButton(error: error),
            ],
          ),
        ),
      );
    }

    final List<TeamDetailDto> visible = state.items;

    // The two empties do not say the same thing: belonging to no team calls
    // for joining one, while a search that matches nothing calls for dropping
    // the search — never for joining a team.
    if (state.isEmpty) {
      return PdlRefresh(
        onRefresh: () => _refresh(notifier),
        child: ListView(
          children: [
            if (_query == null)
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

    final int total = state.total ?? visible.length;

    // La carte de la découverte, la seule carte d'équipe de l'app (règle
    // R12, KIT §9) : bandeau, extrait sur deux lignes, membres et rôle réel.
    // Toucher la carte ouvre l'équipe ; une équipe dont on est membre n'a
    // pas d'autre action.
    // Paginée comme Découvrir : au-delà de la première page, le pied dit
    // « 20 équipes sur 34 » et la suite se charge au défilement.
    return PdlRefresh(
      onRefresh: () => _refresh(notifier),
      child: ListView.separated(
        padding: const EdgeInsets.all(PdlSpacing.section),
        itemCount: visible.length + 1,
        separatorBuilder: (_, _) =>
            const SizedBox(height: PdlSpacing.teamCardGap),
        itemBuilder: (BuildContext context, int index) {
          if (index == visible.length) {
            return PdlPagedListFooter(
              isLoadingNext: state.isLoadingNext,
              hasMore: state.hasMore,
              isEmpty: visible.isEmpty,
              hasError: state.nextError != null,
              onRetry: notifier.retryNextPage,
              progressLabel: pagedProgressNamed(
                'teams.discovery.noun',
                visible.length,
                total,
              ),
              loadingLabel: 'pagination.loadingMore'.tr(),
              endLabel: 'pagination.endOfList'.tr(),
              errorLabel: 'pagination.nextPageError'.tr(),
              retryLabel: 'common.retry'.tr(),
            );
          }
          notifier.onItemBuilt(index);
          final TeamDetailDto team = visible[index];
          return TeamDiscoveryCard(
            key: keys.teams.teamCard(team.slug),
            team: team,
            visibilityKey: keys.teams.teamCardVisibility(team.slug),
            roleKey: keys.teams.teamCardRole(team.slug),
          );
        },
      ),
    );
  }
}
