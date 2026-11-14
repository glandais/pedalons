import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart' hide Visibility;
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/share_link.dart';
import '../../../../core/widgets/markdown_content.dart';
import '../../../../core/widgets/media_attachments.dart';
import '../../../../core/widgets/team_banner.dart';
import '../../../../core/widgets/zone_mention_line.dart';
import '../../../../keys.dart';
import '../../../comments/data/comment_repository.dart';
import '../../../comments/presentation/widgets/comment_thread.dart';
import '../../../feedback/presentation/report_problem_button.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../tags/presentation/content_tags.dart';
import '../../data/post_repository.dart';
import '../../domain/post_neighbours.dart';

final postDetailProvider =
    FutureProvider.family<PostDto, ({String teamSlug, String postSlug})>((
      ref,
      params,
    ) async {
      final repository = ref.watch(postRepositoryProvider);
      return repository.getPost(params.teamSlug, params.postSlug);
    });

/// L'écran d'une publication.
///
/// **Aucun bloc auteur.** La maquette en dessine un — avatar, nom, date — et
/// `PostDto` n'expose ni `createdBy` ni `createdById` : il n'est pas
/// alimentable, et le fabriquer reviendrait à attribuer un texte à quelqu'un.
/// Seule la date longue est conservée (§5.1).
class PostDetailPage extends ConsumerWidget {
  final String teamSlug;
  final String postSlug;

  /// Voisins du fil d'où la publication a été ouverte. Nuls en ouverture par
  /// deeplink — voir [PostNeighbours].
  final PostNeighbours? neighbours;

