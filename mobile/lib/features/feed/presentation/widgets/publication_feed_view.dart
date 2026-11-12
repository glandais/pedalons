import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/adaptive/adaptive.dart';
import '../../../../core/pagination/pagination.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/lists/list_states.dart';
import '../../../../keys.dart';
import '../../../posts/domain/post_neighbours.dart';
import '../../../tags/presentation/tag_filter.dart';
import '../../../tags/providers/team_tags_provider.dart';
import '../../../teams/presentation/widgets/publication_card.dart';
import '../../../teams/providers/team_providers.dart';
import '../../providers/publication_feed_provider.dart';

/// A publication feed: search, type chips, infinite scroll, pull-to-refresh
/// and the four list states.
///
/// Shared by the home feed and a team's Agenda and Publications (ledger
/// `MOB-60`) so they behave identically — only the slivers above the toolbar,
/// the type chips offered and the date filter differ.
class PublicationFeedView extends ConsumerStatefulWidget {
  /// Team to show the feed of, or null for the cross-team home feed.
  final String? teamSlug;

  /// La clé des filtres partagés — recherche, tags, type non piloté —, par
  /// défaut [teamSlug].
  ///
  /// L'Agenda et les Publications d'une même équipe en prennent chacun une à
  /// eux (`agenda/<slug>`, `posts/<slug>`) : sans quoi un tag de sortie choisi
  /// dans l'Agenda suivrait dans les Publications, où il ne trouverait rien,
  /// et une recherche passerait d'une section à l'autre.
  final String? filterScope;

  /// Slivers rendered above the pinned toolbar (app bar, prompts…).
  final List<Widget> leadingSlivers;

  /// Posé en tête de la barre épinglée, au-dessus de la recherche : la
  /// période et la bascule Liste / Calendrier de l'Agenda.
  final Widget? toolbarHeader;

  /// Ce que le pull-to-refresh rafraîchit **en plus** du fil.
  ///
  /// L'accueil y met « Ma prochaine sortie » et « À venir » : tirer sur la
  /// liste doit rafraîchir tout l'écran, pas seulement sa moitié basse.
  final Future<void> Function()? onRefreshExtras;

  /// Message shown when the feed has nothing at all.
  final String emptyMessage;

  /// La ligne sous [emptyMessage] ; celle du fil d'accueil par défaut.
  final String? emptyHint;

  /// Les gestes de l'état vide absolu — « Voir les passées » dans l'Agenda.
  final List<Widget> emptyActions;

  /// L'invite du champ de recherche ; celle du fil d'accueil par défaut.
  final String? searchHint;

  /// En-tête de section posé juste au-dessus des cartes — « Dernières
  /// publications · 1 248 publications » sur l'accueil.
  final bool showSectionHeader;

  /// Le nombre de résultats, en une ligne au-dessus des cartes : « 5 sorties
  /// et voyages à venir » dans l'Agenda. Rien quand il est nul.
  final String Function(int total)? countLabel;

  /// Les types proposés en chips, `null` valant « Tout ». Vide : pas de chip
  /// de type du tout — les Publications, dont le type est [selectedType].
  final List<PublicationType?> typeOptions;

  /// Le type **piloté par l'appelant**, quand [onTypeChanged] est donné.
  ///
  /// L'Agenda tient son type lui-même : il l'ouvre sur celui du lien
  /// (`teamTrips`, `?type=ride`) et le garde d'une vue à l'autre. Il ne le
  /// recopie **jamais** dans `publicationFeedTypeProvider` — leçon de
  /// `WEB-64` : un type écrit dans l'état partagé à l'ouverture fuyait vers le
  /// fil empilé dessous par un lien profond. Sans [onTypeChanged], le type vit
  /// dans `publicationFeedTypeProvider` (le fil d'accueil).
  final PublicationType? selectedType;
  final ValueChanged<PublicationType?>? onTypeChanged;

  /// Le filtre de date de l'Agenda (`when`) ; voir [PublicationFeedKey].
  final PublicationWhen? when;

  /// « Je participe » : avec [when] `UPCOMING`, seulement ce où l'on est
  /// inscrit.
  final bool participating;

  /// La période de l'Agenda **quand elle s'écarte de son défaut** (« Je
  /// participe », « Passées ») : c'est un filtre, que le vide filtré nomme
  /// (règle RL10). `null` à « À venir », et hors de l'Agenda.
  final String? periodFilterLabel;

