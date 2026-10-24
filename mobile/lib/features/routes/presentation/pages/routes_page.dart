import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/pagination/pagination.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../keys.dart';
import '../../../../core/preferences/user_preferences_provider.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../domain/route_filter_labels.dart';
import '../../domain/route_filters.dart';
import '../../providers/route_count_provider.dart';
import '../../providers/route_editor_providers.dart';
import '../../providers/route_list_provider.dart';
import '../widgets/compact_route_row.dart';
import '../widgets/route_card.dart';
import '../widgets/route_filter_sheet.dart';
import '../widgets/routes_map_view.dart';
import '../widgets/routes_toolbar.dart';
import '../../../feedback/presentation/report_problem_button.dart';

/// La parcothèque : une coquille, un jeu de filtres, deux vues.
///
/// La page ne rend plus rien elle-même. Elle tient l'état — filtres, vue,
/// densité — et laisse `RoutesToolbar`, `RoutesMapView` et les deux densités
/// de ligne faire le rendu. C'est ce qui permet aux deux vues de partager
/// **un seul** `routeFiltersProvider` : changer un filtre en carte le change
/// en liste, sans synchronisation à écrire.
class RoutesPage extends ConsumerStatefulWidget {
  /// Team to list routes for, or null for every team the user can see.
  ///
  /// Ce n'est pas la portée *choisie* mais celle que l'écran **impose** : la
  /// section Parcours d'une équipe n'offre pas d'en changer.
  final String? teamSlug;
  final bool embedded;

  /// Vue d'ouverture, quand la route en impose une (`/parcours/carte`). Sans
  /// elle, c'est la dernière vue employée qui gagne.
  final RouteViewMode? initialView;

  const RoutesPage({
    super.key,
    required this.teamSlug,
    this.embedded = false,
    this.initialView,
  });

