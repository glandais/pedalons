import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../api/pedalons_api_client.dart';
import '../../../../config/paths.dart';
import '../../../../core/lists/list_states.dart';
import '../../../../core/material.dart' hide Visibility;
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/widgets/deleted_badge.dart';
import '../../../../core/widgets/row_icon_action.dart';
import '../../../../keys.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../visibility/presentation/visibility_badge.dart';
import '../../domain/team_page_form.dart';
import '../../providers/team_access_probe.dart';
import '../../providers/team_pages_provider.dart';
import '../../providers/team_permission_providers.dart';
import '../../providers/team_providers.dart';

/// « Pages de l'équipe » — le pendant mobile de `TeamPagesAdminPage` du site
/// (docs/LEDGER_*.md MOB-169) : les pages personnalisées de l'équipe (trois au
/// plus), à créer, modifier, réordonner, supprimer et restaurer.
///
/// **Réservé à l'administration de l'équipe** (et à l'admin de plateforme). Le
/// refus est tranché **avant** que la moindre requête de pages ne parte — la
/// liste, qui porte les pages supprimées, n'est écoutée que par le corps rendu
/// une fois le droit établi.
class TeamPagesAdminPage extends ConsumerWidget {
  const TeamPagesAdminPage({super.key, required this.teamSlug});

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
      title: 'teams.pages.title'.tr(),
      onBack: back,
      backSemanticLabel: 'common.back'.tr(),
    );

    Widget shell(Widget body) =>
        PdlScreenScaffold(appBar: appBar(), body: body);

    Widget forbidden({required bool teamReadable}) => shell(
      PdlEmptyState(
        key: keys.teamPages.forbidden,
        variant: PdlEmptyVariant.empty,
        icon: PdlIcons.admin,
        title: 'teams.pages.forbiddenTitle'.tr(),
        message: 'teams.pages.forbiddenMessage'.tr(),
        actions: <Widget>[
          PdlButton(
            key: keys.teamPages.forbiddenBack,
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
    // Une fiche déjà lue reste l'écran en cours : chaque écriture la relit
    // (`notifyTeamPagesChanged`), et une relecture en échec ne le remplace pas
    // par une erreur.
    if (teamValue == null && error != null) {
      // Une équipe que le serveur refuse (403, ou 404 pour une équipe privée
      // dont on n'est pas membre) : un refus, pas une panne à réessayer.
      if (isTeamAccessRefusal(error)) return forbidden(teamReadable: false);
      return shell(
        PdlEmptyState(
          key: keys.teamPages.loadError,
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
    final bool? admin = ref.watch(isTeamAdminProvider(teamSlug));
    if (teamValue == null || admin == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }
    if (!admin) return forbidden(teamReadable: true);

    return _Pages(
      key: ValueKey<String>('${teamValue.id}@$teamSlug'),
      teamSlug: teamSlug,
      appBar: appBar(),
    );
  }
}

/// Le corps de l'écran, rendu à qui administre l'équipe — et à lui seul :
/// c'est lui qui écoute la liste des pages.
class _Pages extends ConsumerStatefulWidget {
  const _Pages({super.key, required this.teamSlug, required this.appBar});

  final String teamSlug;
  final PdlAppBar appBar;

  @override
  ConsumerState<_Pages> createState() => _PagesState();
}

class _PagesState extends ConsumerState<_Pages> {
  /// Un geste est en cours — une confirmation ouverte, une écriture : les
  /// autres attendent. Posé **avant** d'ouvrir la confirmation, pour qu'un
  /// double appui n'en ouvre pas deux.
  bool _busy = false;

  /// Ce que le serveur a refusé à une écriture.
  String? _error;

  String get _slug => widget.teamSlug;

  void _snack(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  /// Lance [write] — une écriture à la fois —, fait relire ce qu'elle change
  /// et confirme par [done] ; un refus du serveur se lit dans le bandeau.
  /// [confirm], s'il est donné, est demandé d'abord : `false` n'envoie rien.
  Future<void> _write({
    required Future<void> Function(TeamPagesClient client) write,
    required String done,
    Future<bool> Function()? confirm,
    List<String> pageSlugs = const <String>[],
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final TeamPagesClient client = ref.read(teamPagesClientProvider);
    // Pris avant l'`await` : l'écran peut être quitté avant la réponse.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    try {
      if (confirm != null && !await confirm()) return;
      await write(client);
      notifyTeamPagesChanged(container, _slug, pageSlugs: pageSlugs);
      _snack(messenger, done);
    } catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Monte ou descend d'un rang la page d'index [index] : la liste complète
  /// des identifiants part, dans son nouvel ordre.
  Future<void> _move(
    List<TeamPageSummaryDto> pages,
    int index, {
    required bool up,
  }) async {
    final List<String>? ids = movedTeamPageIds(pages, index, up: up);
    if (ids == null) return;
    await _write(
      done: 'teams.pages.reordered'.tr(),
      write: (TeamPagesClient client) => client.reorderPages(
        teamSlug: _slug,
        body: ReorderPagesRequest(pageIds: ids),
      ),
    );
  }

  Future<void> _delete(TeamPageSummaryDto page) => _write(
    done: 'teams.pages.deleted'.tr(),
    pageSlugs: <String>[page.slug],
    confirm: () => confirmDestructive(
      context,
      title: 'teams.pages.deleteConfirm.title'.tr(),
      message: 'teams.pages.deleteConfirm.message'.tr(
        namedArgs: <String, String>{'name': page.title},
      ),
      confirmLabel: 'common.delete'.tr(),
    ),
    write: (TeamPagesClient client) =>
        client.deletePage(teamSlug: _slug, pageSlug: page.slug),
  );

  Future<void> _restore(TeamPageSummaryDto page) => _write(
    done: 'teams.pages.restored'.tr(),
    pageSlugs: <String>[page.slug],
    write: (TeamPagesClient client) =>
        client.undeletePage(teamSlug: _slug, pageSlug: page.slug),
  );

  void _openNew() {
    if (_busy) return;
    context.push(Paths.teamAdminPageNew(_slug));
  }

  void _openEdit(TeamPageSummaryDto page) {
    if (_busy) return;
    context.push(Paths.teamAdminPageEdit(_slug, page.slug));
  }

  Future<void> _refresh() async {
    ref.invalidate(teamAdminPagesProvider(_slug));
    try {
      await ref.read(teamAdminPagesProvider(_slug).future);
    } catch (_) {
      // L'échec se rend par l'état d'erreur de la liste.
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final AsyncValue<List<TeamPageSummaryDto>> async = ref.watch(
      teamAdminPagesProvider(_slug),
    );
    // Les lignes déjà lues restent à l'écran pendant une relecture.
    final List<TeamPageSummaryDto>? pages = async.value;
    final int live = pages == null ? 0 : liveTeamPageCount(pages);
    // Les pages à la corbeille ne comptent pas : le serveur ne les compte pas
    // non plus.
    final bool canAdd = pages != null && live < kTeamPageLimit;

    return PdlScreenScaffold(
      appBar: widget.appBar,
      onRefresh: _refresh,
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PdlSpacing.section,
              PdlSpacing.section,
              PdlSpacing.section,
              PdlSpacing.chipGap,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_error != null) ...<Widget>[
                  PdlBanner(
                    key: keys.teamPages.errorBanner,
                    tone: PdlBannerTone.danger,
                    icon: PdlIcons.error,
                    message: _error!,
                    onDismiss: () => setState(() => _error = null),
                    dismissSemanticLabel: 'common.close'.tr(),
                  ),
                  const SizedBox(height: PdlSpacing.chipGap),
                ],
                if (pages != null)
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'teams.pages.count'.plural(
                            live,
                            namedArgs: <String, String>{
                              'max': '$kTeamPageLimit',
                            },
                          ),
                          key: keys.teamPages.count,
                          style: t.sub.copyWith(color: c.textDimmed),
                        ),
                      ),
                      // À trois pages, le bouton disparaît : il n'y a plus
                      // rien à ajouter.
                      if (canAdd && pages.isNotEmpty) ...<Widget>[
                        const SizedBox(width: PdlSpacing.chipGap),
                        PdlButton(
                          key: keys.teamPages.addButton,
                          label: 'teams.pages.add'.tr(),
                          icon: PdlIcons.add,
                          size: PdlButtonSize.sm,
                          enabled: !_busy,
                          onPressed: _openNew,
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
        ..._pageSlivers(async, pages, canAdd),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  List<Widget> _pageSlivers(
    AsyncValue<List<TeamPageSummaryDto>> async,
    List<TeamPageSummaryDto>? pages,
    bool canAdd,
  ) {
    if (pages == null) {
      return <Widget>[
        ListStateSliver(
          child: async.hasError
              ? ListLoadError(
                  key: keys.teamPages.listError,
                  error: async.error!,
                  onRetry: () => ref.invalidate(teamAdminPagesProvider(_slug)),
                )
              : const Center(child: CircularProgressIndicator.adaptive()),
        ),
      ];
    }

    if (pages.isEmpty) {
      return <Widget>[
        ListStateSliver(
          child: PdlEmptyState(
            key: keys.teamPages.empty,
            variant: PdlEmptyVariant.empty,
            icon: PdlIcons.page,
            title: 'teams.pages.emptyTitle'.tr(),
            message: 'teams.pages.emptyMessage'.tr(),
            actions: <Widget>[
              PdlButton(
                key: keys.teamPages.emptyAddButton,
                label: 'teams.pages.add'.tr(),
                icon: PdlIcons.add,
                enabled: !_busy,
                onPressed: _openNew,
              ),
            ],
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
        sliver: SliverList.builder(
          itemCount: pages.length,
          itemBuilder: (BuildContext context, int index) {
            final TeamPageSummaryDto page = pages[index];
            return _PageRow(
              key: keys.teamPages.row(page.id),
              page: page,
              enabled: !_busy,
              showDivider: index < pages.length - 1,
              // La première ne monte pas, la dernière ne descend pas.
              onMoveUp: index == 0 ? null : () => _move(pages, index, up: true),
              onMoveDown: index == pages.length - 1
                  ? null
                  : () => _move(pages, index, up: false),
              onEdit: () => _openEdit(page),
              onDelete: () => _delete(page),
              onRestore: () => _restore(page),
            );
          },
        ),
      ),
    ];
  }
}

/// Une ligne de la liste : le titre, la visibilité (et « Supprimé » pour une
/// page à la corbeille), puis les gestes — monter, descendre, modifier,
/// supprimer ; une page supprimée n'offre que d'être restaurée, et de changer
/// de rang.
class _PageRow extends StatelessWidget {
  const _PageRow({
    super.key,
    required this.page,
    required this.enabled,
    required this.showDivider,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final TeamPageSummaryDto page;
  final bool enabled;
  final bool showDivider;

  /// `null` : la ligne est déjà au bout, le bouton n'est pas rendu.
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final Map<String, String> named = <String, String>{'name': page.title};
    final Visibility visibility = Visibility.fromJson(page.visibility);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: c.borderSubtle))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PdlSpacing.sectionTightV),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              page.title,
              key: keys.teamPages.rowTitle(page.id),
              style: t.bodyStrong,
            ),
            const SizedBox(height: PdlSpacing.badgeGap),
            Wrap(
              spacing: PdlSpacing.badgeGap,
              runSpacing: PdlSpacing.badgeGap,
              children: <Widget>[
                // Une visibilité que cette version ne connaît pas ne se
                // badge pas : elle ne saurait pas la nommer.
                if (visibility != Visibility.$unknown)
                  VisibilityBadge(
                    key: keys.teamPages.rowVisibility(page.id),
                    visibility: visibility,
                  ),
                if (page.deleted)
                  DeletedBadge(key: keys.teamPages.rowDeleted(page.id)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (onMoveUp != null)
                  RowIconAction(
                    key: keys.teamPages.rowMoveUp(page.id),
                    icon: PdlIcons.chevronUp,
                    tooltip: 'teams.pages.moveUpSemantic'.tr(namedArgs: named),
                    color: c.textDimmed,
                    onPressed: enabled ? onMoveUp : null,
                  ),
                if (onMoveDown != null)
                  RowIconAction(
                    key: keys.teamPages.rowMoveDown(page.id),
                    icon: PdlIcons.chevronDown,
                    tooltip: 'teams.pages.moveDownSemantic'.tr(
                      namedArgs: named,
                    ),
                    color: c.textDimmed,
                    onPressed: enabled ? onMoveDown : null,
                  ),
                if (page.deleted)
                  RowIconAction(
                    key: keys.teamPages.rowRestore(page.id),
                    icon: PdlIcons.restore,
                    tooltip: 'teams.pages.restoreSemantic'.tr(namedArgs: named),
                    color: c.success,
                    onPressed: enabled ? onRestore : null,
                  )
                else ...<Widget>[
                  RowIconAction(
                    key: keys.teamPages.rowEdit(page.id),
                    icon: PdlIcons.edit,
                    tooltip: 'teams.pages.editSemantic'.tr(namedArgs: named),
                    color: c.textDimmed,
                    onPressed: enabled ? onEdit : null,
                  ),
                  RowIconAction(
                    key: keys.teamPages.rowDelete(page.id),
                    icon: PdlIcons.delete,
                    tooltip: 'teams.pages.deleteSemantic'.tr(namedArgs: named),
                    color: c.danger,
                    onPressed: enabled ? onDelete : null,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
