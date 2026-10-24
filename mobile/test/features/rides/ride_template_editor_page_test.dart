import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/data/ride_template_repository.dart';
import 'package:pedalons/features/rides/presentation/pages/ride_template_editor_page.dart';
import 'package:pedalons/features/tags/providers/team_tags_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'ride_template_fixtures.dart';

/// L'éditeur d'un modèle de sortie (ledger `MOB-78`) : le refus pour qui
/// n'organise pas, et surtout **ce qui part** — la requête que le serveur
/// appliquera champ par champ, absents compris.
class _StubTemplates implements RideTemplateRepository {
  _StubTemplates(this.template);

  final RideTemplateDto template;
  final List<RideTemplateRequest> created = <RideTemplateRequest>[];
  final List<RideTemplateRequest> updated = <RideTemplateRequest>[];
  int getCalls = 0;

  @override
  Future<RideTemplateDto> get(String teamSlug, String templateSlug) async {
    getCalls++;
    return template;
  }

  @override
  Future<RideTemplateDto> create(
    String teamSlug,
    RideTemplateRequest request,
  ) async {
    created.add(request);
    return template;
  }

  @override
  Future<RideTemplateDto> update(
    String teamSlug,
    String templateSlug,
    RideTemplateRequest request,
  ) async {
    updated.add(request);
    return template;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubTeams implements TeamRepository {
  _StubTeams(this.role, this.visibility);

  final String? role;
  final String visibility;

  TeamDetailDto get _team =>
      fixtureTemplateTeamDetail(role: role, visibility: visibility);

  @override
  Future<TeamDetailDto> getTeam(String slug) async => _team;

  @override
  Future<List<TeamDetailDto>> getMyTeams() async =>
      role == null ? <TeamDetailDto>[] : <TeamDetailDto>[_team];

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

  /// Ouvre l'éditeur **au-dessus** d'une « liste » : l'enregistrement y revient
  /// par `pop`.
  Future<void> open(
    WidgetTester tester, {
    required _StubTemplates templates,
    String? role = 'ORGANIZER',
    String visibility = 'PUBLIC',
    String? templateSlug,
  }) async {
    // Un écran haut : le formulaire est long, et seul ce qui est construit
    // se trouve.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/liste',
      routes: <RouteBase>[
        GoRoute(
          path: '/liste',
          builder: (BuildContext _, GoRouterState _) => const Text('liste'),
        ),
        GoRoute(
          path: '/editor',
          builder: (BuildContext _, GoRouterState _) => RideTemplateEditorPage(
            teamSlug: 'n-peloton',
            templateSlug: templateSlug,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          rideTemplateRepositoryProvider.overrideWithValue(templates),
          teamRepositoryProvider.overrideWithValue(
            _StubTeams(role, visibility),
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
    await tester.pump();
    unawaited(router.push('/editor'));
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('un simple membre lit un refus, pas un formulaire', (
    WidgetTester tester,
  ) async {
    final _StubTemplates templates = _StubTemplates(fixtureTemplate());
    await open(tester, templates: templates, role: 'MEMBER');

    expect(find.byKey(keys.rideTemplates.forbidden), findsOneWidget);
    expect(find.byKey(keys.rideTemplateEditor.saveButton), findsNothing);
  });

  testWidgets('un membre ne lit pas le modèle : le refus passe avant', (
    WidgetTester tester,
  ) async {
    final _StubTemplates templates = _StubTemplates(fixtureTemplate());
    await open(
      tester,
      templates: templates,
      role: 'MEMBER',
      templateSlug: 'dimanche',
    );

    expect(find.byKey(keys.rideTemplates.forbidden), findsOneWidget);
    expect(find.byKey(keys.rideTemplates.loadError), findsNothing);
    expect(templates.getCalls, 0);
  });

  testWidgets('créer envoie un modèle publié d\'un groupe, puis revient à la '
      'liste', (WidgetTester tester) async {
    final _StubTemplates templates = _StubTemplates(fixtureTemplate());
    await open(tester, templates: templates);

    expect(find.text('Nouveau modèle'), findsWidgets);
    await tester.enterText(
      find.byKey(keys.rideTemplateEditor.nameField),
      'Sortie du dimanche',
    );
    await tester.enterText(
      find.byKey(keys.rideTemplateEditor.nextNumberField),
      '42',
    );
    await tester.tap(find.byKey(keys.rideTemplateEditor.saveButton));
    await settle(tester);

    final RideTemplateRequest request = templates.created.single;
    expect(request.name, 'Sortie du dimanche');
    expect(request.status, 'PUBLISHED');
    expect(request.visibility, 'PUBLIC');
    expect(request.nextNumber, 42);
    expect(request.tagIds, isEmpty);
    expect(request.groups.single.name, 'Groupe 1');
    expect(request.groups.single.id, isNull);
    expect(templates.updated, isEmpty);
    // On revient à la liste, restée dessous.
    expect(find.byKey(keys.rideTemplateEditor.saveButton), findsNothing);
    expect(find.text('liste'), findsOneWidget);
  });

  testWidgets('un nom vide bloque l\'envoi et le dit', (
    WidgetTester tester,
  ) async {
    final _StubTemplates templates = _StubTemplates(fixtureTemplate());
    await open(tester, templates: templates);

    await tester.tap(find.byKey(keys.rideTemplateEditor.saveButton));
    await tester.pump();

    expect(templates.created, isEmpty);
    expect(find.byKey(keys.rideTemplateEditor.errorBanner), findsOneWidget);
    expect(
      find.text('Donnez un nom au modèle (200 caractères au plus)'),
      findsOneWidget,
    );
  });

  testWidgets('modifier renvoie les groupes avec leur id et le numéro', (
    WidgetTester tester,
  ) async {
    final _StubTemplates templates = _StubTemplates(
      fixtureTemplate(
        nextNumber: 7,
        groups: <RideTemplateGroupDto>[
          fixtureTemplateGroup(id: 'tg1', name: 'Rapides', maxParticipants: 12),
          fixtureTemplateGroup(id: 'tg2', name: 'Tranquilles', sortOrder: 1),
        ],
      ),
    );
    await open(tester, templates: templates, templateSlug: 'dimanche');

    expect(find.text('Modifier le modèle'), findsWidgets);
    await tester.enterText(
      find.byKey(keys.rideTemplateEditor.nameField),
      'Nouveau nom',
    );
    await tester.tap(find.byKey(keys.rideTemplateEditor.saveButton));
    await settle(tester);

    final RideTemplateRequest request = templates.updated.single;
    expect(request.name, 'Nouveau nom');
    expect(request.nextNumber, 7);
    expect(request.groups.map((RideTemplateGroupRequest g) => g.id), <String?>[
      'tg1',
      'tg2',
    ]);
    expect(request.groups.first.maxParticipants, 12);
    expect(templates.created, isEmpty);
  });

  testWidgets('un modèle n\'a ni meneur, ni parcours, ni image', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      templates: _StubTemplates(fixtureTemplate()),
      templateSlug: 'dimanche',
    );

    expect(find.byKey(keys.rideTemplateEditor.groupName(0)), findsOneWidget);
    expect(find.byKey(keys.rideEditor.groupLeader(0)), findsNothing);
    expect(find.byKey(keys.rideEditor.groupRoute(0)), findsNothing);
    expect(
      find.text(
        'Le ou la capitaine et le parcours se choisissent sur chaque sortie.',
      ),
      findsOneWidget,
    );
    // La barre d'outils du markdown est là, sans son bouton image.
    expect(find.byTooltip('Gras'), findsOneWidget);
    expect(find.byTooltip('Insérer une image'), findsNothing);
  });

  testWidgets('une équipe privée n\'offre pas de visibilité', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      templates: _StubTemplates(fixtureTemplate()),
      visibility: 'TEAM',
    );

    expect(find.byKey(keys.rideTemplateEditor.visibility), findsNothing);
    expect(find.byKey(keys.rideTemplateEditor.status), findsOneWidget);
  });

  testWidgets('une équipe publique offre la visibilité des sorties créées', (
    WidgetTester tester,
  ) async {
    await open(tester, templates: _StubTemplates(fixtureTemplate()));

    expect(find.byKey(keys.rideTemplateEditor.visibility), findsOneWidget);
  });

  testWidgets('vider le numéro envoie null, pas zéro', (
    WidgetTester tester,
  ) async {
    final _StubTemplates templates = _StubTemplates(fixtureTemplate());
    await open(tester, templates: templates, templateSlug: 'dimanche');

    await tester.enterText(
      find.byKey(keys.rideTemplateEditor.nextNumberField),
      '',
    );
    await tester.tap(find.byKey(keys.rideTemplateEditor.saveButton));
    await settle(tester);

    final RideTemplateRequest request = templates.updated.single;
    expect(request.nextNumber, isNull);
    expect(request.toJson().containsKey('nextNumber'), isTrue);
  });
}