  @override
  ConsumerState<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends ConsumerState<RoutesPage> {
  /// Vrai une fois que le seuil de densité a été franchi et signalé : le
  /// bandeau ne se répète pas à chaque page chargée.
  bool _densityNoticeShown = false;
  bool _showDensityNotice = false;

  @override
  void initState() {
    super.initState();
    final RouteViewMode? forced = widget.initialView;
    if (forced != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(routeViewModeProvider.notifier).select(forced);
      });
    }
  }

  /// Scrolls back to the top through the route's primary controller.
  ///
  /// The list deliberately declares no `controller:` of its own: that is what
  /// keeps it the primary scrollable of its route, which is what makes an iOS
  /// status-bar tap scroll it to the top.
  void _scrollToTop() {
    final ScrollController? controller = PrimaryScrollController.maybeOf(
      context,
    );
    if (controller != null && controller.hasClients) controller.jumpTo(0);
  }

  void _setFilters(RouteFilters next) {
    ref.read(routeFiltersProvider(widget.teamSlug).notifier).state = next;
  }

  @override
  Widget build(BuildContext context) {
    // Any filter change is a new result set, so the list restarts at the top
    // instead of leaving the user mid-scroll in results they never saw.
    ref.listen(routeFiltersProvider(widget.teamSlug), (
      RouteFilters? previous,
      RouteFilters next,
    ) {
      if (previous != next) _scrollToTop();
    });

    final RouteFilters filters = ref.watch(
      routeFiltersProvider(widget.teamSlug),
    );
    final RouteViewMode view = ref.watch(routeViewModeProvider);

    final Widget toolbar = RoutesToolbar(
      filters: filters,
      onChanged: _setFilters,
      onOpenFilters: _openFilterSheet,
      view: view,
      onViewChanged: (RouteViewMode next) =>
          ref.read(routeViewModeProvider.notifier).select(next),
      showScopeSelector: widget.teamSlug == null,
      trailing: _addButton(),
    );

    final Widget body = view == RouteViewMode.map
        ? _MapBody(toolbar: toolbar, filters: filters, onChanged: _setFilters)
        : _buildList(filters, toolbar);

    if (widget.embedded) return body;

    // Across every team, the page is the Explorer tab and bears its name; a
    // team's own library stays « Parcours » (docs/LEDGER_*.md WEB-114).
    return Scaffold(
      appBar: PdlAppBar(
        title: (widget.teamSlug == null ? 'nav.explore' : 'routes.title').tr(),
      ),
      body: body,
    );
  }

  /// « Ajouter » : créer un parcours, pour un organisateur de la section
  /// Parcours d'une équipe seulement — ni pour un simple membre, ni sur
  /// l'onglet Explorer de toutes les équipes (ledger `MOB-79`).
  Widget? _addButton() {
    final String? teamSlug = widget.teamSlug;
    if (teamSlug == null) return null;
    if (!(ref.watch(canManageRoutesProvider(teamSlug)) ?? false)) return null;
    void open() => context.push(Paths.routeNew(teamSlug));
    // Le libellé visible est court (« Ajouter ») ; le lecteur d'écran lit
    // « Ajouter un parcours ».
    return Semantics(
      label: 'routes.editor.addSemantic'.tr(),
      excludeSemantics: true,
      button: true,
      onTap: open,
      child: PdlButton(
        key: keys.routes.addButton,
        label: 'routes.editor.add'.tr(),
        icon: PdlIcons.add,
        size: PdlButtonSize.sm,
        onPressed: open,
      ),
    );
  }

  Widget _buildList(RouteFilters filters, Widget toolbar) {
    final PagedListState<RouteDto> state = ref.watch(
      routeListProvider(filters),
    );
    final RouteListNotifier notifier = ref.read(
      routeListProvider(filters).notifier,
    );

    return PdlRefresh(
      onRefresh: notifier.refresh,
      child: CustomScrollView(
        // La clé de stockage est ce qui rend l'offset de défilement à
        // l'identique au retour de la vue Carte comme au retour d'un détail :
        // la liste est recréée, sa position ne l'est pas.
        key: PageStorageKey<String>('routes-list-${widget.teamSlug}'),
        // Explicitly the route's primary scrollable, with no controller of its
        // own: an iOS status-bar tap scrolls it back to the top, and pull-to-
        // refresh still works when the list is too short to scroll.
        primary: true,
        slivers: <Widget>[
          PdlPinnedToolbar(child: toolbar),
          ..._buildContentSlivers(state, notifier, filters),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    PagedListState<RouteDto> state,
    RouteListNotifier notifier,
    RouteFilters filters,
  ) {
    const EdgeInsets padding = EdgeInsets.fromLTRB(
      PdlSpacing.section,
      PdlSpacing.chipGap,
      PdlSpacing.section,
      0,
    );

    if (state.showsSkeletons) {
      return <Widget>[
        SliverPadding(
          padding: padding,
          // Cinq squelettes, pas deux (§1.0.4) : deux ressemblent à une fin de
          // liste.
          sliver: const SliverToBoxAdapter(
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
          child: RoutesEmptyState(filters: filters, onChanged: _setFilters),
        ),
      ];
    }

    final int? total = state.total;
    final RouteListDensity density = effectiveRouteDensity(
      ref.watch(routeDensityProvider),
      total,
    );
    _maybeNoticeDensityCrossing(total);

    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PdlSpacing.section,
            PdlSpacing.chipGap,
            PdlSpacing.section,
            4,
          ),
          child: _CountAndDensityRow(
            filters: filters,
            shown: total ?? state.items.length,
            density: density,
          ),
        ),
      ),
      if (_showDensityNotice)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              0,
              PdlSpacing.section,
              PdlSpacing.chipGap,
            ),
            child: PdlBanner(
              tone: PdlBannerTone.info,
              message: 'routes.list.densitySwitched'.tr(
                namedArgs: <String, String>{
                  'threshold': '$kRouteCompactThreshold',
                },
              ),
              onDismiss: () => setState(() => _showDensityNotice = false),
              dismissSemanticLabel: 'common.close'.tr(),
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
            final RouteDto route = state.items[index];
            return density == RouteListDensity.compact
                ? CompactRouteRow(key: ValueKey<String>(route.id), route: route)
                : RouteCard(key: ValueKey<String>(route.id), route: route);
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
            progressLabel: 'pagination.progress'.tr(
              namedArgs: <String, String>{
                'loaded': '${state.items.length}',
                'total': '${total ?? state.items.length}',
              },
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

  /// Le franchissement du seuil rebascule **une fois** en compact, et le dit.
  ///
  /// Sans le bandeau, la liste changerait de forme toute seule et l'utilisateur
  /// conclurait à un bug ; sans le « une fois », son choix manuel serait
  /// définitivement confisqué.
  void _maybeNoticeDensityCrossing(int? total) {
    if (total == null || _densityNoticeShown) return;
    if (total <= kRouteCompactThreshold) return;
    if (ref.read(routeDensityProvider) != RouteListDensity.cards) return;
    _densityNoticeShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(routeDensityProvider.notifier).select(RouteListDensity.compact);
      setState(() => _showDensityNotice = true);
    });
  }

  Future<void> _openFilterSheet() async {
    final RouteFilters current = ref.read(
      routeFiltersProvider(widget.teamSlug),
    );
    final RouteFilters? result = await showRouteFilterSheet(
      context,
      filters: current,
    );
    if (result != null) _setFilters(result);
  }
}

