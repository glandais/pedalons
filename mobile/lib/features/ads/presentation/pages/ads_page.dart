import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pagination/pagination.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../keys.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/lists/list_states.dart';
import '../../../tags/presentation/tag_filter.dart';
import '../../../tags/providers/team_tags_provider.dart';
import '../../domain/ad_filters.dart';
import '../../providers/ad_list_provider.dart';
import '../widgets/ad_card.dart';
import '../widgets/ad_price_sheet.dart';
import '../widgets/ads_toolbar.dart';

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
    // pas une erreur — ni « Réessayer », qui rendrait le même 403. L'issue est
    // la page « À propos » de l'équipe (règle RL11).
    if (state.initialError != null && isForbiddenError(state.initialError!)) {
      return <Widget>[
        ListStateSliver(
          child: ListAccessRefused(
            key: keys.adsList.membersOnlyState,
            title: 'ads.list.membersOnly.title'.tr(),
            message: 'ads.list.membersOnly.message'.tr(),
            onAbout: () => context.go(Paths.teamAbout(widget.teamSlug)),
          ),
        ),
      ];
    }

    // Une coupure n'est plus lue comme une rubrique désactivée : la forme
    // commune des erreurs de liste distingue le réseau du serveur.
    if (state.initialError != null) {
      return <Widget>[
        ListStateSliver(
          child: ListLoadError(
            error: state.initialError!,
            onRetry: notifier.loadFirstPage,
          ),
        ),
      ];
    }

    if (state.isEmpty) {
      return <Widget>[
        ListStateSliver(
          child: filters.isFiltered
              ? _AdsDeadEnd(filters: filters, onChanged: _setFilters)
              : PdlEmptyState(
                  variant: PdlEmptyVariant.empty,
                  icon: Icons.sell,
                  title: 'ads.empty'.tr(),
                  message: 'ads.emptyHint'.tr(),
                ),
        ),
      ];
    }

    final int total = state.total ?? state.items.length;

    return <Widget>[
      SliverToBoxAdapter(
        child: ListResultCount(listCountLabel('ads.list.count', total)),
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
          // « N annonces sur M » : le seul endroit qui dise ce que la liste
          // cache encore, et il ne coûte aucun appel supplémentaire.
          child: PagedListFooter(
            state: state,
            onRetry: notifier.retryNextPage,
            itemNounKey: 'ads.list.noun',
          ),
        ),
      ),
    ];
  }
}

/// Cul-de-sac : les filtres ne laissent rien passer.
///
/// La forme commune du vide filtré (règle RL10) : les filtres nommés — la
/// recherche, le type, le prix, les tags —, et « Effacer les filtres », qui
/// garde le tri. Pas de « Retirer le filtre X » : il faudrait un appel `count` par
/// filtre posé à chaque frappe, que l'app ne fait pas pour une suggestion
/// secondaire.
class _AdsDeadEnd extends ConsumerWidget {
  const _AdsDeadEnd({required this.filters, required this.onChanged});

  final AdFilters filters;
  final ValueChanged<AdFilters> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? search = filters.search?.trim();
    final List<TagWithUsageDto> vocabulary = teamTagsOrEmpty(ref, (
      teamSlug: filters.teamSlug,
      type: TagTarget.ad,
    ));

    return ListFilteredEmpty(
      key: keys.adsList.filteredEmptyState,
      title: 'lists.emptyFiltered.ads'.tr(),
      filters: <String>[
        if (search != null && search.isNotEmpty) quotedSearch(search),
        if (filters.adType case final AdType type)
          'ads.adType.${type.json}'.tr(),
        ...adPriceFilterNames(filters),
        ...tagNames(vocabulary, filters.tagIds),
      ],
      onClear: () => onChanged(filters.cleared),
    );
  }
}
