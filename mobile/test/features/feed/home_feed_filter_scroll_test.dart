import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/dev/card_gallery/gallery_data.dart';
import 'package:pedalons/features/feed/presentation/widgets/publication_feed_view.dart';
import 'package:pedalons/features/feed/providers/publication_feed_provider.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import '../teams/team_fixtures.dart';

/// Un filtre touché sur l'accueil ramène au début du fil, pas au-dessus des
/// blocs qui le précèdent (docs/LEDGER_*.md MOB-155).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  /// Ce qui précède le fil : « Ma prochaine sortie », « Cette semaine »…
  const double leading = 900;
  const double appBar = 56;

  Future<void> pumpFeed(
    WidgetTester tester, {
    required bool filtersKeepLeading,
  }) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final GalleryData d = GalleryData(images: false);
    final PageResult<PublicationDto> page = PageResult<PublicationDto>(
      items: <PublicationDto>[d.feedRide(), d.feedTrip(), d.feedPost()],
      total: 3,
      firstSectionTotal: 2,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unitSystemProvider.overrideWithValue(UnitSystem.metric),
          publicationFeedProvider.overrideWith((ref, key) => _Feed(key, page)),
          publicationFeedCountProvider.overrideWith((ref, key) async => 3),
          myTeamsProvider.overrideWith(
            (ref) async => <TeamDetailDto>[fixtureTeam()],
          ),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: PublicationFeedView(
              teamSlug: null,
              emptyMessage: 'vide',
              showSectionHeader: true,
              showPeriod: true,
              datedSections: true,
              filtersKeepLeading: filtersKeepLeading,
              leadingSlivers: const <Widget>[
                // Épinglée, comme la barre supérieure de l'accueil.
                SliverAppBar(pinned: true, toolbarHeight: appBar),
                SliverToBoxAdapter(child: SizedBox(height: leading)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  ScrollPosition position(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  Future<void> tapType(WidgetTester tester) async {
    await tester.tap(find.byKey(keys.feed.typeChip(PublicationType.ride)));
    await tester.pump();
    await tester.pump();
  }

  Future<void> tearDownFeed(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('plus bas dans le fil : retour au début du fil, la barre reste '
      'épinglée', (WidgetTester tester) async {
    await pumpFeed(tester, filtersKeepLeading: true);
    position(tester).jumpTo(leading + 120);
    await tester.pump();

    await tapType(tester);

    expect(position(tester).pixels, leading);
    await tearDownFeed(tester);
  });

  testWidgets('au-dessus du fil : rien ne bouge', (WidgetTester tester) async {
    await pumpFeed(tester, filtersKeepLeading: true);
    position(tester).jumpTo(leading - 300);
    await tester.pump();

    await tapType(tester);

    expect(position(tester).pixels, leading - 300);
    await tearDownFeed(tester);
  });

  testWidgets('sans l\'option (Agenda, Publications) : tout en haut', (
    WidgetTester tester,
  ) async {
    await pumpFeed(tester, filtersKeepLeading: false);
    position(tester).jumpTo(leading + 120);
    await tester.pump();

    await tapType(tester);

    expect(position(tester).pixels, 0);
    await tearDownFeed(tester);
  });
}

class _Feed extends PublicationFeedNotifier {
  _Feed(PublicationFeedKey key, this.page)
    : super(PublicationsClient(Dio()), key);

  final PageResult<PublicationDto> page;

  @override
  Future<PageResult<PublicationDto>> fetchPage(int index) =>
      Future<PageResult<PublicationDto>>.value(
        index == 0
            ? page
            : PageResult<PublicationDto>(
                items: const <PublicationDto>[],
                total: page.total,
                firstSectionTotal: page.firstSectionTotal,
              ),
      );
}
