import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/pagination/pagination.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../keys.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/ad_filters.dart';
import '../../providers/ad_list_provider.dart';
import '../widgets/ad_card.dart';
import '../widgets/ads_toolbar.dart';
import '../../../feedback/presentation/report_problem_button.dart';

/// La rubrique Annonces d'une équipe.
///
/// **Le défaut central que cet écran corrige est une troncature silencieuse** :
/// l'appel précédent omettait `page` et `size` et s'arrêtait à la première page
/// du serveur sans jamais le dire. La liste est désormais paginée, et son pied
/// annonce « N annonces sur M » depuis `AdListResponse.total`, que la page
/// apporte : nul besoin d'interroger pour cela `GET …/classifieds/count`, qui
/// existe mais que l'app n'appelle pas.
///
/// C'est un **corps de section**, pas un écran : l'en-tête d'équipe, la rangée
/// de sections et l'état de chargement de l'équipe appartiennent à
/// `TeamHomePage`.
class AdsPage extends ConsumerStatefulWidget {
  final String teamSlug;
  final TeamDetailDto team;

  const AdsPage({super.key, required this.teamSlug, required this.team});

  @override
  ConsumerState<AdsPage> createState() => _AdsPageState();
}

class _AdsPageState extends ConsumerState<AdsPage> {
  void _setFilters(AdFilters next) {
    ref.read(adFiltersProvider(widget.teamSlug).notifier).state = next;
  }

  /// Un changement de filtre est un jeu de résultats neuf : la liste repart en
  /// haut plutôt que de laisser l'utilisateur au milieu de résultats qu'il n'a
  /// jamais vus.
  void _scrollToTop() {
    final ScrollController? controller = PrimaryScrollController.maybeOf(
      context,
    );
    if (controller != null && controller.hasClients) controller.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(adFiltersProvider(widget.teamSlug), (
      AdFilters? previous,
      AdFilters next,
    ) {
      if (previous != next) _scrollToTop();
    });

    final AdFilters filters = ref.watch(adFiltersProvider(widget.teamSlug));
    final PagedListState<AdDto> state = ref.watch(adListProvider(filters));
    final AdListNotifier notifier = ref.read(adListProvider(filters).notifier);

    return PdlRefresh(
      onRefresh: notifier.refresh,
      child: CustomScrollView(
        key: PageStorageKey<String>('ads-list-${widget.teamSlug}'),
        primary: true,
        slivers: <Widget>[
          PdlPinnedToolbar(
            child: AdsToolbar(filters: filters, onChanged: _setFilters),
          ),
          ..._contentSlivers(state, notifier, filters),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  List<Widget> _contentSlivers(
    PagedListState<AdDto> state,
    AdListNotifier notifier,
    AdFilters filters,
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

    // Un refus n'est pas une panne : un lien vers les annonces d'une équipe
    // dont on n'est pas membre lit « Réservées aux membres », comme au site,
    // pas « rubrique non activée, ou réseau indisponible » — ni « Réessayer »,
    // qui rendrait le même 403.
    if (state.initialError != null && isForbiddenError(state.initialError!)) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: PdlEmptyState(
              key: keys.adsList.membersOnlyState,
              variant: PdlEmptyVariant.empty,
              icon: PdlIcons.visibilityTeam,
              title: 'ads.list.membersOnly.title'.tr(),
              message: 'ads.list.membersOnly.message'.tr(),
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
              // L'échec a **deux** causes plausibles et l'API ne les distingue
              // pas : la rubrique désactivée sur l'équipe rend le même 404
              // qu'un réseau absent rend un échec. Les nommer toutes les deux
              // vaut mieux qu'en choisir une au hasard.
              message: 'ads.list.loadError'.tr(),
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
              ? _AdsDeadEnd(filters: filters, onChanged: _setFilters)
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: PdlEmptyState(
                    variant: PdlEmptyVariant.empty,
                    icon: Icons.sell,
                    title: 'ads.empty'.tr(),
                    message: 'ads.emptyHint'.tr(),
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
            'ads.list.count'.plural(
              total,
              args: <String>[AppFormatters.formatNumber(total)],
            ),
            style: context.pdlText.count,
          ),
        ),
      ),
      SliverPadding(
        padding: padding,
        sliver: SliverList.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: PdlSpacing.feedGap),
          itemBuilder: (BuildContext context, int index) {
            notifier.onItemBuilt(index);
            final AdDto ad = state.items[index];
            return AdCard(key: ValueKey<String>(ad.id), ad: ad);
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
            // « N annonces sur M » : le seul endroit qui dise ce que la liste
            // cache encore, et il ne coûte aucun appel supplémentaire.
            progressLabel: pagedProgressNamed(
              'ads.list.noun',
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

/// Cul-de-sac : les filtres ne laissent rien passer.
///
/// [PdlDeadEndEmpty] est réutilisé **tel quel**, avec `suggestedFilter: null`
/// — c'est-à-dire sans « Retirer le filtre X » ni aperçu. La règle de S21-8
/// veut qu'un filtre proposé soit celui qui, une fois levé, maximise le compte
/// serveur : `GET …/classifieds/count` le permettrait, au prix d'un appel par
/// filtre posé à chaque frappe, que l'app ne fait pas pour une suggestion
/// secondaire. « Tout réinitialiser » suffit à sortir du cul-de-sac.
class _AdsDeadEnd extends StatelessWidget {
  const _AdsDeadEnd({required this.filters, required this.onChanged});

  final AdFilters filters;
  final ValueChanged<AdFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final String? search = filters.search?.trim();

    return PdlDeadEndEmpty(
      key: keys.adsList.filteredEmptyState,
      title: 'ads.list.empty.title'.tr(),
      message: search == null || search.isEmpty
          ? 'ads.list.empty.description'.tr()
          : 'ads.list.empty.descriptionSearch'.tr(
              namedArgs: <String, String>{'search': search},
            ),
      resetAllLabel: 'ads.list.empty.resetAll'.tr(),
      onResetAll: () => onChanged(filters.cleared),
    );
  }
}
