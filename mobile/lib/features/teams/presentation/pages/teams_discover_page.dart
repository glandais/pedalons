import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pagination/pagination.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../domain/team_discovery_filters.dart';
import '../../providers/team_discovery_provider.dart';
import '../widgets/team_discovery_card.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../../keys.dart';

/// L'annuaire public : rejoindre une équipe dont on n'est pas membre.
///
/// C'était l'un des deux cul-de-sacs de l'application — la loupe de « Mes
/// équipes » et le bouton de son état vide menaient à un écran « à venir ».
///
/// Le compteur annonce le tri, « triées par nombre de membres » comme la
/// maquette, **parce que** la requête le demande (`kTeamDiscoverySort`,
/// `docs/LEDGER_*.md API-13`) : un tri qu'on ne demande pas ne s'annonce pas.
class TeamsDiscoverPage extends ConsumerStatefulWidget {
  const TeamsDiscoverPage({super.key});

  @override
  ConsumerState<TeamsDiscoverPage> createState() => _TeamsDiscoverPageState();
}

class _TeamsDiscoverPageState extends ConsumerState<TeamsDiscoverPage> {
  void _setFilters(TeamDiscoveryFilters next) {
    ref.read(teamDiscoveryFiltersProvider.notifier).state = next;
  }

  void _scrollToTop() {
    final ScrollController? controller = PrimaryScrollController.maybeOf(
      context,
    );
    if (controller != null && controller.hasClients) controller.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(teamDiscoveryFiltersProvider, (
      TeamDiscoveryFilters? previous,
      TeamDiscoveryFilters next,
    ) {
      if (previous != next) _scrollToTop();
    });

    final TeamDiscoveryFilters filters = ref.watch(
      teamDiscoveryFiltersProvider,
    );
    final PagedListState<TeamDetailDto> state = ref.watch(
      teamDiscoveryProvider(filters),
    );
    final TeamDiscoveryNotifier notifier = ref.read(
      teamDiscoveryProvider(filters).notifier,
    );
    final TeamJoinState joinState = ref.watch(teamJoinControllerProvider);

    return Scaffold(
      backgroundColor: context.pdl.bg,
      appBar: PdlAppBar(
        title: 'teams.discovery.title'.tr(),
        onBack: () => Navigator.of(context).maybePop(),
        backSemanticLabel: 'teams.title'.tr(),
      ),
      body: PdlRefresh(
        onRefresh: notifier.refresh,
        child: CustomScrollView(
          key: const PageStorageKey<String>('teams-discover'),
          primary: true,
          slivers: <Widget>[
            PdlPinnedToolbar(
              child: _DiscoveryToolbar(
                filters: filters,
                onChanged: _setFilters,
              ),
            ),
            if (joinState.failure != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PdlSpacing.section,
                    PdlSpacing.chipGap,
                    PdlSpacing.section,
                    0,
                  ),
                  child: PdlBanner(
                    tone: PdlBannerTone.danger,
                    title: 'teams.discovery.joinFailed'.tr(
                      namedArgs: <String, String>{
                        'team': joinState.failure!.teamName,
                      },
                    ),
                    message: joinState.failure!.message,
                    onDismiss: () => ref
                        .read(teamJoinControllerProvider.notifier)
                        .dismissFailure(),
                    dismissSemanticLabel: 'common.close'.tr(),
                  ),
                ),
              ),
            ..._contentSlivers(state, notifier, filters, joinState),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  List<Widget> _contentSlivers(
    PagedListState<TeamDetailDto> state,
    TeamDiscoveryNotifier notifier,
    TeamDiscoveryFilters filters,
    TeamJoinState joinState,
  ) {
    const EdgeInsets padding = EdgeInsets.fromLTRB(
      PdlSpacing.section,
      PdlSpacing.chipGap,
      PdlSpacing.section,
      0,
    );

    if (state.showsSkeletons) {
      return <Widget>[
        const SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(
            child: PdlSkeletonCardList(
              variant: PdlSkeletonCardVariant.media,
              count: 5,
            ),
          ),
        ),
      ];
    }

    if (state.initialError != null) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: PdlEmptyState(
              variant: PdlEmptyVariant.error,
              title: 'common.loadError'.tr(),
              message: getErrorMessage(state.initialError!),
              actions: <Widget>[
                PdlButton(
                  label: 'common.retry'.tr(),
                  variant: PdlButtonVariant.outline,
                  size: PdlButtonSize.sm,
                  onPressed: notifier.loadFirstPage,
                ),
                ReportProblemButton(error: state.initialError!),
              ],
            ),
          ),
        ),
      ];
    }

    if (state.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: filters.isFiltered
              ? PdlDeadEndEmpty(
                  title: 'teams.discovery.empty.title'.tr(),
                  message: 'teams.discovery.empty.description'.tr(),
                  resetAllLabel: 'teams.discovery.empty.resetAll'.tr(),
                  onResetAll: () => _setFilters(filters.cleared),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: PdlEmptyState(
                    variant: PdlEmptyVariant.empty,
                    icon: Icons.travel_explore_outlined,
                    title: 'teams.discovery.none'.tr(),
                    message: 'teams.discovery.noneHint'.tr(),
                  ),
                ),
        ),
      ];
    }

    final int total = state.total ?? state.items.length;

    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PdlSpacing.section,
            PdlSpacing.chipGap,
            PdlSpacing.section,
            4,
          ),
          child: Text(
            kTeamDiscoverySort == TeamSortBy.memberCount
                ? 'teams.discovery.countSortedByMembers'.tr(
                    namedArgs: <String, String>{
                      'count': 'teams.discovery.count'.plural(total),
                    },
                  )
                : 'teams.discovery.count'.plural(total),
            style: context.pdlText.count,
          ),
        ),
      ),
      SliverPadding(
        padding: padding,
        sliver: SliverList.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: PdlSpacing.teamCardGap),
          itemBuilder: (BuildContext context, int index) {
            notifier.onItemBuilt(index);
            final TeamDetailDto team = state.items[index];
            return TeamDiscoveryCard(
              key: keys.teamsDiscover.card(team.slug),
              // Le rôle rendu est celui du serveur, sauf quand la bascule
              // optimiste l'a devancé.
              team: team.copyWith(role: joinState.roleFor(team)),
              joining: joinState.pending.contains(team.slug),
              onJoin: () =>
                  ref.read(teamJoinControllerProvider.notifier).join(team),
            );
          },
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        sliver: SliverToBoxAdapter(
          child: PdlPagedListFooter(
            isLoadingNext: state.isLoadingNext,
            hasMore: state.hasMore,
            isEmpty: state.items.isEmpty,
            hasError: state.nextError != null,
            onRetry: notifier.retryNextPage,
            progressLabel: pagedProgressNamed(
              'teams.discovery.noun',
              state.items.length,
              total,
            ),
            loadingLabel: 'pagination.loadingMore'.tr(),
            endLabel: 'pagination.endOfList'.tr(),
            errorLabel: 'pagination.nextPageError'.tr(),
            retryLabel: 'common.retry'.tr(),
          ),
        ),
      ),
    ];
  }
}

/// Recherche débouncée et trois chips exclusives.
class _DiscoveryToolbar extends StatelessWidget {
  const _DiscoveryToolbar({required this.filters, required this.onChanged});

  final TeamDiscoveryFilters filters;
  final ValueChanged<TeamDiscoveryFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: PdlSearchField(
            key: keys.teamsDiscover.searchField,
            value: filters.search,
            hintText: 'teams.discovery.searchPlaceholder'.tr(),
            clearTooltip: 'common.clearSearch'.tr(),
            onChanged: (String? value) => onChanged(
              value == null
                  ? filters.copyWith(clearSearch: true)
                  : filters.copyWith(search: value),
            ),
          ),
        ),
        const SizedBox(height: PdlSpacing.chipGap),
        PdlChipRow(
          children: <Widget>[
            for (final TeamDiscoveryScope scope in TeamDiscoveryScope.values)
              PdlChip(
                label: 'teams.discovery.scope.${scope.name}'.tr(),
                selected: filters.scope == scope,
                onTap: () => onChanged(filters.copyWith(scope: scope)),
              ),
          ],
        ),
      ],
    );
  }
}
