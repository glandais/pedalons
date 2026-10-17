import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/data/ride_template_repository.dart';
import 'package:pedalons/features/rides/presentation/pages/ride_template_list_page.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'ride_template_fixtures.dart';

/// La liste des modèles de sortie (ledger `MOB-78`) : le refus pour qui
/// n'organise pas, les cartes et leur résumé, le menu et la suppression.
class _StubTemplates implements RideTemplateRepository {
  _StubTemplates(this.templates);

  final List<RideTemplateDto> templates;
  final List<String> deleted = <String>[];
  int listCalls = 0;

  @override
  Future<PageResult<RideTemplateDto>> list(
    String teamSlug, {
    String? search,
    required int page,
    required int size,
  }) async {
    listCalls++;
    return PageResult<RideTemplateDto>(
      items: List<RideTemplateDto>.of(templates),
      total: templates.length,
    );
  }

  @override
  Future<void> delete(String teamSlug, String templateSlug) async {
    deleted.add(templateSlug);
    templates.removeWhere((RideTemplateDto t) => t.slug == templateSlug);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubTeams implements TeamRepository {
  _StubTeams(this.role);

  final String? role;

  @override
  Future<TeamDetailDto> getTeam(String slug) async =>
      fixtureTemplateTeamDetail(role: role);

  @override
  Future<List<TeamDetailDto>> getMyTeams() async => role == null
      ? <TeamDetailDto>[]
      : <TeamDetailDto>[fixtureTemplateTeamDetail(role: role)];

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

  final String editPattern = PathVariants.rideTemplateEdit(
    ':teamSlug',
    ':templateSlug',
  )['fr']!;
  final String newPattern = PathVariants.rideTemplateNew(':teamSlug')['fr']!;

  Future<void> open(
    WidgetTester tester, {
    required _StubTemplates templates,
    String? role = 'ORGANIZER',
  }) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final GoRouter router = GoRouter(
      initialLocation: '/liste',
      routes: <RouteBase>[
        GoRoute(
          path: '/liste',
          builder: (BuildContext _, GoRouterState _) =>
              const RideTemplateListPage(teamSlug: 'n-peloton'),
        ),
        GoRoute(
          path: editPattern,
          builder: (BuildContext _, GoRouterState state) =>
              Text('édition ${state.pathParameters['templateSlug']}'),
        ),
        GoRoute(
          path: newPattern,
          builder: (BuildContext _, GoRouterState _) => const Text('création'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          rideTemplateRepositoryProvider.overrideWithValue(templates),
          teamRepositoryProvider.overrideWithValue(_StubTeams(role)),
        ],
        child: MaterialApp.router(
          theme: PedalonsTheme.build(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  List<RideTemplateDto> two() => <RideTemplateDto>[
    fixtureTemplate(),
    fixtureTemplate(
      id: 'tpl-2',
      slug: 'semaine',
      name: 'Sortie de semaine',
      status: 'DRAFT',
      nextNumber: null,
      groups: <RideTemplateGroupDto>[fixtureTemplateGroup()],
    ),
  ];

  testWidgets('un organisateur lit une carte par modèle, avec son résumé', (
    WidgetTester tester,
  ) async {
    await open(tester, templates: _StubTemplates(two()));

    expect(find.byKey(keys.rideTemplates.newButton), findsOneWidget);
    expect(find.byKey(keys.rideTemplates.card('dimanche')), findsOneWidget);
    expect(find.byKey(keys.rideTemplates.card('semaine')), findsOneWidget);
    expect(find.text('Sortie du dimanche'), findsOneWidget);
    expect(find.text('3 groupes · prochaine sortie #42'), findsOneWidget);
    expect(find.text('1 groupe · sans numéro'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(keys.rideTemplates.count)).data,
      '2 modèles',
    );
    // Le statut des sorties créées, en capitales : c'est le badge.
    expect(find.text('PUBLIÉ'), findsOneWidget);
    expect(find.text('BROUILLON'), findsOneWidget);
  });

  testWidgets('sans modèle, l\'état vide propose d\'en créer un', (
    WidgetTester tester,
  ) async {
    await open(tester, templates: _StubTemplates(<RideTemplateDto>[]));

    expect(find.byKey(keys.rideTemplates.empty), findsOneWidget);
    expect(find.text('Aucun modèle'), findsWidgets);
    expect(find.byKey(keys.rideTemplates.emptyNewButton), findsOneWidget);

    await tester.tap(find.byKey(keys.rideTemplates.emptyNewButton));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('création'), findsOneWidget);
  });

  testWidgets('un simple membre lit un refus, sans rien charger', (
    WidgetTester tester,
  ) async {
    final _StubTemplates templates = _StubTemplates(two());
    await open(tester, templates: templates, role: 'MEMBER');

    expect(find.byKey(keys.rideTemplates.forbidden), findsOneWidget);
    expect(find.byKey(keys.rideTemplates.newButton), findsNothing);
    expect(find.byKey(keys.rideTemplates.card('dimanche')), findsNothing);
    // Le serveur refuserait la lecture : on ne la demande même pas.
    expect(templates.listCalls, 0);
  });

  testWidgets('le ⋯ ouvre un menu à trois gestes', (WidgetTester tester) async {
    await open(tester, templates: _StubTemplates(two()));

    await tester.tap(find.byKey(keys.rideTemplates.moreButton('dimanche')));
    await tester.pumpAndSettle();

    expect(find.byKey(keys.rideTemplates.menuCreateRide), findsOneWidget);
    expect(find.byKey(keys.rideTemplates.menuEdit), findsOneWidget);
    expect(find.byKey(keys.rideTemplates.menuDelete), findsOneWidget);
    expect(find.text('Créer une sortie depuis ce modèle'), findsOneWidget);
    expect(find.text('Modifier le modèle'), findsOneWidget);
    expect(find.text('Supprimer le modèle'), findsOneWidget);
  });

  testWidgets('supprimer demande confirmation, puis recharge la liste', (
    WidgetTester tester,
  ) async {
    final _StubTemplates templates = _StubTemplates(two());
    await open(tester, templates: templates);

    await tester.tap(find.byKey(keys.rideTemplates.moreButton('dimanche')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(keys.rideTemplates.menuDelete));
    await tester.pumpAndSettle();

    // Rien n'est parti avant la confirmation.
    expect(templates.deleted, isEmpty);
    expect(
      find.textContaining(
        'Les sorties déjà créées depuis ce modèle ne changent pas.',
      ),
      findsOneWidget,
    );

    final int before = templates.listCalls;
    await tester.tap(find.byKey(keys.profile.confirmDestructiveButton));
    await tester.pumpAndSettle();

    expect(templates.deleted, <String>['dimanche']);
    expect(templates.listCalls, greaterThan(before));
    expect(find.byKey(keys.rideTemplates.card('dimanche')), findsNothing);
    expect(find.byKey(keys.rideTemplates.card('semaine')), findsOneWidget);
  });

  testWidgets('toucher une carte ouvre la modification', (
    WidgetTester tester,
  ) async {
    await open(tester, templates: _StubTemplates(two()));

    await tester.tap(find.byKey(keys.rideTemplates.card('semaine')));
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('édition semaine'), findsOneWidget);
  });
}
