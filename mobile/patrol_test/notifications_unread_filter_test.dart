import 'api/teams_content_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-notifications.e2e.ts` › « the inbox filters unread entries from its
/// URL, and "mark all read" empties the filter ».
///
/// « Tout marquer lu » under « Non lues » reloads that list from the server
/// (`NotificationsNotifier.markAllRead`): it reaches its empty state at once, and the bell follows.
void main() {
  testApp(
    'The inbox’s « Non lues » filter lists unread entries only, and « Tout marquer lu » empties it',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final author = await backend.newUser('Unread author');
      final member = await backend.newUser('Unread member');
      final team = await backend.newTeam(author, 'Equipe non lues');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, member);
      final first = await backend.newPost(author, teamSlug, 'Premier article');
      final second = await backend.newPost(author, teamSlug, 'Second article');

      Future<String> notificationOf(Json post) async {
        final n = await eventually(
          () => backend.notificationAbout(
            member,
            'POST_PUBLISHED',
            post['slug'] as String,
          ),
          until: (Json? n) => n != null,
          description: 'the POST_PUBLISHED notification of ${post['name']}',
        );
        return n!['id'] as String;
      }

      final readId = await notificationOf(first);
      final unreadId = await notificationOf(second);
      await backend.markRead(member, readId);
      expect(await backend.unreadCount(member), 1);

      await openAppSignedIn($, member);
      expect(await modules.notifications.waitForBellBadge(), '1');
      await modules.notifications.openInboxFromBell();
      await modules.notifications.waitUntilEntryIsShown(unreadId);
      await modules.notifications.waitUntilEntryIsShown(readId);

      await modules.notifications.showUnreadOnly();
      await modules.notifications.waitUntilEntryIsShown(unreadId);
      expect(modules.notifications.isEntryShown(readId), isFalse);

      await modules.notifications.markAllRead();
      await eventually(
        () => backend.unreadCount(member),
        until: (int count) => count == 0,
        description: 'the inbox read',
        timeout: const Duration(seconds: 10),
      );
      await modules.notifications.waitUntilUnreadEmptyStateIsShown();
      expect(modules.notifications.isEntryShown(unreadId), isFalse);

      await modules.notifications.tapShowAllFromEmptyState();
      await modules.notifications.waitUntilEntryIsShown(unreadId);
      await modules.notifications.waitUntilEntryIsShown(readId);
      expect(
        (await backend.notifications(member))
            .where((Json n) => n['read'] != true)
            .map((Json n) => n['id']),
        isEmpty,
      );

      // The bell reads the count again as the home comes back.
      await openLink($, Paths.home());
      await modules.notifications.waitUntilBellBadgeIsGone();
    },
  );
}
