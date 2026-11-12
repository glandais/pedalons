import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/lists/list_states.dart';
import '../../../../core/lists/list_toolbar.dart';
import '../../../../core/pagination/pagination.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../keys.dart';
import '../../providers/ride_template_providers.dart';
import '../widgets/templates/ride_template_card.dart';
import '../widgets/templates/ride_template_gate.dart';
import '../widgets/templates/ride_template_menu.dart';

/// La liste des modèles de sortie d'une équipe — le pendant mobile de
/// `RideTemplateListPage` du site (ledger `MOB-78`) : recherche, pagination
/// par décalage, une carte par modèle, un menu par carte.
///
/// Réservée aux organisateurs et administrateurs de l'équipe
/// ([RideTemplateAccessGate]) : un simple membre lit un refus.
class RideTemplateListPage extends ConsumerStatefulWidget {
  const RideTemplateListPage({super.key, required this.teamSlug});

  final String teamSlug;

  @override
  ConsumerState<RideTemplateListPage> createState() =>
      _RideTemplateListPageState();
}

class _RideTemplateListPageState extends ConsumerState<RideTemplateListPage> {
  String? _search;

  @override
  Widget build(BuildContext context) {
    final String teamSlug = widget.teamSlug;
    return RideTemplateAccessGate(
      teamSlug: teamSlug,
      title: 'rides.templates.listTitle'.tr(),
      builder: (BuildContext context, TeamDetailDto team, RideTemplateDto? _) =>
          _RideTemplateList(
            teamSlug: teamSlug,
            search: _search,
            onSearch: (String? value) => setState(() => _search = value),
          ),
    );
  }
}

/// L'écran proprement dit, une fois l'accès accordé : il écoute la liste, que
/// la porte ne doit pas charger pour un membre refusé.
class _RideTemplateList extends ConsumerWidget {
  const _RideTemplateList({
    required this.teamSlug,
    required this.search,
    required this.onSearch,
  });

  final String teamSlug;
  final String? search;
  final ValueChanged<String?> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RideTemplateListKey key = (teamSlug: teamSlug, search: search);
    final PagedListState<RideTemplateDto> state = ref.watch(
      rideTemplateListProvider(key),
    );
    final RideTemplateListNotifier notifier = ref.read(
      rideTemplateListProvider(key).notifier,
    );

    void openNew() => context.push(Paths.rideTemplateNew(teamSlug));

    return PdlScreenScaffold(
      appBar: PdlAppBar(
        title: 'rides.templates.listTitle'.tr(),
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
      ),
      // « Créer » à droite de la recherche (règle RL13) : le « + » de la barre
      // de titre y est rangé. La liste n'ouvre qu'à qui crée des sorties
      // ([RideTemplateAccessGate]), le bouton n'a donc pas d'autre condition.
      toolbar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        child: Row(
          children: <Widget>[
            Expanded(
              child: PdlSearchField(
                key: keys.rideTemplates.searchField,
                value: search,
                hintText: 'rides.templates.search'.tr(),
                clearTooltip: 'common.clearSearch'.tr(),
                onChanged: onSearch,
              ),
            ),
            const SizedBox(width: PdlSpacing.chipGap),
            ListCreateButton(
              key: keys.rideTemplates.newButton,
              semanticLabel: 'lists.createLabel.template'.tr(),
              onPressed: openNew,
            ),
          ],
        ),
      ),
      onRefresh: notifier.refresh,
      slivers: _slivers(context, ref, state, notifier, openNew),
    );
  }

  List<Widget> _slivers(
    BuildContext context,
    WidgetRef ref,
    PagedListState<RideTemplateDto> state,
    RideTemplateListNotifier notifier,
    VoidCallback openNew,
  ) {
    if (state.showsSkeletons) {
      return const <Widget>[
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            PdlSpacing.section,
            PdlSpacing.chipGap,
            PdlSpacing.section,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: PdlSkeletonCardList(
              variant: PdlSkeletonCardVariant.compact,
              count: 5,
            ),
          ),
        ),
      ];
    }

    final Object? initialError = state.initialError;
    if (initialError != null) {
      return <Widget>[
        ListStateSliver(
          child: ListLoadError(
            error: initialError,
            onRetry: notifier.loadFirstPage,
          ),
        ),
      ];
    }

    if (state.isEmpty) {
      return <Widget>[
        ListStateSliver(
          child: search == null
              ? PdlEmptyState(
                  key: keys.rideTemplates.empty,
                  variant: PdlEmptyVariant.empty,
                  icon: PdlIcons.template,
                  title: 'rides.templates.emptyTitle'.tr(),
                  message: 'rides.templates.emptyMessage'.tr(),
                  actions: <Widget>[
                    ListEmptyCreateButton(
                      key: keys.rideTemplates.emptyNewButton,
                      label: 'lists.createLabel.template'.tr(),
                      onPressed: openNew,
                    ),
                  ],
                )
              // Un vide filtré a toujours sa sortie : effacer les filtres —
              // ici la recherche, seul filtre de la liste.
              : ListFilteredEmpty(
                  key: keys.rideTemplates.noResults,
                  clearKey: keys.rideTemplates.clearSearchButton,
                  title: 'lists.emptyFiltered.templates'.tr(),
                  filters: <String>[quotedSearch(search!)],
                  onClear: () => onSearch(null),
                ),
        ),
      ];
    }

    final int total = state.total ?? state.items.length;
    return <Widget>[
      SliverToBoxAdapter(
        child: ListResultCount(
          listCountLabel('rides.templates.count', total),
          textKey: keys.rideTemplates.count,
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        sliver: SliverList.separated(
          itemCount: state.items.length,
          separatorBuilder: (BuildContext _, int _) =>
              const SizedBox(height: PdlSpacing.feedGap),
          itemBuilder: (BuildContext context, int index) {
            notifier.onItemBuilt(index);
            final RideTemplateDto template = state.items[index];
            return RideTemplateCard(
              key: ValueKey<String>(template.id),
              template: template,
              onTap: () =>
                  context.push(Paths.rideTemplateEdit(teamSlug, template.slug)),
              onMore: () => showRideTemplateMenu(
                context,
                ref,
                teamSlug: teamSlug,
                template: template,
              ),
            );
          },
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        sliver: SliverToBoxAdapter(
          child: PagedListFooter(
            state: state,
            onRetry: notifier.retryNextPage,
            itemNounKey: 'rides.templates.noun',
          ),
        ),
      ),
    ];
  }
}
