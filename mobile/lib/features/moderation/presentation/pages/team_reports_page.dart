import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/push_location.dart';
import '../../../../keys.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../teams/providers/team_access_probe.dart';
import '../../../teams/providers/team_permission_providers.dart';
import '../../../teams/providers/team_providers.dart';
import '../../data/moderation_repository.dart';
import '../../providers/moderation_refresh.dart';
import '../../providers/team_reports_provider.dart';

/// L'écran que montre un signalement : la publication elle-même, ou celle
/// qu'un commentaire commente. `null` pour un membre, un contenu disparu, ou
/// un type que cette version de l'app ne connaît pas — la ligne reste alors
/// un texte, plutôt qu'un lien vers une route qui n'existe pas.
String? moderationContentPath(ModerationItemDto item) {
  final String? slug = item.contentSlug;
  final String? type = item.contentType;
  if (slug == null || type == null) return null;
  final String team = item.teamSlug;
  return switch (ReportTargetType.fromJson(type)) {
    ReportTargetType.post => Paths.post(team, slug),
    ReportTargetType.ride => Paths.ride(team, slug),
    ReportTargetType.trip => Paths.trip(team, slug),
    ReportTargetType.route => Paths.route(team, slug),
    ReportTargetType.ad => Paths.ad(team, slug),
    ReportTargetType.comment ||
    ReportTargetType.member ||
    ReportTargetType.$unknown => null,
  };
}

/// Ce qui identifie une carte de la file : la cible. La file d'une équipe ne
/// porte que ses propres signalements, l'équipe n'entre donc pas dans la clé.
String moderationItemKey(ModerationItemDto item) =>
    '${item.targetType}_${item.targetId}';

