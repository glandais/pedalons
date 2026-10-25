import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/config/router.dart';

/// The ancestors returned here are what the deep link handler pushes below the
/// target page, so a link opened from outside the app always has a back stack.
///
/// This file is the safety net for any rework of `router.dart`'s shells: the
/// hierarchy is data, and the assertions below are derived from that data
/// rather than hand-listed, so a route added to (or dropped from)
/// `_deepLinkHierarchies` fails the suite until it is covered here.

/// Slugs used to instantiate the parameterized patterns. Kept distinct so a
/// mixed-up parameter shows up in the failure message.
const _teamSlug = 'velo-club';
const _rideSlug = 'rando-du-dimanche';
const _groupId = '0abc1def2ghi3';
const _tripSlug = 'alpes';
const _stageSlug = 'etape-1';
const _postSlug = 'mon-article';
const _routeSlug = 'col-du-galibier';
const _adSlug = 'velo-a-vendre';
const _pageSlug = 'notre-histoire';
const _templateSlug = 'sortie-du-dimanche';

/// One entry of `_deepLinkHierarchies`, mirrored as concrete URLs.
///
/// [id] is the `PathVariants` builder used in `router.dart` — the completeness
/// test below matches these ids against the ones parsed from the source.
class _LinkCase {
  final String id;
  final Map<String, String> target;
  final List<Map<String, String>> ancestors;

  const _LinkCase(this.id, this.target, this.ancestors);
}

