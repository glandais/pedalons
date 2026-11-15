import 'dart:async';

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
import 'package:pedalons/features/rides/data/ride_repository.dart';
import 'package:pedalons/features/rides/presentation/widgets/editor/rich_markdown_editor_field.dart';
import 'package:pedalons/features/rides/presentation/widgets/editor/ride_media_section.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/data/team_webhook_repository.dart';
import 'package:pedalons/features/teams/domain/team_form.dart';
import 'package:pedalons/features/teams/presentation/pages/team_editor_page.dart';
import 'package:pedalons/features/teams/providers/team_permission_providers.dart';
import 'package:pedalons/features/teams/providers/team_providers.dart';
import 'package:pedalons/features/visibility/presentation/visibility_badge.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import '../rides/ride_fixtures.dart';
import 'team_fixtures.dart';

/// Les paramètres d'une équipe (ledger `MOB-166`) : qui y entre, **ce qui
/// part** — le PUT réécrit tous les champs —, les deux confirmations du site
/// (équipe privée, fuseau), l'adresse, la visibilité, la suppression, et ce
/// que l'écran fait d'un refus du serveur.
class _Teams implements TeamRepository {
  _Teams(this.team);

  /// L'équipe telle que le serveur la connaît.
  TeamDetailDto team;

  /// Si posé, `getTeam` répond ce statut HTTP : l'équipe se refuse.
  int? refusedWith;

  /// `getTeam` lève une panne, pas un refus.
  bool unavailable = false;

  /// Si posé, l'écriture suivante (PUT, slug, suppression) lève cette erreur.
  Object? failWith;

  /// Si posé, `updateTeam` attend qu'il soit complété.
  Completer<void>? gate;

  /// Si posé, `changeTeamSlug` attend qu'il soit complété.
  Completer<void>? slugGate;
  int slugCalls = 0;

  /// Si posé, l'aperçu du changement de fuseau attend qu'il soit complété.
  Completer<void>? previewGate;
  bool previewFails = false;
  TeamTimezoneChangePreviewDto preview = const TeamTimezoneChangePreviewDto(
    from: 'Europe/Paris',
    to: 'Pacific/Auckland',
    upcomingCount: 3,
    pastCount: 2,
    upcoming: <TeamTimezoneChangeItemDto>[
      TeamTimezoneChangeItemDto(
        type: 'RIDE',
        id: 'r1',
        slug: 'boucle',
        title: 'Boucle',
        // 09:30 à Paris, l'ancien fuseau ; 21:30 à Auckland.
        dateTime: '2026-12-12T08:30:00Z',
      ),
    ],
  );

  int teamReads = 0;
  int updateCalls = 0;
  final List<(String, TeamRequest)> updates = <(String, TeamRequest)>[];
  final List<(String, String)> slugChanges = <(String, String)>[];
  final List<String> deleted = <String>[];
  final List<(String, String)> previews = <(String, String)>[];

  @override
  Future<TeamDetailDto> getTeam(String slug) async {
    teamReads++;
    final int? status = refusedWith;
    if (status != null) throw _apiError(status, 'NOT_FOUND');
    if (unavailable) throw StateError('indisponible');
    if (slug != team.slug) throw _apiError(404, 'NOT_FOUND');
    return team;
  }

  @override
  Future<List<TeamDetailDto>> getMyTeams() async => <TeamDetailDto>[team];

  @override
  Future<TeamDetailDto> updateTeam(String slug, TeamRequest request) async {
    updateCalls++;
    await gate?.future;
    final Object? error = failWith;
    if (error != null) throw error;
    updates.add((slug, request));
    team = team.copyWith(
      name: request.name,
      about: request.media,
      visibility: request.visibility,
      timezone: request.timezone ?? team.timezone,
    );
    return team;
  }

  @override
  Future<TeamDetailDto> changeTeamSlug(String slug, String newSlug) async {
    slugCalls++;
    await slugGate?.future;
    final Object? error = failWith;
    if (error != null) throw error;
    slugChanges.add((slug, newSlug));
    team = team.copyWith(slug: newSlug);
    return team;
  }

  @override
  Future<void> deleteTeam(String slug) async {
    final Object? error = failWith;
    if (error != null) throw error;
    deleted.add(slug);
  }

