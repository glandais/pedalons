import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/features/feed/presentation/widgets/publication_feed_view.dart';
import 'package:pedalons/features/feed/providers/publication_feed_provider.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';

/// F-DE-4 — la rangée de filtres du fil épinglée.
///
/// Les chips vivaient dans un `SliverToBoxAdapter` : au premier défilement
/// elles quittaient l'écran et n'y revenaient qu'en remontant tout le fil. Au
/// 40ᵉ élément, on ne savait plus ce qu'on regardait et on ne pouvait plus le
/// changer.
///
/// Le test tient les deux moitiés de la correction : la barre est un
/// `SliverPersistentHeader(pinned)`, **et** le champ de recherche du fil — qui
/// n'existait pas — y monte avec les chips. Il tient aussi la contrainte qui
/// borde la correction : la liste reste le scrollable *primaire* de sa route,
/// donc sans `controller:` — sinon le tap sur la barre d'état iOS cesse de la
/// remonter (`list_pages_primary_scroll_test.dart`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host() => ProviderScope(
    overrides: [
      publicationFeedProvider.overrideWith(
        (ref, key) => _FullFeedNotifier(key),
      ),
      myTeamsProvider.overrideWith((ref) async => <TeamDetailDto>[]),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: PublicationFeedView(teamSlug: null, emptyMessage: 'empty'),
      ),
    ),
  );

  testWidgets('la barre du fil est épinglée et porte la recherche', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      find.byType(PdlPinnedToolbar),
      findsOneWidget,
      reason: 'les filtres du fil doivent vivre dans une barre épinglée',
    );
    expect(
      find.byType(PdlSearchField),
      findsOneWidget,
      reason: 'le fil était le seul écran de liste sans champ de recherche',
    );
    expect(find.byType(PdlChipRow), findsOneWidget);

    // Aucune chip, aucun champ ne doit se trouver dans un adaptateur simple :
    // c'est précisément ce qui les faisait sortir de l'écran.
    expect(
      find.ancestor(
        of: find.byType(PdlChipRow),
        matching: find.byType(SliverToBoxAdapter),
      ),
      findsNothing,
    );
  });

  testWidgets('la barre reste visible après un défilement', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    final double before = tester.getTopLeft(find.byType(PdlChipRow)).dy;

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1200));
    await tester.pump();

    expect(
      find.byType(PdlChipRow),
      findsOneWidget,
      reason: 'défiler le fil jusqu\'en bas doit laisser la rangée visible',
    );
    expect(
      tester.getTopLeft(find.byType(PdlChipRow)).dy,
      lessThanOrEqualTo(before),
      reason: 'la barre est épinglée : elle ne redescend pas',
    );
    expect(find.byType(PdlSearchField), findsOneWidget);
  });

  testWidgets('le fil reste le scrollable primaire de sa route', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pump();

    expect(
      tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller,
      isNull,
      reason:
          'un défileur qui porte un contrôleur explicite n\'est plus le '
          'primaire, et le tap sur la barre d\'état ne l\'atteint plus',
    );
  });
}

/// Ne répond jamais : le fil reste sur ses cinq squelettes, aucun appel HTTP
/// n'est émis, et il y a largement de quoi défiler.
class _FullFeedNotifier extends PublicationFeedNotifier {
  _FullFeedNotifier(PublicationFeedKey key)
    : super(PublicationsClient(Dio()), key);

  @override
  Future<PageResult<PublicationDto>> fetchPage(int page) =>
      Completer<PageResult<PublicationDto>>().future;
}
