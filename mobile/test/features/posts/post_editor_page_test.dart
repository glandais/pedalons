import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/material.dart' hide Visibility;
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/posts/data/post_repository.dart';
import 'package:pedalons/features/posts/presentation/pages/post_editor_page.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/content_permissions.dart';
import '../../support/localization.dart';
import '../routes/route_fixtures.dart';
import 'post_fixtures.dart';

/// L'éditeur de publication (ledger `MOB-156`) : le refus pour qui n'organise
/// pas, et surtout **ce qui part** — la requête que le serveur recevra.
class _StubPosts implements PostRepository {
  _StubPosts({PostDto? post}) : post = post ?? fixturePost();

  final PostDto post;
  int reads = 0;

  /// Si posé, `createPost` / `updatePost` lèvent cette erreur.
  Object? failWith;

  final List<({String team, PostRequest request})> created = [];
  final List<({String slug, PostRequest request})> updated = [];

  @override
  Future<PostDto> getPost(String teamSlug, String postSlug) async {
    reads++;
    return post;
  }

  @override
  Future<PostDto> createPost(String teamSlug, PostRequest request) async {
    final Object? error = failWith;
    if (error != null) throw error;
    created.add((team: teamSlug, request: request));
    return fixturePost(slug: 'nouvelle-publication', name: request.name);
  }

