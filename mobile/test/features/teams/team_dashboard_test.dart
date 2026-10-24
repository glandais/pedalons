import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/config/paths.generated.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/auth/data/auth_repository.dart';
import 'package:pedalons/features/auth/data/secure_storage.dart';
import 'package:pedalons/features/auth/domain/auth_state.dart';
import 'package:pedalons/features/auth/providers/auth_provider.dart';
import 'package:pedalons/features/teams/data/team_repository.dart';
import 'package:pedalons/features/teams/presentation/pages/team_dashboard_page.dart';
import 'package:pedalons/features/teams/presentation/pages/team_home_page.dart';
import 'package:pedalons/features/teams/presentation/widgets/team_sections.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'team_fixtures.dart';

/// Le tableau de bord d'équipe : un écran, trois rôles.
///
/// Ce qui se vérifie ici, c'est que **l'écran rend ce que l'API découpe** —
/// le bloc `organizer` n'existe que pour un organisateur ou un administrateur,
/// le bloc `admin` que pour un administrateur, une section `null` disparaît —
/// et que le tableau de bord est la section par défaut d'un membre, et d'un
/// membre seulement.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> renderBody(
    WidgetTester tester,
    TeamDashboardDto dashboard, {
    Brightness brightness = Brightness.light,
    Size size = const Size(1000, 6000),
    bool routed = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final Widget body = Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: TeamDashboardBody(dashboard: dashboard),
      ),
    );
    // Avec [routed], un routeur d'essai : les liens qui poussent une page de
    // l'app (`context.push`) trouvent où aller, et le test lit où.
    final GoRouter? router = routed
        ? GoRouter(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (BuildContext _, GoRouterState _) => body,
              ),
              GoRoute(
                path: PathVariants.rideTemplates(':teamSlug')['fr']!,
                builder: (BuildContext _, GoRouterState state) =>
                    Text('liste modèles ${state.pathParameters['teamSlug']}'),
              ),
            ],
          )
        : null;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authProvider.overrideWith((ref) => _StubAuthNotifier(ref)),
        ],
        child: router == null
            ? MaterialApp(theme: PedalonsTheme.build(brightness), home: body)
            : MaterialApp.router(
                theme: PedalonsTheme.build(brightness),
                routerConfig: router,
              ),
      ),
    );
    await settle(tester);
  }

  group('membre', () {
    testWidgets('voit ses sections, et rien de ce qui organise', (
      WidgetTester tester,
    ) async {
      await renderBody(tester, _dashboard(role: 'MEMBER'));

      expect(find.byKey(keys.teamDashboard.summary), findsOneWidget);
      expect(find.text('MEMBRE'), findsOneWidget);
      expect(find.text('S\'abonner au calendrier'), findsNothing);

      expect(find.byKey(keys.teamDashboard.myUpcoming), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.upcomingRides), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.latestPosts), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.newRoutes), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.latestAds), findsOneWidget);

      expect(find.byKey(keys.teamDashboard.todo), findsNothing);
      expect(find.byKey(keys.teamDashboard.templates), findsNothing);
      expect(find.byKey(keys.teamDashboard.admin), findsNothing);
      expect(find.byKey(keys.teamDashboard.createRideButton), findsNothing);
      expect(find.byKey(keys.teamDashboard.newPostButton), findsNothing);
      expect(
        find.byKey(keys.teamDashboard.rideEditButton('sortie-du-samedi')),
        findsNothing,
      );
    });

    testWidgets('le groupe rejoint porte son nom et son allure', (
      WidgetTester tester,
    ) async {
      await renderBody(tester, _dashboard(role: 'MEMBER'));

      expect(
        find.byKey(keys.teamDashboard.myUpcomingRow('sortie-du-samedi')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(keys.teamDashboard.myUpcomingRow('sortie-du-samedi')),
          matching: find.textContaining('Groupe B ·'),
        ),
        findsOneWidget,
      );
      expect(find.text('Place de la Croix-Rousse'), findsWidgets);
    });

    testWidgets('chaque groupe dit son remplissage, et « Complet » à plein', (
      WidgetTester tester,
    ) async {
      await renderBody(tester, _dashboard(role: 'MEMBER'));

      expect(find.text('11 / 16'), findsOneWidget);
      expect(find.text('COMPLET'), findsOneWidget);
      // Une sortie que rien ne route le dit.
      expect(find.text('Aucun parcours associé'), findsOneWidget);
    });

    testWidgets('un lecteur d\'écran entend la ligne d\'un groupe d\'un seul '
        'tenant : son nom et son remplissage en toutes lettres', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await renderBody(tester, _dashboard(role: 'MEMBER'));

      expect(
        find.bySemanticsLabel(RegExp(r'^.+, 11 inscrits sur 16$')),
        findsOneWidget,
      );
      // Plus de « 11 / 16 » lu seul, sans le groupe.
      expect(find.bySemanticsLabel('11 / 16'), findsNothing);
      handle.dispose();
    });

    testWidgets('une annonce sans prix se lit « Prix à négocier », et son '
        'lieu est un secteur en texte', (WidgetTester tester) async {
      await renderBody(tester, _dashboard(role: 'MEMBER'));

      expect(find.text('Prix à négocier'), findsOneWidget);
      expect(find.text('Secteur Caluire-et-Cuire'), findsOneWidget);
    });

    testWidgets('une section dont le module est désactivé disparaît', (
      WidgetTester tester,
    ) async {
      await renderBody(
        tester,
        _dashboard(role: 'MEMBER').copyWith(latestAds: null, newRoutes: null),
      );

      expect(find.byKey(keys.teamDashboard.latestAds), findsNothing);
      expect(find.byKey(keys.teamDashboard.newRoutes), findsNothing);
      expect(find.byKey(keys.teamDashboard.upcomingRides), findsOneWidget);
    });
  });

  group('organisateur', () {
    testWidgets('ajoute « À traiter », les actions de tête et les modèles', (
      WidgetTester tester,
    ) async {
      await renderBody(tester, _dashboard(role: 'ORGANIZER'));

      expect(find.text('ORGANISATEUR'), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.todo), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.todoDrafts), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.todoWithoutRoute), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.todoFullGroup), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.todoReports), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.createRideButton), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.newPostButton), findsOneWidget);
      expect(
        find.byKey(keys.teamDashboard.rideEditButton('sortie-du-samedi')),
        findsOneWidget,
      );
      expect(find.byKey(keys.teamDashboard.templates), findsOneWidget);
      expect(find.text('Sortie du samedi type'), findsOneWidget);
      // La section ouvre la liste des modèles dans l'app (MOB-78), et la ligne
      // dit le nombre de groupes et le prochain numéro.
      expect(
        find.descendant(
          of: find.byKey(keys.teamDashboard.templatesManageButton),
          matching: find.text('Gérer les modèles'),
        ),
        findsOneWidget,
      );
      expect(find.text('3 groupes · prochaine #42'), findsOneWidget);

      expect(find.byKey(keys.teamDashboard.admin), findsNothing);
    });

    testWidgets(
      '« Gérer les modèles » ouvre la liste dans l\'app, pas le site',
      (WidgetTester tester) async {
        setCurrentLocale('fr');
        await renderBody(tester, _dashboard(role: 'ORGANIZER'), routed: true);

        await tester.ensureVisible(
          find.byKey(keys.teamDashboard.templatesManageButton),
        );
        await tester.tap(find.byKey(keys.teamDashboard.templatesManageButton));
        await settle(tester);

        expect(find.text('liste modèles n-peloton'), findsOneWidget);
        expect(find.byKey(keys.teamDashboard.templates), findsNothing);
      },
    );

    testWidgets('le dernier signalement nomme sa cible et sa raison', (
      WidgetTester tester,
    ) async {
      await renderBody(tester, _dashboard(role: 'ORGANIZER'));

      expect(
        find.textContaining('Commentaire signalé — Spam ou publicité'),
        findsOneWidget,
      );
      expect(find.text('Examiner'), findsOneWidget);
    });

    testWidgets('une catégorie sans attente n\'a pas de tuile', (
      WidgetTester tester,
    ) async {
      final TeamDashboardDto d = _dashboard(role: 'ORGANIZER');
      await renderBody(
        tester,
        d.copyWith(
          organizer: d.organizer!.copyWith(
            drafts: _list(const <PublicationDto>[]),
            reports: const TeamDashboardReportsDto(openCount: 0),
          ),
        ),
      );

      expect(find.byKey(keys.teamDashboard.todo), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.todoDrafts), findsNothing);
      expect(find.byKey(keys.teamDashboard.todoReports), findsNothing);
      expect(find.byKey(keys.teamDashboard.todoWithoutRoute), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.todoFullGroup), findsOneWidget);
    });

    testWidgets('rien en attente nulle part : pas de « À traiter »', (
      WidgetTester tester,
    ) async {
      final TeamDashboardDto d = _dashboard(role: 'ORGANIZER');
      await renderBody(
        tester,
        d.copyWith(
          organizer: d.organizer!.copyWith(
            drafts: _list(const <PublicationDto>[]),
            ridesWithoutRoute: _list(const <PublicationDto>[]),
            ridesWithFullGroup: _list(const <PublicationDto>[]),
            reports: const TeamDashboardReportsDto(openCount: 0),
          ),
        ),
      );

      expect(find.byKey(keys.teamDashboard.todo), findsNothing);
      expect(find.text('À traiter'), findsNothing);
      expect(find.byKey(keys.teamDashboard.createRideButton), findsOneWidget);
    });

    testWidgets('sans module de sorties, ni tuiles de sorties ni modèles', (
      WidgetTester tester,
    ) async {
      final TeamDashboardDto d = _dashboard(role: 'ORGANIZER');
      await renderBody(
        tester,
        d.copyWith(
          team: d.team.copyWith(enableRides: false),
          upcomingRides: null,
          organizer: d.organizer!.copyWith(
            ridesWithoutRoute: null,
            ridesWithFullGroup: null,
            rideTemplates: null,
          ),
        ),
      );

      expect(find.byKey(keys.teamDashboard.todoDrafts), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.todoReports), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.todoWithoutRoute), findsNothing);
      expect(find.byKey(keys.teamDashboard.todoFullGroup), findsNothing);
      expect(find.byKey(keys.teamDashboard.templates), findsNothing);
      expect(find.byKey(keys.teamDashboard.createRideButton), findsNothing);
    });
  });

  group('administrateur', () {
    testWidgets('ajoute le panneau d\'administration', (
      WidgetTester tester,
    ) async {
      await renderBody(tester, _dashboard(role: 'ADMIN'));

      expect(find.text('ADMINISTRATEUR'), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.todo), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.admin), findsOneWidget);
      expect(find.text('3 administrateurs'), findsOneWidget);
      expect(find.text('9 organisateurs'), findsOneWidget);
      expect(find.text('116 membres'), findsOneWidget);
      expect(find.text('Léa Martin'), findsOneWidget);
      expect(find.text('Webhook Discord'), findsOneWidget);
      expect(find.text('ACTIF'), findsOneWidget);
      expect(find.text('Inviter'), findsOneWidget);
      expect(find.text('Gérer les membres'), findsOneWidget);
    });

    testWidgets('sans ajout de membres permis, pas de bouton « Inviter »', (
      WidgetTester tester,
    ) async {
      final TeamDashboardDto d = _dashboard(role: 'ADMIN');
      await renderBody(
        tester,
        d.copyWith(team: d.team.copyWith(addMemberAllowed: false)),
      );

      expect(find.text('Inviter'), findsNothing);
      expect(find.text('Gérer les membres'), findsOneWidget);
    });

    testWidgets('se rend en mode sombre, à la largeur d\'un téléphone', (
      WidgetTester tester,
    ) async {
      await renderBody(
        tester,
        _dashboard(role: 'ADMIN'),
        brightness: Brightness.dark,
        size: const Size(360, 8000),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(keys.teamDashboard.admin), findsOneWidget);
    });
  });

  group('visiteur (API-86)', () {
    testWidgets('la partie publique, sans rôle ni abonnement au calendrier', (
      WidgetTester tester,
    ) async {
      final TeamDashboardDto member = _dashboard(role: 'MEMBER');
      await renderBody(
        tester,
        member.copyWith(
          team: fixtureTeam(memberCount: 128),
          role: null,
          myUpcoming: null,
          latestAds: null,
        ),
      );

      expect(find.byKey(keys.teamDashboard.summary), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.myUpcoming), findsNothing);
      expect(find.byKey(keys.teamDashboard.upcomingRides), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.latestPosts), findsOneWidget);
      expect(find.byKey(keys.teamDashboard.newRoutes), findsOneWidget);
      expect(find.text('MEMBRE'), findsNothing);
    });
  });

  group('largeur d\'un téléphone', () {
    for (final String role in <String>['MEMBER', 'ORGANIZER', 'ADMIN']) {
      testWidgets('$role : rien ne déborde', (WidgetTester tester) async {
        await renderBody(
          tester,
          _dashboard(role: role),
          size: const Size(320, 9000),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('sections', () {
    test('le tableau de bord pour tout le monde (API-86)', () {
      expect(
        resolveTeamRootSection(const <String, String>{}).kind,
        TeamSectionKind.dashboard,
      );
    });

    test('les puces suivent l\'ordre du site, avec les icônes de la charte '
        '(BRAND-6)', () {
      final List<TeamSection> sections = buildTeamSections(
        fixtureTeam(role: 'ADMIN'),
      );

      expect(sections.map((TeamSection s) => s.kind), <TeamSectionKind>[
        TeamSectionKind.dashboard,
        TeamSectionKind.agenda,
        TeamSectionKind.posts,
        TeamSectionKind.routes,
        TeamSectionKind.ads,
        TeamSectionKind.members,
        TeamSectionKind.about,
      ]);
      expect(sections.map((TeamSection s) => s.icon), <IconData>[
        PdlIcons.dashboard,
        PdlIcons.agenda,
        PdlIcons.post,
        PdlIcons.route,
        PdlIcons.ad,
        PdlIcons.people,
        PdlIcons.info,
      ]);
      // Le tableau de bord à l'adresse de l'équipe, sans paramètre.
      expect(sections.first.paths.values, everyElement(isNot(contains('?'))));
    });

    test('un visiteur a le tableau de bord, l\'Agenda et les Publications, '
        'pas les Annonces', () {
      final List<TeamSection> sections = buildTeamSections(fixtureTeam());

      expect(sections.map((TeamSection s) => s.kind), <TeamSectionKind>[
        TeamSectionKind.dashboard,
        TeamSectionKind.agenda,
        TeamSectionKind.posts,
        TeamSectionKind.routes,
        TeamSectionKind.about,
      ]);
    });

    test('un administrateur garde la puce « Membres »', () {
      final List<TeamSection> sections = buildTeamSections(
        fixtureTeam(role: 'ADMIN'),
      );
      expect(
        sections.map((TeamSection s) => s.kind),
        contains(TeamSectionKind.members),
      );
    });

    testWidgets('la page d\'équipe rend le tableau de bord à un membre', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final _StubTeamRepository repository = _StubTeamRepository(
        fixtureTeam(role: 'MEMBER'),
        _dashboard(role: 'MEMBER'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authProvider.overrideWith((ref) => _StubAuthNotifier(ref)),
            teamRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: PedalonsTheme.build(Brightness.light),
            home: const TeamHomePage(
              teamSlug: 'n-peloton',
              section: TeamSectionKind.dashboard,
            ),
          ),
        ),
      );
      await settle(tester);

      expect(find.byType(TeamDashboardPage), findsOneWidget);
      expect(find.byType(TeamDashboardBody), findsOneWidget);
      expect(find.text('Tableau de bord'), findsOneWidget);
      expect(repository.dashboardReads, 1);
    });
  });
}

// ─────────────────────────────────────────────────────────────── jeux de données

const TeamPublicationDto _team = TeamPublicationDto(
  id: 't1',
  slug: 'n-peloton',
  name: 'N-Peloton',
  visibility: 'PUBLIC',
);

RideGroupSummaryDto _group({
  required String id,
  required String name,
  required int count,
  int? max,
  double? speed,
  String? routeSlug,
  int sortOrder = 0,
}) => RideGroupSummaryDto(
  startAt: '2026-10-11T06:00:00Z',
  id: id,
  name: name,
  countParticipants: count,
  maxParticipants: max,
  full: max != null && count >= max,
  sortOrder: sortOrder,
  averageSpeed: speed,
  routeSlug: routeSlug,
);

PublicationDto _ride({
  required String slug,
  required String name,
  List<RideGroupSummaryDto> groups = const <RideGroupSummaryDto>[],
  bool registered = false,
  RideGroupDto? registeredGroup,
  String? routeSlug,
  String status = 'PUBLISHED',
  double? distance,
}) => PublicationDto.ride(
  timezone: 'Europe/Paris',
  full: false,
  id: 'ride-$slug',
  slug: slug,
  name: name,
  media: kEmptyMedia,
  groupSummaries: groups,
  dateTime: '2026-10-10T06:30:00Z',
  endDateTime: '2026-10-10T09:30:00Z',
  status: status,
  finished: false,
  visibility: 'TEAM',
  team: _team,
  participantCount: 20,
  groupCount: groups.length,
  groups: const <RideGroupDto>[],
  tags: const <TagDto>[],
  topParticipants: const <PublicUserDto>[],
  deleted: false,
  registered: registered,
  registeredGroup: registeredGroup,
  registeredGroupId: registeredGroup?.id,
  routeSlug: routeSlug,
  distance: distance,
  elevationGain: distance == null ? null : 980,
  surfaceType: 'ROAD',
  startPlace: const PlaceDetailDto(
    id: 'p1',
    name: 'Place de la Croix-Rousse',
    startPlace: true,
    endPlace: false,
  ),
);

PublicationListResponse _list(List<PublicationDto> rows, {int? total}) =>
    PublicationListResponse(
      publications: rows,
      total: total ?? rows.length,
      page: 0,
      size: 3,
    );

TeamDashboardDto _dashboard({required String role}) {
  final bool organizer = role != 'MEMBER';
  final bool admin = role == 'ADMIN';

  final PublicationDto saturday = _ride(
    slug: 'sortie-du-samedi',
    name: 'Sortie du samedi',
    routeSlug: 'monts-d-or',
    distance: 72000,
    registered: true,
    registeredGroup: const RideGroupDto(
      startAt: '2026-10-11T06:00:00Z',
      id: 'g-b',
      name: 'Groupe B',
      countParticipants: 11,
      participants: <PublicUserDto>[],
      sortOrder: 1,
      registered: true,
      full: false,
      averageSpeed: 26,
    ),
    groups: <RideGroupSummaryDto>[
      _group(id: 'g-a', name: 'Groupe A', count: 14, max: 14, speed: 30),
      _group(
        id: 'g-b',
        name: 'Groupe B',
        count: 11,
        max: 16,
        speed: 26,
        sortOrder: 1,
      ),
    ],
  );
  final PublicationDto night = _ride(
    slug: 'sortie-de-nuit',
    name: 'Sortie de nuit',
    groups: <RideGroupSummaryDto>[
      _group(id: 'g-u', name: 'Groupe unique', count: 7, speed: 25),
    ],
  );

  return TeamDashboardDto(
    team: fixtureTeam(role: role, memberCount: 128).copyWith(
      memberCountByRole: admin
          ? const MemberCountByRoleDto(admins: 3, organizers: 9, members: 116)
          : null,
    ),
    role: role,
    myUpcoming: _list(<PublicationDto>[saturday]),
    upcomingRides: _list(<PublicationDto>[saturday, night], total: 5),
    latestPosts: _list(<PublicationDto>[
      const PublicationDto.post(
        timezone: 'Europe/Paris',
        team: _team,
        id: 'post-1',
        slug: 'bilan',
        name: 'Bilan de la saison',
        media: kEmptyMedia,
        dateTime: '2026-10-02T10:00:00Z',
        status: 'PUBLISHED',
        visibility: 'TEAM',
        deleted: false,
        signedAsTeam: false,
        tags: <TagDto>[],
        excerpt: 'L\'assemblée générale aura lieu le 6 novembre.',
        commentCount: 4,
        createdBy: PublicUserDto(id: 'u1', displayName: 'Martine L.'),
      ),
    ]),
    newRoutes: RouteListResponse(
      routes: <RouteDto>[
        RouteDto(
          elevationState: 'HD',
          id: 'r1',
          slug: 'mont-thou',
          team: _team,
          name: 'Boucle du mont Thou',
          media: kEmptyMedia,
          distance: 64000,
          elevationGain: 1120,
          elevationLoss: 1120,
          surfaceType: 'ROAD',
          visibility: 'TEAM',
          createdAt: '2026-10-01T10:00:00Z',
          deleted: false,
          tags: const <TagDto>[],
        ),
      ],
      total: 1,
      page: 0,
      size: 3,
    ),
    latestAds: AdListResponse(
      ads: <AdDto>[
        _ad(
          slug: 'roues',
          name: 'Paire de roues',
          price: 650,
          sector: 'Caluire-et-Cuire',
        ),
        _ad(
          slug: 'porte-velos',
          name: 'Porte-vélos',
          adType: 'WANTED',
          sector: 'Lyon 9e',
        ),
      ],
      total: 2,
      page: 0,
      size: 3,
    ),
    organizer: organizer
        ? TeamDashboardOrganizerDto(
            drafts: _list(<PublicationDto>[
              _ride(
                slug: 'brouillon',
                name: 'Sortie découverte',
                status: 'DRAFT',
              ),
            ]),
            ridesWithoutRoute: _list(<PublicationDto>[night]),
            ridesWithFullGroup: _list(<PublicationDto>[saturday]),
            reports: const TeamDashboardReportsDto(
              openCount: 1,
              latestReason: 'SPAM',
              latestTargetType: 'COMMENT',
              latestExcerpt: 'Achetez ici',
              latestReportedAt: '2026-10-04T10:00:00Z',
            ),
            rideTemplates: RideTemplateListResponse(
              templates: <RideTemplateDto>[
                RideTemplateDto(
                  team: _team,
                  id: 'tpl-1',
                  slug: 'samedi',
                  name: 'Sortie du samedi type',
                  markdown: '',
                  visibility: 'TEAM',
                  status: 'PUBLISHED',
                  createdAt: '2026-01-01T00:00:00Z',
                  updatedAt: '2026-01-01T00:00:00Z',
                  groupCount: 3,
                  groups: const <RideTemplateGroupDto>[],
                  tags: const <TagDto>[],
                  nextNumber: 42,
                ),
              ],
              total: 1,
              page: 0,
              size: 5,
            ),
          )
        : null,
    admin: admin
        ? TeamDashboardAdminDto(
            newestMembers: MemberListResponse(
              members: <MemberDto>[
                const MemberDto(
                  team: _team,
                  id: 'm1',
                  user: PublicUserDto(id: 'u9', displayName: 'Léa Martin'),
                  role: 'MEMBER',
                  joinedAt: '2026-10-04T10:00:00Z',
                ),
              ],
              total: 128,
              page: 0,
              size: 3,
            ),
            webhook: const TeamWebhookDto(
              configured: true,
              enabled: true,
              kind: 'DISCORD',
              lastStatus: 'SENT',
              lastAttemptAt: '2026-10-02T10:00:00Z',
            ),
          )
        : null,
  );
}

AdDto _ad({
  required String slug,
  required String name,
  required String sector,
  String adType = 'SALE',
  num? price,
}) => AdDto(
  team: _team,
  id: 'ad-$slug',
  slug: slug,
  name: name,
  media: kEmptyMedia,
  images: const <String>[],
  status: 'PUBLISHED',
  visibility: 'TEAM',
  adType: adType,
  createdAt: '2026-10-01T10:00:00Z',
  updatedAt: '2026-10-01T10:00:00Z',
  createdById: 'u1',
  createdByDisplayName: 'Jeanne',
  deleted: false,
  tags: const <TagDto>[],
  price: price,
  locationDescription: sector,
);

// ───────────────────────────────────────────────────────────────────── doublures

class _StubTeamRepository implements TeamRepository {
  _StubTeamRepository(this.team, this.dashboard);

  final TeamDetailDto team;
  final TeamDashboardDto dashboard;
  int dashboardReads = 0;

  @override
  Future<TeamDetailDto> getTeam(String slug) async => team;

  @override
  Future<List<TeamDetailDto>> getMyTeams() async =>
      team.role == null ? const <TeamDetailDto>[] : <TeamDetailDto>[team];

  @override
  Future<TeamDashboardDto> getDashboard(String slug) async {
    dashboardReads++;
    return dashboard;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
    state = const AuthState(isInitialized: true);
  }
}
