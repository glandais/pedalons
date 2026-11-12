import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/comments/data/comment_repository.dart';
import 'package:pedalons/features/comments/presentation/widgets/comment_thread.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

/// KIT §9, règle R8 (ledger `MOB-139`) : supprimer un commentaire se confirme
/// toujours, par la feuille de `confirmDestructive`.
const CommentTarget _target = CommentTarget(
  entity: CommentEntity.post,
  teamSlug: 'equipe',
  slug: 'article',
);

CommentDto _comment(int i) => CommentDto(
  id: 'c$i',
  content: 'Commentaire $i',
  author: const PublicUserDto(id: 'u-me', displayName: 'Moi'),
  createdAt: '2026-09-01T10:00:00Z',
  replies: const <CommentDto>[],
  replyCount: 0,
  deleted: false,
);

class _StubCommentRepository implements CommentRepository {
  _StubCommentRepository(this.count);

  final int count;
  final List<String> deleted = <String>[];

  @override
  Future<CommentListResponse> list(
    CommentTarget target, {
    int page = 0,
    int size = 20,
    String? parentId,
    SortDirection? sort,
  }) async {
    final int start = page * size;
    final int end = (start + size).clamp(0, count);
    return CommentListResponse(
      items: <CommentDto>[for (int i = start; i < end; i++) _comment(i)],
      total: count,
      itemTotal: count,
      page: page,
      size: size,
    );
  }

  @override
  Future<void> delete(CommentTarget target, String commentId) async =>
      deleted.add(commentId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const AuthState _signedIn = AuthState(
  user: UserDto(
    id: 'u-me',
    email: 'moi@example.org',
    displayName: 'Moi',
    plannerQuota: PlannerQuotaDto(used: 0, resetsOn: '2026-12-01'),
    emailVerified: true,
    contactableByMembers: true,
  ),
  accessToken: 'token',
);

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSecureStorage implements SecureTokenStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuthNotifier extends AuthNotifier {
  _StubAuthNotifier(Ref ref)
    : super(_FakeAuthRepository(), _FakeSecureStorage(), ref) {
    state = _signedIn;
  }
}

void main() {
  setUpAll(loadTestTranslations);

  testWidgets('« Supprimer » demande confirmation avant d\'appeler l\'API', (
    WidgetTester tester,
  ) async {
    final _StubCommentRepository repository = _StubCommentRepository(1);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          commentRepositoryProvider.overrideWithValue(repository),
          authProvider.overrideWith((ref) => _StubAuthNotifier(ref)),
          myTeamsProvider.overrideWith((ref) async => <TeamDetailDto>[]),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: ListView(
              children: const <Widget>[
                CommentThread(target: _target, canComment: false),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> chooseDelete() async {
      await tester.tap(find.byKey(keys.comments.moreButton('c0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(keys.moderation.deleteAction));
      await tester.pumpAndSettle();
    }

    // Annuler : rien ne part.
    await chooseDelete();
    expect(find.byKey(keys.profile.confirmDestructiveButton), findsOneWidget);
    expect(find.text('Supprimer le commentaire ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isEmpty);

    // Confirmer : la suppression part.
    await chooseDelete();
    await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
    await tester.pumpAndSettle();
    expect(repository.deleted, <String>['c0']);
  });
}
