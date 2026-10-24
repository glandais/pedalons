import 'package:flutter/material.dart';

import '../../config/locale_context.dart';
import '../../config/paths.generated.dart';

/// Abstract navigation destination used by both NavigationBar and NavigationRail.
class AppDestination {
  final Map<String, String> paths;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AppDestination({
    required this.paths,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  /// URL in the current locale — use for `context.go(...)`.
  String get currentPath => paths[getCurrentLocale()] ?? paths.values.first;
}

/// App-wide navigation destinations, in branch order.
///
/// This list **is** the order of the branches of the `StatefulShellRoute` in
/// `router.dart`: index `i` here selects branch `i` there. Index 0 (home, path
/// `/`) is the fallback destination and must be listed first — see
/// [getDestinationIndex].
///
/// The Teams icon is `group`, settled once for the whole app (the Foundations
/// board uses `i-group`, screens 33/34 `i-users` — only one is kept).
final List<AppDestination> kAppDestinations = [
  AppDestination(
    paths: PathVariants.home(),
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'nav.home',
  ),
  AppDestination(
    paths: PathVariants.teams(),
    icon: Icons.group_outlined,
    selectedIcon: Icons.group,
    label: 'nav.teams',
  ),
  AppDestination(
    paths: PathVariants.calendar(),
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
    label: 'nav.calendar',
  ),
  // « Explorer » : the route library across every team, which the tab opens on
  // its map (the branch's first route in `router.dart`). Matched on the list's
  // path, which prefixes the map's, so both light it up (docs/LEDGER_*.md
  // WEB-114).
  AppDestination(
    paths: PathVariants.allRoutes(),
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
    label: 'nav.explore',
  ),
  AppDestination(
    paths: PathVariants.profile(),
    icon: Icons.person_outlined,
    selectedIcon: Icons.person,
    label: 'nav.profile',
  ),
];

/// Finds the destination index for a given location path.
///
/// Matches against every locale variant so that deep links in one language
/// highlight the right tab even when the user's current locale differs.
/// Home (`/`) is the fallback — skipped during matching since it would
/// prefix-match everything.
///
/// **Most specific wins.** A team's route library lives at
/// `/equipes/{slug}/parcours`, one segment deeper than the global Explorer tab at
/// `/parcours`; matching the longest destination prefix keeps it on Teams
/// instead of letting a shorter, unrelated prefix claim it. Length comparison
/// rather than declaration order so adding a destination cannot silently
/// reshuffle the outcome.
int getDestinationIndex(String location) {
  var bestIndex = 0;
  var bestLength = -1;

  for (int i = 1; i < kAppDestinations.length; i++) {
    for (final path in kAppDestinations[i].paths.values) {
      if (location == path ||
          location.startsWith('$path/') ||
          location.startsWith('$path?')) {
        if (path.length > bestLength) {
          bestLength = path.length;
          bestIndex = i;
        }
      }
    }
  }
  return bestIndex;
}
