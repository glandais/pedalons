import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/adaptive/navigation_destination.dart';

import 'module.dart';

/// The route library (the Explorer tab, and a team's Parcours section): search, filters, the
/// list/map toggle — and a route's page, its trace and « Utilisée dans ».
final class Routes extends Module {
  Routes(super.$);

  /// The Explorer tab, which opens on the map (ledger `WEB-114`); then [switchToList] for the
  /// cards.
  Future<void> goToRoutes() async {
    await $(
      keys.navigation.tab(
        kAppDestinations.firstWhere((d) => d.label == 'nav.explore'),
      ),
    ).tap();
    await $(keys.routes.mapView).waitUntilExists();
  }

  // ── The list ────────────────────────────────────────────────────────────

  Future<void> search(String text) async {
    await $(keys.routes.searchField).enterText(text);
  }

  /// Waits until the list holds the card of [routeSlug] (the search is debounced, then answered by
  /// the API).
  Future<void> waitUntilListed(String routeSlug) async {
    await $(keys.routes.card(routeSlug))
        .waitUntilExists(timeout: const Duration(seconds: 20));
  }

  Future<void> waitUntilNotListed(String routeSlug) async {
    await waitUntilGone(keys.routes.card(routeSlug));
  }

  bool isListed(String routeSlug) => isShown(keys.routes.card(routeSlug));

  /// The filter sheet: picks [value] among a choice (a `SurfaceType`, a `Hilliness`…), applies.
  Future<void> filterBy(Object value) async {
    await $(keys.routes.filterButton).tap();
    await $(keys.routes.filterChoice(value)).waitUntilExists();
    await $.tester.ensureVisible(find.byKey(keys.routes.filterChoice(value)));
    await $.pump(const Duration(milliseconds: 300));
    await $(keys.routes.filterChoice(value)).tap();
    await $(keys.routes.filterApplyButton).tap();
    await waitUntilGone(keys.routes.filterApplyButton);
  }

  /// Waits for the filtered dead end: nothing matches, the way out is offered.
  Future<void> waitUntilFilteredEmpty() async {
    await $(keys.routes.emptyState).waitUntilExists();
  }

  /// Whether the tags of [routeSlug]'s card name [label] — brought into view first.
  Future<bool> cardTagsShow(String routeSlug, String label) async {
    await scrolledIntoView(keys.routes.cardTags(routeSlug));
    return shows(keys.routes.cardTags(routeSlug), label);
  }

  /// The « Tags » chip of a team's list → ticks [tagId] in the sheet → « Appliquer ». The chip is
  /// the last of its row, past its right edge on a phone.
  Future<void> filterByTag(String tagId) async {
    await $(keys.tags.filterChip)
        .waitUntilExists(timeout: const Duration(seconds: 20));
    await $.tester.ensureVisible(find.byKey(keys.tags.filterChip));
    await $.pump(const Duration(milliseconds: 300));
    await $(keys.tags.filterChip).tap();
    await $(keys.tags.pickerRow(tagId)).tap();
    await $(keys.tags.pickerApply).tap();
    await waitUntilGone(keys.tags.pickerApply);
  }

  Future<void> switchToMap() async {
    await $(keys.routes.mapViewSegment).tap();
    await $(keys.routes.mapView).waitUntilExists();
  }

  Future<void> switchToList() async {
    await $(keys.routes.listViewSegment).tap();
    await waitUntilGone(keys.routes.mapView);
  }

  bool get showsMap => isShown(keys.routes.mapView);

  Future<void> openRoute(String routeSlug) async {
    await (await scrolledTo(keys.routes.card(routeSlug))).tap();
    await waitUntilRouteIsShown();
  }

  // ── A route's page ──────────────────────────────────────────────────────

  Future<void> waitUntilRouteIsShown() async {
    await $(keys.routeDetail.title)
        .waitUntilVisible(timeout: const Duration(seconds: 20));
  }

  bool routeTitleShows(String name) => shows(keys.routeDetail.title, name);

  /// Waits for the elevation profile, drawn from the stored track — neither tiles nor routing.
  Future<void> waitUntilTraceIsShown() async {
    await $(keys.routeDetail.elevationProfile)
        .waitUntilExists(timeout: const Duration(seconds: 20));
  }

  /// Waits for the « Utilisée dans » card of the ride or trip [slug].
  Future<void> waitUntilUsageIsShown(String slug) async {
    await $(keys.routeDetail.usage(slug))
        .waitUntilExists(timeout: const Duration(seconds: 20));
  }

  bool showsUsage(String slug) => isShown(keys.routeDetail.usage(slug));

  bool usageShows(String slug, String text) =>
      shows(keys.routeDetail.usage(slug), text);
}
