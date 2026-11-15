import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../api/pedalons_api_client.dart';
import '../../../../config/paths.dart';
import '../../../../core/lists/list_states.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/widgets/row_icon_action.dart';
import '../../../../keys.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../teams/providers/team_access_probe.dart';
import '../../../teams/providers/team_permission_providers.dart';
import '../../../teams/providers/team_providers.dart';
import '../../domain/tag_form.dart';
import '../../providers/team_tags_change.dart';
import '../../providers/team_tags_provider.dart';
import '../widgets/tag_form_sheet.dart';

/// « Tags » — le pendant mobile de `TeamTagsPage` du site (docs/LEDGER_*.md
/// MOB-169) : le vocabulaire de tags de l'équipe, un type de contenu à la
/// fois, à créer, renommer, recolorer et supprimer, chacun avec son usage.
///
/// **Réservé à l'administration de l'équipe** (et à l'admin de plateforme) :
/// un organisateur pose des tags sur ses contenus, il n'en crée pas (plan des
/// tags, D4). Le refus est tranché **avant** que la moindre requête de tags ne
/// parte — le vocabulaire n'est écouté que par le corps rendu une fois le
/// droit établi.
class TeamTagsAdminPage extends ConsumerWidget {
  const TeamTagsAdminPage({super.key, required this.teamSlug, this.type});

  final String teamSlug;

