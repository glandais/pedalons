import 'api/teams_content_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-posts.e2e.ts` › comment replies — a reply nests under its parent, a
/// reply offers no third level, a third party may not delete someone else's comment, the
/// commenter hears of the reply (`COMMENT_REPLY`) and the post's author of the comments
/// (`COMMENT_ON_MY_PUBLICATION`), never of a reply meant for someone else.
///
/// On mobile the thread has a single composer: « Répondre » points it at a comment, and the
/// answer comes back rendered in its parent's thread after the page reloads.
void main() {
  testApp(
    'A member comments on a post, replies under a teammate’s comment, deletes their own, and the teammate hears of the reply',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Reply owner');
      final commenter = await backend.newUser('Reply commenter');
      final member = await backend.newUser('Reply member');
      final team = await backend.newTeam(owner, 'Equipe reponses');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, commenter);
      await backend.addMember(teamSlug, member);
      final post = await backend.newPost(owner, teamSlug, 'Article discute');
      final postSlug = post['slug'] as String;
      final theirs = await backend.commentOnPost(
        commenter,
        teamSlug,
        postSlug,
        'Qui vient samedi ?',
      );
      final theirsId = theirs['id'] as String;

      await openAppSignedIn($, member);
      await openLink($, Paths.post(teamSlug, postSlug));
      await modules.post.waitUntilShown();
      await modules.post.waitUntilCommentIsShown(theirsId);

      // A comment of one's own, at the top level.
      // Typed with asterisks: the thread shows them as typed (rule R12).
      final rootText = '${unique('Mon commentaire')} **samedi**';
      await modules.post.sendComment(rootText);
      final mine = (await backend.postComments(
        member,
        teamSlug,
        postSlug,
      )).where((Json c) => c['content'] == rootText).firstOrNull;
      expect(mine, isNotNull);
      expect((mine!['author'] as Json)['id'], member.id);
      final mineId = mine['id'] as String;
      await modules.post.waitUntilCommentIsShown(mineId);
      expect(modules.post.commentText(mineId), rootText);

      // A reply, nested under the teammate's comment.
      await modules.post.startReplyTo(theirsId);
      expect(modules.post.replyingToShows(commenter.displayName), isTrue);
      final replyText = unique('Moi je viens');
      await modules.post.sendComment(replyText);
      expect(modules.post.isReplying, isFalse);
      final reply = (await backend.postCommentsOf(
        member,
        teamSlug,
        postSlug,
        theirsId,
      )).where((Json c) => c['content'] == replyText).firstOrNull;
      expect(reply, isNotNull);
      final replyId = reply!['id'] as String;
      await modules.post.waitUntilCommentIsShown(replyId);
      expect(modules.post.showsReplyUnder(theirsId, replyId), isTrue);
      // One level of replies, not two.
      expect(modules.post.offersReplyTo(theirsId), isTrue);
      expect(modules.post.offersReplyTo(replyId), isFalse);

      // One's own comment: the menu deletes it, and offers nothing to report.
      await modules.post.openCommentMenu(mineId);
      await modules.moderation.waitUntilMenuIsShown();
      expect(modules.moderation.menuOffersDelete, isTrue);
      expect(modules.moderation.menuOffersReport, isFalse);
      await modules.post.deleteFromOpenMenu();
      await modules.post.waitUntilCommentIsGone(mineId);
      expect(
        await backend.postCommentIds(member, teamSlug, postSlug),
        isNot(contains(mineId)),
      );

      // Someone else's comment: report or block its author, never delete it.
      await modules.post.openCommentMenu(theirsId);
      await modules.moderation.waitUntilMenuIsShown();
      expect(modules.moderation.menuOffersReport, isTrue);
      expect(modules.moderation.menuOffersBlock, isTrue);
      expect(modules.moderation.menuOffersDelete, isFalse);

      // The commenter hears of the reply; the post's author of the comments, not of the reply.
      await eventually(
        () => backend.notificationAbout(commenter, 'COMMENT_REPLY', postSlug),
        until: (Json? n) => n != null,
        description: 'the COMMENT_REPLY notification of the commenter',
      );
      await eventually(
        () => backend.notificationAbout(
          owner,
          'COMMENT_ON_MY_PUBLICATION',
          postSlug,
        ),
        until: (Json? n) => n != null,
        description: 'the COMMENT_ON_MY_PUBLICATION notification of the author',
      );
      expect(
        await backend.notificationAbout(owner, 'COMMENT_REPLY', postSlug),
        isNull,
      );
    },
  );
}
