import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/api/pedalons_api_client.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/material.dart' hide Visibility;
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/presentation/widgets/editor/rich_markdown_editor_field.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/presentation/pages/team_custom_page.dart'
    show teamPageProvider;
import 'package:pedalons/features/teams/presentation/pages/team_page_editor_page.dart';
import 'package:pedalons/features/teams/providers/team_permission_providers.dart';
import 'package:pedalons/features/teams/providers/team_pages_provider.dart';
import 'package:pedalons/keys.dart';

import '../../support/content_permissions.dart';
import '../../support/localization.dart';
import 'team_fixtures.dart';

/// L'éditeur d'une page d'équipe (ledger `MOB-169`) : qui y entre — et que la
/// page n'est lue pour personne d'autre —, les requêtes exactes de création
/// et de modification (le PUT réécrit tout), les visibilités que donne le
/// backend, le changement d'adresse, l'abandon, et l'erreur du serveur qui
/// garde la saisie.
class _Teams implements TeamRepository {
  _Teams({this.role = 'ADMIN', this.refusedWith, this.team});

  final String? role;

  /// Si posé, `getTeam` répond ce statut HTTP : l'équipe se refuse.
  final int? refusedWith;

  /// Réécrit la fiche rendue (visibilité, visibilités permises…).
  final TeamDetailDto Function(TeamDetailDto team)? team;

  int teamReads = 0;
  int myTeamsReads = 0;

  @override
  Future<TeamDetailDto> getTeam(String slug) async {
    teamReads++;
    final int? status = refusedWith;
    if (status != null) throw _apiError(status, 'NOT_FOUND');
    final TeamDetailDto base = fixtureTeam(slug: slug, role: role);
    return team?.call(base) ?? base;
  }

