import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/lists/list_states.dart';
import '../../../../core/material.dart';
import '../../../../core/pagination/pagination.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/link_launcher.dart';
import '../../../../keys.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../teams/providers/team_access_probe.dart';
import '../../../teams/providers/team_permission_providers.dart';
import '../../../teams/providers/team_providers.dart';
import '../../data/places_repository.dart';
import '../../domain/place_filters.dart';
import '../../providers/places_provider.dart';
import '../widgets/place_form_sheet.dart';

/// « Lieux » — le pendant mobile de `TeamPlacesPage` du site
/// (docs/LEDGER_*.md MOB-168) : les points de départ et d'arrivée que les
/// éditeurs de sortie et de voyage proposent, à créer, modifier et supprimer.
///
/// **Réservé à qui organise l'équipe** (rôle Organisateur ou Administrateur,
/// et l'admin de plateforme) : le serveur refuse la liste aux autres. Le refus
/// est tranché **avant** que la moindre requête de lieux ne parte — la liste
/// n'est écoutée que par le corps rendu une fois le droit établi.
class TeamPlacesPage extends ConsumerWidget {
  const TeamPlacesPage({super.key, required this.teamSlug});

  final String teamSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // [teamReadable] faux : l'équipe elle-même s'est refusée, sa page ne
    // dirait qu'« Équipe indisponible » — le retour mène à « Mes équipes ».
    void back({bool teamReadable = true}) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(teamReadable ? Paths.team(teamSlug) : Paths.teams());
      }
    }

    PdlAppBar appBar() => PdlAppBar(
      title: 'places.title'.tr(),
      onBack: back,
      backSemanticLabel: 'common.back'.tr(),
    );

    Widget shell(Widget body) =>
        PdlScreenScaffold(appBar: appBar(), body: body);

    Widget forbidden({required bool teamReadable}) => shell(
      PdlEmptyState(
        key: keys.teamPlaces.forbidden,
        variant: PdlEmptyVariant.empty,
        icon: PdlIcons.admin,
        title: 'teams.manage.forbiddenTitle'.tr(),
        message: 'teams.manage.forbiddenMessage'.tr(),
        actions: <Widget>[
          PdlButton(
            key: keys.teamPlaces.forbiddenBack,
            label: 'common.back'.tr(),
            variant: PdlButtonVariant.outline,
            onPressed: () => back(teamReadable: teamReadable),
          ),
        ],
      ),
    );

    final AsyncValue<TeamDetailDto> team = ref.watch(
      teamDetailProvider(teamSlug),
    );
    final TeamDetailDto? teamValue = team.value;
    final Object? error = team.error;
    // Une fiche déjà lue reste l'écran en cours : une relecture en échec ne
    // le remplace pas par une erreur.
    if (teamValue == null && error != null) {
      // Une équipe que le serveur refuse (403, ou 404 pour une équipe privée
      // dont on n'est pas membre) : un refus, pas une panne à réessayer.
      if (isTeamAccessRefusal(error)) return forbidden(teamReadable: false);
      return shell(
        PdlEmptyState(
          key: keys.teamPlaces.loadError,
          variant: PdlEmptyVariant.error,
          title: 'common.loadError'.tr(),
          message: getErrorMessage(error),
          actions: <Widget>[
            PdlButton(
              label: 'common.retry'.tr(),
              onPressed: () => ref.invalidate(teamDetailProvider(teamSlug)),
            ),
          ],
        ),
      );
    }

    // `null` tant que la fiche charge : ni liste, ni refus.
    final bool? organizer = ref.watch(isTeamOrganizerProvider(teamSlug));
    if (teamValue == null || organizer == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }
    if (!organizer) return forbidden(teamReadable: true);

    return _Places(
      key: ValueKey<String>('${teamValue.id}@$teamSlug'),
      teamSlug: teamSlug,
      appBar: appBar(),
    );
  }
}

/// Le corps de l'écran, rendu à qui organise l'équipe — et à lui seul : c'est
/// lui qui écoute la liste des lieux.
class _Places extends ConsumerStatefulWidget {
  const _Places({super.key, required this.teamSlug, required this.appBar});

  final String teamSlug;
  final PdlAppBar appBar;

  @override
  ConsumerState<_Places> createState() => _PlacesState();
}

