import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/feed/presentation/widgets/publication_feed_view.dart';
import 'package:pedalons/features/feed/providers/publication_feed_provider.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import '../teams/team_fixtures.dart';

/// Le fil d'accueil vide (règles RL8 et RL10 des listes, KIT §10) : la portée
/// écartée de son défaut est un filtre, que le vide filtré nomme et que
/// « Effacer les filtres » remet à « Membre » ; à zéro, l'en-tête ne compte
/// rien.
void main() {
  setUpAll(loadTestTranslations);

  late List<PublicationFeedKey> requested;
  setUp(() => requested = <PublicationFeedKey>[]);

  Future<void> open(
    WidgetTester tester, {
    PublicationFeedScopeChoice? scope,
    PublicationType? type,
  }) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicationFeedProvider.overrideWith((ref, key) {
            requested.add(key);
            return _EmptyFeedNotifier(key);
          }),
          publicationFeedCountProvider.overrideWith((ref, key) async => 0),
          myTeamsProvider.overrideWith(
            (ref) async => <TeamDetailDto>[fixtureTeam(role: 'MEMBER')],
          ),
          if (scope != null)
            publicationFeedScopeProvider(null).overrideWith((ref) => scope),
          if (type != null)
            publicationFeedTypeProvider(null).overrideWith((ref) => type),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const Scaffold(
            body: PublicationFeedView(
              teamSlug: null,
              emptyMessage: 'Aucune publication',
              showSectionHeader: true,
            ),
          ),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  testWidgets('sans filtre : le vide simple, et pas de « 0 publication »', (
    WidgetTester tester,
  ) async {
    await open(tester);

    expect(find.byKey(keys.feed.emptyState), findsOneWidget);
    final PdlSectionHeader header = tester.widget<PdlSectionHeader>(
      find.byType(PdlSectionHeader),
    );
    expect(header.count, isNull);
  });

  testWidgets('« Toutes les équipes » et « Sorties » sont nommés, et '
      '« Effacer les filtres » ramène à « Membre »', (
    WidgetTester tester,
  ) async {
    await open(tester, scope: (minRole: null), type: PublicationType.ride);

    expect(find.byKey(keys.feed.filteredEmptyState), findsOneWidget);
    expect(find.text('Aucune sortie pour ces filtres'), findsOneWidget);
    expect(
      find.text('Rien ne correspond à : Toutes les équipes · Sorties.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(keys.feed.clearFiltersButton));
    for (int i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(requested.last.type, isNull);
    expect(requested.last.minRole, MinRole.member);
    expect(find.byKey(keys.feed.emptyState), findsOneWidget);
  });
}

/// Rend une liste vide : les états vides du fil.
class _EmptyFeedNotifier extends PublicationFeedNotifier {
  _EmptyFeedNotifier(PublicationFeedKey key)
    : super(PublicationsClient(Dio()), key);

  @override
  Future<PageResult<PublicationDto>> fetchPage(int page) async =>
      const PageResult<PublicationDto>(items: <PublicationDto>[], total: 0);
}
