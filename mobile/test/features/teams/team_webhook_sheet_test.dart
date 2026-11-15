import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/data/team_webhook_repository.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_webhook_sheet.dart';
import 'package:pedalons/features/teams/providers/team_dashboard_provider.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

/// La feuille du webhook d'une équipe (ledger `MOB-166`) : une première
/// configuration, une adresse gardée quand le champ reste vide, le message de
/// test et son code HTTP, la suppression, et une URL refusée.
///
/// **L'URL est un secret** : l'API ne la rend que masquée, et la feuille ne
/// montre jamais autre chose.
class _Webhooks implements TeamWebhookRepository {
  _Webhooks(this.webhook);

  /// L'état que le serveur connaît.
  TeamWebhookDto webhook;

  bool loadFails = false;
  Object? saveError;
  TeamWebhookTestDto testResult = const TeamWebhookTestDto(
    success: true,
    statusCode: 200,
  );

  /// Si posé, `save` attend qu'il soit complété.
  Completer<void>? gate;

  int reads = 0;
  int saveCalls = 0;
  final List<({String? url, String language, bool enabled})> saves =
      <({String? url, String language, bool enabled})>[];
  int tests = 0;
  int deletes = 0;

  @override
  Future<TeamWebhookDto> get(String teamSlug) async {
    reads++;
    if (loadFails) throw StateError('indisponible');
    return webhook;
  }

  @override
  Future<TeamWebhookDto> save(
    String teamSlug, {
    String? url,
    required String language,
    required bool enabled,
  }) async {
    saveCalls++;
    await gate?.future;
    final Object? error = saveError;
    if (error != null) throw error;
    saves.add((url: url, language: language, enabled: enabled));
    webhook = TeamWebhookDto(
      configured: true,
      enabled: enabled,
      // Le serveur ne rend jamais que l'adresse masquée.
      maskedUrl: url == null
          ? webhook.maskedUrl
          : 'https://hooks.slack.com/…WXYZ',
      kind: 'SLACK',
      language: language,
    );
    return webhook;
  }

  @override
  Future<TeamWebhookTestDto> test(String teamSlug) async {
    tests++;
    webhook = webhook.copyWith(
      lastStatus: testResult.success ? 'SENT' : 'FAILED',
      lastAttemptAt: '2026-11-15T10:00:00Z',
      lastError: testResult.error,
    );
    return testResult;
  }

  @override
  Future<void> delete(String teamSlug) async {
    deletes++;
    webhook = const TeamWebhookDto(configured: false, enabled: false);
  }
}

class _Teams implements TeamRepository {
  int dashboardReads = 0;

