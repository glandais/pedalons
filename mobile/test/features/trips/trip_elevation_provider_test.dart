import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/elevation/elevation_samples.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/trips/providers/trip_detail_provider.dart';
import 'package:pedalons/features/trips/providers/trip_elevation_provider.dart';

import 'trip_fixtures.dart';

/// S24-4 — le profil global d'un voyage.
///
/// Il est désormais **dérivé de la géométrie déjà chargée pour la carte** : les
/// coordonnées du contrat sont en `G3DM`, `[lon, lat, altitude, cumul]`, donc
/// aucune requête ne lui est propre. Ce qui se vérifie ici est ce qui rend la
/// concaténation honnête — un seul appel réseau pour tout l'écran, le décalage
/// de chaque étape par la distance cumulée, et le **trou signalé** quand une
/// étape manque plutôt qu'un profil raccourci qui se ferait passer pour
/// complet.
class _FakeRouteRepository implements RouteRepository {
  _FakeRouteRepository({this.failFor = const <String>{}});

  final Set<String> failFor;

  /// Un élément par appel groupé. La taille de cette liste est l'assertion la
  /// plus importante du fichier : elle valait autrefois un appel par étape,
  /// plus un appel de profil par étape.
  final List<List<String>> bulkCalls = <List<String>>[];

  @override
  Future<RoutesBulkResponse> getRoutesBulk(
    String teamSlug,
    List<String> slugs, {
    bool geometry = true,
  }) async {
    bulkCalls.add(slugs);
    return RoutesBulkResponse(
      routes: <RouteDetailDto>[
        // Un slug de `failFor` est **absent** de la réponse, comme le ferait le
        // serveur pour un slug inconnu ou illisible.
        for (final String slug in slugs)
          if (!failFor.contains(slug)) _route(slug, _distances[slug]!),
      ],
      extent: null,
    );
  }

  static const Map<String, double> _distances = <String, double>{
    'etape-1': 100000,
    'etape-2': 50000,
    'etape-3': 50000,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} inattendu');
}

/// Une étape rectiligne de quatre sommets, montant de 100 à 130 m, dont la
/// mesure `M` repart de zéro — comme le fait tout tracé du serveur.
RouteDetailDto _route(String slug, double distance) => RouteDetailDto(
  elevationState: 'HD',
  tags: const [],
  id: 'r-$slug',
  slug: slug,
  team: kFixtureTeam,
  name: slug,
  media: kEmptyMedia,
  distance: distance,
  elevationGain: 30,
  elevationLoss: 0,
  surfaceType: 'ROAD',
  visibility: 'PUBLIC',
  createdBy: const PublicUserDto(id: 'u9', displayName: 'Créatrice'),
  createdAt: '2026-01-01T00:00:00Z',
  updatedAt: '2026-01-01T00:00:00Z',
  tracks: <TrackDto>[
    TrackDto(
      line: GeoJsonLineString(
        type: GeoJsonLineStringTypeType.lineString,
        coordinates: <List<double>>[
          for (int i = 0; i < 4; i++)
            <double>[6.0 + i * 0.01, 45.0, 100 + i * 10, distance * i / 3],
        ],
      ),
      climbs: const <ClimbDto>[],
    ),
  ],
  waypoints: const <WaypointDto>[],
  deleted: false,
);

void main() {
  const TripKey key = TripKey(teamSlug: 'n-peloton', tripSlug: 'gtmc-bromance');

  TripDto trip() => fixtureTrip(
    totalDistance: 200000,
    stages: <TripStageDto>[
      fixtureStage(
        index: 1,
        route: fixtureStageRoute(slug: 'etape-1', distance: 100000),
      ),
      fixtureStage(
        index: 2,
        route: fixtureStageRoute(slug: 'etape-2', distance: 50000),
      ),
      fixtureStage(
        index: 3,
        route: fixtureStageRoute(slug: 'etape-3', distance: 50000),
      ),
    ],
  );

  Future<(TripElevation?, _FakeRouteRepository)> load({
    Set<String> failFor = const <String>{},
    TripDto? withTrip,
  }) async {
    final _FakeRouteRepository repository = _FakeRouteRepository(
      failFor: failFor,
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        routeRepositoryProvider.overrideWithValue(repository),
        tripDetailProvider(
          key,
        ).overrideWith((Ref ref) async => withTrip ?? trip()),
      ],
    );
    addTearDown(container.dispose);

    // Le profil suit le chargement des tracés : on garde une souscription pour
    // que le provider auto-disposé ne meure pas entre deux `read`.
    final ProviderSubscription<AsyncValue<TripElevation?>> subscription =
        container.listen(
          tripElevationProvider(key),
          (_, _) {},
          fireImmediately: true,
        );
    addTearDown(subscription.close);

    await container.read(tripDetailProvider(key).future);
    // Laisse partir l'appel groupé et revenir sa réponse.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    return (container.read(tripElevationProvider(key)).value, repository);
  }

  test('un seul appel réseau alimente carte et profil', () async {
    final (TripElevation? profile, _FakeRouteRepository repository) =
        await load();

    expect(repository.bulkCalls, hasLength(1));
    expect(repository.bulkCalls.single, <String>[
      'etape-1',
      'etape-2',
      'etape-3',
    ]);
    expect(profile, isNotNull);
  });

  test('chaque étape est décalée de la distance cumulée', () async {
    final (TripElevation? profile, _) = await load();
    final List<ElevationPoint> points = profile!.samples.points;

    expect(points.first.distance, 0);
    // Les points sont strictement croissants : sans décalage, l'étape 2
    // repartirait de zéro et le profil se replierait sur lui-même — c'est bien
    // ce qui arriverait en concaténant les mesures `M` telles quelles, chaque
    // tracé repartant de zéro.
    for (int i = 1; i < points.length; i++) {
      expect(
        points[i].distance,
        greaterThan(points[i - 1].distance),
        reason: 'point $i',
      );
    }
    expect(points.last.distance, closeTo(200000, 1));
    expect(profile.samples.totalDistance, 200000);
    expect(profile.hasGaps, isFalse);
  });

  test('une étape absente devient un trou signalé, pas un raccourci', () async {
    final (TripElevation? profile, _) = await load(
      failFor: <String>{'etape-2'},
    );

    expect(profile!.hasGaps, isTrue);
    expect(profile.gaps, <String>['J2']);
    // L'axe avance quand même de la distance de l'étape manquante : l'étape 3
    // reste à sa place, entre 150 et 200 km.
    expect(profile.samples.points.last.distance, closeTo(200000, 1));
    expect(profile.samples.totalDistance, 200000);
  });

  test('un voyage sans étape routée n\'a pas de profil', () async {
    final (
      TripElevation? profile,
      _FakeRouteRepository repository,
    ) = await load(
      withTrip: fixtureTrip(
        stages: <TripStageDto>[fixtureStage(index: 1)],
        totalDistance: null,
      ),
    );

    expect(profile, isNull);
    expect(repository.bulkCalls, isEmpty);
  });
}