  @override
  Future<TeamTimezoneChangePreviewDto> previewTimezoneChange(
    String slug,
    String timezone,
  ) async {
    previews.add((slug, timezone));
    await previewGate?.future;
    if (previewFails) throw _apiError(500, 'INTERNAL_ERROR');
    return preview;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rides implements RideRepository {
  int reads = 0;

  @override
  Future<RideDto> getRide(String teamSlug, String rideSlug) async {
    reads++;
    return fixtureRide();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Webhooks implements TeamWebhookRepository {
  @override
  Future<TeamWebhookDto> get(String teamSlug) async =>
      const TeamWebhookDto(configured: false, enabled: false);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DioException _apiError(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/api/teams/n-peloton'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, Object?>>(
    requestOptions: RequestOptions(path: '/api/teams/n-peloton'),
    statusCode: status,
    data: <String, Object?>{'code': code},
  ),
);

const AssetDto _logo = AssetDto(
  id: 'logo',
  fileName: 'logo.png',
  contentType: 'image/png',
  url: '/api/download/PUBLIC/logo',
);
const AssetDto _image = AssetDto(
  id: 'img',
  fileName: 'photo.jpg',
  contentType: 'image/jpeg',
  url: '/api/download/PUBLIC/img',
);
const AssetDto _attachment = AssetDto(
  id: 'pdf',
  fileName: 'statuts.pdf',
  contentType: 'application/pdf',
  url: '/api/download/PUBLIC/pdf',
);

/// Une équipe qui a tout : présentation, logo, image, pièce jointe, position,
/// fuseau, et des interrupteurs écartés de leurs défauts.
TeamDetailDto _team({
  String? role = 'ADMIN',
  String visibility = 'PUBLIC',
  bool visibilityEditable = true,
}) =>
    fixtureTeam(
      slug: 'n-peloton',
      name: 'N-Peloton',
      visibility: visibility,
      role: role,
    ).copyWith(
      about: const MediaDto(
        markdown: 'Le club du Nord.',
        assets: AssetsDto(
          logo: _logo,
          images: <AssetDto>[_image],
          attachments: <AssetDto>[_attachment],
        ),
      ),
      geometry: const TeamDetailDtoGeometry(
        type: TeamDetailDtoGeometryTypeType.point,
        coordinates: <double>[3.06, 50.63],
      ),
      timezone: 'Europe/Paris',
      enableTrips: false,
      enableMemberDirectory: true,
      postsAsTeamByDefault: false,
      visibilityEditable: visibilityEditable,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);

  const RideKey rideKey = RideKey(teamSlug: 'n-peloton', rideSlug: 'sortie');

  late SharedPreferences prefs;
  late _Rides rides;
  setUp(() async {
    setCurrentLocale('fr');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    rides = _Rides();
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProviderContainer> open(
    WidgetTester tester,
    _Teams teams, {
    bool platformAdmin = false,
  }) async {
    // Un écran haut : le formulaire est long, et seul ce qui est construit
    // se trouve.
    tester.view.physicalSize = const Size(1200, 5200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext _, GoRouterState _) => const Text('accueil'),
        ),
        GoRoute(
          path: '/equipes',
          builder: (BuildContext _, GoRouterState _) =>
              const Scaffold(body: Text('mes équipes')),
        ),
        GoRoute(
          path: '/equipes/:teamSlug',
          builder: (BuildContext _, GoRouterState state) => Scaffold(
            body: Text('équipe ${state.pathParameters['teamSlug']}'),
          ),
        ),
        GoRoute(
          path: '/equipes/:teamSlug/admin/parametres',
          builder: (BuildContext _, GoRouterState state) =>
              TeamEditorPage(teamSlug: state.pathParameters['teamSlug']),
        ),
      ],
    );
    final ProviderContainer container = ProviderContainer(
      retry: (int _, Object _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        teamRepositoryProvider.overrideWithValue(teams),
        rideRepositoryProvider.overrideWithValue(rides),
        teamWebhookRepositoryProvider.overrideWithValue(_Webhooks()),
        isPlatformAdminProvider.overrideWithValue(platformAdmin),
      ],
    );
    addTearDown(container.dispose);
    // Un détail de sortie déjà lu : il porte la visibilité et les heures
    // d'avant un changement de visibilité ou de fuseau.
    container.listen(rideDetailProvider(rideKey), (_, _) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    router.push('/equipes/n-peloton/admin/parametres');
    await settle(tester);
    return container;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(keys.teamEditor.saveButton));
    await settle(tester);
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
    await settle(tester);
  }

  Future<void> pickVisibility(WidgetTester tester, String visibility) async {
    await tester.tap(find.byKey(keys.teamEditor.visibilityRow));
    await settle(tester);
    await tester.tap(find.byKey(keys.teamEditor.visibilityOption(visibility)));
    await settle(tester);
  }

  Future<void> pickTimezone(WidgetTester tester) async {
    await tester.tap(find.byKey(keys.teamEditor.timezoneRow));
    await settle(tester);
    await tester.enterText(find.byKey(keys.profile.timezoneSearch), 'auckland');
    await settle(tester);
    await tester.tap(find.text('Pacific/Auckland'));
    await settle(tester);
  }

  PdlButton timezoneConfirm(WidgetTester tester) => tester.widget<PdlButton>(
    find.byKey(keys.teamEditor.timezoneChangeConfirm),
  );

  group('accès', () {
    for (final (String label, String? role) in <(String, String?)>[
      ('un simple membre', 'MEMBER'),
      ('un organisateur', 'ORGANIZER'),
      ('quelqu\'un hors de l\'équipe', null),
    ]) {
      testWidgets('$label lit un refus, pas le formulaire', (
        WidgetTester tester,
      ) async {
        final _Teams teams = _Teams(_team(role: role));
        await open(tester, teams);

        expect(find.byKey(keys.teamEditor.forbidden), findsOneWidget);
        expect(find.text('Réservé au rôle Administrateur'), findsOneWidget);
        expect(find.byKey(keys.teamEditor.nameField), findsNothing);
        expect(find.byKey(keys.teamEditor.saveButton), findsNothing);

        await tester.tap(find.byKey(keys.teamEditor.forbiddenBack));
        await settle(tester);
        expect(find.text('accueil'), findsOneWidget);
      });
    }

    testWidgets('un administrateur lit les paramètres, pré-remplis', (
      WidgetTester tester,
    ) async {
      await open(tester, _Teams(_team()));

      expect(find.text('Paramètres de l\'équipe'), findsOneWidget);
      expect(find.byKey(keys.teamEditor.forbidden), findsNothing);
      expect(
        tester
            .widget<TextField>(find.byKey(keys.teamEditor.nameField))
            .controller!
            .text,
        'N-Peloton',
      );
      expect(find.text('n-peloton'), findsOneWidget);
      expect(find.text('Localisation enregistrée'), findsOneWidget);
      expect(find.text('Europe/Paris'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
    });

    testWidgets('un admin de plateforme non membre aussi, visibilité '
        'modifiable même si l\'équipe ne l\'est pas', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team(role: null, visibilityEditable: false));
      await open(tester, teams, platformAdmin: true);

      expect(find.byKey(keys.teamEditor.nameField), findsOneWidget);
      expect(find.byKey(keys.teamEditor.visibilityBadge), findsNothing);

      await pickVisibility(tester, 'PUBLIC_UNLISTED');
      await save(tester);
      expect(teams.updates.single.$2.visibility, 'PUBLIC_UNLISTED');
    });

    for (final int status in <int>[403, 404]) {
      testWidgets('une équipe que le serveur refuse ($status) : le refus, pas '
          'une erreur à réessayer', (WidgetTester tester) async {
        final _Teams teams = _Teams(_team())..refusedWith = status;
        await open(tester, teams);

        expect(find.byKey(keys.teamEditor.forbidden), findsOneWidget);
        expect(find.byKey(keys.teamEditor.loadError), findsNothing);
        expect(find.text('Réessayer'), findsNothing);
      });
    }

    testWidgets('la fiche en échec : une erreur, et « Réessayer » la relit', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team())..unavailable = true;
      await open(tester, teams);

      expect(find.byKey(keys.teamEditor.loadError), findsOneWidget);
      expect(find.byKey(keys.teamEditor.forbidden), findsNothing);

      teams.unavailable = false;
      await tester.tap(find.text('Réessayer'));
      await settle(tester);
      expect(find.byKey(keys.teamEditor.nameField), findsOneWidget);
    });
  });

