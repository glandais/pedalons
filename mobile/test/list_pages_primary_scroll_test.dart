import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/features/feed/presentation/widgets/publication_feed_view.dart';
import 'package:pedalons/features/feed/providers/publication_feed_provider.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/routes/presentation/pages/routes_page.dart';
import 'package:pedalons/features/routes/domain/route_filters.dart';
import 'package:pedalons/features/routes/providers/route_list_provider.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The paginated lists must stay the primary scrollable of their route,
/// otherwise an iOS status-bar tap has nothing to scroll — see
/// `status_bar_scroll_to_top_test.dart` for the mechanism itself.
///
/// Regression guard: giving these pages a private [ScrollController] (say, to
/// scroll back to the top when a filter changes) silently takes the gesture
/// away, because a scroll view with an explicit controller is no longer the
/// primary one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The route list shows distances, so it reads the unit system, which reads
  /// the local mirror. The mirror is normally loaded before `runApp`; here an
  /// empty one is enough — the defaults are what this test wants anyway.
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  /// The automatic [PrimaryScrollController] inheritance keys off the
  /// platform, which [MaterialScrollBehavior] reads from the theme.
  Widget iosApp(Widget home) => MaterialApp(
    theme: ThemeData(platform: TargetPlatform.iOS),
    home: MediaQuery(
      data: const MediaQueryData(padding: EdgeInsets.only(top: 47)),
      child: home,
    ),
  );

  /// Asserts the page's scroll view is driven by the route's primary
  /// controller — the same check the markdown page makes.
  void expectDrivenByPrimaryController(WidgetTester tester) {
    final scrollView = find.byType(CustomScrollView);
    expect(scrollView, findsOneWidget);

    expect(
      tester.widget<CustomScrollView>(scrollView).controller,
      isNull,
      reason:
          'a scroll view with an explicit controller is not primary, so the '
          'status-bar tap would no longer reach it',
    );
    expect(
      tester.widget<Scrollable>(find.byType(Scrollable).first).controller,
      same(PrimaryScrollController.of(tester.element(scrollView))),
    );
  }

  testWidgets('the route list is the primary scrollable of its route', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routeListProvider.overrideWith(
            (ref, key) => _StuckRouteListNotifier(key),
          ),
          // La section d'une équipe charge son vocabulaire de tags : sans
          // override, la requête partirait sur un vrai Dio.
          teamTagsProvider.overrideWith(
            (ref, key) async => const <TagWithUsageDto>[],
          ),
          // Le bouton « Ajouter » lit « Mes équipes » pour savoir si
          // l'utilisateur est organisateur (MOB-79).
          myTeamsProvider.overrideWith((ref) async => <TeamDetailDto>[]),
        ],
        child: iosApp(const RoutesPage(teamSlug: 'n-peloton')),
      ),
    );
    await tester.pump();

    expectDrivenByPrimaryController(tester);
  });

  testWidgets('the publication feed is the primary scrollable of its route', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationFeedProvider.overrideWith(
            (ref, key) => _StuckFeedNotifier(key),
          ),
        ],
        child: iosApp(
          const Scaffold(
            body: PublicationFeedView(teamSlug: null, emptyMessage: 'empty'),
          ),
        ),
      ),
    );
    await tester.pump();

    expectDrivenByPrimaryController(tester);
  });
}

/// Never answers, so the page stays on its skeleton state and no HTTP call is
/// ever made.
class _StuckRouteListNotifier extends RouteListNotifier {
  _StuckRouteListNotifier(RouteFilters filters)
    : super(RouteRepository(RoutesClient(Dio())), filters);

  @override
  Future<PageResult<RouteDto>> fetchPage(int page) =>
      Completer<PageResult<RouteDto>>().future;
}

class _StuckFeedNotifier extends PublicationFeedNotifier {
  _StuckFeedNotifier(PublicationFeedKey key)
    : super(PublicationsClient(Dio()), key);

  @override
  Future<PageResult<PublicationDto>> fetchPage(int page) =>
      Completer<PageResult<PublicationDto>>().future;
}