  /// Remet la période à son défaut depuis l'état vide filtré : elle est tenue
  /// par l'appelant, comme le type piloté.
  final VoidCallback? onClearPeriod;

  /// Le titre du vide filtré sous le type « Tout » : « Aucune publication pour
  /// ces filtres » par défaut, « Aucune sortie ni aucun voyage… » à l'Agenda.
  final String filteredTitleKey;

  /// Le nom de ce que la liste compte sous le type « Tout », dans son pied
  /// (« 20 publications sur 1 248 »).
  final String itemNounKey;

  const PublicationFeedView({
    super.key,
    required this.teamSlug,
    required this.emptyMessage,
    this.filterScope,
    this.leadingSlivers = const [],
    this.toolbarHeader,
    this.showSectionHeader = false,
    this.onRefreshExtras,
    this.emptyHint,
    this.emptyActions = const <Widget>[],
    this.searchHint,
    this.countLabel,
    this.typeOptions = kFeedTypeOptions,
    this.selectedType,
    this.onTypeChanged,
    this.when,
    this.participating = false,
    this.periodFilterLabel,
    this.onClearPeriod,
    this.filteredTitleKey = 'lists.emptyFiltered.publications',
    this.itemNounKey = 'lists.noun.publication',
  });

  @override
  ConsumerState<PublicationFeedView> createState() =>
      _PublicationFeedViewState();
}

/// Les chips de type du fil d'accueil : Tout, Sorties, Publications, Voyages.
const List<PublicationType?> kFeedTypeOptions = <PublicationType?>[
  null,
  PublicationType.ride,
  PublicationType.post,
  PublicationType.trip,
];

class _PublicationFeedViewState extends ConsumerState<PublicationFeedView> {
  /// La clé des providers de filtres de ce fil.
  String? get _scope => widget.filterScope ?? widget.teamSlug;

  /// Vrai quand l'appelant tient le type ([PublicationFeedView.onTypeChanged]).
  bool get _typeControlled => widget.onTypeChanged != null;

  /// Scrolls back to the top through the route's primary controller.
  ///
  /// The feed deliberately declares no `controller:` of its own: that is what
  /// keeps it the primary scrollable of its route, which is what makes an iOS
  /// status-bar tap scroll it to the top.
  void _scrollToTop() {
    final controller = PrimaryScrollController.maybeOf(context);
    if (controller != null && controller.hasClients) controller.jumpTo(0);
  }

  void _setType(PublicationType? value) {
    if (_typeControlled) {
      widget.onTypeChanged!(value);
    } else {
      ref.read(publicationFeedTypeProvider(_scope).notifier).state = value;
    }
    // Un jeu de tags par type (plan des tags, D3) : des tags de sortie n'ont
    // aucun sens sur la liste des publications.
    _setTags(const <String>[]);
  }

  void _setTags(List<String> value) {
    ref.read(publicationFeedTagsProvider(_scope).notifier).state = value;
  }

  void _setSearch(String? value) {
    ref.read(publicationFeedSearchProvider(_scope).notifier).state = value;
  }

  void _setScope(MinRole? value) {
    ref.read(publicationFeedScopeProvider(_scope).notifier).state = (
      minRole: value,
    );
  }