  const PostDetailPage({
    super.key,
    required this.teamSlug,
    required this.postSlug,
    this.neighbours,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (teamSlug: teamSlug, postSlug: postSlug);
    final AsyncValue<PostDto> postAsync = ref.watch(postDetailProvider(params));

    return postAsync.when(
      data: (PostDto post) =>
          _PostDetailContent(post: post, neighbours: neighbours),
      loading: () => Scaffold(
        appBar: PdlAppBar(
          onBack: () => context.pop(),
          backSemanticLabel: 'common.back'.tr(),
        ),
        body: const SingleChildScrollView(
          padding: EdgeInsets.all(PdlSpacing.section),
          child: PdlSkeletonCardList(
            variant: PdlSkeletonCardVariant.media,
            count: 2,
          ),
        ),
      ),
      error: (Object error, StackTrace stack) => Scaffold(
        appBar: PdlAppBar(
          onBack: () => context.pop(),
          backSemanticLabel: 'common.back'.tr(),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: PdlEmptyState(
              key: keys.post.loadError,
              variant: PdlEmptyVariant.error,
              title: 'common.loadError'.tr(),
              message: getErrorMessage(error, stack),
              actions: <Widget>[
                PdlButton(
                  label: 'common.retry'.tr(),
                  variant: PdlButtonVariant.outline,
                  onPressed: () => ref.invalidate(postDetailProvider(params)),
                ),
                ReportProblemButton(error: error, stackTrace: stack),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostDetailContent extends ConsumerWidget {
  const _PostDetailContent({required this.post, this.neighbours});

  final PostDto post;
  final PostNeighbours? neighbours;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PdlColors c = context.pdl;
    // Le droit de commenter, calculé par le backend pour **cette**
    // publication (docs/LEDGER_*.md MOB-137).
    final bool canComment = post.permissions.canComment ?? false;
    final VoidCallback? viewTeam = teamLinkOf(context, post.team);
    final List<AssetDto> attachments = post.media.assets.attachments;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: PdlAppBar(
        // Pas de titre : le corps porte déjà le nom en 22/700, juste
        // dessous. Le répéter en 17 dans la barre le dit deux fois.
        onBack: () => context.pop(),
        backSemanticLabel: 'common.back'.tr(),
        actions: <Widget>[
          PdlAppBarAction(
            icon: PdlIcons.share,
            semanticLabel: 'routes.share'.tr(),
            onPressed: () => unawaited(_share(context)),
          ),
          // Signaler seulement : une publication n'expose pas son auteur, on
          // ne peut donc ni savoir si c'est la sienne, ni proposer de le
          // bloquer. Le serveur refuse `REPORT_SELF`, et la feuille le dit.
          PdlAppBarAction(
            key: keys.post.moreButton,
            icon: PdlIcons.more,
            semanticLabel: 'moderation.more'.tr(),
            onPressed: () => unawaited(
              showDetailModerationMenu(
                context,
                subject: ModerationSubject(
                  teamSlug: post.team.slug,
                  type: ReportTargetType.post,
                  id: post.id,
                  teamName: post.team.name,
                ),
              ),
            ),
          ),
        ],
      ),
      body: PdlRefresh(
        onRefresh: () async {
          final params = (teamSlug: post.team.slug, postSlug: post.slug);
          ref.invalidate(postDetailProvider(params));
          try {
            await ref.read(postDetailProvider(params).future);
          } catch (_) {
            // L'échec se rend par l'état d'erreur de l'écran.
          }
        },
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.all(PdlSpacing.section),
              sliver: SliverList.list(
                children: <Widget>[
                  _identity(context),
                  const SizedBox(height: PdlSpacing.section),
                  if (post.media.markdown.trim().isNotEmpty)
                    MarkdownContent(
                      data: post.media.markdown,
                      images: post.media.assets.images,
                    ),
                  MediaAttachments(attachments: attachments),
                  const SizedBox(height: PdlSpacing.section),
                  // `commentCount` absent signifie « vous n'avez pas le droit de
                  // lire les commentaires » : un non-membre n'est même pas
                  // informé qu'il y en a zéro, donc le fil ne se monte pas.
                  if (post.commentCount != null)
                    CommentThread(
                      target: CommentTarget(
                        entity: CommentEntity.post,
                        teamSlug: post.team.slug,
                        slug: post.slug,
                      ),
                      canComment: canComment,
                    )
                  else
                    // Une équipe que l'appelant ne peut pas consulter (privée,
                    // publication lue par lien) n'offre pas de lien vers elle.
                    PdlBanner(
                      tone: PdlBannerTone.info,
                      message: viewTeam == null
                          ? 'posts.commentsPrivateTeam'.tr()
                          : 'posts.commentsMembersOnly'.tr(),
                      action: viewTeam == null
                          ? null
                          : PdlButton(
                              label: 'teams.viewTeam'.tr(),
                              variant: PdlButtonVariant.outline,
                              size: PdlButtonSize.sm,
                              onPressed: viewTeam,
                            ),
                    ),
                ],
              ),
            ),
            // Absent en ouverture froide, et sans espace résiduel : le composant
            // rend `SizedBox.shrink()` quand il n'a aucun voisin.
            SliverToBoxAdapter(
              child: PdlPrevNextNav(
                previous: _target(
                  context,
                  neighbours?.previous,
                  forward: false,
                ),
                next: _target(context, neighbours?.next, forward: true),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }

  PdlPrevNextTarget? _target(
    BuildContext context,
    PostNeighbour? neighbour, {
    required bool forward,
  }) {
    if (neighbour == null) return null;
    return PdlPrevNextTarget(
      caption: forward ? 'posts.next'.tr() : 'posts.previous'.tr(),
      title: neighbour.name,
      // `pushReplacement` : enchaîner dix publications ne doit pas empiler dix
      // écrans à remonter un à un pour revenir au fil.
      onTap: () => context.pushReplacement(
        Paths.post(post.team.slug, neighbour.slug),
        // Recentrée sur le voisin : sans cela, il hériterait des voisins de
        // la publication qu'on vient de quitter.
        extra: neighbours?.movedTo(neighbour.slug),
      ),
    );
  }

  /// Ligne d'équipe, titre multi-ligne, badges, date longue.
  Future<void> _share(BuildContext context) => shareAppLink(
    context,
    title: post.name,
    path: Paths.post(post.team.slug, post.slug),
  );

  Widget _identity(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    // Un rendez-vous dans le fuseau de la publication, celui de l'équipe
    // (`PostDto.timezone`, docs/LEDGER_*.md API-60) : date et heure, puis la
    // mention « heure de Tokyo (ven. 17:30 chez vous) » quand le décalage du
    // lecteur diffère — la règle du détail web, pour que les deux clients
    // disent la même chose de la même publication.
    final DateTime? wall = AppFormatters.tryParseZoneTime(
      post.dateTime,
      post.timezone,
    );
    final String? at = wall == null
        ? null
        : 'dates.at'.tr(
            namedArgs: <String, String>{
              'date': AppFormatters.formatFullDate(wall),
              'time': AppFormatters.formatTime(wall),
            },
          );
    final Widget? mention = ZoneMentionLine.maybe(post.dateTime, post.timezone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PdlTeamLine(
          label: post.team.name,
          imageUrl: post.team.logoUrl,
          onTap: teamLinkOf(context, post.team),
        ),
        const SizedBox(height: PdlSpacing.chipGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Le titre n'est **pas** tronqué ici : sur un détail, il est le
            // sujet de l'écran, pas une ligne de liste.
            Expanded(
              child: Text(
                post.name,
                key: keys.post.title,
                style: t.screenTitle,
              ),
            ),
            const SizedBox(width: PdlSpacing.chipGap),
            PdlBadgeStack(
              badges: <Widget>[
                PdlBadge(
                  label: 'publicationType.post'.tr(),
                  tone: PublicationType.post.tone(c),
                ),
                if (post.status == 'DRAFT')
                  PdlBadge(
                    label: 'status.draft'.tr(),
                    tone: Status.draft.tone(c),
                  ),
              ],
            ),
          ],
        ),
        // Le bloc auteur de la maquette : avatar, nom, date. `createdBy` est
        // nul quand l'équipe signe la publication et que le lecteur n'en est
        // ni administrateur ni l'auteur (ledger `API-6`) — la ligne d'équipe
        // au-dessus est alors la signature, et seule la date reste.
        if (post.createdBy case final PublicUserDto author) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          PdlPersonRow(
            name: author.displayName,
            imageUrl: author.avatarUrl,
            avatarSize: 32,
            subtitle: <String>[
              ?at,
              // Un administrateur voit qui a écrit une publication que
              // l'équipe signe : il doit savoir que les lecteurs, eux, ne le
              // voient pas.
              if (post.signedAsTeam) 'posts.onBehalfOfTeam'.tr(),
            ].join(' · '),
          ),
        ] else if (at != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(at, style: t.sub),
        ],
        if (mention != null) ...<Widget>[const SizedBox(height: 4), mention],
        // Les tags sous la signature : ils qualifient le contenu, pas son
        // statut (ledger `MOB-39`).
        if (post.tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: PdlSpacing.chipGap),
          ContentTagRow(tags: post.tags),
        ],
      ],
    );
  }
}
