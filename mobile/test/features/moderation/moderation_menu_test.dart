import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/moderation/data/moderation_repository.dart';
import 'package:pedalons/features/moderation/presentation/moderation_menu.dart';

import '../../support/localization.dart';

/// Directive App Store 1.2 — signaler et bloquer depuis le contenu, en deux
/// ou trois gestes : `⋯` → Signaler → motif → Envoyer ; `⋯` → Bloquer →
/// Confirmer.
class _FakeRepository implements ModerationRepository {
  final List<Map<String, Object?>> reports = <Map<String, Object?>>[];
  final List<String> blocked = <String>[];

  @override
  Future<void> report({
    required String teamSlug,
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? message,
  }) async {
    reports.add(<String, Object?>{
      'teamSlug': teamSlug,
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'message': message,
    });
  }

  @override
  Future<void> block(String userId) async => blocked.add(userId);

  @override
  Future<List<PublicUserDto>> listBlocked() async => <PublicUserDto>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const ModerationSubject _comment = ModerationSubject(
  teamSlug: 'gaby',
  type: ReportTargetType.comment,
  id: 'c1',
  teamName: 'Gaby',
);

void main() {
  setUpAll(loadTestTranslations);

  late _FakeRepository repository;
  ModerationOutcome? outcome;

  setUp(() {
    repository = _FakeRepository();
    outcome = null;
  });

  Future<void> open(
    WidgetTester tester, {
    bool canReport = true,
    String? blockUserId,
    String? blockUserName,
    Future<void> Function()? onDelete,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [moderationRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () async {
                  outcome = await showModerationMenu(
                    context,
                    subject: _comment,
                    canReport: canReport,
                    blockUserId: blockUserId,
                    blockUserName: blockUserName,
                    onDelete: onDelete,
                  );
                },
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

  testWidgets(
    'le commentaire d\'un autre : Signaler et Bloquer, pas Supprimer',
    (WidgetTester tester) async {
      await open(tester, blockUserId: 'u2', blockUserName: 'Hélène');

      expect(find.text('Signaler'), findsOneWidget);
      expect(find.text('Bloquer Hélène'), findsOneWidget);
      expect(find.text('Supprimer'), findsNothing);
    },
  );

  testWidgets('son propre commentaire : Supprimer seulement', (
    WidgetTester tester,
  ) async {
    bool deleted = false;
    await open(tester, canReport: false, onDelete: () async => deleted = true);

    expect(find.text('Signaler'), findsNothing);
    expect(find.textContaining('Bloquer'), findsNothing);

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
    expect(outcome, ModerationOutcome.deleted);
  });

  testWidgets('un menu vide ne s\'ouvre pas', (WidgetTester tester) async {
    await open(tester, canReport: false);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('Signaler → motif → Envoyer, puis la confirmation', (
    WidgetTester tester,
  ) async {
    await open(tester, blockUserId: 'u2', blockUserName: 'Hélène');
    await tester.tap(find.text('Signaler'));
    await tester.pumpAndSettle();

    expect(find.text('Signaler ce commentaire'), findsOneWidget);
    expect(
      find.text('Transmis à qui organise Gaby et à l\'équipe Pédalons.'),
      findsOneWidget,
    );

    // Sans motif, Envoyer ne part pas.
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();
    expect(repository.reports, isEmpty);

    await tester.tap(find.text('Spam ou publicité'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '  Lien douteux  ');
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(repository.reports.single, <String, Object?>{
      'teamSlug': 'gaby',
      'targetType': ReportTargetType.comment,
      'targetId': 'c1',
      'reason': ReportReason.spam,
      'message': '  Lien douteux  ',
    });
    expect(outcome, ModerationOutcome.reported);
    expect(
      find.text('Merci. Ce contenu est masqué pour vous.'),
      findsOneWidget,
    );
  });

  testWidgets('Bloquer → Confirmer', (WidgetTester tester) async {
    await open(tester, blockUserId: 'u2', blockUserName: 'Hélène');
    await tester.tap(find.text('Bloquer Hélène'));
    await tester.pumpAndSettle();

    expect(find.text('Bloquer Hélène ?'), findsOneWidget);
    await tester.tap(find.text('Bloquer'));
    await tester.pumpAndSettle();

    expect(repository.blocked, <String>['u2']);
    expect(outcome, ModerationOutcome.blocked);
    expect(find.text('Vous avez bloqué Hélène.'), findsOneWidget);
  });
}
