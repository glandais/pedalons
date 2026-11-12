import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/logging/app_log.dart';
import 'package:pedalons/core/logging/client_context.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/feedback/data/feedback_repository.dart';
import 'package:pedalons/features/feedback/presentation/feedback_sheet.dart';

import '../../support/localization.dart';

class _FakeRepository implements FeedbackRepository {
  final List<FeedbackRequest> sent = <FeedbackRequest>[];
  Object? failWith;

  @override
  Future<void> send(FeedbackRequest request) async {
    final Object? failure = failWith;
    if (failure != null) throw failure;
    sent.add(request);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DioException _rateLimited() {
  final RequestOptions options = RequestOptions(path: '/api/feedback');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: 429,
      headers: Headers.fromMap(<String, List<String>>{
        'retry-after': <String>['120'],
      }),
      data: <String, dynamic>{'code': 'FEEDBACK_RATE_LIMITED'},
    ),
  );
}

void main() {
  setUpAll(loadTestTranslations);

  late _FakeRepository repository;
  late AppLog log;

  setUp(() {
    repository = _FakeRepository();
    log = AppLog()
      ..info('navigation', '/equipes/gaby')
      ..warn('http', 'GET /api/teams/gaby → 500');
  });

  Future<void> open(WidgetTester tester, {ClientErrorDto? error}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final ClientContextBuilder builder = ClientContextBuilder(
      platform: 'ANDROID',
      locale: () => 'fr',
    )..recordNavigation('/equipes/gaby/sorties?token=x');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedbackRepositoryProvider.overrideWithValue(repository),
          appLogProvider.overrideWithValue(log),
          clientContextBuilderProvider.overrideWithValue(builder),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () => showFeedbackSheet(context, error: error),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('un bug, informations techniques jointes, puis le merci', (
    WidgetTester tester,
  ) async {
    await open(tester);
    expect(find.text('Signaler un problème'), findsOneWidget);

    // Trop court : Envoyer ne part pas.
    await tester.enterText(find.byType(TextField), 'Court');
    await tester.pump();
    await tester.tap(find.text('Envoyer'));
    await tester.pump();
    expect(repository.sent, isEmpty);

    await tester.enterText(
      find.byType(TextField),
      '  La carte reste grise sur la sortie.  ',
    );
    await tester.pump();
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    final FeedbackRequest request = repository.sent.single;
    expect(request.kind, 'BUG');
    expect(request.message, 'La carte reste grise sur la sortie.');
    expect(request.context.route, '/equipes/gaby/sorties');
    expect(request.context.teamSlug, 'gaby');
    expect(
      request.logs!.map((ClientLogEntryDto e) => e.message),
      contains('GET /api/teams/gaby → 500'),
    );
    expect(find.byType(FeedbackSheet), findsNothing);
    expect(find.text('Signalement envoyé avec succès, merci.'), findsOneWidget);
  });

  testWidgets('une suggestion sans informations techniques', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Suggestion'));
    await tester.tap(find.text('Joindre les informations techniques'));
    await tester.pump();
    expect(
      find.text(
        'Seules la plateforme, la version de l\'app et la langue seront jointes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Voir ce qui sera envoyé'), findsNothing);

    await tester.enterText(
      find.byType(TextField),
      'Un export du calendrier en PDF.',
    );
    await tester.pump();
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    final FeedbackRequest request = repository.sent.single;
    expect(request.kind, 'SUGGESTION');
    expect(request.logs, isNull);
    expect(request.error, isNull);
    expect(request.context.route, isNull);
    expect(request.context.platform, 'ANDROID');
  });

  testWidgets('l\'aperçu montre ce qui part, lignes du journal comprises', (
    WidgetTester tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Voir ce qui sera envoyé'));
    await tester.pump();

    final String preview = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    expect(preview, contains('platform: ANDROID'));
    expect(preview, contains('route: /equipes/gaby/sorties'));
    expect(preview, isNot(contains('token')));
    expect(preview, contains('WARN [http] GET /api/teams/gaby → 500'));
  });

  testWidgets('le quota garde le brouillon et dit quand réessayer', (
    WidgetTester tester,
  ) async {
    await open(tester);
    repository.failWith = _rateLimited();
    await tester.enterText(
      find.byType(TextField),
      'La carte reste grise sur la sortie.',
    );
    await tester.pump();
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackSheet), findsOneWidget);
    expect(
      find.text(
        'Vous avez envoyé beaucoup de signalements. Réessayez dans 2 minutes, votre texte est conservé.',
      ),
      findsOneWidget,
    );
    expect(find.text('La carte reste grise sur la sortie.'), findsOneWidget);

    repository.failWith = null;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(
      repository.sent.single.message,
      'La carte reste grise sur la sortie.',
    );
  });

  testWidgets('ouverte depuis une erreur, elle la joint', (
    WidgetTester tester,
  ) async {
    const ClientErrorDto error = ClientErrorDto(
      type: 'StateError',
      message: 'Bad state: boom',
      stack: '#0      main (package:pedalons/main.dart:1:1)',
    );
    await open(tester, error: error);
    expect(
      find.text('Erreur jointe : Bad state: boom', findRichText: true),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextField),
      'Ça plante en ouvrant la sortie.',
    );
    await tester.pump();
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();
    expect(repository.sent.single.error, error);
  });

  testWidgets('un bug part sans message, une suggestion non', (
    WidgetTester tester,
  ) async {
    const ClientErrorDto error = ClientErrorDto(
      type: 'StateError',
      message: 'Bad state: boom',
    );
    await open(tester, error: error);

    await tester.tap(find.text('Suggestion'));
    await tester.pump();
    await tester.tap(find.text('Envoyer'));
    await tester.pump();
    expect(repository.sent, isEmpty);
    expect(find.text('Au moins 10 caractères.'), findsOneWidget);

    await tester.tap(find.text('Bug'));
    await tester.pump();
    expect(find.text('Au moins 10 caractères.'), findsNothing);
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    final FeedbackRequest request = repository.sent.single;
    expect(request.kind, 'BUG');
    expect(request.message, isNull);
    expect(request.error, error);
  });
}
