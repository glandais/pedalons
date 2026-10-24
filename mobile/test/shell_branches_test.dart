import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/config/router.dart';
import 'package:pedalons/core/adaptive/navigation_destination.dart';

/// Shape of the navigation shell, asserted on the real `GoRouter`.
///
/// The migration to `StatefulShellRoute.indexedStack` rests on three structural
/// facts that no screen test would catch as clearly:
///
/// 1. there is **one** shell, with five branches in the order of
///    `kAppDestinations` — the two mutually exclusive `ShellRoute`s are gone, so
///    the tab bar never disappears inside a team;
/// 2. each branch owns a **distinct navigator**, which is what makes
///    `indexedStack` keep one back stack per tab: leaving a team for Calendar
///    and coming back restores the team;
/// 3. the whole team tree lives in the Teams branch at **unchanged URLs**, and
///    full-screen detail pages still escape to the root navigator.
void main() {
  late GoRouter router;

  setUpAll(() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    router = container.read(routerProvider);
  });

  StatefulShellRoute shell() {
    final shells = router.configuration.routes.whereType<StatefulShellRoute>();
    expect(shells, hasLength(1), reason: 'exactly one navigation shell');
    return shells.first;
  }

  /// Every path reachable inside [routes], flattened, absolute paths only —
  /// which is what branch-level routes use.
  List<String> topLevelPaths(List<RouteBase> routes) =>
      routes.whereType<GoRoute>().map((r) => r.path).toList();

  test('the shell has the five branches, in destination order', () {
    expect(shell().branches, hasLength(5));
    expect(kAppDestinations, hasLength(5));
  });

  test('each branch has its own navigator', () {
    final keys = shell().branches
        .map((b) => b.navigatorKey)
        .toList(growable: false);

    expect(
      keys.toSet(),
      hasLength(keys.length),
      reason:
          'two branches sharing a navigator would share a back stack, and '
          'switching tabs would lose where the user was',
    );
    expect(
      keys,
      isNot(contains(router.configuration.navigatorKey)),
      reason: 'a branch must not reuse the root navigator',
    );
  });

  test('each branch is rooted on its destination, in both locales', () {
    for (var i = 0; i < kAppDestinations.length; i++) {
      final paths = topLevelPaths(shell().branches[i].routes);
      for (final variant in kAppDestinations[i].paths.values) {
        expect(
          paths,
          contains(variant),
          reason: 'branch $i should serve ${kAppDestinations[i].label}',
        );
      }
    }
  });

  test('the Explorer branch opens on the routes map, the list beside it', () {
    final explorer = shell().branches[3];
    expect(
      PathVariants.allRoutesMap().values,
      contains(explorer.defaultRoute?.path),
      reason: 'the tab, and a tap on it once shown, land on the map',
    );
    expect(
      topLevelPaths(explorer.routes),
      containsAll(PathVariants.allRoutes().values),
    );
  });

  test('the team tree lives in the Teams branch, at unchanged URLs', () {
    final teamsBranch = shell().branches[1];
    final paths = topLevelPaths(teamsBranch.routes);

    for (final variant in PathVariants.team(':teamSlug').values) {
      expect(paths, contains(variant));
    }
    for (final variant in PathVariants.teamsDiscover().values) {
      expect(paths, contains(variant));
    }

    // The literal discovery segment must be declared before the `:teamSlug`
    // parameter, otherwise `/equipes/decouvrir` would be read as a team slug.
    expect(
      paths.indexOf(PathVariants.teamsDiscover()['fr']!),
      lessThan(paths.indexOf(PathVariants.team(':teamSlug')['fr']!)),
    );
  });

  test(
    'every mobile route still resolves, tabs and team sections included',
    () {
      const slug = 'n-peloton';
      final everyPath = <String>[
        ...PathVariants.home().values,
        ...PathVariants.teams().values,
        ...PathVariants.teamsDiscover().values,
        ...PathVariants.calendar().values,
        ...PathVariants.allRoutes().values,
        ...PathVariants.allRoutesMap().values,
        ...PathVariants.profile().values,
        ...PathVariants.team(slug).values,
        ...PathVariants.teamAbout(slug).values,
        ...PathVariants.teamCalendar(slug).values,
        ...PathVariants.teamAds(slug).values,
        ...PathVariants.teamMembers(slug).values,
        ...PathVariants.teamPage(slug, 'notre-histoire').values,
        ...PathVariants.routes(slug).values,
        ...PathVariants.route(slug, 'galibier').values,
        ...PathVariants.ride(slug, 'rando').values,
        ...PathVariants.post(slug, 'article').values,
        ...PathVariants.trip(slug, 'alpes').values,
        ...PathVariants.stage(slug, 'alpes', 'jour-1').values,
        ...PathVariants.ad(slug, 'velo').values,
      ];

      for (final path in everyPath) {
        expect(
          router.configuration.findMatch(Uri.parse(path)).isError,
          isFalse,
          reason: 'no route matches $path',
        );
      }
    },
  );

  test('full-screen detail pages still escape to the root navigator', () {
    final teamRoute = shell().branches[1].routes
        .whereType<GoRoute>()
        .firstWhere((r) => r.path == PathVariants.team(':teamSlug')['fr']!);

    final rootKey = router.configuration.navigatorKey;
    GlobalKey<NavigatorState>? parentOf(String suffix) => teamRoute.routes
        .whereType<GoRoute>()
        .firstWhere((r) => r.path.startsWith(suffix))
        .parentNavigatorKey;

    // Details cover the tab bar…
    for (final suffix in ['sorties/', 'articles/', 'voyages/', 'annonces/']) {
      expect(parentOf(suffix), same(rootKey), reason: suffix);
    }
    // …while team sections stay inside the branch, under the tab bar.
    for (final suffix in ['calendrier', 'annonces', 'membres', 'a-propos']) {
      expect(
        teamRoute.routes
            .whereType<GoRoute>()
            .firstWhere((r) => r.path == suffix)
            .parentNavigatorKey,
        isNull,
        reason: suffix,
      );
    }
  });
}
