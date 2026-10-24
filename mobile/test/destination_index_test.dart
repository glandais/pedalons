import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/adaptive/navigation_destination.dart';

/// `getDestinationIndex` decides which of the five fixed tabs is highlighted
/// for a URL. It is the only rule for that, so the shell and the tab bar cannot
/// disagree — and its order must be **most specific first**, because two
/// destinations share a word: the global route library at `/parcours` and a
/// team's route library at `/equipes/{slug}/parcours`.
void main() {
  const teamSlug = 'n-peloton';

  /// Index of a destination by its translation key, so a reordering of
  /// `kAppDestinations` moves the expectations with it instead of breaking.
  int indexOf(String label) =>
      kAppDestinations.indexWhere((d) => d.label == label);

  group('the five branches, in order', () {
    test('kAppDestinations has exactly the five tabs of the shell', () {
      expect(kAppDestinations.map((d) => d.label), [
        'nav.home',
        'nav.teams',
        'nav.calendar',
        'nav.explore',
        'nav.profile',
      ]);
    });

    test('each tab root selects its own tab, in both locales', () {
      for (final destination in kAppDestinations) {
        for (final path in destination.paths.values) {
          expect(
            getDestinationIndex(path),
            kAppDestinations.indexOf(destination),
            reason: '$path should select "${destination.label}"',
          );
        }
      }
    });
  });

  group('most specific wins', () {
    test('a team route library stays on Teams, not Routes', () {
      for (final path in PathVariants.routes(teamSlug).values) {
        expect(
          getDestinationIndex(path),
          indexOf('nav.teams'),
          reason: '$path belongs to the team, not to the global route library',
        );
      }
      for (final path in PathVariants.route(teamSlug, 'galibier').values) {
        expect(getDestinationIndex(path), indexOf('nav.teams'));
      }
    });

    test('a team calendar stays on Teams, not Calendar', () {
      for (final path in PathVariants.teamCalendar(teamSlug).values) {
        expect(getDestinationIndex(path), indexOf('nav.teams'));
      }
    });

    test('the global routes map stays on Explorer', () {
      for (final path in PathVariants.allRoutesMap().values) {
        expect(getDestinationIndex(path), indexOf('nav.explore'));
      }
    });

    test('every page under a team lights up Teams', () {
      final underTeam = <String>[
        ...PathVariants.team(teamSlug).values,
        ...PathVariants.teamAbout(teamSlug).values,
        ...PathVariants.teamAds(teamSlug).values,
        ...PathVariants.teamMembers(teamSlug).values,
        ...PathVariants.teamsDiscover().values,
        ...PathVariants.teamPage(teamSlug, 'histoire').values,
        ...PathVariants.ride(teamSlug, 'rando').values,
        ...PathVariants.trip(teamSlug, 'alpes').values,
        ...PathVariants.stage(teamSlug, 'alpes', 'jour-1').values,
        ...PathVariants.post(teamSlug, 'article').values,
        ...PathVariants.ad(teamSlug, 'velo').values,
      ];
      for (final path in underTeam) {
        expect(
          getDestinationIndex(path),
          indexOf('nav.teams'),
          reason: '$path is under a team',
        );
      }
    });
  });

  group('home is the fallback', () {
    test('the root path and anything unmatched fall back to Home', () {
      expect(getDestinationIndex('/'), 0);
      expect(getDestinationIndex('/inconnu'), 0);
      expect(getDestinationIndex('/connexion'), 0);
    });

    test('a query string does not defeat the match', () {
      expect(
        getDestinationIndex('${PathVariants.teams()['fr']}?q=abc'),
        indexOf('nav.teams'),
      );
    });
  });
}
