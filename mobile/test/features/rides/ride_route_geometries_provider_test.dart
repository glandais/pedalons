import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';
import 'package:pedalons/features/routes/data/route_repository.dart';

import 'ride_fixtures.dart';

/// M1 — le chargement des tracés d'une sortie ne doit pas suivre le cycle de
/// vie de son détail.
///
/// Ce que ces tests vérifient précisément, c'est le défaut trouvé en revue :
/// `rideDetailProvider` est invalidé après chaque inscription, désinscription
/// ou échec (`ride_registration_controller.dart`), et le lot de géométries ne
/// doit **pas** en repartir tant que l'ensemble des `routeSlug` distincts n'a
/// pas changé — sans quoi rejoindre un groupe retéléchargerait plusieurs
/// mégaoctets de tracés pour un compteur de participants qui a bougé.
class _CountingRouteRepository implements RouteRepository {
  /// Un élément par appel `getRoutesBulk`, avec les slugs demandés.
  final List<List<String>> bulkCalls = <List<String>>[];

  /// Retient la réponse jusqu'à ce que le test libère, pour observer l'état
  /// intermédiaire d'un refetch en cours.
  Completer<void>? gate;

  @override
  Future<RoutesBulkResponse> getRoutesBulk(
    String teamSlug,
    List<String> slugs, {
    bool geometry = true,
  }) async {
    bulkCalls.add(slugs);
    if (gate != null) await gate!.future;
    return RoutesBulkResponse(
      routes: <RouteDetailDto>[
        for (final String slug in slugs)
          RouteDetailDto(
            elevationState: 'HD',
            tags: const [],
            id: 'r-$slug',
            slug: slug,
            team: const TeamPublicationDto(
              id: 't1',
              slug: 'n-peloton',
              name: 'N-Peloton',
              visibility: 'PUBLIC',
            ),
            name: slug,
            media: const MediaDto(
              markdown: '',
              assets: AssetsDto(
                images: <AssetDto>[],
                attachments: <AssetDto>[],
              ),
            ),
            distance: 50000,
            elevationGain: 800,
            elevationLoss: 800,
            surfaceType: 'GRAVEL',
            visibility: 'PUBLIC',
            createdBy: const PublicUserDto(id: 'u9', displayName: 'Créatrice'),
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

void main() {
  const RideKey key = RideKey(teamSlug: 'n-peloton', rideSlug: 'np-665');

  Future<(ProviderContainer, _CountingRouteRepository)> boot(
    RideDto ride,
  ) async {
    final _CountingRouteRepository repo = _CountingRouteRepository();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        routeRepositoryProvider.overrideWithValue(repo),
        rideDetailProvider(key).overrideWith((Ref ref) async => ride),
      ],
    );
    addTearDown(container.dispose);
    container.listen(
      rideRouteGeometriesProvider(key),
      (RideRouteGeometriesState? previous, RideRouteGeometriesState next) {},
      fireImmediately: true,
    );
    await container.read(rideDetailProvider(key).future);
    // Laisse le lot initial partir et se résoudre.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return (container, repo);
  }

  test('dix groupes sur trois parcours ne font qu\'un appel groupé', () async {
    final RideDto ride = fixtureRide(
      groups: <RideGroupDto>[
        for (int i = 0; i < 10; i++)
          fixtureGroup(id: 'g$i', sortOrder: i, routeSlug: 'parcours-${i % 3}'),
      ],
    );
    final (ProviderContainer container, _CountingRouteRepository repo) =
        await boot(ride);

    expect(repo.bulkCalls.length, 1);
    expect(repo.bulkCalls.single, <String>[
      'parcours-0',
      'parcours-1',
      'parcours-2',
    ]);
    expect(
      container.read(rideRouteGeometriesProvider(key)).geometries.length,
      3,
    );
  });

  test(
    'invalider le détail après une inscription ne relance pas le lot',
    () async {
      final RideDto ride = fixtureRide(
        groups: <RideGroupDto>[
          fixtureGroup(id: 'g1', routeSlug: 'court'),
          fixtureGroup(id: 'g2', sortOrder: 1, routeSlug: 'long'),
        ],
      );
      final (ProviderContainer container, _CountingRouteRepository repo) =
          await boot(ride);
      expect(repo.bulkCalls.length, 1);

      // C'est exactement ce que fait `RideRegistrationController` après un
      // `join`/`leave` réussi ou raté : invalider le détail partagé. Les
      // parcours des groupes n'ont pas changé — le lot ne doit pas repartir.
      container.invalidate(rideDetailProvider(key));
      await container.read(rideDetailProvider(key).future);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        repo.bulkCalls.length,
        1,
        reason:
            'un changement de participants ne doit pas retélécharger les '
            'géométries',
      );
    },
  );

  test(
    'invalider plusieurs fois de suite (switchGroup, échec) ne fait toujours qu\'un appel',
    () async {
      final RideDto ride = fixtureRide(
        groups: <RideGroupDto>[fixtureGroup(id: 'g1', routeSlug: 'seul')],
      );
      final (ProviderContainer container, _CountingRouteRepository repo) =
          await boot(ride);
      expect(repo.bulkCalls.length, 1);

      // `switchGroup` invalide deux fois (leave, puis join) ; un échec en
      // invalide une troisième (`_fail`).
      for (int i = 0; i < 3; i++) {
        container.invalidate(rideDetailProvider(key));
        await container.read(rideDetailProvider(key).future);
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repo.bulkCalls.length, 1);
    },
  );

  test(
    'au-delà de cinquante parcours distincts, le lot est plafonné',
    () async {
      final RideDto ride = fixtureRide(
        groups: <RideGroupDto>[
          for (int i = 0; i < 60; i++)
            fixtureGroup(id: 'g$i', sortOrder: i, routeSlug: 'parcours-$i'),
        ],
      );
      final (ProviderContainer container, _CountingRouteRepository repo) =
          await boot(ride);

      expect(repo.bulkCalls.length, 1);
      expect(repo.bulkCalls.single.length, kRideRouteSlugCap);
      expect(
        container.read(rideRouteGeometriesProvider(key)).geometries.length,
        kRideRouteSlugCap,
      );
    },
  );

  group('M1b — un vrai changement d\'ensemble ne vide pas la carte', () {
    test('un parcours déjà chargé reste affiché pendant que le nouveau se '
        'charge', () async {
      final RideDto ride1 = fixtureRide(
        groups: <RideGroupDto>[fixtureGroup(id: 'g1', routeSlug: 'a')],
      );
      final (ProviderContainer container, _CountingRouteRepository repo) =
          await boot(ride1);
      expect(repo.bulkCalls.length, 1);
      expect(
        container.read(rideRouteGeometriesProvider(key)).geometries.keys,
        <String>['a'],
      );

      // La sortie gagne un second groupe sur un nouveau parcours : `a`
      // reste voulu, `b` est nouveau. Le lot suivant est retenu par la
      // porte pour observer l'état pendant qu'il est en vol.
      repo.gate = Completer<void>();
      final RideDto ride2 = fixtureRide(
        groups: <RideGroupDto>[
          fixtureGroup(id: 'g1', routeSlug: 'a'),
          fixtureGroup(id: 'g2', sortOrder: 1, routeSlug: 'b'),
        ],
      );
      container.read(rideRouteGeometriesProvider(key).notifier).loadFor(ride2);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Seul le nouveau slug repart en requête — `a` n'est pas
      // retéléchargé.
      expect(repo.bulkCalls.length, 2);
      expect(repo.bulkCalls.last, <String>['b']);

      // `a`, déjà connu, reste affiché ; `b` est en cours de chargement,
      // pas en erreur — la carte ne se vide pas le temps du lot.
      final RideRouteGeometriesState mid = container.read(
        rideRouteGeometriesProvider(key),
      );
      expect(mid.geometries.keys, <String>['a']);
      expect(
        container
            .read(
              rideRouteGeometryProvider(
                const RouteRef(
                  teamSlug: 'n-peloton',
                  rideSlug: 'np-665',
                  routeSlug: 'a',
                ),
              ),
            )
            .hasValue,
        isTrue,
        reason: 'le tracé déjà connu doit continuer à s\'afficher',
      );
      expect(
        container
            .read(
              rideRouteGeometryProvider(
                const RouteRef(
                  teamSlug: 'n-peloton',
                  rideSlug: 'np-665',
                  routeSlug: 'b',
                ),
              ),
            )
            .isLoading,
        isTrue,
        reason: 'seul le tracé neuf doit être en chargement',
      );

      repo.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(rideRouteGeometriesProvider(key)).geometries.keys,
        containsAll(<String>['a', 'b']),
      );
    });

    test('un parcours qui sort de l\'ensemble voulu disparaît tout de suite, '
        'sans attendre le nouveau lot', () async {
      final RideDto ride1 = fixtureRide(
        groups: <RideGroupDto>[fixtureGroup(id: 'g1', routeSlug: 'a')],
      );
      final (ProviderContainer container, _CountingRouteRepository repo) =
          await boot(ride1);
      expect(
        container.read(rideRouteGeometriesProvider(key)).geometries.keys,
        <String>['a'],
      );

      // La sortie change entièrement de parcours : `a` n'est plus voulu du
      // tout, `c` est nouveau. Le lot est retenu pour observer l'état
      // avant que la réponse n'arrive.
      repo.gate = Completer<void>();
      final RideDto ride2 = fixtureRide(
        groups: <RideGroupDto>[fixtureGroup(id: 'g3', routeSlug: 'c')],
      );
      container.read(rideRouteGeometriesProvider(key).notifier).loadFor(ride2);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(
        container.read(rideRouteGeometriesProvider(key)).geometries,
        isNot(contains('a')),
        reason:
            'un parcours qui ne fait plus partie de la sortie ne doit '
            'pas survivre le temps du lot suivant',
      );

      repo.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        container.read(rideRouteGeometriesProvider(key)).geometries.keys,
        <String>['c'],
      );
    });
  });
}