class _PlacesState extends ConsumerState<_Places> {
  /// Une suppression est en cours : les autres gestes attendent.
  bool _writing = false;

  /// Une feuille est ouverte — le formulaire, ou la confirmation d'une
  /// suppression. Posé **avant** de l'ouvrir : un double appui n'en ouvre pas
  /// deux, et n'envoie pas deux suppressions.
  bool _sheetOpen = false;

  /// Ce que le serveur a refusé à une suppression, dans la barre épinglée.
  String? _error;

  String get _slug => widget.teamSlug;

  void _setFilters(PlaceFilters next) {
    ref.read(placeFiltersProvider(_slug).notifier).state = next;
  }

  void _snack(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  /// Ouvre le formulaire — d'un nouveau lieu, ou de [place]. La feuille
  /// enregistre et fait relire la liste ; l'écran confirme.
  Future<void> _openForm([PlaceDetailDto? place]) async {
    if (_writing || _sheetOpen) return;
    _sheetOpen = true;
    setState(() => _error = null);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final PlaceDetailDto? saved;
    try {
      saved = await showPlaceFormSheet(context, _slug, place: place);
    } finally {
      _sheetOpen = false;
    }
    if (saved == null) return;
    _snack(
      messenger,
      place == null ? 'places.created'.tr() : 'places.updated'.tr(),
    );
  }

  Future<void> _delete(PlaceDetailDto place) async {
    if (_writing || _sheetOpen) return;
    _sheetOpen = true;
    final bool confirmed;
    try {
      confirmed = await confirmDestructive(
        context,
        title: 'places.deleteConfirm.title'.tr(),
        message: 'places.deleteConfirm.message'.tr(),
        confirmLabel: 'places.deleteConfirm.confirm'.tr(),
      );
    } finally {
      _sheetOpen = false;
    }
    if (!confirmed || !mounted || _writing) return;

    final PlacesRepository repository = ref.read(placesRepositoryProvider);
    // Pris avant l'`await` : l'écran peut être quitté avant la réponse.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    setState(() {
      _writing = true;
      _error = null;
    });
    try {
      await repository.delete(_slug, place.id);
      notifyPlacesChanged(container, PlaceChange.deleted(_slug, place.id));
      _snack(messenger, 'places.deleted'.tr());
    } catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PlaceFilters filters = ref.watch(placeFiltersProvider(_slug));
    final PagedListState<PlaceDetailDto> state = ref.watch(
      teamPlacesProvider(filters),
    );
    final TeamPlacesNotifier notifier = ref.read(
      teamPlacesProvider(filters).notifier,
    );

