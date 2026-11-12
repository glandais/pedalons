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
import '../../../../core/utils/formatters.dart';
import '../../../auth/domain/auth_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../../teams/providers/team_providers.dart';
import '../../data/comment_repository.dart';
import '../../providers/comment_thread_provider.dart';
import '../../../../keys.dart';

/// Le fil de commentaires — un niveau de réponse, pas deux.
///
/// Un fil de discussion imbriqué sans limite finit en escalier de 20 px de
/// large sur un téléphone. La maquette n'en montre qu'un niveau, et l'API le
/// permet sans le forcer : répondre à une réponse rattache au même parent.
class CommentThread extends ConsumerStatefulWidget {
  const CommentThread({
    super.key,
    required this.target,
    this.canComment = true,
    this.countAtEnd = false,
  });

  final CommentTarget target;

  /// Les commentaires sont réservés aux membres : un non-membre lit le fil
  /// mais ne voit pas le composeur.
  final bool canComment;

  /// Le compte à droite du titre, en 12 gris (« 2 commentaires ») : le
  /// gabarit `DetailSection` des écrans de détail refaits (ledger `MOB-134`).
  final bool countAtEnd;

  @override
  ConsumerState<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends ConsumerState<CommentThread> {
  final TextEditingController _composer = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// À qui l'on répond, s'il y a lieu. Un seul composeur pour tout le fil :
  /// la maquette en montrait deux formes, elles sont unifiées sur celle-ci.
  CommentDto? _replyTo;
  bool _posting = false;
  Object? _error;

  @override
  void dispose() {
    _composer.dispose();
    _focus.dispose();
    super.dispose();
  }

  CommentThreadNotifier get _notifier =>
      ref.read(commentThreadProvider(widget.target).notifier);

  @override
  Widget build(BuildContext context) {
    final PagedListState<CommentDto> state = ref.watch(
      commentThreadProvider(widget.target),
    );
    final String? currentUserId = ref.watch(
      authProvider.select((AuthState s) => s.user?.id),
    );
    final bool platformAdmin = ref.watch(
      authProvider.select(
        (AuthState s) => s.user?.platformRole == 'PLATFORM_ADMIN',
      ),
    );
    // Le rôle vient de « Mes équipes », déjà chargée par l'écran pour savoir
    // si l'on est membre : aucun appel de plus par fil.
    final TeamDetailDto? team = ref
        .watch(myTeamsProvider)
        .value
        ?.where((TeamDetailDto t) => t.slug == widget.target.teamSlug)
        .firstOrNull;
    final _Viewer viewer = _Viewer(
      userId: currentUserId,
      moderates:
          platformAdmin || team?.role == 'ORGANIZER' || team?.role == 'ADMIN',
      teamName: team?.name,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PdlSectionHeader(
          title: 'rides.comments'.tr(),
          count: state.total == null
              ? null
              : 'comments.count'.plural(state.total!),
          countAtEnd: widget.countAtEnd,
          padding: const EdgeInsets.only(bottom: 10),
        ),
        if (widget.canComment) ...<Widget>[
          _composerRow(context),
          const SizedBox(height: 14),
        ],
        if (_error != null) ...<Widget>[
          PdlBanner(
            tone: PdlBannerTone.danger,
            message: getErrorMessage(_error!),
            onDismiss: () => setState(() => _error = null),
            dismissSemanticLabel: 'common.close'.tr(),
          ),
          const SizedBox(height: 14),
        ],
        if (state.isLoadingInitial)
          const PdlSkeletonCard(variant: PdlSkeletonCardVariant.person)
        else if (state.initialError != null)
          PdlEmptyState(
            variant: PdlEmptyVariant.error,
            title: 'common.loadError'.tr(),
            message: getErrorMessage(state.initialError!),
            actions: <Widget>[
              PdlButton(
                label: 'common.retry'.tr(),
                variant: PdlButtonVariant.outline,
                onPressed: _notifier.loadFirstPage,
              ),
            ],
          )
        else if (state.items.isEmpty)
          PdlEmptyState(
            variant: PdlEmptyVariant.empty,
            title: 'comments.emptyTitle'.tr(),
            message: 'comments.emptyMessage'.tr(),
          )
        else
          for (final CommentDto comment in state.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _thread(comment, viewer),
            ),
        // Le fil est une `Column` posée dans le défilement de la page, pas une
        // liste paresseuse : `onItemBuilt` y chargerait toutes les pages d'un
        // coup, chacune construisant la suivante. La suite part donc quand le
        // pied approche de l'écran — et « Voir plus », comme sur le web, reste
        // là pour qui ne défile pas (`docs/LEDGER_*.md MOB-34`).
        if (state.hasMore &&
            !state.isLoadingNext &&
            state.nextError == null &&
            state.items.isNotEmpty)
          _NearViewportTrigger(
            // Un déclencheur neuf par page : la page suivante arrive souvent
            // avant la frame qui aurait démonté celui-ci, et l'élément réutilisé
            // garderait son « déjà déclenché ».
            key: ValueKey<int>(state.items.length),
            onNear: _notifier.loadNextPage,
            child: Center(
              child: PdlButton(
                key: keys.comments.loadMoreButton,
                label: 'comments.loadMore'.tr(),
                variant: PdlButtonVariant.text,
                size: PdlButtonSize.sm,
                onPressed: _notifier.loadNextPage,
              ),
            ),
          )
        else if (state.hasMore || state.nextError != null)
          PdlPagedListFooter(
            isLoadingNext: state.isLoadingNext,
            hasMore: state.hasMore,
            isEmpty: state.items.isEmpty,
            hasError: state.nextError != null,
            progressLabel: 'comments.progress'.tr(
              namedArgs: <String, String>{
                'loaded': '${state.items.length}',
                'total': '${state.total ?? state.items.length}',
              },
            ),
            loadingLabel: 'pagination.loadingMore'.tr(),
            endLabel: 'pagination.endOfList'.tr(),
            errorLabel: 'pagination.nextPageError'.tr(),
            retryLabel: 'common.retry'.tr(),
            onRetry: _notifier.loadNextPage,
          ),
      ],
    );
  }

