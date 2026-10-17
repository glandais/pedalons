import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';
import 'package:pedalons/features/trips/providers/trip_detail_provider.dart';
import 'package:pedalons/features/trips/providers/trip_tracks_provider.dart';

import 'trip_fixtures.dart';

/// S24-3 — le chargement des tracés d'un voyage.
///
/// Un seul appel `getRoutesBulk` couvre toutes les étapes voulues, au lieu
/// d'un `getRoute` par étape : ce qui se vérifie ici, c'est que **un seul**
/// appel part (pas un par étape), que le nombre d'étapes chargées reste
/// **plafonné à douze** avec le dépassement visible dans l'état, que deux
/// étapes qui partagent un parcours ne demandent **qu'un** slug, et qu'un
/// parcours absent de la réponse (silencieusement omis par le lot, comme le
/// ferait un slug inconnu ou illisible) est retenu dans `failed`, pas perdu.
class _CountingRouteRepository implements RouteRepository {
  _CountingRouteRepository({this.failFor = const <String>{}});

  final Set<String> failFor;

  /// Un élément par appel `getRoutesBulk`, avec les slugs demandés dans
  /// l'ordre envoyé.
  final List<List<String>> bulkCalls = <List<String>>[];

  /// Retient la réponse jusqu'à ce que le test libère, pour observer l'état
  /// intermédiaire.
  Completer<void>? gate;

  @override
  Future<RoutesBulkResponse> getRoutesBulk(
    String teamSlug,
    List<String> slugs, {
    bool geometry = true,
  }) async {
    bulkCalls.add(slugs);
    if (gate != null) await gate!.future;
    // Un slug de `failFor` est **absent** de la réponse — c'est ainsi que le
    // lot traite un slug inconnu ou illisible côté serveur : jamais une
    // erreur pour tout le lot.
    return RoutesBulkResponse(
      routes: <RouteDetailDto>[
        for (final String slug in slugs)
          if (!failFor.contains(slug))
            RouteDetailDto(
              elevationState: 'HD',
              tags: const [],
              id: 'r-$slug',
              slug: slug,
              team: kFixtureTeam,
              name: slug,
              media: kEmptyMedia,
              distance: 50000,
              elevationGain: 800,
              elevationLoss: 800,
              surfaceType: 'GRAVEL',
              visibility: 'PUBLIC',
              createdBy: const PublicUserDto(
                id: 'u9',
                displayName: 'Créatrice',
              ),
              createdAt: '2026-01-01T10:00:00Z',
              updatedAt: '2026-01-01T10:00:00Z',
              deleted: false,
              tracks: const <TrackDto>[],
              waypoints: const <WaypointDto>[],
            ),
      ],
      extent: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} inattendu');
}

TripDto _tripWithStages(int count) => fixtureTrip(
  stages: <TripStageDto>[
    for (int i = 1; i <= count; i++)
      fixtureStage(
        index: i,
        stageCount: count,
        route: fixtureStageRoute(slug: 'etape-$i', name: 'Étape $i'),
      ),
  ],
);

void main() {
  const TripKey key = TripKey(teamSlug: 'n-peloton', tripSlug: 'gtmc-bromance');

  Future<(ProviderContainer, _CountingRouteRepository)> boot(
    TripDto trip, {
    Set<String> failFor = const <String>{},
    bool hold = false,
  }) async {
    final _CountingRouteRepository repo = _CountingRouteRepository(
      failFor: failFor,
    );
    // La porte se pose **avant** que le contrôleur ne démarre : le chargement
    // part dès que le détail arrive, donc au milieu de ce `boot`.
    if (hold) repo.gate = Completer<void>();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        routeRepositoryProvider.overrideWithValue(repo),
        tripDetailProvider(key).overrideWith((Ref ref) async => trip),
      ],
    );
    addTearDown(container.dispose);
    container.listen(
      tripTracksProvider(key),
      (TripTracksState? previous, TripTracksState next) {},
      fireImmediately: true,
    );
    await container.read(tripDetailProvider(key).future);
    return (container, repo);
  }

  test('toutes les étapes partent dans un seul appel groupé', () async {
    final (ProviderContainer container, _CountingRouteRepository repo) =
        await boot(_tripWithStages(10), hold: true);

    // Un seul appel part, avec les dix slugs — pas dix appels séparés.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repo.bulkCalls.length, 1);
    expect(repo.bulkCalls.single.length, 10);
    expect(
      container.read(tripTracksProvider(key)).geometries,
      isEmpty,
      reason: 'la porte retient encore la réponse',
    );

    repo.gate!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(tripTracksProvider(key)).geometries.length, 10);
    expect(repo.bulkCalls.length, 1, reason: 'toujours un seul appel');
  });

  test('au-delà de douze étapes, le plafond est chargé et signalé', () async {
    final (ProviderContainer container, _CountingRouteRepository repo) =
        await boot(_tripWithStages(18));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final TripTracksState state = container.read(tripTracksProvider(key));
    expect(state.total, 18);
    expect(state.requested, kTripTrackStageCap);
    expect(state.truncated, isTrue, reason: 'jamais silencieux');
    expect(repo.bulkCalls.single.length, kTripTrackStageCap);
  });

  test('deux étapes sur le même parcours ne demandent qu\'un slug', () async {
    final RouteDto shared = fixtureStageRoute(slug: 'aller-retour');
    final (
      ProviderContainer container,
      _CountingRouteRepository repo,
    ) = await boot(
      fixtureTrip(
        stages: <TripStageDto>[
          fixtureStage(index: 1, route: shared),
          fixtureStage(index: 2, route: shared),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(repo.bulkCalls.single, <String>['aller-retour']);
    expect(container.read(tripTracksProvider(key)).total, 1);
  });

  test('un parcours absent de la réponse est retenu, pas perdu', () async {
    final (ProviderContainer container, _CountingRouteRepository repo) =
        await boot(_tripWithStages(3), failFor: <String>{'etape-2'});
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final TripTracksState state = container.read(tripTracksProvider(key));
    expect(state.failed, <String>{'etape-2'});
    expect(state.geometries.keys, containsAll(<String>['etape-1', 'etape-3']));
    expect(state.isLoading, isFalse);
  });

  test('le retry ne redemande que ce qui a échoué', () async {
    final (ProviderContainer container, _CountingRouteRepository repo) =
        await boot(_tripWithStages(3), failFor: <String>{'etape-2'});
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.bulkCalls.length, 1);

    container.read(tripTracksProvider(key).notifier).retryFailed();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Un second appel groupé part, avec le seul slug qui manquait — pas les
    // trois étapes.
    expect(repo.bulkCalls.length, 2);
    expect(repo.bulkCalls.last, <String>['etape-2']);
    // Le faux dépôt exclut toujours `etape-2` : le retry échoue de nouveau,
    // ce qui montre que c'est bien un nouvel appel qui a couru, pas un cache.
    expect(container.read(tripTracksProvider(key)).failed, <String>{'etape-2'});
  });

  test('les étapes partent dans l\'ordre du voyage', () async {
    final (
      ProviderContainer container,
      _CountingRouteRepository repo,
    ) = await boot(
      fixtureTrip(
        stages: <TripStageDto>[
          fixtureStage(index: 3, route: fixtureStageRoute(slug: 'etape-3')),
          fixtureStage(index: 1, route: fixtureStageRoute(slug: 'etape-1')),
          fixtureStage(index: 2, route: fixtureStageRoute(slug: 'etape-2')),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(repo.bulkCalls.single, <String>['etape-1', 'etape-2', 'etape-3']);
  });
}