  @override
  void didUpdateWidget(PublicationFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Un autre jeu de résultats : retour en haut de liste.
    if (oldWidget.selectedType != widget.selectedType ||
        oldWidget.when != widget.when ||
        oldWidget.participating != widget.participating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToTop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Switching filter is a new result set: back to the top of the list.
    ref.listen(publicationFeedTypeProvider(_scope), (previous, next) {
      if (previous != next && !_typeControlled) _scrollToTop();
    });
    ref.listen(publicationFeedSearchProvider(_scope), (previous, next) {
      if (previous != next) _scrollToTop();
    });
    ref.listen(publicationFeedScopeProvider(_scope), (previous, next) {
      if (previous != next) _scrollToTop();
    });
    ref.listen(publicationFeedTagsProvider(_scope), (previous, next) {
      if (previous != next) _scrollToTop();
    });

    final PublicationType? type = _typeControlled || widget.typeOptions.isEmpty
        ? widget.selectedType
        : ref.watch(publicationFeedTypeProvider(_scope));
    final search = ref.watch(publicationFeedSearchProvider(_scope));
    // La portée n'existe que sur le fil d'accueil : un fil d'équipe *est* déjà
    // une portée.
    final PublicationFeedScopeChoice? scopeChoice = widget.teamSlug == null
        ? ref.watch(publicationFeedScopeProvider(_scope))
        : null;
    final MinRole? defaultScope = widget.teamSlug == null
        ? ref.watch(membershipDefaultScopeProvider)
        : null;
    final MinRole? minRole = widget.teamSlug != null
        ? null
        : scopeChoice != null
        ? scopeChoice.minRole
        : defaultScope;
    // Le filtre par tag n'existe que sur un fil d'équipe filtré par type —
    // la liste dédiée de ce type (D13) — et que si l'équipe a des tags pour
    // ce type : sans eux, pas de chip.
    final String? teamSlug = widget.teamSlug;
    final TagTarget? tagTarget = teamSlug == null ? null : _tagTarget(type);
    final List<TagWithUsageDto> tagVocabulary = tagTarget == null
        ? const <TagWithUsageDto>[]
        : teamTagsOrEmpty(ref, (teamSlug: teamSlug!, type: tagTarget));
    final List<String> tagIds = tagVocabulary.isEmpty
        ? const <String>[]
        : ref.watch(publicationFeedTagsProvider(_scope));
    final PublicationFeedKey key = (
      teamSlug: widget.teamSlug,
      type: type,
      search: search,
      minRole: minRole,
      tags: feedTagsKey(teamSlug: teamSlug, type: type, tagIds: tagIds),
      when: widget.when,
      participating: widget.participating,
    );
    final state = ref.watch(publicationFeedProvider(key));
    final notifier = ref.read(publicationFeedProvider(key).notifier);
    final String? countLine = widget.countLabel == null
        ? null
        : ref
              .watch(publicationFeedCountProvider(key))
              .maybeWhen(
                data: (int total) =>
                    total == 0 ? null : widget.countLabel!(total),
                orElse: () => null,
              );

    return PdlRefresh(
      onRefresh: () async {
        await Future.wait<void>(<Future<void>>[
          notifier.refresh(),
          if (widget.countLabel != null)
            ref.refresh(publicationFeedCountProvider(key).future),
          if (widget.onRefreshExtras != null) widget.onRefreshExtras!(),
        ]);
      },
      child: CustomScrollView(
        // Explicitly the route's primary scrollable, with no controller of its
        // own: an iOS status-bar tap scrolls it back to the top, and pull-to-
        // refresh still works when the list is too short to scroll.
        primary: true,
        slivers: [
          ...widget.leadingSlivers,
          // F-DE-4 : la rangée de filtres vivait dans un `SliverToBoxAdapter`.
          // Elle sortait de l'écran au premier défilement et n'y revenait
          // qu'en remontant tout le fil : au 40ᵉ élément, plus moyen de savoir
          // ni de changer ce qu'on regardait. `PdlPinnedToolbar` l'épingle,
          // comme `routes_page` le fait déjà, et le champ de recherche — qui
          // manquait au fil — y monte avec elle.
          PdlPinnedToolbar(
            padding: EdgeInsets.zero,
            child: FeedToolbar(
              header: widget.toolbarHeader,
              search: search,
              searchHint: widget.searchHint,
              selectedType: type,
              typeOptions: widget.typeOptions,
              selectedScope: minRole,
              showScope: widget.teamSlug == null,
              onSearchChanged: _setSearch,
              onTypeSelected: _setType,
              onScopeSelected: _setScope,
              tagVocabulary: tagVocabulary,
              selectedTags: tagIds,
              onTagsChanged: _setTags,
            ),
          ),
          if (widget.showSectionHeader)
            SliverToBoxAdapter(
              child: ContentWidthConstraint(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: PdlSectionHeader(
                  title: 'home.latestPublications'.tr(),
                  // Formaté, accordé, et tu à zéro : l'état vide parle
                  // (règle RL8).
                  count: ref
                      .watch(publicationFeedCountProvider(key))
                      .maybeWhen(
                        data: (int total) => total == 0
                            ? null
                            : listCountLabel('home.publicationCount', total),
                        orElse: () => null,
                      ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          if (countLine != null && !state.isEmpty)
            SliverToBoxAdapter(
              child: ContentWidthConstraint(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  countLine,
                  key: keys.feed.resultCount,
                  style: context.pdlText.sub,
                ),
              ),
            ),
          ..._buildContentSlivers(
            context,
            state,
            notifier,
            search: search,
            tagIds: tagIds,
            tagVocabulary: tagVocabulary,
            // Le type ne filtre que là où il se choisit : dans les
            // Publications, il *est* la liste.
            chosenType: widget.typeOptions.isNotEmpty ? type : null,
            // La portée ne filtre que si elle s'écarte de son défaut.
            scopeFilter: widget.teamSlug == null && minRole != defaultScope
                ? minRole
                : _noScopeFilter,
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  /// Le jeu de tags d'un type de publication ; `null` pour « Tout ».
  static TagTarget? _tagTarget(PublicationType? type) => switch (type) {
    PublicationType.ride => TagTarget.ride,
    PublicationType.post => TagTarget.post,
    PublicationType.trip => TagTarget.trip,
    _ => null,
  };

  /// Le marqueur « la portée n'est pas un filtre » : `null` est une portée,
  /// « Toutes les équipes ».
  static const Object _noScopeFilter = Object();

  List<Widget> _buildContentSlivers(
    BuildContext context,
    PagedListState<PublicationDto> state,
    PublicationFeedNotifier notifier, {
    required String? search,
    required List<String> tagIds,
    required List<TagWithUsageDto> tagVocabulary,
    required PublicationType? chosenType,
    required Object? scopeFilter,
  }) {
    if (state.showsSkeletons) {
      return [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: ContentWidthConstraint(
              // Cinq squelettes, pas deux (§1.0.4) : deux ressemblent à une
              // fin de liste.
              child: const PdlSkeletonCardList(),
            ),
          ),
        ),
      ];
    }

    // §1.3.4 : un échec est un état, pas un événement. La forme commune des
    // listes (règle RL11) — « Chargement impossible » ou « Pas de connexion »,
    // « Réessayer », « Signaler un problème » —, là où le fil avait un
    // bandeau « Fil indisponible. » à lui.
    if (state.initialError != null) {
      return [
        ListStateSliver(
          child: ContentWidthConstraint(
            child: ListLoadError(
              error: state.initialError!,
              onRetry: notifier.loadFirstPage,
            ),
          ),
        ),
      ];
    }

    if (state.isEmpty) {
      // F-DE-9 : « rien ici » et « rien qui corresponde » ne disent pas la
      // même chose et n'appellent pas la même action. Le vide filtré nomme
      // ce qui filtre et offre la sortie ; le vide absolu dit ce qui
      // apparaîtra ici.
      //
      // **Tout critère écarté de son défaut filtre** (règle RL10) : la
      // recherche, la période (« Je participe », « Passées »), le type, les
      // tags, la portée.
      final bool searched = search != null && search.isNotEmpty;
      final bool scoped = !identical(scopeFilter, _noScopeFilter);
      final String? period = widget.periodFilterLabel;
      final List<String> filters = <String>[
        if (searched) quotedSearch(search),
        if (scoped) _FilterChips.scopeLabel(scopeFilter as MinRole?),
        ?period,
        if (chosenType != null) _FilterChips.typeLabel(chosenType),
        ...tagNames(tagVocabulary, tagIds),
      ];
      return [
        ListStateSliver(
          child: ContentWidthConstraint(
            child: filters.isEmpty
                ? PdlEmptyState(
                    key: keys.feed.emptyState,
                    variant: PdlEmptyVariant.empty,
                    icon: Icons.dynamic_feed,
                    title: widget.emptyMessage,
                    message: widget.emptyHint ?? 'home.feed.emptyHint'.tr(),
                    actions: widget.emptyActions,
                  )
                : ListFilteredEmpty(
                    key: keys.feed.filteredEmptyState,
                    clearKey: keys.feed.clearFiltersButton,
                    title: switch (chosenType) {
                      PublicationType.ride => 'lists.emptyFiltered.rides',
                      PublicationType.trip => 'lists.emptyFiltered.trips',
                      PublicationType.post =>
                        'lists.emptyFiltered.publications',
                      _ => widget.filteredTitleKey,
                    }.tr(),
                    filters: filters,
                    // Un seul geste lève tout ce qui est nommé : la
                    // recherche, le type et ses tags, la période et la
                    // portée, remises à leur défaut.
                    onClear: () {
                      if (searched) _setSearch(null);
                      if (chosenType != null) {
                        // Lever le type lève aussi ses tags.
                        _setType(null);
                      } else if (tagIds.isNotEmpty) {
                        _setTags(const <String>[]);
                      }
                      if (scoped) {
                        ref
                                .read(
                                  publicationFeedScopeProvider(_scope).notifier,
                                )
                                .state =
                            null;
                      }
                      if (period != null) widget.onClearPeriod?.call();
                    },
                  ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        sliver: SliverList.separated(
          itemCount: state.items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            notifier.onItemBuilt(index);
            return ContentWidthConstraint(
              child: PublicationCard(
                key: keys.feed.card(state.items[index].slug),
                publication: state.items[index],
                postNeighbours: _postNeighbours(state.items, index),
              ),
            );
          },
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: ContentWidthConstraint(
            child: PagedListFooter(
              state: state,
              onRetry: notifier.retryNextPage,
              skeleton: const PdlSkeletonCard(),
              itemNounKey: switch (chosenType) {
                PublicationType.ride => 'lists.noun.ride',
                PublicationType.trip => 'lists.noun.trip',
                PublicationType.post => 'lists.noun.publication',
                _ => widget.itemNounKey,
              },
            ),
          ),
        ),
      ),
    ];
  }
}

/// Le contenu de la barre épinglée : recherche puis chips de type.
///
/// Aucune hauteur n'y est écrite. C'est la contrepartie de F-DE-3 côté barre :
/// [PdlPinnedToolbar] mesure ce qu'on lui donne, à condition qu'on ne lui
/// donne rien de figé.
class FeedToolbar extends StatelessWidget {
  /// Au-dessus de la recherche : la période et la vue de l'Agenda.
  final Widget? header;

  final String? search;

  /// L'invite de la recherche ; celle du fil d'accueil par défaut.
  final String? searchHint;
  final PublicationType? selectedType;

  /// Les chips de type ; aucune quand la liste est vide.
  final List<PublicationType?> typeOptions;

  /// Portée courante ; ignorée quand [showScope] est faux.
  final MinRole? selectedScope;
  final bool showScope;

  final ValueChanged<String?> onSearchChanged;
  final ValueChanged<PublicationType?> onTypeSelected;
  final ValueChanged<MinRole?> onScopeSelected;

  const FeedToolbar({
    super.key,
    required this.search,
    required this.selectedType,
    required this.onSearchChanged,
    required this.onTypeSelected,
    required this.onScopeSelected,
    this.header,
    this.searchHint,
    this.typeOptions = kFeedTypeOptions,
    this.selectedScope,
    this.showScope = false,
    this.tagVocabulary = const <TagWithUsageDto>[],
    this.selectedTags = const <String>[],
    this.onTagsChanged,
  });

  /// Tags du type choisi, sur un fil d'équipe ; vide ailleurs, et la chip
  /// « Tags » n'est alors pas rendue.
  final List<TagWithUsageDto> tagVocabulary;
  final List<String> selectedTags;
  final ValueChanged<List<String>>? onTagsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null)
          ContentWidthConstraint(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: header!,
          ),
        ContentWidthConstraint(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: PdlSearchField(
            key: keys.feed.searchField,
            value: search,
            hintText: searchHint ?? 'home.feed.searchPlaceholder'.tr(),
            clearTooltip: 'common.clearSearch'.tr(),
            onChanged: onSearchChanged,
          ),
        ),
        // Les Publications n'ont ni type à choisir ni, sans tags, de filtre :
        // pas de rangée vide alors.
        if (typeOptions.isNotEmpty ||
            showScope ||
            (tagVocabulary.isNotEmpty && onTagsChanged != null))
          _FilterChips(
            typeOptions: typeOptions,
            selectedType: selectedType,
            selectedScope: selectedScope,
            showScope: showScope,
            onTypeSelected: onTypeSelected,
            onScopeSelected: onScopeSelected,
            tagVocabulary: tagVocabulary,
            selectedTags: selectedTags,
            onTagsChanged: onTagsChanged,
          ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  final List<PublicationType?> typeOptions;
  final PublicationType? selectedType;
  final MinRole? selectedScope;
  final bool showScope;
  final ValueChanged<PublicationType?> onTypeSelected;
  final ValueChanged<MinRole?> onScopeSelected;

  const _FilterChips({
    required this.typeOptions,
    required this.selectedType,
    required this.selectedScope,
    required this.showScope,
    required this.onTypeSelected,
    required this.onScopeSelected,
    required this.tagVocabulary,
    required this.selectedTags,
    required this.onTagsChanged,
  });

  final List<TagWithUsageDto> tagVocabulary;
  final List<String> selectedTags;
  final ValueChanged<List<String>>? onTagsChanged;

  PublicationType? get selected => selectedType;
  ValueChanged<PublicationType?> get onSelected => onTypeSelected;

  @override
  Widget build(BuildContext context) {
    // F-DE-3 : un `SingleChildScrollView` nu coupait la 4ᵉ chip net sur le
    // bord droit, sans rien qui signale qu'il en restait — une chip tronquée
    // se lit comme une chip abîmée. `PdlChipRow` fond les 28 derniers pixels
    // et mesure sa hauteur au lieu de la figer.
    return PdlChipRow(
      children: [
        // La portée d'abord, en chip de tri : elle décide de *quoi* on parle
        // avant que le type ne décide *de quel type*.
        if (showScope)
          PdlChip(
            label: scopeLabel(selectedScope),
            icon: Icons.tune,
            sortStyle: true,
            selected: selectedScope != null,
            onTap: () => _openScopeSheet(context),
          ),
        for (final PublicationType? type in typeOptions)
          _chip(label: typeLabel(type), icon: _typeIcon(type), value: type),
        // Après les types : elle affine celui qui est choisi.
        if (tagVocabulary.isNotEmpty && onTagsChanged != null)
          TagFilterChip(
            vocabulary: tagVocabulary,
            selected: selectedTags,
            onChanged: onTagsChanged!,
          ),
      ],
    );
  }

  static String typeLabel(PublicationType? type) => switch (type) {
    PublicationType.ride => 'rides.title'.tr(),
    PublicationType.post => 'posts.title'.tr(),
    PublicationType.trip => 'trips.title'.tr(),
    _ => 'home.feed.all'.tr(),
  };

  static IconData? _typeIcon(PublicationType? type) => switch (type) {
    PublicationType.ride => Icons.directions_bike,
    PublicationType.post => Icons.article,
    PublicationType.trip => Icons.hiking,
    _ => null,
  };

  /// Le libellé de la chip de portée : le rôle minimum, ou « Toutes les
  /// équipes » sans rôle.
  static String scopeLabel(MinRole? scope) => switch (scope) {
    MinRole.member => 'roles.member'.tr(),
    MinRole.organizer => 'roles.organizer'.tr(),
    MinRole.admin => 'roles.admin'.tr(),
    _ => 'home.scopeAllTeams'.tr(),
  };

  /// La portée s'ouvre en feuille plutôt qu'en quatre chips : elle est
  /// exclusive, et quatre chips de plus repousseraient les types hors écran.
  Future<void> _openScopeSheet(BuildContext context) async {
    const List<MinRole?> options = <MinRole?>[
      null,
      MinRole.member,
      MinRole.organizer,
      MinRole.admin,
    ];
    final int? picked = await PdlSheet.show<int>(
      context: context,
      builder: (BuildContext sheetContext) => PdlSheet(
        title: 'home.scope'.tr(),
        children: <Widget>[
          for (int i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PdlSettingRow(
                title: scopeLabel(options[i]),
                trailing: options[i] == selectedScope
                    ? Icon(Icons.check, color: context.pdl.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(i),
              ),
            ),
        ],
      ),
    );
    if (picked != null) onScopeSelected(options[picked]);
  }

  Widget _chip({
    required String label,
    required PublicationType? value,
    IconData? icon,
  }) {
    return PdlChip(
      key: keys.feed.typeChip(value),
      label: label,
      icon: icon,
      selected: selected == value,
      onTap: () => onSelected(value),
    );
  }
}

/// La place de la publication en [index] **dans l'ordre du fil**.
///
/// Le contrat n'expose aucun voisinage : cette liste-ci est la seule source
/// honnête, et elle ne vaut que pour cette session d'écran — d'où le passage
/// par l'`extra` de la route plutôt que par l'URL.
///
/// Seules les **publications** entrent dans la liste : une sortie n'est pas la
/// publication suivante d'une publication, et le bloc mènerait à un autre
/// écran.
PostNeighbours? _postNeighbours(List<PublicationDto> items, int index) {
  if (items[index] is! PublicationDtoPost) return null;

  final List<PostNeighbour> posts = <PostNeighbour>[];
  int position = -1;
  for (int i = 0; i < items.length; i++) {
    final PublicationDto item = items[i];
    if (item is! PublicationDtoPost) continue;
    if (i == index) position = posts.length;
    posts.add(PostNeighbour(slug: item.slug, name: item.name));
  }
  if (posts.length < 2) return null;
  return PostNeighbours(posts: posts, index: position);
}