  @override
  Future<List<TeamDetailDto>> getMyTeams() async {
    myTeamsReads++;
    return const <TeamDetailDto>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Pages implements TeamPagesClient {
  _Pages({TeamPageDto? page}) : page = page ?? _rules();

  TeamPageDto page;
  Object? readError;
  Object? writeError;

  /// Si posé, les écritures attendent qu'il soit complété.
  Completer<void>? writeGate;

  final List<String> reads = <String>[];
  int listCalls = 0;
  final List<Map<String, Object?>> created = <Map<String, Object?>>[];
  final List<({String slug, Map<String, Object?> body})> updated =
      <({String slug, Map<String, Object?> body})>[];
  final List<({String slug, Map<String, Object?> body})> slugChanges =
      <({String slug, Map<String, Object?> body})>[];

  Future<void> _write() async {
    await writeGate?.future;
    final Object? error = writeError;
    if (error != null) throw error;
  }

  @override
  Future<List<TeamPageSummaryDto>> listPages({required String teamSlug}) async {
    listCalls++;
    return const <TeamPageSummaryDto>[];
  }

  @override
  Future<TeamPageDto> getPage({
    required String pageSlug,
    required String teamSlug,
  }) async {
    reads.add(pageSlug);
    final Object? error = readError;
    if (error != null) throw error;
    return page.copyWith(slug: pageSlug);
  }

  @override
  Future<TeamPageDto> createPage({
    required String teamSlug,
    required TeamPageRequest body,
  }) async {
    await _write();
    created.add(body.toJson());
    return page.copyWith(
      id: 'new',
      slug: 'nouvelle-page',
      title: body.title,
      media: body.media,
      visibility: body.visibility,
    );
  }

  @override
  Future<TeamPageDto> updatePage({
    required String pageSlug,
    required String teamSlug,
    required TeamPageRequest body,
  }) async {
    await _write();
    updated.add((slug: pageSlug, body: body.toJson()));
    return page = page.copyWith(
      title: body.title,
      media: body.media,
      visibility: body.visibility,
    );
  }

  @override
  Future<TeamPageDto> changePageSlug({
    required String pageSlug,
    required String teamSlug,
    required SlugChangeRequest body,
  }) async {
    await _write();
    slugChanges.add((slug: pageSlug, body: body.toJson()));
    return page = page.copyWith(slug: body.slug);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const AssetDto _image = AssetDto(
  id: 'img1',
  fileName: 'col.jpg',
  contentType: 'image/jpeg',
  url: '/api/download/team/img1',
  size: 1200,
);

const AssetDto _attachment = AssetDto(
  id: 'att1',
  fileName: 'reglement.pdf',
  contentType: 'application/pdf',
  url: '/api/download/team/att1',
  size: 4200,
);

const MediaDto _media = MediaDto(
  markdown: 'Le règlement du club.',
  assets: AssetsDto(
    images: <AssetDto>[_image],
    attachments: <AssetDto>[_attachment],
    logo: _image,
  ),
);

TeamPageDto _rules({
  String visibility = 'PUBLIC',
  bool canEdit = true,
  List<Visibility>? allowed,
}) => TeamPageDto(
  team: kMemberTeam,
  id: 'pg2',
  title: 'Règlement',
  slug: 'reglement',
  media: _media,
  visibility: visibility,
  order: 1,
  deleted: false,
  permissions: ContentPermissionsDto(
    canEdit: canEdit,
    canDelete: canEdit,
    indexable: false,
    allowedVisibilities:
        allowed ??
        const <Visibility>[
          Visibility.team,
          Visibility.publicUnlisted,
          Visibility.public,
        ],
  ),
);

DioException _apiError(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/api/teams/n-peloton/pages'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, Object?>>(
    requestOptions: RequestOptions(path: '/api/teams/n-peloton/pages'),
    statusCode: status,
    data: <String, Object?>{'code': code},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);
  setUp(() => setCurrentLocale('fr'));

  final k = keys.teamPageEditor;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  late GoRouter router;

  /// Ouvre l'éditeur au-dessus de la liste des pages : une création, ou la
  /// modification de [pageSlug].
  Future<ProviderContainer> open(
    WidgetTester tester, {
    _Teams? teams,
    _Pages? pages,
    String? pageSlug,
    bool platformAdmin = false,
  }) async {
    tester.view.physicalSize = const Size(600, 3200);
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
          path: Paths.teamAdminPages(':teamSlug'),
          // Un `Scaffold`, comme la vraie liste : c'est lui qui montre le
          // message de l'enregistrement.
          builder: (BuildContext _, GoRouterState _) =>
              const Scaffold(body: Text('liste')),
          routes: <RouteBase>[
            GoRoute(
              path: 'nouvelle',
              builder: (BuildContext _, GoRouterState state) =>
                  TeamPageEditorPage(
                    teamSlug: state.pathParameters['teamSlug']!,
                  ),
            ),
            GoRoute(
              path: ':pageSlug/modifier',
              builder: (BuildContext _, GoRouterState state) =>
                  TeamPageEditorPage(
                    teamSlug: state.pathParameters['teamSlug']!,
                    pageSlug: state.pathParameters['pageSlug'],
                  ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          teamRepositoryProvider.overrideWithValue(teams ?? _Teams()),
          teamPagesClientProvider.overrideWithValue(pages ?? _Pages()),
          isPlatformAdminProvider.overrideWithValue(platformAdmin),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.go(
      pageSlug == null
          ? Paths.teamAdminPageNew('n-peloton')
          : Paths.teamAdminPageEdit('n-peloton', pageSlug),
    );
    await settle(tester);
    return ProviderScope.containerOf(
      tester.element(find.byType(TeamPageEditorPage)),
      listen: false,
    );
  }

  String location() => router.routerDelegate.currentConfiguration.uri.path;

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(k.saveButton));
    await settle(tester);
  }

  String titleText(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(k.titleField)).controller!.text;

  bool titleEnabled(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(k.titleField)).enabled ?? true;

  group('accès', () {
    for (final String? role in <String?>['ORGANIZER', 'MEMBER', null]) {
      testWidgets('rôle $role : un refus, et la page n\'est pas lue', (
        WidgetTester tester,
      ) async {
        final _Pages pages = _Pages();
        await open(
          tester,
          teams: _Teams(role: role),
          pages: pages,
          pageSlug: 'reglement',
        );

        expect(find.byKey(k.forbidden), findsOneWidget);
        expect(find.text('Réservé au rôle Administrateur'), findsOneWidget);
        expect(pages.reads, isEmpty);
        expect(find.byKey(k.titleField), findsNothing);

        await tester.tap(find.byKey(k.forbiddenBack));
        await settle(tester);
        expect(find.text('liste'), findsOneWidget);
      });
    }

    for (final int status in <int>[403, 404]) {
      testWidgets('une équipe que le serveur refuse ($status) : le refus, la '
          'page n\'est pas lue', (WidgetTester tester) async {
        final _Pages pages = _Pages();
        await open(
          tester,
          teams: _Teams(refusedWith: status),
          pages: pages,
          pageSlug: 'reglement',
        );

        expect(find.byKey(k.forbidden), findsOneWidget);
        expect(find.byKey(k.loadError), findsNothing);
        expect(pages.reads, isEmpty);
      });
    }

    testWidgets('une page que le backend ne laisse pas modifier '
        '(`canEdit` faux) : le refus, pas le formulaire', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages(page: _rules(canEdit: false));
      await open(tester, pages: pages, pageSlug: 'reglement');

      expect(pages.reads, <String>['reglement']);
      expect(find.byKey(k.forbidden), findsOneWidget);
      expect(find.byKey(k.titleField), findsNothing);
    });

    testWidgets('une page introuvable : une erreur à réessayer', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages()..readError = _apiError(404, 'NOT_FOUND');
      await open(tester, pages: pages, pageSlug: 'reglement');

      expect(find.byKey(k.loadError), findsOneWidget);
      expect(find.byKey(k.forbidden), findsNothing);

      pages.readError = null;
      await tester.tap(find.text('Réessayer'));
      await settle(tester);
      expect(find.byKey(k.titleField), findsOneWidget);
    });

    testWidgets('admin de plateforme non membre : le formulaire', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teams: _Teams(role: null),
        platformAdmin: true,
        pageSlug: 'reglement',
      );

      expect(find.byKey(k.forbidden), findsNothing);
      expect(titleText(tester), 'Règlement');
    });
  });