/// Every entry of `_deepLinkHierarchies`, in the same order.
final List<_LinkCase> _cases = [
  // Standalone pages outside any shell → back to home.
  _LinkCase('apps', PathVariants.apps(), [PathVariants.home()]),
  _LinkCase('privacy', PathVariants.privacy(), [PathVariants.home()]),
  _LinkCase('terms', PathVariants.terms(), [PathVariants.home()]),
  _LinkCase('deviceVerifyGarmin', PathVariants.deviceVerifyGarmin(), [
    PathVariants.home(),
  ]),
  _LinkCase('deviceVerifyKaroo', PathVariants.deviceVerifyKaroo(), [
    PathVariants.home(),
  ]),
  _LinkCase('deviceHammerhead', PathVariants.deviceHammerhead(), [
    PathVariants.home(),
  ]),

  // La boîte de réception vit sous l'accueil, d'où sa cloche l'ouvre.
  _LinkCase('notifications', PathVariants.notifications(), [
    PathVariants.home(),
  ]),

  // Les sous-pages du profil vivent sous sa vue d'ensemble.
  _LinkCase('profilePreferences', PathVariants.profilePreferences(), [
    PathVariants.profile(),
  ]),
  _LinkCase('profileNotifications', PathVariants.profileNotifications(), [
    PathVariants.profile(),
  ]),
  _LinkCase('profileDevices', PathVariants.profileDevices(), [
    PathVariants.profile(),
  ]),
  _LinkCase('profileSecurity', PathVariants.profileSecurity(), [
    PathVariants.profile(),
  ]),
  _LinkCase('profilePrivacy', PathVariants.profilePrivacy(), [
    PathVariants.profile(),
  ]),
  // « Personnes bloquées » est sous « Confidentialité ».
  _LinkCase('blockedUsers', PathVariants.blockedUsers(), [
    PathVariants.profile(),
    PathVariants.profilePrivacy(),
  ]),
  _LinkCase('profileAccount', PathVariants.profileAccount(), [
    PathVariants.profile(),
  ]),
  _LinkCase('profileHelp', PathVariants.profileHelp(), [
    PathVariants.profile(),
  ]),

  // Team pages → back to the teams list (not home: two branch roots stacked
  // would merge into one shell match).
  _LinkCase('teamsDiscover', PathVariants.teamsDiscover(), [
    PathVariants.teams(),
  ]),
  _LinkCase('team', PathVariants.team(_teamSlug), [PathVariants.teams()]),

  // Team sections. They stopped at the teams list while `TeamShell` provided
  // the navigation between them; that shell is gone, so each section is a plain
  // page of the Teams branch and needs the team itself underneath — otherwise a
  // cold start on `/equipes/x/a-propos` would go back to `/equipes` without ever
  // showing team x.
  _LinkCase('teamAbout', PathVariants.teamAbout(_teamSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
  ]),
  _LinkCase('teamCalendar', PathVariants.teamCalendar(_teamSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
  ]),
  _LinkCase('routes', PathVariants.routes(_teamSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
  ]),
  _LinkCase('teamAds', PathVariants.teamAds(_teamSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
  ]),
  _LinkCase('teamMembers', PathVariants.teamMembers(_teamSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
  ]),
  // L'Agenda et les Publications du site (ledger `WEB-68`).
  _LinkCase('teamAgenda', PathVariants.teamAgenda(_teamSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
  ]),
  _LinkCase('teamPosts', PathVariants.teamPosts(_teamSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
  ]),
  // Les anciens onglets « Sorties » / « Voyages » du site (ledger `WEB-64`),
  // rendus en Agenda.
  _LinkCase('teamRides', PathVariants.teamRides(_teamSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
  ]),
  _LinkCase('teamTrips', PathVariants.teamTrips(_teamSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
  ]),

  // Detail pages → the full chain down to their list.
  _LinkCase('teamPage', PathVariants.teamPage(_teamSlug, _pageSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
  ]),
  // Une sortie et un voyage sous l'Agenda, une publication sous les
  // Publications (ledger `MOB-60`).
  _LinkCase('ride', PathVariants.ride(_teamSlug, _rideSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
    PathVariants.teamAgenda(_teamSlug),
  ]),
  _LinkCase(
    'rideGroup',
    PathVariants.rideGroup(_teamSlug, _rideSlug, _groupId),
    [
      PathVariants.teams(),
      PathVariants.team(_teamSlug),
      PathVariants.teamAgenda(_teamSlug),
      PathVariants.ride(_teamSlug, _rideSlug),
    ],
  ),
  // L'éditeur d'une sortie (ledger `MOB-80`) : la création sous l'Agenda,
  // la modification sous la fiche qu'elle réécrit.
  _LinkCase('rideNew', PathVariants.rideNew(_teamSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
    PathVariants.teamAgenda(_teamSlug),
  ]),
  _LinkCase('rideEdit', PathVariants.rideEdit(_teamSlug, _rideSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
    PathVariants.teamAgenda(_teamSlug),
    PathVariants.ride(_teamSlug, _rideSlug),
  ]),
  // Les modèles de sortie (ledger `MOB-78`) : la liste sous l'équipe, le
  // formulaire sous la liste.
  _LinkCase('rideTemplates', PathVariants.rideTemplates(_teamSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
  ]),
  _LinkCase('rideTemplateNew', PathVariants.rideTemplateNew(_teamSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
    PathVariants.rideTemplates(_teamSlug),
  ]),
  _LinkCase(
    'rideTemplateEdit',
    PathVariants.rideTemplateEdit(_teamSlug, _templateSlug),
    [
      PathVariants.teams(),
      PathVariants.team(_teamSlug),
      PathVariants.rideTemplates(_teamSlug),
    ],
  ),
  _LinkCase('post', PathVariants.post(_teamSlug, _postSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
    PathVariants.teamPosts(_teamSlug),
  ]),
  _LinkCase('trip', PathVariants.trip(_teamSlug, _tripSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
    PathVariants.teamAgenda(_teamSlug),
  ]),
  _LinkCase('stage', PathVariants.stage(_teamSlug, _tripSlug, _stageSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
    PathVariants.teamAgenda(_teamSlug),
    PathVariants.trip(_teamSlug, _tripSlug),
  ]),
  _LinkCase('ad', PathVariants.ad(_teamSlug, _adSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
    PathVariants.teamAds(_teamSlug),
  ]),
  // L'éditeur d'un parcours (ledger `MOB-79`) : la création sous la liste des
  // parcours, la modification sous la fiche qu'elle réécrit. `routeNew` et
  // `routeEdit` avant `route`, comme dans le routeur.
  _LinkCase('routeNew', PathVariants.routeNew(_teamSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
    PathVariants.routes(_teamSlug),
  ]),
  _LinkCase('routeEdit', PathVariants.routeEdit(_teamSlug, _routeSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
    PathVariants.routes(_teamSlug),
    PathVariants.route(_teamSlug, _routeSlug),
  ]),
  _LinkCase('route', PathVariants.route(_teamSlug, _routeSlug), [
    PathVariants.teams(),
    PathVariants.team(_teamSlug),
    PathVariants.routes(_teamSlug),
  ]),
];

