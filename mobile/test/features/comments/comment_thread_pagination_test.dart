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

/// MOB-34 — un fil plus long qu'une page atteint sa page suivante.
///
/// Le fil est une `Column` dans le défilement de la page : rien n'y appelait
/// `loadNextPage`, et le 21ᵉ commentaire restait inaccessible.
const CommentTarget _target = CommentTarget(
  entity: CommentEntity.post,
  teamSlug: 'equipe',
  slug: 'article',
);

CommentDto _comment(int i) => CommentDto(
  id: 'c$i',
  content: 'Commentaire $i',
  author: const PublicUserDto(id: 'u-autre', displayName: 'Autre'),
  createdAt: '2026-09-01T10:00:00Z',
  replies: const <CommentDto>[],
  replyCount: 0,
  deleted: false,
);

class _StubCommentRepository implements CommentRepository {
  _StubCommentRepository(this.count);

  final int count;
  final List<int> pagesAsked = <int>[];

  @override
  Future<CommentListResponse> list(
    CommentTarget target, {
    int page = 0,
    int size = 20,
    String? parentId,
    SortDirection? sort,
  }) async {
    pagesAsked.add(page);
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const AuthState _signedIn = AuthState(
  user: UserDto(
    plannerQuota: PlannerQuotaDto(used: 0, resetsOn: '2026-12-01'),
    id: 'u-me',
    email: 'moi@example.org',
    displayName: 'Moi',
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

  Future<_StubCommentRepository> openThread(
    WidgetTester tester, {
    required int count,
  }) async {
    final _StubCommentRepository repository = _StubCommentRepository(count);
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
            // Une liste à slivers, comme les pages : son décalage de peinture
            // vient de la mise en page, pas directement de `pixels` comme dans
            // un `SingleChildScrollView` — c'est ce qui rendait le pied
            // « en retard d'un cran » quand il se mesurait trop tôt.
            body: ListView(
              children: <Widget>[
                // Ce qui précède le fil sur une vraie page : le pied du fil
                // commence hors de l'écran.
                const SizedBox(height: 600),
                CommentThread(target: _target, canComment: false),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('défiler jusqu\'au pied charge la page suivante', (
    WidgetTester tester,
  ) async {
    final _StubCommentRepository repository = await openThread(
      tester,
      count: 21,
    );
    // Le pied est loin sous l'écran : rien n'est demandé d'avance.
    expect(repository.pagesAsked, <int>[0]);
    expect(find.byKey(keys.comments.comment('c20')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(keys.comments.comment('c20')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(repository.pagesAsked, <int>[0, 1]);
    expect(find.byKey(keys.comments.comment('c20')), findsOneWidget);
    expect(find.byKey(keys.comments.loadMoreButton), findsNothing);
  });

  // Le défilement prévient avant la mise en page de sa frame. Mesuré à ce
  // moment-là, le pied était encore à sa place d'avant : au dernier cran, sans
  // rebond pour relancer l'écoute (Android), la page suivante ne venait jamais.
  testWidgets(
    'un seul cran jusqu\'en bas, sans rebond, charge la page suivante',
    (WidgetTester tester) async {
      final _StubCommentRepository repository = await openThread(
        tester,
        count: 21,
      );
      final ScrollPosition position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;

      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(repository.pagesAsked, <int>[0, 1]);
    },
  );

  testWidgets('chaque page en appelle une seule autre, jamais toutes', (
    WidgetTester tester,
  ) async {
    final _StubCommentRepository repository = await openThread(
      tester,
      count: 45,
    );
    await tester.scrollUntilVisible(
      find.byKey(keys.comments.comment('c25')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    // La deuxième page est là, la troisième attend qu'on descende.
    expect(repository.pagesAsked, <int>[0, 1]);

    await tester.scrollUntilVisible(
      find.byKey(keys.comments.comment('c44')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(repository.pagesAsked, <int>[0, 1, 2]);
  });
}