  group('enregistrer', () {
    testWidgets('un formulaire intact renvoie l\'équipe entière : médias, '
        'position, fuseau, visibilité, interrupteurs', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team());
      await open(tester, teams);

      await save(tester);

      final (String slug, TeamRequest sent) = teams.updates.single;
      expect(slug, 'n-peloton');
      // Le corps exact du PUT, clé par clé.
      expect(sent.toJson(), <String, Object?>{
        'name': 'N-Peloton',
        // La présentation entière : texte, logo, image, pièce jointe.
        'media': _team().about.toJson(),
        'visibility': 'PUBLIC',
        'enableTrips': false,
        'enableAds': true,
        'enablePosts': true,
        'enableRides': true,
        'enableRoutes': true,
        'enableMemberDirectory': true,
        'postsAsTeamByDefault': false,
        'geometry': <String, Object?>{
          'type': 'Point',
          'coordinates': <double>[3.06, 50.63],
        },
        'timezone': 'Europe/Paris',
      });
      // C'est aussi ce que rend le modèle seul.
      expect(sent, TeamForm.fromTeam(_team()).toRequest());
      expect(sent.media.assets.logo, _logo);
      expect(sent.media.assets.images, <AssetDto>[_image]);
      expect(sent.media.assets.attachments, <AssetDto>[_attachment]);

      // Aucune confirmation : ni la visibilité ni le fuseau n'ont changé.
      expect(teams.previews, isEmpty);
      expect(find.text('équipe n-peloton'), findsOneWidget);
      expect(find.text('Équipe mise à jour'), findsOneWidget);
      // Le contenu déjà lu n'a pas à l'être de nouveau.
      expect(rides.reads, 1);
    });

