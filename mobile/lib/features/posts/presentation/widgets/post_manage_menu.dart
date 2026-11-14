import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../api/generated/export.dart';
import '../../../../config/paths.dart';
import '../../../../core/material.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/utils/api_error_handler.dart';
import '../../../../keys.dart';
import '../../../moderation/presentation/moderation_menu.dart';
import '../../../profile/presentation/widgets/confirm_sheet.dart';
import '../../data/post_repository.dart';
import '../../providers/post_providers.dart';

/// Les gestes d'un organisateur sur une publication, selon son statut — ceux
/// du menu du site (`PostDetailPage`) : publier un brouillon, dépublier ou
/// annuler une publication en ligne, rétablir une publication annulée,
/// supprimer, restaurer, et signaler (ledger `MOB-156`). Modifier est le
/// crayon de la barre.
enum PostManageAction {
  publish,
  unpublish,
  cancel,
  reinstate,
  delete,
  restore,
  report,
}

/// Les gestes offerts pour [post], dans l'ordre du menu. Une publication
/// supprimée n'offre que sa restauration.
///
/// Chaque geste suit le droit que le backend calcule pour **cette**
/// publication (`permissions`, docs/LEDGER_*.md MOB-137) : changer le statut
/// demande `canEdit`, supprimer et restaurer `canDelete`.
List<PostManageAction> postManageActions(PostDto post) {
  final bool edit = post.permissions.canEdit;
  final bool delete = post.permissions.canDelete;
  if (post.deleted) {
    return <PostManageAction>[if (delete) PostManageAction.restore];
  }
  return <PostManageAction>[
    if (edit && post.status == Status.draft.json) PostManageAction.publish,
    if (edit && post.status == Status.published.json) ...<PostManageAction>[
      PostManageAction.unpublish,
      PostManageAction.cancel,
    ],
    if (edit && post.status == Status.cancelled.json)
      PostManageAction.reinstate,
    if (delete) PostManageAction.delete,
    PostManageAction.report,
  ];
}

/// Le `⋯` de l'écran ouvre-t-il « Gérer la publication » plutôt que la seule
/// modération ?
bool postHasManageActions(PostDto post) =>
    post.permissions.canEdit || post.permissions.canDelete;

