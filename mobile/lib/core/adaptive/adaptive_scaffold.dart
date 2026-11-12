import 'package:easy_localization/easy_localization.dart';

import '../../keys.dart';
import '../material.dart';
import '../pdl/pdl.dart';
import 'breakpoints.dart';
import 'navigation_destination.dart';

/// Adaptive scaffold that switches between bottom tabs and navigation rail
/// based on window width.
///
/// - Compact (< 600): [PdlBottomTabs] — the charter's tab bar, five fixed
///   entries, real system inset, blurred overlay background
/// - Medium (600-840): NavigationRail with icons and labels
/// - Expanded (>= 840): Extended NavigationRail
///
/// The rail is deliberately kept: below 600 px a bottom bar is the only place
/// a thumb reaches, above it a side rail gives the content its width back.
/// Only the compact branch moved to the component library.
class AdaptiveScaffold extends StatelessWidget {
  final Widget child;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const AdaptiveScaffold({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final sizeClass = Breakpoints.getWindowSizeClass(width);

    return switch (sizeClass) {
      WindowSizeClass.compact => _buildCompactLayout(context),
      WindowSizeClass.medium => _buildMediumLayout(context, extended: false),
      WindowSizeClass.expanded => _buildMediumLayout(context, extended: true),
    };
  }

  /// Compact layout with the charter's bottom tab bar.
  Widget _buildCompactLayout(BuildContext context) {
    // A plain [Scaffold] and not [PdlScreenScaffold]: the shell hosts whole
    // pages, each with its own scaffold, app bar and bottom padding. Letting
    // the shell extend its body under the tabs would make every page pad for
    // them a second time.
    return Scaffold(
      body: child,
      bottomNavigationBar: PdlBottomTabs(
        selectedIndex: selectedIndex,
        onSelected: onDestinationSelected,
        items: kAppDestinations
            .map(
              (dest) => PdlTabItem(
                key: keys.navigation.tab(dest),
                icon: dest.icon,
                activeIcon: dest.selectedIcon,
                label: dest.label.tr(),
              ),
            )
            .toList(),
      ),
    );
  }

  /// Medium/Expanded layout with navigation rail.
  Widget _buildMediumLayout(BuildContext context, {required bool extended}) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            extended: extended,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            backgroundColor: theme.colorScheme.surface,
            destinations: kAppDestinations
                .map(
                  (dest) => NavigationRailDestination(
                    icon: Icon(dest.icon),
                    selectedIcon: Icon(dest.selectedIcon),
                    label: Text(dest.label.tr()),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