    testWidgets('le nom, un interrupteur et une position effacée partent ; '
        'le reste est gardé', (WidgetTester tester) async {
      final _Teams teams = _Teams(_team());
      await open(tester, teams);

      await tester.enterText(
        find.byKey(keys.teamEditor.nameField),
        'N-Peloton Lille',
      );
      await tester.tap(find.byKey(keys.teamEditor.enableAds));
      await tester.tap(find.byKey(keys.teamEditor.locationClear));
      await tester.pump();
      await save(tester);

      final TeamRequest sent = teams.updates.single.$2;
      expect(sent.name, 'N-Peloton Lille');
      expect(sent.enableAds, isFalse);
      // `geometry: null` : le PUT l'efface (`TeamService.updateTeam`).
      expect(sent.geometry, isNull);
      expect(sent.toJson().containsKey('geometry'), isTrue);
      expect(sent.media.assets.logo, _logo);
      expect(sent.media.assets.images, <AssetDto>[_image]);
      expect(sent.media.assets.attachments, <AssetDto>[_attachment]);
      expect(sent.timezone, 'Europe/Paris');
      expect(sent.enableTrips, isFalse);
      expect(sent.postsAsTeamByDefault, isFalse);
    });

    testWidgets('« Enregistrer » touché deux fois pendant l\'envoi : une '
        'seule requête', (WidgetTester tester) async {
      final _Teams teams = _Teams(_team())..gate = Completer<void>();
      await open(tester, teams);

      await save(tester);
      await save(tester);
      expect(teams.updateCalls, 1);

      teams.gate!.complete();
      await settle(tester);
      expect(teams.updateCalls, 1);
      expect(find.text('équipe n-peloton'), findsOneWidget);
    });

    testWidgets('sans nom : rien ne part', (WidgetTester tester) async {
      final _Teams teams = _Teams(_team());
      await open(tester, teams);

      await tester.enterText(find.byKey(keys.teamEditor.nameField), '  ');
      await save(tester);

      expect(teams.updateCalls, 0);
      expect(find.text('Entre 1 et 200 caractères'), findsOneWidget);
    });

    testWidgets('un refus du serveur garde le formulaire et sa saisie', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team())
        ..failWith = _apiError(400, 'INVALID_TIMEZONE');
      await open(tester, teams);

      await tester.enterText(find.byKey(keys.teamEditor.nameField), 'Autre');
      await save(tester);

