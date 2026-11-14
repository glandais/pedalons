import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/posts/data/post_repository.dart';
import 'package:pedalons/features/posts/presentation/widgets/post_manage_menu.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/content_permissions.dart';
import '../../support/localization.dart';
import 'post_fixtures.dart';

/// Le menu « Gérer la publication » (ledger `MOB-156`).
class _StubPosts implements PostRepository {
  final List<String> statuses = <String>[];
  final List<String> deleted = <String>[];
  final List<String> restored = <String>[];

  @override
  Future<PostDto> changeStatus(
    String teamSlug,
    String postSlug,
    Status status,
  ) async {
    statuses.add('$postSlug ${status.json}');
    return fixturePost(slug: postSlug, status: status.json!);
  }

  @override
  Future<void> deletePost(String teamSlug, String postSlug) async =>
      deleted.add('$teamSlug/$postSlug');

  @override
  Future<PostDto> undeletePost(String teamSlug, String postSlug) async {
    restored.add('$teamSlug/$postSlug');
    return fixturePost(slug: postSlug);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  group('postManageActions', () {
    test('selon le statut, comme le menu du site', () {
      expect(
        postManageActions(fixturePost(status: 'DRAFT')),
        <PostManageAction>[
          PostManageAction.publish,
          PostManageAction.delete,
          PostManageAction.report,
        ],
      );
      expect(postManageActions(fixturePost()), <PostManageAction>[
        PostManageAction.unpublish,
        PostManageAction.cancel,
        PostManageAction.delete,
        PostManageAction.report,
      ]);
      expect(
        postManageActions(fixturePost(status: 'CANCELLED')),
        <PostManageAction>[
          PostManageAction.reinstate,
          PostManageAction.delete,
          PostManageAction.report,
        ],
      );
    });

    test("une publication supprimée n'offre que sa restauration", () {
      expect(postManageActions(fixturePost(deleted: true)), <PostManageAction>[
        PostManageAction.restore,
      ]);
    });

    // Les droits viennent du bloc `permissions` de la publication, pas du
    // rôle (docs/LEDGER_*.md MOB-137).
    test('sans aucun droit : le signalement seul, et pas de « Gérer »', () {
      final PostDto post = fixturePost(permissions: kNoPermissions);
      expect(postManageActions(post), <PostManageAction>[
        PostManageAction.report,
      ]);
      expect(postHasManageActions(post), isFalse);
    });

    test('canEdit sans canDelete : le statut, pas la suppression', () {
      final PostDto post = fixturePost(
        permissions: kNoPermissions.copyWith(canEdit: true),
      );
      expect(postManageActions(post), <PostManageAction>[
        PostManageAction.unpublish,
        PostManageAction.cancel,
        PostManageAction.report,
      ]);
      expect(postHasManageActions(post), isTrue);
    });
  });

  group('la feuille', () {
    late SharedPreferences prefs;
    late _StubPosts posts;

    setUp(() async {
      setCurrentLocale('fr');
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      posts = _StubPosts();
    });

    Future<void> settle(WidgetTester tester) async {
      for (int i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> pump(WidgetTester tester, {required PostDto post}) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final GoRouter router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext _, GoRouterState _) => Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                  Scaffold(
                    body: TextButton(
                      onPressed: () => showPostManageMenu(context, ref, post),
                      child: const Text('ouvrir'),
                    ),
                  ),
            ),
          ),
          GoRoute(
            path: PathVariants.teamPosts(':teamSlug')['fr']!,
            builder: (BuildContext _, GoRouterState _) =>
                const Text('publications de l\'équipe'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            postRepositoryProvider.overrideWithValue(posts),
          ],
          child: MaterialApp.router(
            theme: PedalonsTheme.build(Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await settle(tester);
    }

    testWidgets('un brouillon se publie sans confirmation', (
      WidgetTester tester,
    ) async {
      await pump(tester, post: fixturePost(status: 'DRAFT'));

      expect(find.text('Gérer la publication'), findsOneWidget);
      expect(find.byKey(keys.postManage.unpublish), findsNothing);
      await tester.tap(find.byKey(keys.postManage.publish));
      await settle(tester);

      expect(posts.statuses, <String>['retour-de-sortie PUBLISHED']);
      expect(find.text('Publication mise en ligne'), findsOneWidget);
    });

    testWidgets('dépublier demande confirmation', (WidgetTester tester) async {
      await pump(tester, post: fixturePost());

      await tester.tap(find.byKey(keys.postManage.unpublish));
      await settle(tester);
      expect(find.text('Dépublier la publication ?'), findsOneWidget);
      expect(posts.statuses, isEmpty);

      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);
      expect(posts.statuses, <String>['retour-de-sortie DRAFT']);
    });

    testWidgets('une publication supprimée : « Restaurer » seulement', (
      WidgetTester tester,
    ) async {
      await pump(tester, post: fixturePost(deleted: true));

      expect(find.byKey(keys.postManage.delete), findsNothing);
      await tester.tap(find.byKey(keys.postManage.restore));
      await settle(tester);

      expect(posts.restored, <String>['n-peloton/retour-de-sortie']);
      expect(find.text('Publication restaurée'), findsOneWidget);
    });

    testWidgets('la suppression demande confirmation, puis supprime', (
      WidgetTester tester,
    ) async {
      await pump(tester, post: fixturePost());

      await tester.tap(find.byKey(keys.postManage.delete));
      await settle(tester);
      expect(find.text('Supprimer la publication ?'), findsOneWidget);
      expect(posts.deleted, isEmpty);

      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(posts.deleted, <String>['n-peloton/retour-de-sortie']);
      // Rien dessous : retour aux publications de l'équipe.
      expect(find.text('publications de l\'équipe'), findsOneWidget);
    });

    testWidgets('annuler la confirmation ne supprime rien', (
      WidgetTester tester,
    ) async {
      await pump(tester, post: fixturePost());

      await tester.tap(find.byKey(keys.postManage.delete));
      await settle(tester);
      await tester.tap(find.text('Annuler'));
      await settle(tester);

      expect(posts.deleted, isEmpty);
    });
  });
}
