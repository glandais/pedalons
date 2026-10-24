import 'api/calendar_seed.dart';
import 'api/rides_home_trips_seed.dart';
import 'common.dart';

/// Web counterpart: `calendar.e2e.ts` — the calendar of a member merges the rides of every team
/// they belong to and no other (a public team's public ride stays out), each card names its team
/// and « Inscrit · Groupe A » where they are registered, and an event opens its ride. A team's
/// calendar shows that team alone, and its subscription card hands out the team's feed URL
/// (`teamFeedUrlTemplate` with the slug put in) through the clipboard only; « Régénérer le lien »
/// replaces the token.
void main() {
  testApp(
    'The calendar shows the rides of my teams only, opens a ride, and hands out the team feed URL, regenerated on demand',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final member = await backend.newUser('Calendar member');
      final neighbour = await backend.newUser('Calendar neighbour');
      // One team per creator: the teams are the platform admin's, the member is added to both.
      final admin = await backend.admin();
      final mine = await backend.newTeam(admin, 'Mon equipe calendrier');
      final alsoMine = await backend.newTeam(admin, 'Autre equipe calendrier');
      final foreign = await backend.newTeam(
        neighbour,
        'Equipe voisine calendrier',
        visibility: 'PUBLIC',
      );
      final mineSlug = mine['slug'] as String;
      final alsoMineSlug = alsoMine['slug'] as String;
      await backend.addMember(mineSlug, member);
      await backend.addMember(alsoMineSlug, member);
      final now = DateTime.now();
      DateTime tomorrowAt(int hour) =>
          DateTime(now.year, now.month, now.day + 1, hour);
      final joined = await backend.newRideAt(
        admin,
        mineSlug,
        'Sortie inscrite',
        tomorrowAt(9),
      );
      final other = await backend.newRideAt(
        admin,
        alsoMineSlug,
        'Sortie non inscrite',
        tomorrowAt(14),
      );
      final outside = await backend.newPublicRideAt(
        neighbour,
        foreign['slug'] as String,
        'Sortie voisine',
        tomorrowAt(10),
      );
      final joinedSlug = joined['slug'] as String;
      final otherSlug = other['slug'] as String;
      final outsideSlug = outside['slug'] as String;
      await backend.joinGroup(
        member,
        mineSlug,
        joinedSlug,
        groupIdNamed(joined, 'Groupe A'),
      );

      // The calendar tab: both of my teams' rides, not the public neighbour's.
      await openAppSignedIn($, member);
      await modules.calendar.goToCalendar();
      await modules.calendar.showMonthOf(tomorrowAt(9));
      await modules.calendar.waitUntilEventIsShown(joinedSlug);
      await modules.calendar.waitUntilEventIsShown(otherSlug);
      expect(modules.calendar.showsEvent(outsideSlug), isFalse);
      expect(
        modules.calendar.eventShows(joinedSlug, mine['name'] as String),
        isTrue,
      );
      expect(
        modules.calendar.eventShows(otherSlug, alsoMine['name'] as String),
        isTrue,
      );
      expect(
        modules.calendar.registeredBadgeShows(
          joinedSlug,
          'J\'y vais · Groupe A',
        ),
        isTrue,
      );
      expect(modules.calendar.showsRegistered(otherSlug), isFalse);

      // An event opens its ride.
      await modules.calendar.openEvent(joinedSlug);
      await modules.ride.waitUntilShown();
      expect(modules.ride.title, joined['name']);

      // The team's calendar: that team's ride alone, and its own feed URL on copy.
      await openLink($, Paths.teamCalendar(mineSlug));
      await modules.calendar.showMonthOf(tomorrowAt(9));
      await modules.calendar.waitUntilEventIsShown(joinedSlug);
      expect(modules.calendar.showsEvent(otherSlug), isFalse);
      final token = await backend.calendarToken(member);
      final template = token['teamFeedUrlTemplate'] as String;
      expect(template, contains('{teamSlug}'));
      final copied = await modules.calendar.copyFeedUrl();
      expect(copied, template.replaceAll('{teamSlug}', mineSlug));
      expect(Uri.parse(copied!).path, '/api/teams/$mineSlug/calendar/ics');
      expect(modules.calendar.noticeShows('Lien copié'), isTrue);

      // « Régénérer le lien »: a new token, and the copy hands out the new URL.
      await modules.calendar.regenerateFeed();
      final regenerated = await eventually(
        () => backend.calendarToken(member),
        until: (Json t) => t['teamFeedUrlTemplate'] != template,
        description: 'a regenerated calendar token',
      );
      final recopied = await modules.calendar.copyFeedUrl();
      expect(
        recopied,
        (regenerated['teamFeedUrlTemplate'] as String).replaceAll(
          '{teamSlug}',
          mineSlug,
        ),
      );
      expect(recopied, isNot(equals(copied)));
    },
  );
}
