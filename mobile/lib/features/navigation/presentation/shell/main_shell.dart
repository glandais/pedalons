import 'package:go_router/go_router.dart';

import '../../../../core/adaptive/adaptive.dart';
import '../../../../core/config/app_outdated_banner.dart';
import '../../../../core/material.dart';

/// The one and only navigation shell: five fixed tabs, present on every screen
/// that is not a full-screen detail page — team screens included.
///
/// Backed by a [StatefulShellRoute.indexedStack], so **each tab keeps its own
/// stack**: opening a team, switching to Calendar and coming back to Teams
/// restores the team where it was left.
///
/// - Compact screens: `PdlBottomTabs` (wave C of the component library)
/// - Medium screens: side NavigationRail
/// - Expanded screens: extended NavigationRail
class MainShell extends StatelessWidget {
  /// The shell built by go_router. It is both the body (an `IndexedStack` of
  /// the five branch navigators) and the API to switch branch.
  final StatefulNavigationShell navigationShell;

  /// Router state of the current match — its `uri` is the full location.
  final GoRouterState state;

  const MainShell({
    super.key,
    required this.navigationShell,
    required this.state,
  });

  void _onDestinationSelected(int index) {
    // Tapping the tab already shown pops its branch back to its root, the
    // platform-standard behaviour; tapping another one restores that branch
    // where it was left.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      // Derived from the URL rather than read off the shell, so a single rule —
      // the most specific destination prefix — decides the highlighted tab, and
      // `/equipes/{slug}/parcours` stays on Teams instead of jumping to Routes.
      selectedIndex: getDestinationIndex(state.uri.path),
      onDestinationSelected: _onDestinationSelected,
      // Le bandeau d'obsolescence vit ici et non dans chaque page : il porte
      // sur l'application, pas sur un écran, et il ne rend rien tant que le
      // serveur n'a pas dit qu'il y avait lieu de prévenir.
      child: Column(
        children: <Widget>[
          const AppOutdatedBanner(),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
