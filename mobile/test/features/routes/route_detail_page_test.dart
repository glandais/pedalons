import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/comments/data/comment_repository.dart';
import 'package:pedalons/features/comments/presentation/widgets/comment_thread.dart';
import 'package:pedalons/features/routes/presentation/pages/route_detail_page.dart';
import 'package:pedalons/features/routes/presentation/widgets/gps_button.dart';
import 'package:pedalons/features/routes/presentation/widgets/route_section.dart';
import 'package:pedalons/features/routes/providers/route_detail_provider.dart';
import 'package:pedalons/keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/localization.dart';
import 'route_fixtures.dart';

/// La fiche parcours en page qui défile (ledger `MOB-134`, lot 10, maquette
/// `parcours-mobile-cible`, KIT §8) : l'ordre des sections, un seul bouton
/// « GPS », plus d'exports séparés ni de feuille à crans, les commentaires.
const RouteKey _key = RouteKey(
  teamSlug: 'n-peloton',
  routeSlug: 'col-de-la-croix',
);

const AssetDto _gpx = AssetDto(
  id: 'a-gpx',
  fileName: 'col.gpx',
  contentType: 'application/gpx+xml',
  url: '/api/download/public/col.gpx',
);

TrackDto _track() => TrackDto(
  line: GeoJsonLineString(
    type: GeoJsonLineStringTypeType.lineString,
    coordinates: <List<double>>[
      for (int i = 0; i <= 50; i++)
        <double>[5, 45 + i * 1000 / 111195, 100.0 + (i % 10) * 20, i * 1000.0],
    ],
  ),
  climbs: const <ClimbDto>[
    ClimbDto(
      startDistance: 10000,
      endDistance: 14000,
      elevationGain: 214,
      averageGradient: 5.1,
      maxGradient: 8.4,
      category: 'CAT3',
      parts: <ClimbPartDto>[],
      name: 'Roc\'h Trévezel',
    ),
  ],
);

RouteDetailDto _route({int? commentCount = 2, String markdown = 'Boucle.'}) =>
    fixtureRouteDetail().copyWith(
      createdAt: '2026-11-03T10:00:00Z',
      commentCount: commentCount,
      media: MediaDto(
        markdown: markdown,
        assets: const AssetsDto(
          images: <AssetDto>[],
          attachments: <AssetDto>[],
          gpx: _gpx,
        ),
      ),
      tracks: <TrackDto>[_track()],
      waypoints: <WaypointDto>[
        fixtureWaypoint(id: 'w1', type: 'WATER', distance: 400),
        fixtureWaypoint(id: 'w2', type: 'SUPPLY', distance: 41000),
      ],
      tags: const <TagDto>[],
    );

const RouteUsageDto _usage = RouteUsageDto(
  timezone: 'Europe/Paris',
  type: 'RIDE',
  slug: 'boucle',
  name: 'Boucle des Monts d\'Arrée',
  dateTime: '2036-08-01T12:00:00Z',
  teamSlug: 'n-peloton',
  referencedDirectly: true,
  viaChildNames: <String>[],
);

/// Un fil vide : seule compte ici la cible demandée.
class _StubCommentRepository implements CommentRepository {
  final List<CommentTarget> targets = <CommentTarget>[];