      expect(find.byKey(keys.teamEditor.errorBanner), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(keys.teamEditor.nameField))
            .controller!
            .text,
        'Autre',
      );
      // Un second essai repart.
      teams.failWith = null;
      await save(tester);
      expect(teams.updates.single.$2.name, 'Autre');
    });

    testWidgets('quitter des paramètres modifiés demande confirmation', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team());
      await open(tester, teams);

      await tester.enterText(find.byKey(keys.teamEditor.nameField), 'Autre');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(find.text('Abandonner les modifications ?'), findsOneWidget);
      expect(teams.updateCalls, 0);
    });
  });

  group('médias', () {
    testWidgets('l\'éditeur riche a son outil image, la section Médias est '
        'là, et une pièce jointe retirée ne repart pas', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team());
      await open(tester, teams);

      final RichMarkdownEditorField editor = tester
          .widget<RichMarkdownEditorField>(
            find.byType(RichMarkdownEditorField),
          );
      expect(editor.onInsertImage, isNotNull);
      expect(editor.images, <AssetDto>[_image]);

      final RideMediaSection media = tester.widget<RideMediaSection>(
        find.byType(RideMediaSection),
      );
      expect(media.assets.logo, _logo);
      media.onRemoveAttachment(_attachment);
      await tester.pump();
      await save(tester);

      final AssetsDto sent = teams.updates.single.$2.media.assets;
      expect(sent.attachments, isEmpty);
      // Le logo et l'image n'ont pas bougé.
      expect(sent.logo, _logo);
      expect(sent.images, <AssetDto>[_image]);
    });
  });

  group('visibilité', () {
    testWidgets('non modifiable : un badge, pas de feuille', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team(visibilityEditable: false));
      await open(tester, teams);

      expect(
        tester
            .widget<VisibilityBadge>(
              find.byKey(keys.teamEditor.visibilityBadge),
            )
            .visibility,
        Visibility.public,
      );

      await tester.tap(find.byKey(keys.teamEditor.visibilityRow));
      await settle(tester);
      expect(
        find.byKey(keys.teamEditor.visibilityOption('TEAM')),
        findsNothing,
      );

      // La visibilité repart telle quelle.
      await save(tester);
      expect(teams.updates.single.$2.visibility, 'PUBLIC');
    });

    testWidgets('modifiable : la feuille propose les trois choix du site', (
      WidgetTester tester,
    ) async {
      await open(tester, _Teams(_team()));

      await tester.tap(find.byKey(keys.teamEditor.visibilityRow));
      await settle(tester);

      for (final String v in <String>['TEAM', 'PUBLIC_UNLISTED', 'PUBLIC']) {
        expect(find.byKey(keys.teamEditor.visibilityOption(v)), findsOneWidget);
      }
      expect(find.text('Équipe uniquement'), findsOneWidget);
      expect(find.text('Non répertorié'), findsOneWidget);
    });

    testWidgets('rendre l\'équipe privée se confirme ; annuler n\'envoie '
        'rien', (WidgetTester tester) async {
      final _Teams teams = _Teams(_team());
      await open(tester, teams);

      await pickVisibility(tester, 'TEAM');
      await save(tester);

      expect(find.text('Rendre l\'équipe privée ?'), findsOneWidget);
      expect(
        find.textContaining('les liens déjà partagés ne mèneront plus'),
        findsOneWidget,
      );
      expect(teams.updateCalls, 0);

      await tester.tap(find.text('Annuler'));
      await settle(tester);
      expect(teams.updateCalls, 0);
      // Toujours sur le formulaire, le choix gardé.
      expect(find.byKey(keys.teamEditor.saveButton), findsOneWidget);

      await save(tester);
      await confirm(tester);
      expect(teams.updates.single.$2.visibility, 'TEAM');
      expect(find.text('équipe n-peloton'), findsOneWidget);
      // Tout le contenu est passé en « Équipe uniquement » : il est relu.
      expect(rides.reads, 2);
    });

    testWidgets('ouvrir une équipe privée ne demande rien', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team(visibility: 'TEAM'));
      await open(tester, teams);

      await pickVisibility(tester, 'PUBLIC');
      await save(tester);

      expect(find.text('Rendre l\'équipe privée ?'), findsNothing);
      expect(teams.updates.single.$2.visibility, 'PUBLIC');
      expect(rides.reads, 2);
    });
  });

  group('fuseau', () {
    testWidgets('un fuseau changé se confirme sur l\'aperçu du serveur : '
        'inactif tant qu\'il charge, l\'exemple lu dans l\'ancien fuseau', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team())..previewGate = Completer<void>();
      await open(tester, teams);

      await pickTimezone(tester);
      await save(tester);

      // L'aperçu est demandé pour le nouveau fuseau, et rien n'est écrit.
      expect(teams.previews, <(String, String)>[
        ('n-peloton', 'Pacific/Auckland'),
      ]);
      expect(find.byKey(keys.teamEditor.timezoneChangeSheet), findsOneWidget);
      expect(timezoneConfirm(tester).enabled, isFalse);
      await tester.tap(find.byKey(keys.teamEditor.timezoneChangeConfirm));
      await settle(tester);
      expect(teams.updateCalls, 0);

      teams.previewGate!.complete();
      await settle(tester);

      expect(
        find.text(
          'Passer l\'équipe de l\'heure de Paris à l\'heure '
          'd\'Auckland ?',
        ),
        findsOneWidget,
      );
      // 08:30 UTC : 09:30 à Paris, l'ancien fuseau — pas 21:30 à Auckland.
      final String upcoming = tester
          .widget<Text>(find.byKey(keys.teamEditor.timezoneChangeUpcoming))
          .data!;
      expect(
        upcoming,
        startsWith(
          '3 rendez-vous à venir sans lieu de départ, par exemple '
          'la sortie « Boucle » du sam. 12 déc.',
        ),
      );
      expect(
        upcoming,
        endsWith('restera à 09:30, désormais heure d\'Auckland.'),
      );
      expect(
        find.text(
          '2 rendez-vous passés sans lieu de départ gardent leur '
          'heure réelle, désormais affichée heure d\'Auckland.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Les sorties, voyages et étapes situés par un lieu de '
          'départ ou un parcours ne changent pas.',
        ),
        findsOneWidget,
      );

      expect(timezoneConfirm(tester).enabled, isTrue);
      await tester.tap(find.byKey(keys.teamEditor.timezoneChangeConfirm));
      await settle(tester);

      expect(teams.updates.single.$2.timezone, 'Pacific/Auckland');
      expect(find.text('équipe n-peloton'), findsOneWidget);
      // Les heures des rendez-vous ont bougé : le contenu est relu.
      expect(rides.reads, 2);
    });

    testWidgets('aucun rendez-vous à venir : la feuille le dit', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team())
        ..preview = const TeamTimezoneChangePreviewDto(
          from: 'Europe/Paris',
          to: 'Pacific/Auckland',
          upcomingCount: 0,
          pastCount: 0,
          upcoming: <TeamTimezoneChangeItemDto>[],
        );
      await open(tester, teams);

      await pickTimezone(tester);
      await save(tester);

      expect(
        find.text(
          'Aucun rendez-vous à venir sans lieu de départ : aucune '
          'heure ne change.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('rendez-vous passé'), findsNothing);
    });

    testWidgets('l\'aperçu en échec : un message, « Réessayer », et rien à '
        'confirmer', (WidgetTester tester) async {
      final _Teams teams = _Teams(_team())..previewFails = true;
      await open(tester, teams);

      await pickTimezone(tester);
      await save(tester);

      expect(find.byKey(keys.teamEditor.timezoneChangeError), findsOneWidget);
      expect(
        find.text(
          'Impossible de calculer les conséquences de ce changement. '
          'Veuillez réessayer.',
        ),
        findsOneWidget,
      );
      expect(timezoneConfirm(tester).enabled, isFalse);

      teams.previewFails = false;
      await tester.tap(find.byKey(keys.teamEditor.timezoneChangeRetry));
      await settle(tester);

      expect(find.byKey(keys.teamEditor.timezoneChangeError), findsNothing);
      expect(teams.previews, hasLength(2));
      expect(timezoneConfirm(tester).enabled, isTrue);
      expect(teams.updateCalls, 0);
    });

    testWidgets('annuler le changement de fuseau n\'envoie rien', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team());
      await open(tester, teams);

      await pickTimezone(tester);
      await save(tester);
      await tester.tap(find.text('Annuler'));
      await settle(tester);

      expect(teams.updateCalls, 0);
      expect(find.byKey(keys.teamEditor.saveButton), findsOneWidget);
    });

    testWidgets('privée et fuseau changé : les deux confirmations, dans '
        'l\'ordre du site', (WidgetTester tester) async {
      final _Teams teams = _Teams(_team());
      await open(tester, teams);

      await pickVisibility(tester, 'TEAM');
      await pickTimezone(tester);
      await save(tester);

      // D'abord l'équipe privée : l'aperçu du fuseau n'est pas encore lu.
      expect(find.text('Rendre l\'équipe privée ?'), findsOneWidget);
      expect(teams.previews, isEmpty);
      await confirm(tester);

      expect(find.byKey(keys.teamEditor.timezoneChangeSheet), findsOneWidget);
      expect(teams.updateCalls, 0);
      await tester.tap(find.byKey(keys.teamEditor.timezoneChangeConfirm));
      await settle(tester);

      final TeamRequest sent = teams.updates.single.$2;
      expect(sent.visibility, 'TEAM');
      expect(sent.timezone, 'Pacific/Auckland');
    });
  });

  group('adresse', () {
    Future<void> changeSlug(WidgetTester tester, String slug) async {
      await tester.tap(find.byKey(keys.teamEditor.slugRow));
      await settle(tester);
      await tester.enterText(find.byKey(keys.teamEditor.slugField), slug);
      await tester.tap(find.byKey(keys.teamEditor.slugSave));
      await settle(tester);
    }

    testWidgets('changer l\'adresse : l\'appel à part, puis les paramètres '
        'de la nouvelle adresse', (WidgetTester tester) async {
      final _Teams teams = _Teams(_team());
      final ProviderContainer container = await open(tester, teams);
      // L'ancienne fiche est écoutée ailleurs dans l'app : elle est relue.
      container.listen(teamDetailProvider('n-peloton'), (_, _) {});
      final int readsBefore = teams.teamReads;

      await tester.tap(find.byKey(keys.teamEditor.slugRow));
      await settle(tester);
      // L'ancienne adresse d'une équipe redirige : la feuille le dit.
      expect(
        find.textContaining('L\'ancienne adresse redirigera'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(keys.teamEditor.slugField),
        'peloton-du-nord',
      );
      await tester.tap(find.byKey(keys.teamEditor.slugSave));
      await settle(tester);

      expect(teams.slugChanges, <(String, String)>[
        ('n-peloton', 'peloton-du-nord'),
      ]);
      // Aucun PUT : l'adresse a son propre appel.
      expect(teams.updateCalls, 0);
      expect(find.text('Adresse modifiée'), findsOneWidget);
      // L'écran est celui de la nouvelle adresse.
      expect(find.text('peloton-du-nord'), findsOneWidget);
      expect(find.byKey(keys.teamEditor.nameField), findsOneWidget);
      // L'ancienne et la nouvelle fiche ont été lues.
      expect(teams.teamReads, greaterThanOrEqualTo(readsBefore + 2));
    });

    testWidgets('pendant le changement d\'adresse : ni enregistrement, ni '
        'second changement, ni suppression', (WidgetTester tester) async {
      final _Teams teams = _Teams(_team())..slugGate = Completer<void>();
      await open(tester, teams);

      await changeSlug(tester, 'peloton-du-nord');
      // La requête est partie, sa réponse se fait attendre.
      expect(teams.slugCalls, 1);
      expect(teams.slugChanges, isEmpty);
      // La ligne le montre.
      expect(
        find.descendant(
          of: find.byKey(keys.teamEditor.slugRow),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      // « Enregistrer » n'envoie pas de PUT vers l'ancienne adresse.
      await tester.tap(find.byKey(keys.teamEditor.saveButton));
      await tester.pump(const Duration(milliseconds: 100));
      expect(teams.updateCalls, 0);

      // La ligne d'adresse, inactive, ne rouvre pas sa feuille : pas de second
      // changement.
      await tester.tap(
        find.byKey(keys.teamEditor.slugRow),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(keys.teamEditor.slugField), findsNothing);
      expect(teams.slugCalls, 1);

      // « Supprimer l'équipe » n'ouvre pas sa confirmation.
      await tester.ensureVisible(find.byKey(keys.teamEditor.deleteButton));
      await tester.tap(
        find.byKey(keys.teamEditor.deleteButton),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(teams.deleted, isEmpty);
      expect(find.byKey(keys.profile.confirmDestructiveButton), findsNothing);

      teams.slugGate!.complete();
      await settle(tester);
      expect(teams.slugChanges, <(String, String)>[
        ('n-peloton', 'peloton-du-nord'),
      ]);
      expect(teams.updateCalls, 0);
      expect(find.text('peloton-du-nord'), findsOneWidget);
    });

    testWidgets('un changement d\'adresse refusé : la ligne se rouvre', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team())
        ..slugGate = Completer<void>()
        ..failWith = _apiError(409, 'SLUG_TAKEN');
      await open(tester, teams);

      await changeSlug(tester, 'peloton-du-nord');
      teams.slugGate!.complete();
      await settle(tester);

      expect(find.byKey(keys.teamEditor.errorBanner), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(keys.teamEditor.slugRow),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      await tester.tap(find.byKey(keys.teamEditor.slugRow));
      await settle(tester);
      expect(find.byKey(keys.teamEditor.slugField), findsOneWidget);
    });

    testWidgets('un formulaire modifié : l\'abandon se confirme d\'abord', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team());
      await open(tester, teams);

      await tester.enterText(find.byKey(keys.teamEditor.nameField), 'Autre');
      await tester.pump();
      await tester.tap(find.byKey(keys.teamEditor.slugRow));
      await settle(tester);

      expect(find.text('Abandonner les modifications ?'), findsOneWidget);
      expect(find.byKey(keys.teamEditor.slugField), findsNothing);

      await confirm(tester);
      expect(find.byKey(keys.teamEditor.slugField), findsOneWidget);

      // L'adresse changée, l'écran repart de l'équipe telle qu'elle est : la
      // saisie abandonnée n'y est plus, et une nouvelle se protège de nouveau.
      await tester.enterText(
        find.byKey(keys.teamEditor.slugField),
        'peloton-du-nord',
      );
      await tester.tap(find.byKey(keys.teamEditor.slugSave));
      await settle(tester);
      expect(find.text('peloton-du-nord'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(keys.teamEditor.nameField))
            .controller!
            .text,
        'N-Peloton',
      );
      expect(teams.updateCalls, 0);

      await tester.enterText(find.byKey(keys.teamEditor.nameField), 'Encore');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(find.text('Abandonner les modifications ?'), findsOneWidget);
    });

    for (final (String code, String message) in <(String, String)>[
      ('SLUG_TAKEN', 'Cette URL personnalisée est déjà utilisée'),
      ('INVALID_SLUG', 'L\'URL personnalisée est invalide'),
    ]) {
      testWidgets('$code : le bandeau le dit, l\'adresse reste', (
        WidgetTester tester,
      ) async {
        final _Teams teams = _Teams(_team())..failWith = _apiError(409, code);
        await open(tester, teams);

        await changeSlug(tester, 'pris');

        expect(find.byKey(keys.teamEditor.errorBanner), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(find.text('n-peloton'), findsOneWidget);
      });
    }
  });

  group('supprimer', () {
    testWidgets('la suppression se confirme, puis mène à « Mes équipes »', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team());
      await open(tester, teams);

      await tester.tap(find.byKey(keys.teamEditor.deleteButton));
      await settle(tester);

      expect(find.text('Supprimer l\'équipe ?'), findsOneWidget);
      expect(
        find.textContaining('Voulez-vous vraiment supprimer N-Peloton ?'),
        findsOneWidget,
      );
      expect(teams.deleted, isEmpty);

      await confirm(tester);

      expect(teams.deleted, <String>['n-peloton']);
      expect(find.text('mes équipes'), findsOneWidget);
      expect(find.text('Équipe supprimée'), findsOneWidget);
    });

    testWidgets('annuler ne supprime rien', (WidgetTester tester) async {
      final _Teams teams = _Teams(_team());
      await open(tester, teams);

      await tester.tap(find.byKey(keys.teamEditor.deleteButton));
      await settle(tester);
      await tester.tap(find.text('Annuler'));
      await settle(tester);

      expect(teams.deleted, isEmpty);
      expect(find.byKey(keys.teamEditor.saveButton), findsOneWidget);
    });

    testWidgets('MIGRATED_TEAM : le bandeau le dit, l\'équipe reste', (
      WidgetTester tester,
    ) async {
      final _Teams teams = _Teams(_team())
        ..failWith = _apiError(400, 'MIGRATED_TEAM');
      await open(tester, teams);

      await tester.tap(find.byKey(keys.teamEditor.deleteButton));
      await settle(tester);
      await confirm(tester);

      expect(find.byKey(keys.teamEditor.errorBanner), findsOneWidget);
      expect(
        find.textContaining('Cette équipe est venue de biketeam'),
        findsOneWidget,
      );
      expect(find.byKey(keys.teamEditor.saveButton), findsOneWidget);
      expect(find.text('mes équipes'), findsNothing);
    });
  });

  testWidgets('« Webhook » ouvre sa feuille', (WidgetTester tester) async {
    await open(tester, _Teams(_team()));

    await tester.tap(find.byKey(keys.teamEditor.webhookRow));
    await settle(tester);

    expect(find.byKey(keys.teamWebhook.sheet), findsOneWidget);
  });
}