/// « Signalements » — la file de modération d'une équipe, le pendant mobile de
/// `TeamReportsPage` du site (docs/LEDGER_*.md MOB-168) : une carte par cible
/// signalée, à supprimer ou à rejeter.
///
/// **Réservé à qui organise l'équipe et à l'admin de plateforme**, qui y
/// arrive par une notification `CONTENT_REPORTED` sans être membre. Le refus
/// est tranché **avant** que la file ne soit lue — elle n'est écoutée que par
/// le corps rendu une fois le droit établi.
///
/// Les personnes qui signalent restent anonymes : la file d'une équipe n'en
/// porte aucune, et cet écran n'en montre aucune.
class TeamReportsPage extends ConsumerWidget {
  const TeamReportsPage({super.key, required this.teamSlug});

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
      title: 'moderation.queue.title'.tr(),
      onBack: back,
      backSemanticLabel: 'common.back'.tr(),
    );

    Widget shell(Widget body) =>
        PdlScreenScaffold(appBar: appBar(), body: body);

    Widget forbidden({required bool teamReadable}) => shell(
      PdlEmptyState(
        key: keys.teamReports.forbidden,
        variant: PdlEmptyVariant.empty,
        icon: PdlIcons.admin,
        title: 'teams.manage.forbiddenTitle'.tr(),
        message: 'teams.manage.forbiddenMessage'.tr(),
        actions: <Widget>[
          PdlButton(
            key: keys.teamReports.forbiddenBack,
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
          key: keys.teamReports.loadError,
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

    // `null` tant que la fiche charge : ni file, ni refus. L'admin de
    // plateforme est compté parmi qui organise, membre ou non.
    final bool? organizer = ref.watch(isTeamOrganizerProvider(teamSlug));
    final bool? admin = ref.watch(isTeamAdminProvider(teamSlug));
    if (teamValue == null || organizer == null || admin == null) {
      return shell(const Center(child: CircularProgressIndicator.adaptive()));
    }
    if (!organizer) return forbidden(teamReadable: true);

    return _Reports(
      key: ValueKey<String>('${teamValue.id}@$teamSlug'),
      teamSlug: teamSlug,
      appBar: appBar(),
      canOpenMembers: admin,
    );
  }
}

/// Le corps de l'écran, rendu à qui modère l'équipe — et à lui seul : c'est
/// lui qui écoute la file.
class _Reports extends ConsumerStatefulWidget {
  const _Reports({
    super.key,
    required this.teamSlug,
    required this.appBar,
    required this.canOpenMembers,
  });

  final String teamSlug;
  final PdlAppBar appBar;

  /// La personne administre l'équipe : l'écran « Gestion des membres », où un
  /// membre signalé se retire, lui est ouvert.
  final bool canOpenMembers;

  @override
  ConsumerState<_Reports> createState() => _ReportsState();
}

class _ReportsState extends ConsumerState<_Reports> {
  ReportQueueStatus _status = ReportQueueStatus.open;

  /// La carte dont la décision est en cours ([moderationItemKey]) : les
  /// autres gestes attendent.
  String? _resolving;

  /// Ce que le serveur a refusé à une décision.
  String? _error;

  String get _slug => widget.teamSlug;

  TeamReportsKey get _queue => (teamSlug: _slug, status: _status);

  void _snack(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  /// Applique [action] à tous les signalements ouverts de la cible. Supprimer
  /// se confirme ; rejeter part aussitôt, comme au site.
  Future<void> _decide(ModerationItemDto item, ModerationAction action) async {
    if (_resolving != null) return;
    final bool removes = action == ModerationAction.removeContent;
    if (removes) {
      final bool confirmed = await confirmDestructive(
        context,
        title: 'moderation.queue.removeConfirm.title'.tr(),
        message: 'moderation.queue.removeConfirm.message'.tr(),
        confirmLabel: 'moderation.queue.actions.remove'.tr(),
      );
      if (!confirmed || !mounted || _resolving != null) return;
    }

    final ModerationRepository repository = ref.read(
      moderationRepositoryProvider,
    );
    // Pris avant l'`await` : l'écran peut être quitté avant la réponse.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ProviderContainer container = ProviderScope.containerOf(
      context,
      listen: false,
    );
    setState(() {
      _resolving = moderationItemKey(item);
      _error = null;
    });
    try {
      await repository.resolveTeamReports(
        _slug,
        targetType: item.targetType,
        targetId: item.targetId,
        action: action,
      );
      refreshAfterModerationDecision(
        container,
        teamSlug: _slug,
        item: item,
        action: action,
      );
      _snack(
        messenger,
        removes
            ? 'moderation.queue.removed'.tr()
            : 'moderation.queue.dismissed'.tr(),
      );
    } catch (error, stackTrace) {
      if (mounted) setState(() => _error = getErrorMessage(error, stackTrace));
    } finally {
      if (mounted) setState(() => _resolving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ModerationItemDto>> reports = ref.watch(
      teamReportsProvider(_queue),
    );

    return PdlScreenScaffold(
      appBar: widget.appBar,
      onRefresh: () => ref.refresh(teamReportsProvider(_queue).future),
      slivers: <Widget>[
        SliverToBoxAdapter(child: _header(context)),
        ..._queueSlivers(reports),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  /// La phrase d'introduction, les deux onglets, et le bandeau d'une décision
  /// refusée.
  Widget _header(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Padding(
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
            'moderation.queue.description'.tr(),
            style: t.sub.copyWith(color: c.textDimmed),
          ),
          const SizedBox(height: PdlSpacing.section),
          PdlSegmented<ReportQueueStatus>(
            value: _status,
            onChanged: (ReportQueueStatus status) =>
                setState(() => _status = status),
            segments: <PdlSegment<ReportQueueStatus>>[
              PdlSegment<ReportQueueStatus>(
                key: keys.teamReports.tab(ReportQueueStatus.open),
                value: ReportQueueStatus.open,
                label: 'moderation.queue.tabs.open'.tr(),
              ),
              PdlSegment<ReportQueueStatus>(
                key: keys.teamReports.tab(ReportQueueStatus.resolved),
                value: ReportQueueStatus.resolved,
                label: 'moderation.queue.tabs.resolved'.tr(),
              ),
            ],
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            PdlBanner(
              key: keys.teamReports.errorBanner,
              tone: PdlBannerTone.danger,
              icon: PdlIcons.error,
              message: _error!,
              onDismiss: () => setState(() => _error = null),
              dismissSemanticLabel: 'common.close'.tr(),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _queueSlivers(AsyncValue<List<ModerationItemDto>> reports) {
    // Une file déjà lue reste à l'écran pendant sa relecture (après une
    // décision) : ni squelettes, ni saut.
    final List<ModerationItemDto>? items = reports.value;
    if (items == null) {
      final Object? error = reports.error;
      return <Widget>[
        SliverToBoxAdapter(
          child: error == null
              ? const Padding(
                  padding: EdgeInsets.all(PdlSpacing.section),
                  child: PdlSkeletonCardList(
                    variant: PdlSkeletonCardVariant.compact,
                    count: 3,
                  ),
                )
              : PdlEmptyState(
                  key: keys.teamReports.listError,
                  variant: PdlEmptyVariant.error,
                  title: 'common.loadError'.tr(),
                  message: getErrorMessage(error),
                  actions: <Widget>[
                    PdlButton(
                      label: 'common.retry'.tr(),
                      onPressed: () =>
                          ref.invalidate(teamReportsProvider(_queue)),
                    ),
                  ],
                ),
        ),
      ];
    }

    if (items.isEmpty) {
      final bool open = _status == ReportQueueStatus.open;
      return <Widget>[
        SliverToBoxAdapter(
          child: PdlEmptyState(
            key: open
                ? keys.teamReports.emptyOpen
                : keys.teamReports.emptyResolved,
            variant: PdlEmptyVariant.empty,
            icon: PdlIcons.report,
            title: open
                ? 'moderation.queue.empty.open.title'.tr()
                : 'moderation.queue.empty.resolved.title'.tr(),
            message: open
                ? 'moderation.queue.empty.open.description'.tr()
                : 'moderation.queue.empty.resolved.description'.tr(),
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          PdlSpacing.section,
          PdlSpacing.section,
          PdlSpacing.section,
          0,
        ),
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (BuildContext _, int _) =>
              const SizedBox(height: PdlSpacing.teamCardGap),
          itemBuilder: (BuildContext context, int index) {
            final ModerationItemDto item = items[index];
            final String id = moderationItemKey(item);
            return _ReportCard(
              key: keys.teamReports.card(id),
              item: item,
              // Une décision à la fois : les autres cartes attendent.
              enabled: _resolving == null,
              resolving: _resolving == id,
              canOpenMembers: widget.canOpenMembers,
              onRemove: () => _decide(item, ModerationAction.removeContent),
              onDismiss: () => _decide(item, ModerationAction.dismiss),
            );
          },
        ),
      ),
    ];
  }
}

/// Une cible signalée, tous ses signalements regroupés : ce qu'elle est,
/// combien de fois et pourquoi elle a été signalée, et les deux décisions.
class _ReportCard extends StatelessWidget {
  const _ReportCard({
    super.key,
    required this.item,
    required this.enabled,
    required this.resolving,
    required this.canOpenMembers,
    required this.onRemove,
    required this.onDismiss,
  });

  final ModerationItemDto item;
  final bool enabled;
  final bool resolving;
  final bool canOpenMembers;
  final VoidCallback onRemove;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final String id = moderationItemKey(item);
    final ReportTargetType type = ReportTargetType.fromJson(item.targetType);
    final ReportStatus status = ReportStatus.fromJson(item.status);
    final bool isMember = type == ReportTargetType.member;
    final bool isOpen = status == ReportStatus.open;
    final DateTime? lastReported = AppFormatters.tryParseDisplayTime(
      item.lastReportedAt,
    );
    final String? contentName = item.contentName;
    final String? contentLabel = contentName == null
        ? null
        : type == ReportTargetType.comment
        ? 'moderation.queue.commentOn'.tr(
            namedArgs: <String, String>{'name': contentName},
          )
        : contentName;
    final String? path = moderationContentPath(item);
    final String? excerpt = item.excerpt;
    final Map<String, String> named = <String, String>{
      'name': item.targetUser.displayName,
    };

    return PdlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            spacing: PdlSpacing.badgeGap,
            runSpacing: PdlSpacing.badgeGap,
            children: <Widget>[
              PdlBadge(
                key: keys.teamReports.cardType(id),
                label: type == ReportTargetType.$unknown
                    ? 'moderation.targetType.other'.tr()
                    : 'moderation.targetType.${type.json}'.tr(),
                tone: PdlFamily.gray.soft(c),
              ),
              PdlBadge(
                key: keys.teamReports.cardCount(id),
                label: 'moderation.queue.reportCount'.plural(
                  item.reportCount,
                  args: <String>[AppFormatters.formatNumber(item.reportCount)],
                ),
                icon: PdlIcons.report,
                tone: PdlFamily.red.soft(c),
              ),
              if (item.hidden)
                PdlBadge(
                  key: keys.teamReports.cardHidden(id),
                  label: 'moderation.queue.hidden'.tr(),
                  tone: PdlFamily.yellow.soft(c),
                ),
              if (status == ReportStatus.removed)
                PdlBadge(
                  key: keys.teamReports.cardStatus(id),
                  label: 'moderation.status.REMOVED'.tr(),
                  tone: PdlFamily.red.soft(c),
                ),
              if (status == ReportStatus.dismissed)
                PdlBadge(
                  key: keys.teamReports.cardStatus(id),
                  label: 'moderation.status.DISMISSED'.tr(),
                  tone: PdlFamily.gray.soft(c),
                ),
            ],
          ),
          if (lastReported != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.badgeGap),
            Text(
              'moderation.queue.lastReported'.tr(
                namedArgs: <String, String>{
                  'date': AppFormatters.formatLongDateTime(lastReported),
                },
              ),
              style: t.xs.copyWith(color: c.textDimmed),
            ),
          ],

          // ── Le contenu ── Un lien quand il existe encore et que l'app en
          // a l'écran ; son nom seul sinon.
          if (contentLabel != null) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            if (path != null)
              _ContentLink(
                key: keys.teamReports.cardContentLink(id),
                label: contentLabel,
                onTap: () => pushLocation(context, path),
              )
            else
              Text(
                contentLabel,
                key: keys.teamReports.cardContentName(id),
                style: t.bodyStrong,
              ),
          ],
          if (!isMember && contentName == null) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            Text(
              'moderation.queue.contentGone'.tr(),
              key: keys.teamReports.cardContentGone(id),
              style: t.sub.copyWith(
                color: c.textDimmed,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // ── Qui ── L'auteur du contenu, ou le membre signalé — jamais qui
          // a signalé.
          const SizedBox(height: PdlSpacing.chipGap),
          Row(
            children: <Widget>[
              PdlAvatar(
                name: item.targetUser.displayName,
                imageUrl: item.targetUser.avatarUrl,
                size: 26,
              ),
              const SizedBox(width: PdlSpacing.chipGap),
              Expanded(
                child: Text(
                  isMember
                      ? 'moderation.queue.member'.tr(namedArgs: named)
                      : 'moderation.queue.author'.tr(namedArgs: named),
                  key: keys.teamReports.cardUser(id),
                  style: t.sub,
                ),
              ),
            ],
          ),

          // ── L'extrait ── Le texte tel qu'il était au premier signalement.
          if (excerpt != null && excerpt.isNotEmpty) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: PdlRadii.smAll,
              ),
              child: Padding(
                padding: const EdgeInsets.all(PdlSpacing.cardTight),
                child: Text(
                  excerpt,
                  key: keys.teamReports.cardExcerpt(id),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: t.sub,
                ),
              ),
            ),
          ],

          // ── Les motifs ──
          if (item.reasons.isNotEmpty) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            Wrap(
              spacing: PdlSpacing.badgeGap,
              runSpacing: PdlSpacing.badgeGap,
              children: <Widget>[
                for (final ReportReason reason in item.reasons)
                  if (reason != ReportReason.$unknown)
                    PdlBadge(
                      key: keys.teamReports.cardReason(id, reason),
                      label: 'moderation.reason.${reason.json}'.tr(),
                      tone: PdlFamily.gray.soft(c),
                    ),
              ],
            ),
          ],

          // ── Les précisions ── Le texte libre des signalements, sans nom.
          if (item.messages.isNotEmpty) ...<Widget>[
            const SizedBox(height: PdlSpacing.chipGap),
            Text('moderation.queue.messages'.tr(), style: t.bodyStrong),
            for (final String message in item.messages) ...<Widget>[
              const SizedBox(height: PdlSpacing.badgeGap),
              Text(message, style: t.sub.copyWith(color: c.textDimmed)),
            ],
          ],

          // ── Les décisions ── Sur une cible encore à traiter.
          if (isOpen) ...<Widget>[
            const SizedBox(height: PdlSpacing.section),
            Wrap(
              spacing: PdlSpacing.chipGap,
              runSpacing: PdlSpacing.chipGap,
              children: <Widget>[
                // Un membre ne se supprime pas d'ici.
                if (!isMember)
                  PdlButton(
                    key: keys.teamReports.removeButton(id),
                    label: 'moderation.queue.actions.remove'.tr(),
                    icon: PdlIcons.delete,
                    variant: PdlButtonVariant.danger,
                    size: PdlButtonSize.sm,
                    enabled: enabled,
                    onPressed: onRemove,
                  ),
                PdlButton(
                  key: keys.teamReports.dismissButton(id),
                  label: 'moderation.queue.actions.dismiss'.tr(),
                  icon: PdlIcons.check,
                  variant: PdlButtonVariant.outline,
                  size: PdlButtonSize.sm,
                  loading: resolving,
                  enabled: enabled,
                  onPressed: onDismiss,
                ),
              ],
            ),
            if (isMember) ...<Widget>[
              const SizedBox(height: PdlSpacing.chipGap),
              Text(
                'moderation.queue.memberHint'.tr(),
                key: keys.teamReports.memberHint(id),
                style: t.xs.copyWith(color: c.textDimmed),
              ),
              // Le lien n'est offert qu'à qui peut ouvrir l'écran.
              if (canOpenMembers)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PdlButton(
                    key: keys.teamReports.membersLink(id),
                    label: 'teams.manage.members'.tr(),
                    icon: PdlIcons.people,
                    variant: PdlButtonVariant.text,
                    size: PdlButtonSize.sm,
                    onPressed: () => pushLocation(
                      context,
                      Paths.teamAdminMembers(item.teamSlug),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Le nom du contenu signalé, en lien vers son écran dans l'app.
class _ContentLink extends StatelessWidget {
  const _ContentLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: PdlRadii.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: PdlMetrics.tapTarget),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(label, style: t.bodyStrong.copyWith(color: c.primary)),
          ),
        ),
      ),
    );
  }
}