  @override
  Future<CommentListResponse> list(
    CommentTarget target, {
    int page = 0,
    int size = 20,
    String? parentId,
    SortDirection? sort,
  }) async {
    targets.add(target);
    return CommentListResponse(
      items: const <CommentDto>[],
      total: 0,
      itemTotal: 0,
      page: page,
      size: size,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadTestTranslations);

  Future<_StubCommentRepository> open(
    WidgetTester tester,
    RouteDetailDto route,
  ) async {
    // Une page assez haute pour que ce qui est sous le pli soit construit :
    // un `CustomScrollView` ne livre pas aux `find` ce qu'il n'affiche pas.
    tester.view.physicalSize = const Size(402 * 3, 5000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final _StubCommentRepository comments = _StubCommentRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          commentRepositoryProvider.overrideWithValue(comments),
          routeDetailProvider(_key).overrideWith((Ref ref) async => route),
          routeUsagesProvider(_key)
              .overrideWith((Ref ref) async => const <RouteUsageDto>[_usage]),
        ],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: const RouteDetailPage(
            teamSlug: 'n-peloton',
            routeSlug: 'col-de-la-croix',
          ),
        ),
      ),
    );
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    return comments;
  }

  void expectOrder(WidgetTester tester, List<Key> order) {
    final List<double> tops = <double>[
      for (final Key k in order) tester.getTopLeft(find.byKey(k)).dy,
    ];
    for (int i = 1; i < tops.length; i++) {
      expect(
        tops[i],
        greaterThan(tops[i - 1]),
        reason: '${order[i]} doit suivre ${order[i - 1]}',
      );
    }
  }

  Finder inTiles(String text) => find.descendant(
    of: find.byKey(keys.routeDetail.statTiles),
    matching: find.text(text),
  );

  testWidgets('parcours-mobile-cible', (WidgetTester tester) async {
    final _StubCommentRepository comments = await open(tester, _route());

    expectOrder(tester, <Key>[
      keys.routeDetail.title,
      keys.routeDetail.statTiles,
      keys.routeDetail.routeSection,
      keys.routeDetail.descriptionSection,
      keys.routeDetail.waypointsSection,
      keys.routeDetail.climbsSection,
      keys.routeDetail.usagesSection,
      keys.routeDetail.informationSection,
      keys.routeDetail.commentsSection,
    ]);

    // Dans la section Parcours : la carte, le profil, puis « GPS ».
    expectOrder(tester, <Key>[
      keys.routeDetail.map,
      keys.routeDetail.elevationProfile,
      keys.routeDetail.gps,
    ]);
    expect(
      find.descendant(
        of: find.byKey(keys.routeDetail.routeSection),
        matching: find.byKey(keys.routeDetail.gps),
      ),
      findsOneWidget,
    );
    // Un seul bouton « GPS », plus de GPX / FIT / Envoyer séparés.
    expect(find.byType(GpsButton), findsOneWidget);
    for (final String old in <String>[
      'GPX',
      'FIT',
      'Envoyer vers un appareil',
    ]) {
      expect(find.text(old), findsNothing);
    }
    // Plus de barre d'actions : une page qui défile.
    expect(find.byType(PdlActionBar), findsNothing);
    expect(find.byType(RouteSection), findsOneWidget);

    // L'identité : l'équipe cliquable, le titre.
    expect(find.byType(PdlTeamLine), findsOneWidget);
    expect(
      tester.widget<PdlTeamLine>(find.byType(PdlTeamLine)).onTap,
      isNotNull,
    );

    // Distance | Dénivelé positif, sur une seule ligne.
    expect(inTiles('Distance'), findsOneWidget);
    expect(inTiles('Dénivelé positif'), findsOneWidget);
    expect(
      tester.getTopLeft(inTiles('Dénivelé positif')).dy,
      tester.getTopLeft(inTiles('Distance')).dy,
    );

    // Les comptes à droite des titres.
    expect(find.text('2 points'), findsOneWidget);
    expect(find.text('1 montée'), findsOneWidget);

    // « Créé le 3 novembre 2026 », sans jour de la semaine.
    expect(
      find.descendant(
        of: find.byKey(keys.routeDetail.informationSection),
        matching: find.text('3 novembre 2026'),
      ),
      findsOneWidget,
    );

    // Les commentaires sont ceux du parcours.
    expect(find.byType(CommentThread), findsOneWidget);
    expect(comments.targets.single.entity, CommentEntity.route);
    expect(comments.targets.single.slug, 'col-de-la-croix');

    // Le partage dans la barre du haut, pour tout le monde ; sans session,
    // rien à signaler : pas de `⋯`.
    expect(find.byKey(keys.routeDetail.shareButton), findsOneWidget);
    expect(find.byKey(keys.routeDetail.moreButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sans droit de lire les commentaires, ni fil ni section', (
    WidgetTester tester,
  ) async {
    final _StubCommentRepository comments = await open(
      tester,
      _route(commentCount: null),
    );

    expect(find.byKey(keys.routeDetail.commentsSection), findsNothing);
    expect(find.byType(CommentThread), findsNothing);
    expect(comments.targets, isEmpty);
  });

  testWidgets('équipe non consultable : la ligne d\'équipe ne mène nulle part '
      '(MOB-137)', (WidgetTester tester) async {
    final RouteDetailDto route = _route(commentCount: null);
    await open(
      tester,
      route.copyWith(team: route.team.copyWith(accessible: false)),
    );

    expect(find.byType(PdlTeamLine), findsOneWidget);
    expect(tester.widget<PdlTeamLine>(find.byType(PdlTeamLine)).onTap, isNull);
  });

  testWidgets('sans description, pas de section Description', (
    WidgetTester tester,
  ) async {
    await open(tester, _route(markdown: ''));

    expect(find.byKey(keys.routeDetail.descriptionSection), findsNothing);
    expect(find.byKey(keys.routeDetail.waypointsSection), findsOneWidget);
  });

  testWidgets('sans tracé : l\'état vide, ni carte ni points', (
    WidgetTester tester,
  ) async {
    await open(tester, _route().copyWith(tracks: const <TrackDto>[]));

    expect(find.text('Aucune donnée de tracé'), findsOneWidget);
    expect(find.byKey(keys.routeDetail.map), findsNothing);
    expect(find.byKey(keys.routeDetail.waypointsSection), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
