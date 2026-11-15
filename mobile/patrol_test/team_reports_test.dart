import 'api/teams_content_seed.dart';
import 'common.dart';
import 'modules/team_reports.dart';

/// Web counterpart: `flow-moderation.e2e.ts` › team moderation (`TeamReportsPage`,
/// `ModerationQueue`: the moderator dismisses reports, « Supprimer le contenu » deletes the post
/// for everyone) and `flow-notifications.e2e.ts` › the `CONTENT_REPORTED` notification.
///
/// In the app (ledger `MOB-168`): a team administrator reaches « Signalements » from the hub,
/// finds a reported post and a reported member, opens the post from its card, dismisses the
/// member's report (no « Supprimer le contenu » for a member) and removes the post after the
/// confirmation — it is gone for the other members, and « Traités » shows the decision. An
/// organizer reaches the queue from the `CONTENT_REPORTED` notification and gets no link to the
/// members screen; a plain member reads a refusal.
///
/// Written, not yet run (ledger `MOB-168`).
void main() {
  testApp(
    'A team administrator dismisses a member’s report and removes a reported post from the queue',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      // The moderator never sees reports about their own content: someone else writes the post.
      final moderator = await backend.newUser('Queue moderator');
      final author = await backend.newUser('Queue author');
      final reported = await backend.newUser('Queue reported');
      final reporter = await backend.newUser('Queue reporter');
      final bystander = await backend.newUser('Queue bystander');
      final team = await backend.newTeam(moderator, 'Equipe file');
      final slug = team['slug'] as String;
      await backend.addMember(slug, author, role: 'ORGANIZER');
      for (final member in [reported, reporter, bystander]) {
        await backend.addMember(slug, member);
      }
      final post = await backend.newPost(author, slug, 'Article a moderer');
      final postSlug = post['slug'] as String;
      final postId = post['id'] as String;
      await backend.report(reporter, slug, 'POST', postId);
      await backend.report(reporter, slug, 'MEMBER', reported.id);
      final postCard = TeamReports.card('POST', postId);
      final memberCard = TeamReports.card('MEMBER', reported.id);

      await openAppSignedIn($, moderator);
      await openLink($, Paths.team(slug));
      await modules.teams.waitUntilTeamIsShown();
      await modules.teamAdmin.openFromHeader();
      await modules.teamAdmin.openReports();
      await modules.teamReports.waitUntilShown();

      // One card per target: what it is, how many reports, who wrote it — never who reported.
      await modules.teamReports.waitUntilCardIsShown(postCard);
      expect(modules.teamReports.cardShows(postCard, 'PUBLICATION'), isTrue);
      expect(modules.teamReports.cardShows(postCard, '1 SIGNALEMENT'), isTrue);
      expect(
        modules.teamReports.cardShows(postCard, post['name'] as String),
        isTrue,
      );
      expect(
        modules.teamReports.cardShows(postCard, author.displayName),
        isTrue,
      );
      expect(
        modules.teamReports.cardShows(postCard, reporter.displayName),
        isFalse,
      );
      expect(modules.teamReports.offersRemove(postCard), isTrue);

      // A reported member: nothing to remove, and — for an administrator — the way to the
      // members screen.
      await modules.teamReports.waitUntilCardIsShown(memberCard);
      expect(
        modules.teamReports.cardShows(memberCard, reported.displayName),
        isTrue,
      );
      expect(modules.teamReports.offersRemove(memberCard), isFalse);
      expect(modules.teamReports.offersMembersLink(memberCard), isTrue);

      // The content's name opens its page in the app, and back comes to the queue.
      await modules.teamReports.openContent(postCard);
      await modules.post.waitUntilShown();
      expect(modules.post.title, post['name']);
      await modules.teamReports.backToQueue();

      // Dismissing needs no confirmation: the report is closed, the member stays.
      await modules.teamReports.dismiss(memberCard);
      expect(await backend.queueItem(moderator, slug, reported.id), isNull);
      expect(await backend.roleOf(moderator, slug, reported), 'MEMBER');
      expect(modules.teamReports.showsCard(postCard), isTrue);

      // Removing asks first; the post is then gone for everyone.
      await modules.teamReports.removeContent(postCard);
      expect(await backend.queueItem(moderator, slug, postId), isNull);
      expect(await backend.findPost(bystander, slug, postSlug), isNull);
      await modules.teamReports.waitUntilOpenQueueIsEmpty();

      // « Traités » keeps both decisions.
      await modules.teamReports.openResolved();
      await modules.teamReports.waitUntilCardIsShown(postCard);
      await modules.teamReports.waitUntilCardShows(postCard, 'SUPPRIMÉ');
      await modules.teamReports.waitUntilCardIsShown(memberCard);
      expect(modules.teamReports.cardShows(memberCard, 'REJETÉ'), isTrue);
      expect(modules.teamReports.offersRemove(postCard), isFalse);
      final resolved = await backend.resolvedQueue(moderator, slug);
      final decisions = resolved.map((Json item) => item['status']).toSet();
      expect(decisions, contains('REMOVED'));
      expect(decisions, contains('DISMISSED'));
    },
  );

  testApp(
    'An organizer reaches the queue from the CONTENT_REPORTED notification; a plain member is refused',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Queue gate owner');
      final organizer = await backend.newUser('Queue gate organizer');
      final reported = await backend.newUser('Queue gate reported');
      final reporter = await backend.newUser('Queue gate reporter');
      final team = await backend.newTeam(owner, 'Equipe file fermee');
      final slug = team['slug'] as String;
      await backend.addMember(slug, organizer, role: 'ORGANIZER');
      await backend.addMember(slug, reported);
      await backend.addMember(slug, reporter);
      await backend.report(reporter, slug, 'MEMBER', reported.id);
      final memberCard = TeamReports.card('MEMBER', reported.id);

      // A plain member — the reporter — has no queue: the link reads a refusal.
      await openAppSignedIn($, reporter);
      await openLink($, Paths.teamAdminReports(slug));
      expect(await modules.teamReports.showsForbidden(), isTrue);

      // The organizer is told, and the notification opens the queue in the app.
      final notification = await eventually(
        () => backend.notificationInTeam(organizer, 'CONTENT_REPORTED', slug),
        until: (Json? n) => n != null,
        description: 'the CONTENT_REPORTED notification',
      );
      final id = notification!['id'] as String;
      await openAppSignedIn($, organizer);
      await modules.notifications.waitForBellBadge();
      await modules.notifications.openInboxFromBell();
      await modules.notifications.waitUntilEntryIsShown(id);
      await modules.notifications.openEntry(id);
      await modules.teamReports.waitUntilShown();

      // An organizer decides, but does not manage members: no link to a screen that refuses them.
      await modules.teamReports.waitUntilCardIsShown(memberCard);
      expect(modules.teamReports.offersRemove(memberCard), isFalse);
      expect(modules.teamReports.offersMembersLink(memberCard), isFalse);
      await modules.teamReports.dismiss(memberCard);
      expect(await backend.queueItem(owner, slug, reported.id), isNull);
    },
  );
}