/// Deep-linkable routes that legitimately have no ancestor: they either carry
/// the bottom navigation themselves or are auth pages, which own their flow.
final Map<String, Map<String, String>> _selfNavigating = {
  'home': PathVariants.home(),
  'teams': PathVariants.teams(),
  'calendar': PathVariants.calendar(),
  'allRoutes': PathVariants.allRoutes(),
  // The Explorer tab's root since WEB-114: the list is its other view.
  'allRoutesMap': PathVariants.allRoutesMap(),
  'profile': PathVariants.profile(),
  'login': PathVariants.login(),
  'register': PathVariants.register(),
  'verifyEmail': PathVariants.verifyEmail(),
  'forgotPassword': PathVariants.forgotPassword(),
  'resetPassword': PathVariants.resetPassword(),
};

/// `/a/b` is under `/a`, and everything is under `/`.
///
/// One parent is logical rather than a prefix: a team's Agenda holds its rides
/// and trips (`/equipes/x/agenda` above `/equipes/x/sorties/y`), as the site's
/// breadcrumb does (ledger `MOB-60`). It is accepted above those two only.
bool _isAncestorPath(String ancestor, String path) {
  if (ancestor == '/' || path.startsWith('$ancestor/')) return true;
  const String agenda = '/agenda';
  if (!ancestor.endsWith(agenda)) return false;
  final String team = ancestor.substring(0, ancestor.length - agenda.length);
  return <String>[
    'sorties',
    'rides',
    'voyages',
    'trips',
  ].any((String segment) => path.startsWith('$team/$segment/'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GoRouter router;

  setUpAll(() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    router = container.read(routerProvider);
  });

  bool routerMatches(String path) =>
      !router.configuration.findMatch(Uri.parse(path)).isError;

  group('ancestorsForDeepLink — every hierarchy entry, every locale', () {
    for (final c in _cases) {
      for (final locale in c.target.keys) {
        final target = c.target[locale]!;
        final expected = c.ancestors.map((v) => v[locale]!).toList();

        test('${c.id} [$locale] $target', () {
          final actual = ancestorsForDeepLink(target);

          // The chain itself, in the locale the link was authored in.
          expect(actual, expected, reason: 'wrong ancestors for $target');
          expect(
            actual,
            isNotEmpty,
            reason:
                '$target would open with no back '
                'stack',
          );

          // Root → immediate parent, each one strictly above the next and
          // above the target. Catches a reordered or mis-scoped chain.
          expect(
            actual.toSet(),
            hasLength(actual.length),
            reason: 'duplicate ancestor in $actual',
          );
          expect(
            actual,
            isNot(contains(target)),
            reason: 'the target must not be pushed twice',
          );
          for (var i = 0; i < actual.length; i++) {
            expect(
              _isAncestorPath(actual[i], target),
              isTrue,
              reason: '"${actual[i]}" is not above "$target"',
            );
            if (i > 0) {
              expect(
                _isAncestorPath(actual[i - 1], actual[i]),
                isTrue,
                reason: '"${actual[i - 1]}" is not above "${actual[i]}"',
              );
            }
          }

          // Locale purity: an ancestor built in the other locale would not sit
          // above a target authored in this one, except where both locales
          // share the same URL.
          for (final other in c.target.keys) {
            if (other == locale) continue;
            for (var i = 0; i < actual.length; i++) {
              final otherVariant = c.ancestors[i][other]!;
              if (otherVariant == expected[i]) continue;
              expect(
                actual[i],
                isNot(otherVariant),
                reason: 'ancestor $i of $target is in locale "$other"',
              );
            }
          }

          // Query strings belong to the target, not to the match.
          expect(ancestorsForDeepLink('$target?token=abc&x=1'), expected);

          // The pushed URLs must be real routes, not just strings.
          expect(
            routerMatches(target),
            isTrue,
            reason: 'no route matches the target $target',
          );
          for (final ancestor in actual) {
            expect(
              routerMatches(ancestor),
              isTrue,
              reason: 'no route matches the ancestor $ancestor',
            );
          }
        });
      }
    }
  });

  group('pages that carry their own navigation need no ancestor', () {
    _selfNavigating.forEach((id, variants) {
      for (final locale in variants.keys) {
        final path = variants[locale]!;
        test('$id [$locale] $path', () {
          expect(ancestorsForDeepLink(path), isEmpty);
          expect(ancestorsForDeepLink('$path?token=abc'), isEmpty);
          expect(routerMatches(path), isTrue);
        });
      }
    });
  });

  group('explicit chains', () {
    test('legal pages fall back to the app home', () {
      expect(ancestorsForDeepLink('/confidentialite'), ['/']);
      expect(ancestorsForDeepLink('/privacy'), ['/']);
      expect(ancestorsForDeepLink('/cgu'), ['/']);
      expect(ancestorsForDeepLink('/terms'), ['/']);
    });

    test(
      'device verification pages keep their query string out of the match',
      () {
        expect(ancestorsForDeepLink('/garmin?code=ABC123'), ['/']);
        expect(ancestorsForDeepLink('/karoo'), ['/']);
      },
    );

    // Team-scoped chains start at the teams tab, not at home: stacking two
    // branch roots would leave the shell state — and so the highlighted tab —
    // on the first one.
    test('a team goes back to the teams list', () {
      expect(ancestorsForDeepLink('/equipes/velo-club'), ['/equipes']);
      expect(ancestorsForDeepLink('/teams/velo-club'), ['/teams']);
      expect(ancestorsForDeepLink('/equipes/decouvrir'), ['/equipes']);
    });

    // Sections are content of the team since `TeamShell` was removed, so the
    // team sits between them and the teams list.
    test('team sections go back through the team itself', () {
      expect(ancestorsForDeepLink('/equipes/velo-club/a-propos'), [
        '/equipes',
        '/equipes/velo-club',
      ]);
      expect(ancestorsForDeepLink('/equipes/velo-club/calendrier'), [
        '/equipes',
        '/equipes/velo-club',
      ]);
      expect(ancestorsForDeepLink('/equipes/velo-club/parcours'), [
        '/equipes',
        '/equipes/velo-club',
      ]);
      expect(ancestorsForDeepLink('/equipes/velo-club/annonces'), [
        '/equipes',
        '/equipes/velo-club',
      ]);
      expect(ancestorsForDeepLink('/teams/velo-club/classifieds'), [
        '/teams',
        '/teams/velo-club',
      ]);
      // The criterion of F-NA-3, verbatim: a cold link to a team's member list
      // has the team, then "my teams", underneath.
      expect(ancestorsForDeepLink('/equipes/n-peloton/membres'), [
        '/equipes',
        '/equipes/n-peloton',
      ]);
      expect(ancestorsForDeepLink('/teams/n-peloton/members'), [
        '/teams',
        '/teams/n-peloton',
      ]);
    });

    test(
      'the global routes map is the Explorer tab root, with nothing under it',
      () {
        expect(ancestorsForDeepLink('/parcours/carte'), isEmpty);
        expect(ancestorsForDeepLink('/routes/map'), isEmpty);
      },
    );

    test('detail pages rebuild their full hierarchy', () {
      expect(ancestorsForDeepLink('/equipes/velo-club/sorties/rando'), [
        '/equipes',
        '/equipes/velo-club',
        '/equipes/velo-club/agenda',
      ]);
      expect(ancestorsForDeepLink('/equipes/velo-club/articles/mon-article'), [
        '/equipes',
        '/equipes/velo-club',
        '/equipes/velo-club/articles',
      ]);
      expect(ancestorsForDeepLink('/equipes/velo-club/voyages/alpes'), [
        '/equipes',
        '/equipes/velo-club',
        '/equipes/velo-club/agenda',
      ]);
      expect(
        ancestorsForDeepLink('/equipes/velo-club/voyages/alpes/etapes/jour-1'),
        [
          '/equipes',
          '/equipes/velo-club',
          '/equipes/velo-club/agenda',
          '/equipes/velo-club/voyages/alpes',
        ],
      );
      expect(
        ancestorsForDeepLink('/teams/velo-club/trips/alpes/stages/day-1'),
        [
          '/teams',
          '/teams/velo-club',
          '/teams/velo-club/agenda',
          '/teams/velo-club/trips/alpes',
        ],
      );
      expect(ancestorsForDeepLink('/equipes/velo-club/parcours/galibier'), [
        '/equipes',
        '/equipes/velo-club',
        '/equipes/velo-club/parcours',
      ]);
      expect(ancestorsForDeepLink('/equipes/velo-club/annonces/velo'), [
        '/equipes',
        '/equipes/velo-club',
        '/equipes/velo-club/annonces',
      ]);
      expect(ancestorsForDeepLink('/equipes/velo-club/pages/notre-histoire'), [
        '/equipes',
        '/equipes/velo-club',
      ]);
    });

    test('an unknown path gets no ancestor rather than a bogus one', () {
      expect(ancestorsForDeepLink('/equipes/velo-club/inconnu/x'), isEmpty);
      expect(ancestorsForDeepLink('/nope'), isEmpty);
    });
  });

  // The two guards that keep the table above honest: it must list exactly the
  // entries declared in router.dart, and every deep-linkable mobile route of
  // the contract must be accounted for — with a hierarchy or as a page that
  // navigates on its own.
  group('completeness', () {
    test('covers exactly the entries of _deepLinkHierarchies', () {
      final source = File('lib/config/router.dart').readAsStringSync();
      final start = source.indexOf('_deepLinkHierarchies = [');
      expect(start, isNonNegative, reason: '_deepLinkHierarchies not found');
      final end = source.indexOf('\n];', start);
      expect(end, isNonNegative);
      final block = source.substring(start, end);

      final declared = RegExp(r'patterns:\s*PathVariants\.(\w+)\(')
          .allMatches(block)
          .map((m) => m.group(1)!)
          .toList();

      expect(
        _cases.map((c) => c.id).toList(),
        declared,
        reason:
            'the table in this test must mirror _deepLinkHierarchies '
            '(same entries, same order)',
      );
    });

    test('every deep-linkable mobile route is classified', () {
      final ids = _mobileDeepLinkIds();
      expect(ids, isNotEmpty, reason: 'routes.yaml parsing broke');

      final known = {..._cases.map((c) => c.id), ..._selfNavigating.keys};
      expect(
        ids.difference(known),
        isEmpty,
        reason:
            'these deep-linkable routes have neither a hierarchy nor a '
            'self-navigating exemption',
      );
    });
  });
}

/// Mobile builder names of the routes declared deep-linkable in the contract.
/// Hand-rolled rather than pulling in a YAML parser: the file is a flat list of
/// blocks with one field per line.
Set<String> _mobileDeepLinkIds() {
  final lines = File('../contracts/routes.yaml')
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('#'));

  final ids = <String>{};
  String? id;
  String? mobileName;
  var mobile = false;
  var deeplink = false;

  void flush() {
    if (id != null && mobile && deeplink) ids.add(mobileName ?? id!);
    id = null;
    mobileName = null;
    mobile = false;
    deeplink = false;
  }

  for (final line in lines) {
    final idMatch = RegExp(r'^\s*- id:\s*(\S+)\s*$').firstMatch(line);
    if (idMatch != null) {
      flush();
      id = idMatch.group(1);
      continue;
    }
    if (id == null) continue;
    final field = RegExp(r'^    (\w+):\s*(\S+)\s*$').firstMatch(line);
    if (field == null) continue;
    switch (field.group(1)) {
      case 'mobile':
        mobile = field.group(2) == 'true';
      case 'deeplink':
        deeplink = field.group(2) == 'true';
      case 'mobileName':
        mobileName = field.group(2);
    }
  }
  flush();
  return ids;
}