  @override
  Future<TeamDashboardDto> getDashboard(String slug) async {
    dashboardReads++;
    throw StateError('sans importance');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const TeamWebhookDto _none = TeamWebhookDto(configured: false, enabled: false);

const TeamWebhookDto _slack = TeamWebhookDto(
  configured: true,
  enabled: true,
  maskedUrl: 'https://hooks.slack.com/…ABCD',
  kind: 'SLACK',
  language: 'en',
  lastStatus: 'FAILED',
  lastError: 'HTTP 410 Gone',
  lastAttemptAt: '2026-11-14T08:00:00Z',
);

DioException _apiError(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/api/teams/n-peloton/webhook'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, Object?>>(
    requestOptions: RequestOptions(path: '/api/teams/n-peloton/webhook'),
    statusCode: status,
    data: <String, Object?>{'code': code},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);
  setUp(() => setCurrentLocale('fr'));

  late _Teams teams;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester tester, _Webhooks webhooks) async {
    // Une feuille haute : tout son contenu est construit.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    teams = _Teams();
    final ProviderContainer container = ProviderContainer(
      retry: (int _, Object _) => null,
      overrides: [
        teamWebhookRepositoryProvider.overrideWithValue(webhooks),
        teamRepositoryProvider.overrideWithValue(teams),
      ],
    );
    addTearDown(container.dispose);
    // Le tableau de bord montre l'état du webhook : il est relu après chaque
    // écriture.
    container.listen(
      teamDashboardProvider('n-peloton'),
      (_, _) {},
      onError: (_, _) {},
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => showTeamWebhookSheet(context, 'n-peloton'),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await settle(tester);
  }

  PdlButton button(WidgetTester tester, Key key) =>
      tester.widget<PdlButton>(find.byKey(key));

  String urlText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(keys.teamWebhook.urlField))
      .controller!
      .text;

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(keys.teamWebhook.saveButton));
    await settle(tester);
  }

  testWidgets('première configuration : « Enregistrer » attend une URL, '
      'la langue est celle de l\'app, les annonces partent activées', (
    WidgetTester tester,
  ) async {
    final _Webhooks webhooks = _Webhooks(_none);
    await open(tester, webhooks);
    expect(teams.dashboardReads, 1);

    expect(find.byKey(keys.teamWebhook.maskedUrl), findsNothing);
    expect(find.byKey(keys.teamWebhook.testButton), findsNothing);
    expect(find.byKey(keys.teamWebhook.removeButton), findsNothing);
    expect(urlText(tester), isEmpty);
    expect(button(tester, keys.teamWebhook.saveButton).enabled, isFalse);
    expect(
      tester
          .widget<PdlSwitch>(find.byKey(keys.teamWebhook.enabledSwitch))
          .value,
      isTrue,
    );

    // Sans URL, rien ne part.
    await save(tester);
    expect(webhooks.saveCalls, 0);

    await tester.enterText(
      find.byKey(keys.teamWebhook.urlField),
      '  https://hooks.slack.com/services/T000/B000/SECRETWXYZ  ',
    );
    await tester.pump();
    expect(button(tester, keys.teamWebhook.saveButton).enabled, isTrue);
    await save(tester);

    expect(webhooks.saves.single, (
      url: 'https://hooks.slack.com/services/T000/B000/SECRETWXYZ',
      language: 'fr',
      enabled: true,
    ));
    // La feuille reste ouverte, repartie de l'état enregistré : le champ est
    // vide, et seule l'adresse masquée se lit.
    expect(find.byKey(keys.teamWebhook.noticeBanner), findsOneWidget);
    expect(find.text('Webhook enregistré'), findsOneWidget);
    expect(urlText(tester), isEmpty);
    expect(find.text('https://hooks.slack.com/…WXYZ'), findsOneWidget);
    expect(find.textContaining('SECRETWXYZ'), findsNothing);
    expect(find.byKey(keys.teamWebhook.testButton), findsOneWidget);
    // Le tableau de bord est relu.
    expect(teams.dashboardReads, 2);
  });

  testWidgets('un webhook en place : l\'adresse masquée seulement, sa '
      'langue, son dernier envoi', (WidgetTester tester) async {
    await open(tester, _Webhooks(_slack));

    expect(
      tester.widget<Text>(find.byKey(keys.teamWebhook.maskedUrl)).data,
      'https://hooks.slack.com/…ABCD',
    );
    expect(find.text('SLACK'), findsOneWidget);
    expect(urlText(tester), isEmpty);
    expect(
      find.text(
        'Laissez vide pour garder l\'adresse actuelle, ou collez une '
        'nouvelle URL pour la remplacer.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<PdlBadge>(find.byKey(keys.teamWebhook.lastStatus)).label,
      'Échec',
    );
    expect(find.text('HTTP 410 Gone'), findsOneWidget);
    expect(button(tester, keys.teamWebhook.saveButton).enabled, isTrue);
  });

  testWidgets('le champ laissé vide garde l\'adresse : la requête n\'en '
      'porte pas', (WidgetTester tester) async {
    final _Webhooks webhooks = _Webhooks(_slack);
    await open(tester, webhooks);

    await tester.tap(find.byKey(keys.teamWebhook.language('fr')));
    await tester.tap(find.byKey(keys.teamWebhook.enabledSwitch));
    await tester.pump();
    await save(tester);

    expect(webhooks.saves.single, (url: null, language: 'fr', enabled: false));
    // L'adresse actuelle n'a pas bougé.
    expect(find.text('https://hooks.slack.com/…ABCD'), findsOneWidget);
  });

  testWidgets('la langue du webhook l\'emporte sur celle de l\'app', (
    WidgetTester tester,
  ) async {
    final _Webhooks webhooks = _Webhooks(_slack);
    await open(tester, webhooks);

    await save(tester);

    expect(webhooks.saves.single.language, 'en');
  });

  testWidgets('« Enregistrer » touché deux fois pendant l\'envoi : une '
      'seule requête', (WidgetTester tester) async {
    final _Webhooks webhooks = _Webhooks(_slack)..gate = Completer<void>();
    await open(tester, webhooks);

    await save(tester);
    await save(tester);
    expect(webhooks.saveCalls, 1);

    webhooks.gate!.complete();
    await settle(tester);
    expect(webhooks.saveCalls, 1);
  });

  testWidgets('WEBHOOK_URL_INVALID : le bandeau le dit, la saisie reste', (
    WidgetTester tester,
  ) async {
    final _Webhooks webhooks = _Webhooks(_none)
      ..saveError = _apiError(400, 'WEBHOOK_URL_INVALID');
    await open(tester, webhooks);

    await tester.enterText(
      find.byKey(keys.teamWebhook.urlField),
      'http://localhost/hook',
    );
    await tester.pump();
    await save(tester);

    expect(find.byKey(keys.teamWebhook.errorBanner), findsOneWidget);
    expect(
      find.textContaining('Cette adresse de webhook n\'est pas acceptée'),
      findsOneWidget,
    );
    expect(urlText(tester), 'http://localhost/hook');
    expect(find.byKey(keys.teamWebhook.noticeBanner), findsNothing);

    // Un second essai repart.
    webhooks.saveError = null;
    await save(tester);
    expect(webhooks.saves.single.url, 'http://localhost/hook');
  });

  testWidgets('le message de test reçu : son code HTTP, et le dernier envoi '
      'relu', (WidgetTester tester) async {
    final _Webhooks webhooks = _Webhooks(_slack);
    await open(tester, webhooks);

    await tester.tap(find.byKey(keys.teamWebhook.testButton));
    await settle(tester);

    expect(webhooks.tests, 1);
    expect(find.byKey(keys.teamWebhook.testResult), findsOneWidget);
    expect(find.text('Message de test reçu (HTTP 200).'), findsOneWidget);
    expect(
      tester.widget<PdlBadge>(find.byKey(keys.teamWebhook.lastStatus)).label,
      'Réussi',
    );
  });

  testWidgets('le message de test refusé : le code HTTP et la raison', (
    WidgetTester tester,
  ) async {
    final _Webhooks webhooks = _Webhooks(_slack)
      ..testResult = const TeamWebhookTestDto(
        success: false,
        statusCode: 404,
        error: 'Not Found',
      );
    await open(tester, webhooks);

    await tester.tap(find.byKey(keys.teamWebhook.testButton));
    await settle(tester);

    expect(
      find.text('Le message de test a été refusé (HTTP 404). Not Found'),
      findsOneWidget,
    );
  });

  testWidgets('le message de test sans réponse : la raison seule', (
    WidgetTester tester,
  ) async {
    final _Webhooks webhooks = _Webhooks(_slack)
      ..testResult = const TeamWebhookTestDto(
        success: false,
        error: 'Connexion refusée',
      );
    await open(tester, webhooks);

    await tester.tap(find.byKey(keys.teamWebhook.testButton));
    await settle(tester);

    expect(
      find.text('Le message de test n\'a pas abouti : Connexion refusée'),
      findsOneWidget,
    );
  });

  testWidgets('supprimer le webhook se confirme, et la feuille repart d\'une '
      'première configuration', (WidgetTester tester) async {
    final _Webhooks webhooks = _Webhooks(_slack);
    await open(tester, webhooks);

    await tester.tap(find.byKey(keys.teamWebhook.removeButton));
    await settle(tester);
    expect(find.text('Supprimer le webhook ?'), findsOneWidget);
    expect(webhooks.deletes, 0);

    await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
    await settle(tester);

    expect(webhooks.deletes, 1);
    expect(find.text('Webhook supprimé'), findsOneWidget);
    expect(find.byKey(keys.teamWebhook.maskedUrl), findsNothing);
    expect(find.byKey(keys.teamWebhook.testButton), findsNothing);
    expect(button(tester, keys.teamWebhook.saveButton).enabled, isFalse);
    expect(teams.dashboardReads, 2);
  });

  testWidgets('annuler la suppression garde le webhook', (
    WidgetTester tester,
  ) async {
    final _Webhooks webhooks = _Webhooks(_slack);
    await open(tester, webhooks);

    await tester.tap(find.byKey(keys.teamWebhook.removeButton));
    await settle(tester);
    await tester.tap(find.text('Annuler'));
    await settle(tester);

    expect(webhooks.deletes, 0);
    expect(find.byKey(keys.teamWebhook.maskedUrl), findsOneWidget);
  });

  testWidgets('le webhook illisible : une erreur, et « Réessayer » le relit', (
    WidgetTester tester,
  ) async {
    final _Webhooks webhooks = _Webhooks(_slack)..loadFails = true;
    await open(tester, webhooks);

    expect(find.byKey(keys.teamWebhook.loadError), findsOneWidget);
    expect(find.byKey(keys.teamWebhook.saveButton), findsNothing);

    webhooks.loadFails = false;
    await tester.tap(find.text('Réessayer'));
    await settle(tester);

    expect(find.byKey(keys.teamWebhook.loadError), findsNothing);
    expect(find.byKey(keys.teamWebhook.urlField), findsOneWidget);
  });
}