  // ── Un fil : le commentaire racine et ses réponses ──────────────────────
  Widget _thread(CommentDto comment, _Viewer viewer) {
    final PdlColors c = context.pdl;
    final List<CommentDto> replies = _notifier.repliesOf(comment);

    return Column(
      key: keys.comments.thread(comment.id),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _comment(comment, viewer),
        for (final CommentDto reply in replies)
          Padding(
            padding: const EdgeInsets.only(top: 14, left: 14),
            child: Container(
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: c.borderSubtle, width: 2),
                ),
              ),
              child: _comment(reply, viewer, isReply: true),
            ),
          ),
        if (_notifier.hasMoreReplies(comment))
          Align(
            alignment: Alignment.centerLeft,
            child: PdlButton(
              label: 'comments.showReplies'.plural(
                comment.replyCount - replies.length,
              ),
              variant: PdlButtonVariant.text,
              size: PdlButtonSize.sm,
              onPressed: () => _notifier.loadReplies(comment),
            ),
          ),
      ],
    );
  }

  Widget _comment(CommentDto comment, _Viewer viewer, {bool isReply = false}) {
    final String? currentUserId = viewer.userId;
    final PdlTypography t = context.pdlText;
    // Le commentaire d'un compte supprimé, gardé seulement pour porter les
    // réponses des autres : ni auteur, ni date, ni action.
    if (comment.deleted) {
      return Text(
        'comments.deletedPlaceholder'.tr(),
        style: t.xs.copyWith(fontStyle: FontStyle.italic),
      );
    }
    final bool mine = comment.author.id == currentUserId;
    final DateTime? createdAt = DateTime.tryParse(comment.createdAt);

    return Row(
      key: keys.comments.comment(comment.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PdlAvatar(
          name: comment.author.displayName,
          imageUrl: comment.author.avatarUrl,
          size: 40,
          isCurrentUser: mine,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            comment.author.displayName,
                            style: t.bodyStrong.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: PdlSpacing.chipGap),
                        if (createdAt != null)
                          Text(
                            AppFormatters.formatRelative(createdAt),
                            style: t.xs,
                          ),
                      ],
                    ),
                  ),
                  // Le menu `⋯` : Signaler et Bloquer pour le commentaire d'un
                  // autre, Supprimer pour le sien — ou pour tout commentaire
                  // de l'équipe qu'on organise.
                  if (currentUserId != null)
                    ModerationMoreButton(
                      key: keys.comments.moreButton(comment.id),
                      onPressed: () => _openMenu(comment, viewer, mine: mine),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              // Le texte tel qu'il a été tapé, retours à la ligne gardés, sans
              // rendu Markdown (règle R12, KIT §9) : la saisie ne le propose
              // pas, et un `**gras**` rendu change ce que la personne a écrit
              // — comme un lien `[texte](adresse)` y cacherait son adresse.
              Text(
                comment.content,
                key: keys.comments.content(comment.id),
                style: t.body,
              ),
              if (widget.canComment && !isReply)
                Align(
                  alignment: Alignment.centerLeft,
                  child: PdlButton(
                    key: keys.comments.replyButton(comment.id),
                    label: 'comments.reply'.tr(),
                    variant: PdlButtonVariant.text,
                    size: PdlButtonSize.sm,
                    onPressed: () {
                      setState(() => _replyTo = comment);
                      _focus.requestFocus();
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Le composeur, unique ────────────────────────────────────────────────
  Widget _composerRow(BuildContext context) {
    final CommentDto? replyTo = _replyTo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (replyTo != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              key: keys.comments.replyingToBanner,
              children: <Widget>[
                Expanded(
                  child: Text(
                    'comments.replyingTo'.tr(
                      namedArgs: <String, String>{
                        'name': replyTo.author.displayName,
                      },
                    ),
                    style: context.pdlText.xs,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PdlButton(
                  key: keys.comments.cancelReplyButton,
                  label: 'common.cancel'.tr(),
                  variant: PdlButtonVariant.text,
                  size: PdlButtonSize.sm,
                  onPressed: () => setState(() => _replyTo = null),
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              // Un `TextField` nu, habillé par `inputDecorationTheme` :
              // `PdlSearchField` est un champ de recherche à anti-rebond, pas
              // une zone de saisie multiligne, et le tordre en composeur
              // coûterait plus cher que ces six lignes.
              child: TextField(
                key: keys.comments.composerField,
                controller: _composer,
                focusNode: _focus,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'comments.placeholder'.tr(),
                ),
              ),
            ),
            const SizedBox(width: PdlSpacing.chipGap),
            PdlButton(
              key: keys.comments.sendButton,
              label: 'comments.send'.tr(),
              loadingLabel: 'comments.sending'.tr(),
              loading: _posting,
              onPressed: _post,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _post() async {
    final String content = _composer.text.trim();
    if (content.isEmpty || _posting) return;
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await _notifier.post(content: content, parentId: _replyTo?.id);
      if (!mounted) return;
      _composer.clear();
      setState(() => _replyTo = null);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _openMenu(
    CommentDto comment,
    _Viewer viewer, {
    required bool mine,
  }) {
    return showModerationMenu(
      context,
      subject: ModerationSubject(
        teamSlug: widget.target.teamSlug,
        type: ReportTargetType.comment,
        id: comment.id,
        teamName: viewer.teamName,
      ),
      canReport: !mine,
      blockUserId: mine ? null : comment.author.id,
      blockUserName: mine ? null : comment.author.displayName,
      onDelete: mine || viewer.moderates ? () => _remove(comment) : null,
    );
  }

  /// Supprimer se confirme toujours (KIT §9, règle R8 ; ledger `MOB-139`) —
  /// la même feuille que pour un modèle de sortie ou un appareil délié.
  Future<void> _remove(CommentDto comment) async {
    final bool confirmed = await confirmDestructive(
      context,
      title: 'comments.confirmDelete.title'.tr(),
      message: 'comments.confirmDelete.message'.tr(),
      confirmLabel: 'common.delete'.tr(),
    );
    if (!confirmed || !mounted) return;
    try {
      await _notifier.remove(comment);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }
}

/// Qui lit le fil, pour le menu `⋯` de chaque commentaire.
class _Viewer {
  const _Viewer({this.userId, this.moderates = false, this.teamName});

  final String? userId;

  /// Organisateur ou administrateur de l'équipe, ou administrateur de la
  /// plateforme : il peut supprimer le commentaire d'un autre.
  final bool moderates;

  final String? teamName;
}

/// Appelle [onNear] quand [child] arrive à moins de [margin] du bas de la
/// zone visible du défilement qui l'entoure — ou tout de suite s'il n'y en a
/// pas, la page tenant alors entière à l'écran.
///
/// Vérifié après chaque construction et à chaque mouvement du défilement.
/// Ne se déclenche qu'une fois par montage : le fil en monte un neuf, par sa
/// clé, à chaque page arrivée.
class _NearViewportTrigger extends StatefulWidget {
  const _NearViewportTrigger({
    super.key,
    required this.onNear,
    required this.child,
  });

  final VoidCallback onNear;
  final Widget child;

  static const double margin = 300;

  @override
  State<_NearViewportTrigger> createState() => _NearViewportTriggerState();
}

class _NearViewportTriggerState extends State<_NearViewportTrigger> {
  ScrollPosition? _position;
  bool _fired = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollPosition? position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.removeListener(_onScroll);
      _position = position?..addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  /// Le défilement prévient **avant** la mise en page de sa frame : mesuré là,
  /// le déclencheur est encore à sa place d'avant, en retard d'un cran. Au
  /// dernier cran — le bas de la page, sans rebond qui relance l'écoute comme
  /// sur iOS — il se croyait encore loin et la page suivante ne venait jamais.
  /// La mesure attend donc la fin de la frame.
  void _onScroll() {
    if (_fired) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_fired || !mounted) return;
    final RenderObject? box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final ScrollableState? scrollable = Scrollable.maybeOf(context);
    final RenderObject? viewport = scrollable?.context.findRenderObject();
    if (viewport is RenderBox && viewport.hasSize) {
      final double top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      if (top > viewport.size.height + _NearViewportTrigger.margin) return;
    }
    _fired = true;
    widget.onNear();
  }

  @override
  Widget build(BuildContext context) {
    // Après la frame : la position n'est connue qu'une fois la mise en page
    // faite, et `onNear` modifie un provider, interdit pendant un `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    return widget.child;
  }
}