/// Ouvre le menu « Gérer la publication » et exécute le geste choisi.
Future<void> showPostManageMenu(
  BuildContext context,
  WidgetRef ref,
  PostDto post,
) async {
  final List<PostManageAction> actions = postManageActions(post);
  final PostManageAction? action = await PdlSheet.show<PostManageAction>(
    context: context,
    builder: (BuildContext sheetContext) => PdlSheet(
      title: 'posts.manage.menuTitle'.tr(),
      bodyPadding: EdgeInsets.zero,
      footer: const SafeArea(
        top: false,
        child: SizedBox(height: PdlSpacing.chipGap),
      ),
      children: <Widget>[
        for (final PostManageAction a in actions)
          PdlSettingRow(
            key: _key(a),
            icon: _icon(a),
            title: 'posts.manage.${_label(a)}'.tr(),
            destructive: a == PostManageAction.delete,
            showDivider:
                a == PostManageAction.delete &&
                actions.contains(PostManageAction.report),
            trailing: const SizedBox.shrink(),
            onTap: () => Navigator.of(sheetContext).pop(a),
          ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;
  await runPostManageAction(context, ref, post, action);
}

/// Exécute [action] sur [post] : confirmation d'abord pour ce qui retire la
/// publication aux lecteurs, puis l'appel, l'invalidation des vues, le
/// message.
Future<void> runPostManageAction(
  BuildContext context,
  WidgetRef ref,
  PostDto post,
  PostManageAction action,
) async {
  final String team = post.team.slug;
  if (action == PostManageAction.report) {
    await showDetailModerationMenu(
      context,
      subject: ModerationSubject(
        teamSlug: team,
        type: ReportTargetType.post,
        id: post.id,
        teamName: post.team.name,
      ),
    );
    return;
  }

  final ({String title, String message})? confirm = switch (action) {
    PostManageAction.unpublish => (
      title: 'posts.manage.unpublishTitle'.tr(),
      message: 'posts.manage.unpublishMessage'.tr(),
    ),
    PostManageAction.cancel => (
      title: 'posts.manage.cancelTitle'.tr(),
      message: 'posts.manage.cancelMessage'.tr(),
    ),
    PostManageAction.delete => (
      title: 'posts.manage.deleteTitle'.tr(),
      message: 'posts.manage.deleteMessage'.tr(),
    ),
    _ => null,
  };
  if (confirm != null) {
    final bool ok = await confirmDestructive(
      context,
      title: confirm.title,
      message: confirm.message,
      confirmLabel: 'posts.manage.${_label(action)}'.tr(),
    );
    if (!ok || !context.mounted) return;
  }

  final PostRepository repo = ref.read(postRepositoryProvider);
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final GoRouter router = GoRouter.of(context);
  try {
    switch (action) {
      case PostManageAction.publish || PostManageAction.reinstate:
        await repo.changeStatus(team, post.slug, Status.published);
      case PostManageAction.unpublish:
        await repo.changeStatus(team, post.slug, Status.draft);
      case PostManageAction.cancel:
        await repo.changeStatus(team, post.slug, Status.cancelled);
      case PostManageAction.delete:
        await repo.deletePost(team, post.slug);
      case PostManageAction.restore:
        await repo.undeletePost(team, post.slug);
      case PostManageAction.report:
        return;
    }
  } catch (error, stackTrace) {
    messenger?.showSnackBar(
      SnackBar(content: Text(getErrorMessage(error, stackTrace))),
    );
    return;
  }

  notifyPostChanged(
    ref,
    teamSlug: team,
    postKey: (teamSlug: team, postSlug: post.slug),
  );
  messenger?.showSnackBar(
    SnackBar(content: Text('posts.manage.${_done(action)}'.tr())),
  );
  if (action == PostManageAction.delete) {
    // L'écran d'une publication supprimée n'a plus lieu d'être ouvert :
    // retour à ce qui était dessous, sinon aux publications de l'équipe.
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Paths.teamPosts(team));
    }
  }
}

String _label(PostManageAction a) => switch (a) {
  PostManageAction.publish => 'publish',
  PostManageAction.unpublish => 'unpublish',
  PostManageAction.cancel => 'cancel',
  PostManageAction.reinstate => 'reinstate',
  PostManageAction.delete => 'delete',
  PostManageAction.restore => 'restore',
  PostManageAction.report => 'report',
};

String _done(PostManageAction a) => switch (a) {
  PostManageAction.publish => 'published',
  PostManageAction.unpublish => 'unpublished',
  PostManageAction.cancel => 'cancelled',
  PostManageAction.reinstate => 'reinstated',
  PostManageAction.delete => 'deleted',
  PostManageAction.restore => 'restored',
  PostManageAction.report => 'report',
};

IconData _icon(PostManageAction a) => switch (a) {
  PostManageAction.publish => PdlIcons.publish,
  PostManageAction.unpublish => PdlIcons.unpublish,
  PostManageAction.cancel => PdlIcons.cancelled,
  PostManageAction.reinstate => PdlIcons.refresh,
  PostManageAction.delete => PdlIcons.delete,
  PostManageAction.restore => PdlIcons.restore,
  PostManageAction.report => PdlIcons.report,
};

Key _key(PostManageAction a) => switch (a) {
  PostManageAction.publish => keys.postManage.publish,
  PostManageAction.unpublish => keys.postManage.unpublish,
  PostManageAction.cancel => keys.postManage.cancel,
  PostManageAction.reinstate => keys.postManage.reinstate,
  PostManageAction.delete => keys.postManage.delete,
  PostManageAction.restore => keys.postManage.restore,
  PostManageAction.report => keys.postManage.report,
};