/// La vue Carte : la barre d'outils, puis la carte sur tout le reste.
///
/// Pas de `CustomScrollView` ici — une carte ne défile pas —, donc pas de
/// `PdlPinnedToolbar` non plus : la barre est simplement posée au-dessus, ce
/// qui revient au même puisque rien ne passe dessous.
class _MapBody extends StatelessWidget {
  const _MapBody({
    required this.toolbar,
    required this.filters,
    required this.onChanged,
  });

  final Widget toolbar;
  final RouteFilters filters;
  final ValueChanged<RouteFilters> onChanged;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    return Column(
      children: <Widget>[
        Material(
          color: c.overlaySolid,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: PdlMetrics.toolbarPadding,
            ),
            child: toolbar,
          ),
        ),
        Divider(height: 1, color: c.borderSubtle),
        Expanded(
          child: RoutesMapView(
            key: keys.routes.mapView,
            filters: filters,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// « 412 parcours sur 2 585 » et le segmenté de densité.
///
/// Les deux nombres viennent du **même** endpoint `count`, l'un sur les
/// filtres courants, l'autre sur la portée seule : ils ne peuvent donc pas
/// raconter deux histoires différentes.
class _CountAndDensityRow extends ConsumerWidget {
  const _CountAndDensityRow({
    required this.filters,
    required this.shown,
    required this.density,
  });

  final RouteFilters filters;
  final int shown;
  final RouteListDensity density;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlTypography t = context.pdlText;
    final int? total = ref.watch(routeTotalCountProvider(filters)).value;
    final bool filtered = filters.activeFields.isNotEmpty;

    final String label = (filtered && total != null && total != shown)
        ? 'routes.list.countOf'.tr(
            namedArgs: <String, String>{'shown': '$shown', 'total': '$total'},
          )
        : 'routes.list.count'.plural(shown);

    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: t.count)),
        SizedBox(
          width: 176,
          child: PdlSegmented<RouteListDensity>(
            value: density,
            onChanged: (RouteListDensity next) =>
                ref.read(routeDensityProvider.notifier).select(next),
            segments: <PdlSegment<RouteListDensity>>[
              PdlSegment<RouteListDensity>(
                value: RouteListDensity.cards,
                label: 'routes.density.cards'.tr(),
              ),
              PdlSegment<RouteListDensity>(
                value: RouteListDensity.compact,
                label: 'routes.density.compact'.tr(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dead end: the filters match nothing.
///
/// Rather than a bare "no results", this names the filter most likely to
/// blame, offers to drop it, and proves the offer is worth taking by
/// previewing what would come back without it.
///
/// **Le filtre proposé n'est plus deviné** (S21-8) : c'est celui qui, une fois
/// levé, maximise le compte serveur — voir [routeDeadEndSuggestionProvider].
/// Le rendu, lui, appartient à [PdlDeadEndEmpty] (B22) ; ce qui reste ici est
/// ce que `core/pdl` ne peut pas connaître — les [RouteFilters], les clés de
/// localisation et le provider d'aperçu.
class RoutesEmptyState extends ConsumerWidget {
  final RouteFilters filters;
  final ValueChanged<RouteFilters> onChanged;

  const RoutesEmptyState({
    super.key,
    required this.filters,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RouteFilterField? culprit = ref.watch(
      routeDeadEndSuggestionProvider(filters),
    );
    final String? search = filters.search?.trim();

    return PdlDeadEndEmpty(
      key: keys.routes.emptyState,
      title: 'routes.list.empty.title'.tr(),
      message: search == null || search.isEmpty
          ? 'routes.list.empty.description'.tr()
          : 'routes.list.empty.descriptionSearch'.tr(
              namedArgs: <String, String>{'search': search},
            ),
      removeFilterLabel: culprit == null
          ? null
          : 'routes.list.empty.removeFilter'.tr(
              namedArgs: <String, String>{
                'filter': RouteFilterLabels.filterFieldName(culprit),
              },
            ),
      onRemoveFilter: culprit == null
          ? null
          : () => onChanged(filters.without(culprit)),
      resetAllLabel: 'routes.list.empty.resetAll'.tr(),
      onResetAll: () => onChanged(filters.cleared),
      previewChild: culprit == null
          ? null
          : _WithoutFilterPreview(filters: filters, field: culprit),
    );
  }
}

/// A few of the routes that dropping [field] would bring back.
class _WithoutFilterPreview extends ConsumerWidget {
  final RouteFilters filters;
  final RouteFilterField field;

  const _WithoutFilterPreview({required this.filters, required this.field});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlTypography t = context.pdlText;
    final List<RouteDto>? routes = ref
        .watch(routePreviewProvider(filters.without(field)))
        .value;
    if (routes == null || routes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'routes.list.empty.withoutFilter'.tr(
            namedArgs: <String, String>{
              'filter': RouteFilterLabels.filterFieldName(field),
            },
          ),
          style: t.count,
        ),
        const SizedBox(height: 8),
        // Trois lignes, pas plus : c'est un argument, pas une liste.
        for (final RouteDto route in routes.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: PdlSpacing.feedGap),
            child: _RoutePreviewTile(route: route),
          ),
      ],
    );
  }
}

class _RoutePreviewTile extends ConsumerWidget {
  final RouteDto route;

  const _RoutePreviewTile({required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final UnitSystem units = ref.watch(unitSystemProvider);

    return PdlCard(
      padding: PdlCardPadding.tight,
      onTap: () => context.push(Paths.route(route.team.slug, route.slug)),
      child: Row(
        children: <Widget>[
          PdlThumb(
            imageUrl:
                route.media.assets.thumbnailLight?.url ?? route.thumbnailUrl,
            darkImageUrl: route.media.assets.thumbnailDark?.url,
            size: PdlMetrics.thumbSm,
            fallbackIcon: PdlIcons.route,
          ),
          const SizedBox(width: PdlSpacing.cardTight),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  route.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.cardTitle.copyWith(color: c.text),
                ),
                const SizedBox(height: 2),
                PdlStatRow(stats: routeStats(route, units)),
              ],
            ),
          ),
          Icon(PdlIcons.chevronRight, size: 20, color: c.textDimmed),
        ],
      ),
    );
  }
}
