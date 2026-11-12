import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/widgets/markdown_content.dart';
import 'package:pedalons/features/comments/data/comment_repository.dart';
import 'package:pedalons/features/comments/presentation/widgets/comment_thread.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

const CommentTarget _target = CommentTarget(
  entity: CommentEntity.ride,
  teamSlug: 'equipe',
  slug: 'sortie',
);

class _OneComment implements CommentRepository {
  _OneComment(this.content);

  final String content;

  @override
  Future<CommentListResponse> list(
    CommentTarget target, {
    int page = 0,
    int size = 20,
    String? parentId,
    SortDirection? sort,
  }) async => CommentListResponse(
    items: <CommentDto>[
      CommentDto(
        id: 'c1',
        content: content,
        author: const PublicUserDto(id: 'u-karim', displayName: 'Karim'),
        createdAt: '2026-09-01T10:00:00Z',
        replies: const <CommentDto>[],
        replyCount: 0,
        deleted: false,
      ),
    ],
    total: 1,
    itemTotal: 1,
    page: page,
    size: size,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Règle R12 (KIT §9, docs/LEDGER_*.md MOB-139) : un commentaire s'affiche
/// tel qu'il a été tapé — ni gras ni lien rendus, les retours à la ligne
/// gardés. Les descriptions et les pages, elles, gardent leur rendu Markdown.
void main() {
  setUpAll(loadTestTranslations);

  Future<void> open(WidgetTester tester, String content) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          commentRepositoryProvider.overrideWithValue(_OneComment(content)),
          myTeamsProvider.overrideWith((ref) async => <TeamDetailDto>[]),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: CommentThread(target: _target, canComment: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('`**gras**` et `[lien](adresse)` restent tels quels', (
    WidgetTester tester,
  ) async {
    const String typed =
        'On se retrouve au café **avant le départ** ? [plan](https://x.invalid)';
    await open(tester, typed);

    final Text text = tester.widget<Text>(
      find.byKey(keys.comments.content('c1')),
    );
    expect(text.data, typed);
    expect(find.byType(MarkdownContent), findsNothing);
  });

  testWidgets('les retours à la ligne sont gardés', (
    WidgetTester tester,
  ) async {
    await open(tester, 'Oui, 8 h 45.\nJe prends les clés.');

    expect(
      tester.widget<Text>(find.byKey(keys.comments.content('c1'))).data,
      'Oui, 8 h 45.\nJe prends les clés.',
    );
  });
}
