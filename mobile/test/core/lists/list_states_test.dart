import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/core/lists/list_states.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/formatters.dart';

import '../../support/localization.dart';

/// Les états communs des listes (règles RL8, RL10, RL11 et RL12, KIT §10) :
/// une seule forme d'erreur, de refus, de vide filtré, de compteur et de pied
/// pour toutes les listes de l'app.
void main() {
  setUpAll(loadTestTranslations);

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: PedalonsTheme.build(Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  DioException httpError(int status, {Map<String, Object?>? body}) {
    final RequestOptions request = RequestOptions(path: '/api/x');
    return DioException(
      requestOptions: request,
      type: DioExceptionType.badResponse,
      response: Response<Object?>(
        requestOptions: request,
        statusCode: status,
        data: body,
      ),
    );
  }

  group('RL11 — ListLoadError', () {
    testWidgets('une panne du serveur : « Chargement impossible », le serveur '
        'nommé, « Réessayer », « Signaler un problème »', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      await pump(
        tester,
        ListLoadError(error: httpError(500), onRetry: () => retries++),
      );

      expect(find.text('Chargement impossible'), findsOneWidget);
      expect(
        find.text(
          'Le serveur n\'a pas pu répondre. Réessayez dans un instant.',
        ),
        findsOneWidget,
      );
      expect(find.text('Signaler un problème'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      expect(retries, 1);
    });

    testWidgets('une coupure : « Pas de connexion », rien à signaler', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        ListLoadError(
          error: DioException(
            requestOptions: RequestOptions(path: '/api/x'),
            type: DioExceptionType.connectionError,
          ),
          onRetry: () {},
        ),
      );

      expect(find.text('Pas de connexion'), findsOneWidget);
      expect(
        find.text('Vérifiez votre connexion internet, puis réessayez.'),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Chargement impossible'), findsNothing);
      expect(find.text('Signaler un problème'), findsNothing);
    });

    testWidgets('un code métier rend son message, sous le même titre', (
      WidgetTester tester,
    ) async {
      await pump(
        tester,
        ListLoadError(
          error: httpError(409, body: <String, Object?>{'code': 'GROUP_FULL'}),
          onRetry: () {},
        ),
      );

      expect(find.text('Chargement impossible'), findsOneWidget);
      expect(find.text('Ce groupe est complet'), findsOneWidget);
    });
  });

  testWidgets('RL11 — un refus a une issue, sans « Réessayer »', (
    WidgetTester tester,
  ) async {
    int abouts = 0;
    await pump(
      tester,
      ListAccessRefused(
        title: 'Réservées aux membres',
        message:
            'Les annonces de l\'équipe ne sont visibles que par ses '
            'membres.',
        onAbout: () => abouts++,
      ),
    );

    expect(find.text('Réessayer'), findsNothing);
    await tester.tap(find.text('À propos de l\'équipe'));
    expect(abouts, 1);
  });

  testWidgets('RL10 — le vide filtré nomme les filtres, un seul geste', (
    WidgetTester tester,
  ) async {
    int clears = 0;
    await pump(
      tester,
      ListFilteredEmpty(
        title: 'Aucune sortie pour ces filtres',
        filters: <String>[quotedSearch(' monts '), 'Je participe', 'Sorties'],
        onClear: () => clears++,
      ),
    );

    expect(find.text('Aucune sortie pour ces filtres'), findsOneWidget);
    expect(
      find.text('Rien ne correspond à : « monts » · Je participe · Sorties.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Effacer les filtres'));
    expect(clears, 1);
  });

  test('RL8 — le compteur est formaté et accordé', () {
    final String formatted = AppFormatters.formatNumber(2585);
    expect(formatted, isNot('2585'));
    expect(listCountLabel('ads.list.count', 2585), '$formatted annonces');
    expect(listCountLabel('ads.list.count', 1), '1 annonce');
  });

  testWidgets('RL12 — un seul pied, nommé et formaté', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      const PagedListFooter(
        state: PagedListState<int>(
          items: <int>[1, 2, 3],
          total: 3,
          hasMore: false,
          isLoadingInitial: false,
        ),
        onRetry: _noop,
        itemNounKey: 'ads.list.noun',
      ),
    );

    expect(find.text('3 annonces sur 3 · Vous avez tout vu'), findsOneWidget);
  });
}

void _noop() {}