    return PdlScreenScaffold(
      appBar: widget.appBar,
      onRefresh: notifier.refresh,
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              PdlSpacing.section,
              PdlSpacing.section,
              0,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: PdlButton(
                key: keys.teamPlaces.addButton,
                label: 'places.add'.tr(),
                icon: PdlIcons.add,
                size: PdlButtonSize.sm,
                enabled: !_writing,
                onPressed: _openForm,
              ),
            ),
          ),
        ),
        PdlPinnedToolbar(child: _toolbar(filters)),
        ..._placeSlivers(state, notifier, filters),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  /// La barre épinglée : le bandeau d'erreur et la recherche par nom ou
  /// adresse.
  Widget _toolbar(PlaceFilters filters) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              0,
              PdlSpacing.section,
              PdlSpacing.chipGap,
            ),
            child: PdlBanner(
              key: keys.teamPlaces.errorBanner,
              tone: PdlBannerTone.danger,
              icon: PdlIcons.error,
              message: _error!,
              onDismiss: () => setState(() => _error = null),
              dismissSemanticLabel: 'common.close'.tr(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
          child: PdlSearchField(
            key: keys.teamPlaces.searchField,
            value: filters.search,
            hintText: 'places.searchPlaceholder'.tr(),
            clearTooltip: 'common.clearSearch'.tr(),
            onChanged: (String? value) =>
                _setFilters(filters.withSearch(value)),
          ),
        ),
      ],
    );
  }

  List<Widget> _placeSlivers(
    PagedListState<PlaceDetailDto> state,
    TeamPlacesNotifier notifier,
    PlaceFilters filters,
  ) {
    if (state.showsSkeletons) {
      return <Widget>[
        const SliverPadding(
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
      final String? search = filters.search?.trim();
      return <Widget>[
        ListStateSliver(
          child: search != null && search.isNotEmpty
              ? ListFilteredEmpty(
                  key: keys.teamPlaces.searchEmpty,
                  title: 'places.noResults'.tr(),
                  filters: <String>[quotedSearch(search)],
                  onClear: () => _setFilters(filters.cleared),
                )
              : PdlEmptyState(
                  key: keys.teamPlaces.empty,
                  variant: PdlEmptyVariant.empty,
                  icon: PdlIcons.place,
                  title: 'places.emptyTitle'.tr(),
                  message: 'places.emptyMessage'.tr(),
                ),
        ),
      ];
    }

    final int total = state.total ?? state.items.length;
    return <Widget>[
      SliverToBoxAdapter(
        child: ListResultCount(
          listCountLabel('places.count', total),
          textKey: keys.teamPlaces.resultCount,
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        sliver: SliverList.builder(
          itemCount: state.items.length,
          itemBuilder: (BuildContext context, int index) {
            notifier.onItemBuilt(index);
            final PlaceDetailDto place = state.items[index];
            return _PlaceRow(
              key: keys.teamPlaces.row(place.id),
              place: place,
              enabled: !_writing,
              showDivider: index < state.items.length - 1,
              onEdit: () => _openForm(place),
              onDelete: () => _delete(place),
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
            itemNounKey: 'places.noun',
          ),
        ),
      ),
    ];
  }
}

/// Une ligne de la liste : le nom, l'adresse, « Voir sur la carte » quand le
/// lieu a un lien, les badges d'usage, et les deux gestes.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    super.key,
    required this.place,
    required this.enabled,
    required this.showDivider,
    required this.onEdit,
    required this.onDelete,
  });

  final PlaceDetailDto place;
  final bool enabled;
  final bool showDivider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final String? address = place.address;
    final String? link = place.link;
    final Map<String, String> named = <String, String>{'name': place.name};

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: c.borderSubtle))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PdlSpacing.sectionTightV),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(PdlIcons.place, size: 20, color: c.textDimmed),
            ),
            const SizedBox(width: PdlSpacing.chipGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(place.name, style: t.bodyStrong),
                  if (address != null && address.isNotEmpty)
                    Text(address, style: t.sub.copyWith(color: c.textDimmed)),
                  if (place.startPlace || place.endPlace) ...<Widget>[
                    const SizedBox(height: PdlSpacing.badgeGap),
                    Wrap(
                      spacing: PdlSpacing.badgeGap,
                      runSpacing: PdlSpacing.badgeGap,
                      children: <Widget>[
                        if (place.startPlace)
                          PdlBadge(
                            key: keys.teamPlaces.rowStart(place.id),
                            label: 'places.start'.tr(),
                            tone: PdlFamily.green.soft(c),
                          ),
                        if (place.endPlace)
                          PdlBadge(
                            key: keys.teamPlaces.rowEnd(place.id),
                            label: 'places.end'.tr(),
                            tone: PdlFamily.blue.soft(c),
                          ),
                      ],
                    ),
                  ],
                  // Le lien quitte l'app : la carte d'un service tiers.
                  if (link != null && link.isNotEmpty)
                    PdlButton(
                      key: keys.teamPlaces.rowLink(place.id),
                      label: 'places.viewLink'.tr(),
                      icon: PdlIcons.openExternal,
                      variant: PdlButtonVariant.text,
                      size: PdlButtonSize.sm,
                      onPressed: () => openLink(context, link),
                    ),
                ],
              ),
            ),
            _RowAction(
              key: keys.teamPlaces.rowEdit(place.id),
              icon: PdlIcons.edit,
              tooltip: 'places.editSemantic'.tr(namedArgs: named),
              color: c.textDimmed,
              onPressed: enabled ? onEdit : null,
            ),
            _RowAction(
              key: keys.teamPlaces.rowDelete(place.id),
              icon: PdlIcons.delete,
              tooltip: 'places.deleteSemantic'.tr(namedArgs: named),
              color: c.danger,
              onPressed: enabled ? onDelete : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Un geste d'une ligne : 44 × 44, icône discrète, libellé pour les lecteurs
/// d'écran.
class _RowAction extends StatelessWidget {
  const _RowAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20, color: color),
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(
        width: PdlMetrics.tapTarget,
        height: PdlMetrics.tapTarget,
      ),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
    );
  }
}