  /// Le `?type=` de la route (`ride`, `post`, `trip`, `route`, `ad`) : le type
  /// à ouvrir, comme au site. Absent ou inconnu, le premier proposé.
  final String? type;

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
      title: 'tags.admin.title'.tr(),
      onBack: back,
      backSemanticLabel: 'common.back'.tr(),
    );

    Widget shell(Widget body) =>
        PdlScreenScaffold(appBar: appBar(), body: body);

    Widget forbidden({required bool teamReadable}) => shell(
      PdlEmptyState(
        key: keys.teamTags.forbidden,
        variant: PdlEmptyVariant.empty,
        icon: PdlIcons.admin,
        title: 'tags.admin.forbiddenTitle'.tr(),
        message: 'tags.admin.forbiddenMessage'.tr(),
        actions: <Widget>[
          PdlButton(
            key: keys.teamTags.forbiddenBack,
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
          key: keys.teamTags.loadError,
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

    return _Tags(
      key: ValueKey<String>('${teamValue.id}@$teamSlug'),
      team: teamValue,
      teamSlug: teamSlug,
      requested: tagKindFromQuery(type),
      appBar: appBar(),
    );
  }
}

/// Le corps de l'écran, rendu à qui administre l'équipe — et à lui seul :
/// c'est lui qui écoute le vocabulaire.
class _Tags extends ConsumerStatefulWidget {
  const _Tags({
    super.key,
    required this.team,
    required this.teamSlug,
    required this.requested,
    required this.appBar,
  });

  final TeamDetailDto team;
  final String teamSlug;
  final TagTarget? requested;
  final PdlAppBar appBar;

  @override
  ConsumerState<_Tags> createState() => _TagsState();
}

class _TagsState extends ConsumerState<_Tags> {
  /// Le type choisi : celui de la route, puis celui de la dernière puce
  /// touchée. Ignoré s'il n'est pas (ou plus) proposé.
  late TagTarget? _kind = widget.requested;

  /// Un geste est en cours — une feuille ouverte, une confirmation, une
  /// suppression : les autres attendent. Posé **avant** d'ouvrir la feuille,
  /// pour qu'un double appui n'en ouvre pas deux.
  bool _busy = false;

  /// Ce que le serveur a refusé à une suppression, dans la barre épinglée.
  String? _error;

  String get _slug => widget.teamSlug;

  void _snack(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  /// Ouvre le formulaire — d'un nouveau tag de [kind], ou de [tag]. La
  /// feuille enregistre et fait relire le vocabulaire ; l'écran confirme.
  Future<void> _openForm(TagTarget kind, [TagWithUsageDto? tag]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final TagWithUsageDto? saved = await showTagFormSheet(
        context,
        _slug,
        type: kind,
        tag: tag,
      );
      if (saved == null) return;
      _snack(
        messenger,
        tag == null ? 'tags.admin.created'.tr() : 'tags.admin.updated'.tr(),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(TagWithUsageDto tag) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final TagsClient client = ref.read(tagsClientProvider);
    // Pris avant l'`await` : l'écran peut être quitté avant la réponse.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    final Color chipColor = tagFamily(tag.color).soft(context.pdl).fill;
    try {
      final bool confirmed = await confirmDestructive(
        context,
        title: 'tags.admin.deleteConfirm.title'.tr(),
        leading: PdlTag(
          key: keys.teamTags.deleteChip,
          label: tag.label,
          color: chipColor,
        ),
        message: tag.usageCount > 0
            ? listCountLabel('tags.admin.deleteConfirm.used', tag.usageCount)
            : 'tags.admin.deleteConfirm.unused'.tr(),
        confirmLabel: 'tags.admin.deleteConfirm.confirm'.tr(),
      );
      if (!confirmed) return;
      final TagDeletedDto result = await client.deleteTeamTag(
        teamSlug: _slug,
        tagId: tag.id,
      );
      notifyTeamTagsChanged(
        container,
        TeamTagChange.deleted(_slug, TagTarget.fromJson(tag.type)),
      );
      // Zéro se dit à part : en français, la règle de pluriel le range avec
      // « un ».
      _snack(
        messenger,
        result.detachedCount > 0
            ? listCountLabel('tags.admin.deleted', result.detachedCount)
            : 'tags.admin.deletedUnused'.tr(),
      );
    } catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(teamAllTagsProvider(_slug));
    try {
      await ref.read(teamAllTagsProvider(_slug).future);
    } catch (_) {
      // L'échec se rend par l'état d'erreur de la liste.
    }
  }

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final AsyncValue<List<TagWithUsageDto>> tags = ref.watch(
      teamAllTagsProvider(_slug),
    );
    // Les lignes déjà lues restent à l'écran pendant une relecture.
    final List<TagWithUsageDto>? loaded = tags.value;
    final Map<TagTarget, List<TagWithUsageDto>> byKind = tagsByKind(
      loaded ?? const <TagWithUsageDto>[],
    );
    final List<TagTarget> kinds = offeredTagKinds(widget.team, byKind);
    final TagTarget? chosen = _kind;
    final TagTarget? current = chosen != null && kinds.contains(chosen)
        ? chosen
        : kinds.firstOrNull;
    final List<TagWithUsageDto> currentTags = current == null
        ? const <TagWithUsageDto>[]
        : byKind[current]!;
    final bool atLimit = currentTags.length >= kTagLimitPerKind;

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
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'tags.admin.description'.tr(),
                  style: t.sub.copyWith(color: c.textDimmed),
                ),
                if (current != null) ...<Widget>[
                  const SizedBox(height: PdlSpacing.chipGap),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: PdlButton(
                      key: keys.teamTags.addButton,
                      label: 'tags.admin.add'.tr(),
                      icon: PdlIcons.add,
                      size: PdlButtonSize.sm,
                      // Tant que le vocabulaire n'est pas lu, la limite ne
                      // l'est pas non plus.
                      enabled: !_busy && !atLimit && loaded != null,
                      onPressed: () => _openForm(current),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (current != null || _error != null)
          PdlPinnedToolbar(child: _toolbar(kinds, current, byKind)),
        if (current == null)
          // Tant que le vocabulaire charge, un type sans section pourrait
          // encore se révéler porteur de tags : pas de verdict avant.
          ListStateSliver(
            child: loaded == null && !tags.hasError
                ? const Center(child: CircularProgressIndicator.adaptive())
                : loaded == null
                ? _tagsError(tags.error!)
                : PdlEmptyState(
                    key: keys.teamTags.noKind,
                    variant: PdlEmptyVariant.empty,
                    icon: PdlIcons.tag,
                    title: 'tags.admin.noKind.title'.tr(),
                    message: 'tags.admin.noKind.description'.tr(),
                  ),
          )
        else ...<Widget>[
          if (loaded != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PdlSpacing.section,
                  PdlSpacing.chipGap,
                  PdlSpacing.section,
                  0,
                ),
                child: Text(
                  'tags.admin.limit'.tr(
                    namedArgs: <String, String>{
                      'used': '${currentTags.length}',
                      'max': '$kTagLimitPerKind',
                    },
                  ),
                  key: keys.teamTags.limit,
                  style: t.xs.copyWith(
                    color: atLimit ? c.danger : c.textDimmed,
                  ),
                ),
              ),
            ),
          ..._tagSlivers(tags, loaded, current, currentTags),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  Widget _tagsError(Object error) => ListLoadError(
    key: keys.teamTags.tagsError,
    error: error,
    onRetry: () => ref.invalidate(teamAllTagsProvider(_slug)),
  );

  /// La barre épinglée : le bandeau d'erreur et une puce par type, avec son
  /// compte.
  Widget _toolbar(
    List<TagTarget> kinds,
    TagTarget? current,
    Map<TagTarget, List<TagWithUsageDto>> byKind,
  ) {
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
              key: keys.teamTags.errorBanner,
              tone: PdlBannerTone.danger,
              icon: PdlIcons.error,
              message: _error!,
              onDismiss: () => setState(() => _error = null),
              dismissSemanticLabel: 'common.close'.tr(),
            ),
          ),
        if (kinds.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.section),
            child: Row(
              children: <Widget>[
                for (final TagTarget kind in kinds) ...<Widget>[
                  if (kind != kinds.first)
                    const SizedBox(width: PdlSpacing.chipGap),
                  PdlChip(
                    key: keys.teamTags.kind(kind.json!),
                    label: 'tags.admin.kindCount'.tr(
                      namedArgs: <String, String>{
                        'kind': 'tags.admin.kind.${kind.json!}'.tr(),
                        'count': '${byKind[kind]!.length}',
                      },
                    ),
                    selected: kind == current,
                    onTap: () => setState(() => _kind = kind),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _tagSlivers(
    AsyncValue<List<TagWithUsageDto>> tags,
    List<TagWithUsageDto>? loaded,
    TagTarget current,
    List<TagWithUsageDto> currentTags,
  ) {
    if (loaded == null) {
      return <Widget>[
        ListStateSliver(
          child: tags.hasError
              ? _tagsError(tags.error!)
              : const Center(child: CircularProgressIndicator.adaptive()),
        ),
      ];
    }

    if (currentTags.isEmpty) {
      return <Widget>[
        ListStateSliver(
          child: PdlEmptyState(
            key: keys.teamTags.empty,
            variant: PdlEmptyVariant.empty,
            icon: PdlIcons.tag,
            title: 'tags.admin.empty.title'.tr(),
            message: 'tags.admin.empty.${current.json!}'.tr(),
            actions: <Widget>[
              PdlButton(
                key: keys.teamTags.emptyAddButton,
                label: 'tags.admin.add'.tr(),
                icon: PdlIcons.add,
                enabled: !_busy,
                onPressed: () => _openForm(current),
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
          itemCount: currentTags.length,
          itemBuilder: (BuildContext context, int index) {
            final TagWithUsageDto tag = currentTags[index];
            return _TagRow(
              key: keys.teamTags.row(tag.id),
              tag: tag,
              enabled: !_busy,
              showDivider: index < currentTags.length - 1,
              onEdit: () => _openForm(current, tag),
              onDelete: () => _delete(tag),
            );
          },
        ),
      ),
    ];
  }
}

/// Une ligne du vocabulaire : la puce du tag, son usage, et les deux gestes.
class _TagRow extends StatelessWidget {
  const _TagRow({
    super.key,
    required this.tag,
    required this.enabled,
    required this.showDivider,
    required this.onEdit,
    required this.onDelete,
  });

  final TagWithUsageDto tag;
  final bool enabled;
  final bool showDivider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final Map<String, String> named = <String, String>{'label': tag.label};

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: c.borderSubtle))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PdlSpacing.badgeGap),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Wrap(
                spacing: PdlSpacing.chipGap,
                runSpacing: PdlSpacing.badgeGap,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  PdlTag(
                    key: keys.teamTags.rowChip(tag.id),
                    label: tag.label,
                    color: tagFamily(tag.color).soft(c).fill,
                  ),
                  Text(
                    tag.usageCount > 0
                        ? listCountLabel('tags.admin.usage', tag.usageCount)
                        : 'tags.admin.unused'.tr(),
                    key: keys.teamTags.rowUsage(tag.id),
                    style: t.sub.copyWith(color: c.textDimmed),
                  ),
                ],
              ),
            ),
            RowIconAction(
              key: keys.teamTags.rowEdit(tag.id),
              icon: PdlIcons.edit,
              tooltip: 'tags.admin.editSemantic'.tr(namedArgs: named),
              color: c.textDimmed,
              onPressed: enabled ? onEdit : null,
            ),
            RowIconAction(
              key: keys.teamTags.rowDelete(tag.id),
              icon: PdlIcons.delete,
              tooltip: 'tags.admin.deleteSemantic'.tr(namedArgs: named),
              color: c.danger,
              onPressed: enabled ? onDelete : null,
            ),
          ],
        ),
      ),
    );
  }
}