  @override
  Future<PostDto> updatePost(
    String teamSlug,
    String postSlug,
    PostRequest request,
  ) async {
    final Object? error = failWith;
    if (error != null) throw error;
    updated.add((slug: postSlug, request: request));
    return fixturePost(slug: postSlug, name: request.name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubTeams implements TeamRepository {
  _StubTeams(this.team);

  final TeamDetailDto team;

  @override
  Future<TeamDetailDto> getTeam(String slug) async => team;

  @override
  Future<List<TeamDetailDto>> getMyTeams() async =>
      team.role == null ? <TeamDetailDto>[] : <TeamDetailDto>[team];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;
  setUp(() async {
    setCurrentLocale('fr');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  late GoRouter router;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> open(
    WidgetTester tester, {
    required _StubPosts posts,
    String? role = 'ORGANIZER',
    bool enablePosts = true,
    bool postsAsTeamByDefault = true,
    String? postSlug,
  }) async {
    // Un écran haut : le formulaire est long, et seul ce qui est construit
    // se trouve.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) => const Text('accueil'),
        ),
        GoRoute(
          path: '/editor',
          builder: (BuildContext _, GoRouterState _) =>
              PostEditorPage(teamSlug: 'n-peloton', postSlug: postSlug),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/articles/:postSlug',
          builder: (BuildContext _, GoRouterState state) =>
              Text('publication ${state.pathParameters['postSlug']}'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          postRepositoryProvider.overrideWithValue(posts),
          teamRepositoryProvider.overrideWithValue(
            _StubTeams(
              fixtureRouteTeam(role: role).copyWith(
                enablePosts: enablePosts,
                postsAsTeamByDefault: postsAsTeamByDefault,
              ),
            ),
          ),
          teamTagsProvider.overrideWith(
            (Ref ref, ({String teamSlug, TagTarget type}) key) async =>
                <TagWithUsageDto>[],
          ),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.push('/editor');
    await settle(tester);
  }

  testWidgets('un simple membre lit un refus, pas un formulaire', (
    WidgetTester tester,
  ) async {
    await open(tester, posts: _StubPosts(), role: 'MEMBER');

    expect(find.byKey(keys.postEditor.forbidden), findsOneWidget);
    expect(find.text('Réservé au rôle Organisateur'), findsOneWidget);
    expect(find.byKey(keys.postEditor.saveButton), findsNothing);
  });

  testWidgets('le refus précède la lecture de la publication', (
    WidgetTester tester,
  ) async {
    final _StubPosts posts = _StubPosts();
    await open(
      tester,
      posts: posts,
      role: 'MEMBER',
      postSlug: 'retour-de-sortie',
    );

    expect(find.byKey(keys.postEditor.forbidden), findsOneWidget);
    expect(posts.reads, 0);
  });

  testWidgets('module publications coupé : le même écran, un autre message', (
    WidgetTester tester,
  ) async {
    await open(tester, posts: _StubPosts(), enablePosts: false);

    expect(find.byKey(keys.postEditor.forbidden), findsOneWidget);
    expect(
      find.text('Les publications sont désactivées pour cette équipe.'),
      findsOneWidget,
    );
  });

  testWidgets('sans canEdit sur la publication : refus', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      posts: _StubPosts(post: fixturePost(permissions: kNoPermissions)),
      postSlug: 'retour-de-sortie',
    );

    expect(find.byKey(keys.postEditor.forbidden), findsOneWidget);
    expect(find.byKey(keys.postEditor.saveButton), findsNothing);
  });

  group('création', () {
    testWidgets('brouillon par défaut : le titre et le texte partent, signés '
        'comme l\'équipe le veut', (WidgetTester tester) async {
      final _StubPosts posts = _StubPosts();
      await open(tester, posts: posts);

      expect(find.text('Nouvelle publication'), findsOneWidget);
      expect(find.byKey(keys.postEditor.slugRow), findsNothing);
      // Brouillon : la publication programmée, pas la date.
      expect(find.byKey(keys.postEditor.publishAtRow), findsOneWidget);
      expect(find.byKey(keys.postEditor.dateRow), findsNothing);

      await tester.enterText(
        find.byKey(keys.postEditor.nameField),
        'Retour du dimanche',
      );
      await tester.enterText(
        find.byKey(keys.postEditor.markdownField),
        'Quel vent !',
      );
      await tester.pump();
      await tester.tap(find.byKey(keys.postEditor.saveButton));
      await settle(tester);

      final ({String team, PostRequest request}) sent = posts.created.single;
      expect(sent.team, 'n-peloton');
      expect(sent.request.name, 'Retour du dimanche');
      expect(sent.request.media.markdown, 'Quel vent !');
      expect(sent.request.status, 'DRAFT');
      expect(sent.request.visibility, 'PUBLIC');
      expect(sent.request.signedAsTeam, isTrue);
      expect(sent.request.publishAt, isNull);
      expect(sent.request.tagIds, isEmpty);
      // La création laisse place à l'écran de la publication.
      expect(find.text('publication nouvelle-publication'), findsOneWidget);
    });

    testWidgets('« Publié » montre la date, et l\'interrupteur change la '
        'signature', (WidgetTester tester) async {
      final _StubPosts posts = _StubPosts();
      await open(tester, posts: posts, postsAsTeamByDefault: false);

      await tester.enterText(find.byKey(keys.postEditor.nameField), 'Titre');
      await tester.tap(find.byKey(keys.postEditor.statusOption('PUBLISHED')));
      await tester.pump();
      expect(find.byKey(keys.postEditor.dateRow), findsOneWidget);
      expect(find.byKey(keys.postEditor.timeRow), findsOneWidget);
      expect(find.byKey(keys.postEditor.publishAtRow), findsNothing);

      expect(
        tester
            .widget<PdlSwitch>(find.byKey(keys.postEditor.signedAsTeam))
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(keys.postEditor.signedAsTeam));
      await tester.pump();

      await tester.tap(find.byKey(keys.postEditor.saveButton));
      await settle(tester);

      final PostRequest request = posts.created.single.request;
      expect(request.status, 'PUBLISHED');
      expect(request.signedAsTeam, isTrue);
    });

    testWidgets('sans titre : rien ne part, le champ le dit', (
      WidgetTester tester,
    ) async {
      final _StubPosts posts = _StubPosts();
      await open(tester, posts: posts);

      await tester.tap(find.byKey(keys.postEditor.saveButton));
      await settle(tester);

      expect(posts.created, isEmpty);
      expect(find.byKey(keys.postEditor.errorBanner), findsOneWidget);
      expect(find.text('Entre 1 et 200 caractères'), findsOneWidget);
    });

    testWidgets('un échec du serveur garde le formulaire', (
      WidgetTester tester,
    ) async {
      final _StubPosts posts = _StubPosts()
        ..failWith = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.badResponse,
          response: Response<Map<String, Object?>>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 403,
            data: const <String, Object?>{'code': 'FORBIDDEN'},
          ),
        );
      await open(tester, posts: posts);

      await tester.enterText(find.byKey(keys.postEditor.nameField), 'Titre');
      await tester.tap(find.byKey(keys.postEditor.saveButton));
      await settle(tester);

      expect(find.byKey(keys.postEditor.errorBanner), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(keys.postEditor.nameField))
            .controller!
            .text,
        'Titre',
      );
    });
  });

  group('modification', () {
    testWidgets('le formulaire reprend la publication, et la réécrit en '
        'entier', (WidgetTester tester) async {
      final _StubPosts posts = _StubPosts(
        post: fixturePost(
          tags: const <TagDto>[TagDto(id: 'g1', label: 'Récit', color: 'blue')],
        ),
      );
      await open(tester, posts: posts, postSlug: 'retour-de-sortie');

      expect(find.text('Modifier la publication'), findsOneWidget);
      expect(find.byKey(keys.postEditor.slugRow), findsOneWidget);
      expect(find.text('retour-de-sortie'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      // Publiée : sa date, dans son fuseau (09:00 UTC, 11:00 à Paris).
      expect(find.byKey(keys.postEditor.dateRow), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);

      await tester.enterText(
        find.byKey(keys.postEditor.nameField),
        'Titre corrigé',
      );
      await tester.tap(find.byKey(keys.postEditor.saveButton));
      await settle(tester);

      final ({String slug, PostRequest request}) sent = posts.updated.single;
      expect(sent.slug, 'retour-de-sortie');
      expect(sent.request.name, 'Titre corrigé');
      expect(sent.request.media.markdown, 'Belle matinée.');
      expect(sent.request.dateTime, '2026-05-03T11:00:00');
      expect(sent.request.status, 'PUBLISHED');
      expect(sent.request.visibility, 'TEAM');
      expect(sent.request.signedAsTeam, isFalse);
      expect(sent.request.tagIds, <String>['g1']);
      // Revenu à ce qui était dessous.
      expect(find.text('accueil'), findsOneWidget);
    });

    testWidgets('une publication annulée garde son statut proposé', (
      WidgetTester tester,
    ) async {
      final _StubPosts posts = _StubPosts(
        post: fixturePost(status: 'CANCELLED'),
      );
      await open(tester, posts: posts, postSlug: 'retour-de-sortie');

      expect(
        find.byKey(keys.postEditor.statusOption('CANCELLED')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(keys.postEditor.saveButton));
      await settle(tester);
      expect(posts.updated.single.request.status, 'CANCELLED');
    });

    testWidgets('quitter un formulaire modifié demande confirmation', (
      WidgetTester tester,
    ) async {
      final _StubPosts posts = _StubPosts();
      await open(tester, posts: posts, postSlug: 'retour-de-sortie');

      await tester.enterText(find.byKey(keys.postEditor.nameField), 'Autre');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.text('Abandonner les modifications ?'), findsOneWidget);
      expect(posts.updated, isEmpty);
    });
  });
}