  group('création', () {
    testWidgets('le formulaire vide : pas d\'adresse à changer, « Créer la '
        'page »', (WidgetTester tester) async {
      await open(tester);

      expect(find.text('Créer une page'), findsOneWidget);
      expect(find.byKey(k.slugRow), findsNothing);
      expect(titleText(tester), '');
      expect(
        tester.widget<PdlButton>(find.byKey(k.saveButton)).label,
        'Créer la page',
      );
    });

    for (final String title in <String>['', '   ', 'a' * 101]) {
      testWidgets('un titre de ${title.length} caractères n\'envoie rien, et '
          'le champ le dit sans couper la saisie', (WidgetTester tester) async {
        final _Pages pages = _Pages();
        await open(tester, pages: pages);

        expect(find.text('Entre 1 et 100 caractères'), findsNothing);
        await tester.enterText(find.byKey(k.titleField), title);
        await save(tester);

        expect(pages.created, isEmpty);
        expect(find.text('Entre 1 et 100 caractères'), findsOneWidget);
        expect(find.byKey(k.errorBanner), findsOneWidget);
        expect(titleText(tester), title);
      });
    }

    testWidgets('la requête exacte : titre rogné, texte, médias vides, '
        '« Équipe » par défaut ; puis retour à la liste', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages();
      final _Teams teams = _Teams();
      await open(tester, teams: teams, pages: pages);
      final int teamReads = teams.teamReads;

      await tester.enterText(find.byKey(k.titleField), '  FAQ ');
      // L'éditeur riche (une WebView, absente des tests de widget) écrit son
      // markdown dans le contrôleur du champ : on y écrit à sa place.
      expect(find.byKey(k.markdownField), findsOneWidget);
      tester
              .widget<RichMarkdownEditorField>(
                find.byType(RichMarkdownEditorField),
              )
              .controller
              .text =
          'Les questions fréquentes.';
      await tester.pump();
      await save(tester);

      expect(pages.created.single, <String, Object?>{
        'title': 'FAQ',
        'media': const MediaDto(
          markdown: 'Les questions fréquentes.',
          assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
        ).toJson(),
        'visibility': 'TEAM',
      });
      expect(pages.updated, isEmpty);
      expect(find.text('Page créée'), findsOneWidget);
      expect(find.text('liste'), findsOneWidget);
      expect(location(), '/equipes/n-peloton/admin/pages');
      // La fiche de l'équipe — « À propos » lit son `pages[]` — est relue ;
      // « Mes équipes » non.
      expect(teams.teamReads, teamReads + 1);
      expect(teams.myTeamsReads, 0);
    });

    testWidgets('les visibilités sont celles que le backend donne à '
        'l\'équipe ; la valeur choisie part', (WidgetTester tester) async {
      final _Pages pages = _Pages();
      await open(tester, pages: pages);

      for (final String v in <String>['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']) {
        expect(find.byKey(keys.visibility.option(v)), findsOneWidget);
      }
      expect(find.byKey(k.visibilityHint), findsOneWidget);

      await tester.enterText(find.byKey(k.titleField), 'FAQ');
      await tester.tap(find.byKey(keys.visibility.option('PUBLIC')));
      await settle(tester);
      await save(tester);

      expect(pages.created.single['visibility'], 'PUBLIC');
    });

    testWidgets('une seule visibilité permise : le champ n\'est pas rendu, '
        'et c\'est elle qui part', (WidgetTester tester) async {
      final _Pages pages = _Pages();
      await open(
        tester,
        // Une équipe privée sans contenu public par lien : « Équipe » seule.
        teams: _Teams(
          team: (TeamDetailDto t) => t.copyWith(
            visibility: 'TEAM',
            allowedContentVisibilities: contentVisibilitiesFor('TEAM'),
          ),
        ),
        pages: pages,
      );

      expect(find.byKey(k.visibility), findsNothing);
      expect(find.byKey(keys.visibility.option('TEAM')), findsNothing);
      expect(find.byKey(k.visibilityHint), findsNothing);

      await tester.enterText(find.byKey(k.titleField), 'FAQ');
      await save(tester);
      expect(pages.created.single['visibility'], 'TEAM');
    });

    testWidgets('les visibilités ne se déduisent pas du rôle ni de la '
        'visibilité de l\'équipe : une équipe publique à qui le backend ne '
        'donne que deux valeurs n\'en propose que deux', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        teams: _Teams(
          team: (TeamDetailDto t) => t.copyWith(
            allowedContentVisibilities: kAllContentVisibilities.copyWith(
              teamPage: <Visibility>[Visibility.team, Visibility.public],
            ),
          ),
        ),
      );

      expect(find.byKey(keys.visibility.option('TEAM')), findsOneWidget);
      expect(find.byKey(keys.visibility.option('PUBLIC')), findsOneWidget);
      expect(
        find.byKey(keys.visibility.option('PUBLIC_UNLISTED')),
        findsNothing,
      );
    });

    testWidgets('TOO_MANY_TEAM_PAGES : un bandeau, le formulaire et la saisie '
        'restent', (WidgetTester tester) async {
      final _Pages pages = _Pages()
        ..writeError = _apiError(400, 'TOO_MANY_TEAM_PAGES');
      await open(tester, pages: pages);

      await tester.enterText(find.byKey(k.titleField), 'Une de trop');
      await save(tester);

      expect(find.byKey(k.errorBanner), findsOneWidget);
      expect(
        find.text('Le nombre maximum de pages pour cette équipe est atteint'),
        findsOneWidget,
      );
      expect(titleText(tester), 'Une de trop');
      expect(location(), '/equipes/n-peloton/admin/pages/nouvelle');

      // Le formulaire repart.
      pages.writeError = null;
      await save(tester);
      expect(pages.created.single['title'], 'Une de trop');
    });

    testWidgets('pendant l\'enregistrement, la saisie est figée et un second '
        'appui ne part pas', (WidgetTester tester) async {
      final _Pages pages = _Pages()..writeGate = Completer<void>();
      await open(tester, pages: pages);

      await tester.enterText(find.byKey(k.titleField), 'FAQ');
      await tester.tap(find.byKey(k.saveButton));
      await tester.pump();
      expect(titleEnabled(tester), isFalse);
      await tester.tap(find.byKey(k.saveButton), warnIfMissed: false);
      await tester.pump();

      pages.writeGate!.complete();
      await settle(tester);
      expect(pages.created, hasLength(1));
    });
  });

  group('modification', () {
    testWidgets('un formulaire intact renvoie la page entière — titre, '
        'texte, logo, images, pièces jointes, visibilité : le PUT réécrit '
        'tout', (WidgetTester tester) async {
      final _Pages pages = _Pages();
      await open(tester, pages: pages, pageSlug: 'reglement');

      expect(find.text('Modifier la page'), findsOneWidget);
      expect(titleText(tester), 'Règlement');
      expect(find.byKey(k.slugRow), findsOneWidget);
      expect(find.text('reglement'), findsOneWidget);

      await save(tester);

      expect(pages.updated.single.slug, 'reglement');
      expect(pages.updated.single.body, <String, Object?>{
        'title': 'Règlement',
        'media': _media.toJson(),
        'visibility': 'PUBLIC',
      });
      expect(pages.created, isEmpty);
      expect(find.text('Page mise à jour'), findsOneWidget);
      expect(find.text('liste'), findsOneWidget);
    });

    testWidgets('le titre et la visibilité changés partent, les médias '
        'restent', (WidgetTester tester) async {
      final _Pages pages = _Pages();
      await open(tester, pages: pages, pageSlug: 'reglement');

      await tester.enterText(find.byKey(k.titleField), 'Charte');
      await tester.tap(find.byKey(keys.visibility.option('TEAM')));
      await settle(tester);
      await save(tester);

      expect(pages.updated.single.body, <String, Object?>{
        'title': 'Charte',
        'media': _media.toJson(),
        'visibility': 'TEAM',
      });
    });

    testWidgets('les visibilités sont celles de la page '
        '(`permissions.allowedVisibilities`), pas celles de l\'équipe', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        pages: _Pages(
          page: _rules(
            visibility: 'TEAM',
            allowed: const <Visibility>[Visibility.team, Visibility.public],
          ),
        ),
        pageSlug: 'reglement',
      );

      expect(find.byKey(keys.visibility.option('TEAM')), findsOneWidget);
      expect(find.byKey(keys.visibility.option('PUBLIC')), findsOneWidget);
      expect(
        find.byKey(keys.visibility.option('PUBLIC_UNLISTED')),
        findsNothing,
      );
    });

    testWidgets('une seule visibilité permise, celle de la page : le champ '
        'n\'est pas rendu', (WidgetTester tester) async {
      await open(
        tester,
        pages: _Pages(
          page: _rules(
            visibility: 'TEAM',
            allowed: const <Visibility>[Visibility.team],
          ),
        ),
        pageSlug: 'reglement',
      );

      expect(find.byKey(k.visibility), findsNothing);
      expect(find.byKey(keys.visibility.notAllowed), findsNothing);
    });

    testWidgets('la visibilité actuelle n\'est plus permise : elle reste '
        'affichée avec l\'avertissement, jusqu\'à ce qu\'une autre soit '
        'choisie', (WidgetTester tester) async {
      final _Pages pages = _Pages(
        page: _rules(
          visibility: 'PUBLIC',
          allowed: const <Visibility>[Visibility.team],
        ),
      );
      await open(tester, pages: pages, pageSlug: 'reglement');

      expect(find.byKey(k.visibility), findsOneWidget);
      expect(find.byKey(keys.visibility.option('PUBLIC')), findsOneWidget);
      expect(find.byKey(keys.visibility.option('TEAM')), findsOneWidget);
      expect(find.byKey(keys.visibility.notAllowed), findsOneWidget);

      // « Équipe » se choisit ; « Public », abandonné, n'est plus proposé.
      await tester.tap(find.byKey(keys.visibility.option('TEAM')));
      await settle(tester);
      expect(find.byKey(keys.visibility.option('PUBLIC')), findsNothing);
      expect(find.byKey(keys.visibility.notAllowed), findsNothing);
      await save(tester);
      expect(pages.updated.single.body['visibility'], 'TEAM');
    });

    testWidgets('une erreur du serveur garde le formulaire et la saisie', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages()..writeError = _apiError(403, 'FORBIDDEN');
      await open(tester, pages: pages, pageSlug: 'reglement');

      await tester.enterText(find.byKey(k.titleField), 'Charte');
      await save(tester);

      expect(find.byKey(k.errorBanner), findsOneWidget);
      expect(titleText(tester), 'Charte');
      expect(find.text('liste'), findsNothing);
      expect(find.text('Page mise à jour'), findsNothing);
    });

    testWidgets('après l\'enregistrement, la liste des pages et le contenu '
        'de la page sont relus', (WidgetTester tester) async {
      final _Pages pages = _Pages();
      final ProviderContainer container = await open(
        tester,
        pages: pages,
        pageSlug: 'reglement',
      );
      // La liste d'administration, restée ouverte sous l'éditeur.
      final ProviderSubscription<AsyncValue<List<TeamPageSummaryDto>>> list =
          container.listen(teamAdminPagesProvider('n-peloton'), (_, _) {});
      addTearDown(list.close);
      await settle(tester);
      expect(pages.listCalls, 1);
      expect(pages.reads, <String>['reglement']);

      await tester.enterText(find.byKey(k.titleField), 'Charte');
      await save(tester);

      expect(pages.listCalls, 2);
    });
  });

  group('revue finale', () {
    testWidgets('l\'éditeur relit la page à son ouverture, même si l\'app '
        'l\'a déjà lue : le formulaire part de la page d\'aujourd\'hui', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages();
      await open(tester, pages: pages, pageSlug: 'reglement');
      expect(pages.reads, <String>['reglement']);
      expect(titleText(tester), 'Règlement');

      // Retour à la liste : la page reste en cache.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('liste'), findsOneWidget);

      // Entre-temps, quelqu'un lui a ajouté une pièce jointe au site.
      const AssetDto added = AssetDto(
        id: 'att2',
        fileName: 'charte.pdf',
        contentType: 'application/pdf',
        url: '/api/download/team/att2',
      );
      pages.page = pages.page.copyWith(
        title: 'Règlement 2027',
        media: _media.copyWith(
          assets: _media.assets.copyWith(
            attachments: <AssetDto>[_attachment, added],
          ),
        ),
      );

      router.go(Paths.teamAdminPageEdit('n-peloton', 'reglement'));
      await settle(tester);

      expect(pages.reads, <String>['reglement', 'reglement']);
      expect(titleText(tester), 'Règlement 2027');

      // Le formulaire intact renvoie la pièce jointe ajoutée ailleurs.
      await save(tester);
      expect(
        ((pages.updated.single.body['media']!
                as Map<String, Object?>)['assets']!
            as Map<String, Object?>)['attachments'],
        hasLength(2),
      );
    });

    testWidgets('une relecture sous le formulaire ne réécrit pas la saisie', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages();
      final ProviderContainer container = await open(
        tester,
        pages: pages,
        pageSlug: 'reglement',
      );

      await tester.enterText(find.byKey(k.titleField), 'En cours');
      await tester.pump();
      pages.page = pages.page.copyWith(title: 'Changé ailleurs');
      container.invalidate(
        teamPageProvider((teamSlug: 'n-peloton', pageSlug: 'reglement')),
      );
      await settle(tester);

      expect(titleText(tester), 'En cours');
    });

    testWidgets('une visibilité que cette version ne connaît pas ne part '
        'pas : le bandeau le dit, et en choisir une autre enregistre', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages(
        page: _rules(
          visibility: 'FRIENDS',
          allowed: const <Visibility>[Visibility.team, Visibility.public],
        ),
      );
      await open(tester, pages: pages, pageSlug: 'reglement');

      await save(tester);
      expect(pages.updated, isEmpty);
      expect(
        find.textContaining('ne connaît pas la visibilité de cette page'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(keys.visibility.option('TEAM')));
      await settle(tester);
      await save(tester);
      expect(pages.updated.single.body['visibility'], 'TEAM');
    });
  });

  group('adresse', () {
    Future<void> changeSlug(WidgetTester tester, String slug) async {
      await tester.tap(find.byKey(k.slugRow));
      await settle(tester);
      await tester.enterText(find.byKey(k.slugField), slug);
      await tester.tap(find.byKey(k.slugSave));
      await settle(tester);
    }

    testWidgets('changer l\'adresse envoie le nouveau slug, puis l\'éditeur '
        'repart de la nouvelle adresse', (WidgetTester tester) async {
      final _Pages pages = _Pages();
      await open(tester, pages: pages, pageSlug: 'reglement');

      await changeSlug(tester, 'charte');

      expect(pages.slugChanges.single.slug, 'reglement');
      expect(pages.slugChanges.single.body, <String, Object?>{
        'slug': 'charte',
      });
      expect(pages.updated, isEmpty);
      expect(find.text('Adresse modifiée'), findsOneWidget);
      expect(location(), '/equipes/n-peloton/admin/pages/charte/modifier');
      expect(find.text('charte'), findsOneWidget);
      expect(titleText(tester), 'Règlement');
    });

    testWidgets('un formulaire modifié demande d\'abord d\'abandonner', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages();
      await open(tester, pages: pages, pageSlug: 'reglement');

      await tester.enterText(find.byKey(k.titleField), 'Autre');
      await tester.pump();
      await tester.tap(find.byKey(k.slugRow));
      await settle(tester);

      expect(find.text('Abandonner les modifications ?'), findsOneWidget);
      expect(find.byKey(k.slugField), findsNothing);

      await tester.tap(find.text('Annuler'));
      await settle(tester);
      expect(find.byKey(k.slugField), findsNothing);
      expect(titleText(tester), 'Autre');
      expect(pages.slugChanges, isEmpty);
    });

    testWidgets('pendant le changement d\'adresse, la saisie est figée et '
        '« Enregistrer » attend : rien ne part vers l\'ancienne adresse', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages()..writeGate = Completer<void>();
      await open(tester, pages: pages, pageSlug: 'reglement');

      await changeSlug(tester, 'charte');

      expect(titleEnabled(tester), isFalse);
      expect(
        tester.widget<PdlButton>(find.byKey(k.saveButton)).enabled,
        isFalse,
      );
      await tester.tap(find.byKey(k.saveButton), warnIfMissed: false);
      await tester.tap(find.byKey(k.slugRow), warnIfMissed: false);
      await settle(tester);
      expect(find.byKey(k.slugField), findsNothing);

      pages.writeGate!.complete();
      await settle(tester);
      expect(pages.updated, isEmpty);
      expect(pages.slugChanges, hasLength(1));
      expect(location(), '/equipes/n-peloton/admin/pages/charte/modifier');
    });

    for (final (String code, String message) in <(String, String)>[
      ('SLUG_TAKEN', 'Cette URL personnalisée est déjà utilisée'),
      ('INVALID_SLUG', 'L\'URL personnalisée est invalide'),
    ]) {
      testWidgets('$code : le bandeau le dit, l\'adresse reste, la saisie '
          'est rendue', (WidgetTester tester) async {
        final _Pages pages = _Pages()..writeError = _apiError(409, code);
        await open(tester, pages: pages, pageSlug: 'reglement');

        await changeSlug(tester, 'faq');

        expect(find.text(message), findsOneWidget);
        expect(location(), '/equipes/n-peloton/admin/pages/reglement/modifier');
        expect(titleEnabled(tester), isTrue);
      });
    }
  });

  group('abandon', () {
    testWidgets('quitter un formulaire modifié demande confirmation ; '
        'annuler y reste, confirmer rend la liste', (
      WidgetTester tester,
    ) async {
      final _Pages pages = _Pages();
      await open(tester, pages: pages, pageSlug: 'reglement');

      await tester.enterText(find.byKey(k.titleField), 'Charte');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Abandonner les modifications ?'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await settle(tester);
      expect(titleText(tester), 'Charte');

      await tester.binding.handlePopRoute();
      await settle(tester);
      await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
      await settle(tester);

      expect(find.text('liste'), findsOneWidget);
      expect(pages.updated, isEmpty);
    });

    testWidgets('quitter un formulaire intact ne demande rien', (
      WidgetTester tester,
    ) async {
      await open(tester, pageSlug: 'reglement');

      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.text('Abandonner les modifications ?'), findsNothing);
      expect(find.text('liste'), findsOneWidget);
    });
  });
}
