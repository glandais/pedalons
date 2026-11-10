import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/rides/data/ride_repository.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/features/rides/providers/ride_registration_controller.dart';

import 'ride_fixtures.dart';

/// S12-3 — la séquence d'inscription.
///
/// Ce qui est vérifié ici est exactement ce que la v1 ratait :
///
/// * la bascule est **optimiste** — le bouton change avant la réponse ;
/// * un échec **rétablit** l'état d'avant, il ne laisse pas un état inventé ;
/// * l'exclusivité est lue **avant l'appel** : inscrit ailleurs, rejoindre est
///   un changement de groupe atomique, jamais un `joinGroup` que l'API
///   refuserait (docs/LEDGER_*.md MOB-134, lot 8) ;
/// * la désinscription est **un** appel, jamais une boucle sur les groupes ;
/// * chaque motif d'échec porte le **nom du groupe** fautif.
class _FakeRideRepository implements RideRepository {
  _FakeRideRepository(this._ride);

  RideDto _ride;

  final List<String> joined = <String>[];
  final List<String> left = <String>[];
  final List<String> switched = <String>[];
  Object? joinError;
  Object? leaveError;
  Object? switchError;

  /// Bloque l'appel jusqu'à ce que le test le libère, pour observer l'état
  /// pendant que la requête est en vol.
  Completer<void>? gate;

  void serve(RideDto ride) => _ride = ride;

  @override
  Future<RideWeatherDto> getRideWeather(
    String teamSlug,
    String rideSlug,
  ) async => fixtureWeather();

  @override
  Future<RideDto> getRide(String teamSlug, String rideSlug) async => _ride;

  @override
  Future<RideParticipationDto> joinGroup(
    String teamSlug,
    String rideSlug,
    String groupId,
  ) async {
    joined.add(groupId);
    if (gate != null) await gate!.future;
    if (joinError != null) throw joinError!;
    return const RideParticipationDto(id: 'p1', userId: 'u0');
  }

  @override
  Future<void> leaveGroup(
    String teamSlug,
    String rideSlug,
    String groupId,
  ) async {
    left.add(groupId);
    if (gate != null) await gate!.future;
    if (leaveError != null) throw leaveError!;
  }

  @override
  Future<RideParticipationDto> switchGroup(
    String teamSlug,
    String rideSlug,
    String groupId,
  ) async {
    switched.add(groupId);
    if (gate != null) await gate!.future;
    if (switchError != null) throw switchError!;
    return const RideParticipationDto(id: 'p2', userId: 'u0');
  }

  // Les gestes d'organisateur (ledger `MOB-80`) ne sont pas exercés ici.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DioException _apiError(String code, {int status = 400}) => DioException(
  requestOptions: RequestOptions(path: '/'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, dynamic>>(
    requestOptions: RequestOptions(path: '/'),
    statusCode: status,
    data: <String, dynamic>{'code': code},
  ),
);

void main() {
  const RideKey key = RideKey(teamSlug: 'n-peloton', rideSlug: 'np-665');

  /// Deux groupes : celui qu'on vise et celui qui peut bloquer.
  RideDto twoGroups({String? registeredIn}) => fixtureRide(
    registered: registeredIn != null,
    registeredGroupId: registeredIn,
    groups: <RideGroupDto>[
      fixtureGroup(
        id: 'g1',
        name: 'Chill Route Long',
        registered: registeredIn == 'g1',
        countParticipants: 10,
        maxParticipants: 20,
      ),
      fixtureGroup(
        id: 'g2',
        name: 'G1',
        sortOrder: 1,
        registered: registeredIn == 'g2',
        countParticipants: 17,
        maxParticipants: 18,
      ),
    ],
  );

  Future<(ProviderContainer, _FakeRideRepository)> boot(RideDto ride) async {
    final _FakeRideRepository repo = _FakeRideRepository(ride);
    final ProviderContainer container = ProviderContainer(
      overrides: [rideRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    // Le contrôleur adopte le détail : on l'attend avant d'agir.
    container.listen(
      rideRegistrationProvider(key),
      (RideRegistrationState? previous, RideRegistrationState next) {},
      fireImmediately: true,
    );
    await container.read(rideDetailProvider(key).future);
    return (container, repo);
  }

  test('rejoindre bascule le bouton avant la réponse du réseau', () async {
    final (ProviderContainer container, _FakeRideRepository repo) = await boot(
      twoGroups(),
    );
    repo.gate = Completer<void>();

    final RideRegistrationController controller = container.read(
      rideRegistrationProvider(key).notifier,
    );
    final Future<void> pending = controller.join('g1');

    // L'appel est parti, la réponse n'est pas arrivée : l'état est déjà celui
    // de l'inscription.
    final RideRegistrationState optimistic = container.read(
      rideRegistrationProvider(key),
    );
    expect(optimistic.pendingGroupId, 'g1');
    final RideGroupDto g1 = optimistic.ride.value!.groups.first;
    expect(g1.registered, isTrue);
    expect(g1.countParticipants, 11);
    expect(optimistic.ride.value!.registeredGroupId, 'g1');

    repo.serve(twoGroups(registeredIn: 'g1'));
    repo.gate!.complete();
    await pending;

    expect(repo.joined, <String>['g1']);
    expect(container.read(rideRegistrationProvider(key)).failure, isNull);
  });

  test('un GROUP_FULL restaure l\'état et nomme le groupe', () async {
    final (ProviderContainer container, _FakeRideRepository repo) = await boot(
      twoGroups(),
    );
    repo.joinError = _apiError('GROUP_FULL', status: 409);

    await container.read(rideRegistrationProvider(key).notifier).join('g2');

    final RideRegistrationState after = container.read(
      rideRegistrationProvider(key),
    );
    expect(after.failure!.reason, RegistrationFailureReason.groupFull);
    expect(after.failure!.groupName, 'G1');
    expect(after.pendingGroupId, isNull);
    // Rétablissement complet : le groupe est revenu à 17 inscrits, non 18.
    final RideGroupDto g2 = after.ride.value!.groups[1];
    expect(g2.registered, isFalse);
    expect(g2.countParticipants, 17);
    expect(after.ride.value!.registeredGroupId, isNull);
  });

  test('inscrit ailleurs, rejoindre change de groupe en un seul appel, sans '
      'bandeau', () async {
    final (ProviderContainer container, _FakeRideRepository repo) = await boot(
      twoGroups(registeredIn: 'g1'),
    );

    repo.serve(twoGroups(registeredIn: 'g2'));
    await container.read(rideRegistrationProvider(key).notifier).join('g2');

    expect(repo.joined, isEmpty, reason: 'l\'API répondrait 400');
    expect(repo.switched, <String>['g2']);
    expect(repo.left, isEmpty);
    expect(container.read(rideRegistrationProvider(key)).failure, isNull);
  });

  test('un ALREADY_REGISTERED du serveur (inscription faite sur un autre '
      'appareil) pose le bandeau, filet de la course', () async {
    final (ProviderContainer container, _FakeRideRepository repo) = await boot(
      twoGroups(),
    );
    repo.joinError = _apiError('ALREADY_REGISTERED');

    await container.read(rideRegistrationProvider(key).notifier).join('g2');

    final RegistrationFailure failure = container
        .read(rideRegistrationProvider(key))
        .failure!;
    expect(failure.reason, RegistrationFailureReason.alreadyRegistered);
    expect(failure.groupName, 'G1');
    expect(failure.leaving, isFalse);
  });

  test('un échec de désinscription se reprend en quittant', () async {
    final (ProviderContainer container, _FakeRideRepository repo) = await boot(
      twoGroups(registeredIn: 'g1'),
    );
    repo.leaveError = _apiError('SOMETHING');

    await container.read(rideRegistrationProvider(key).notifier).leave('g1');

    final RegistrationFailure failure = container
        .read(rideRegistrationProvider(key))
        .failure!;
    expect(failure.reason, RegistrationFailureReason.generic);
    expect(failure.leaving, isTrue);
  });

  test('un 403 devient le motif « réservé aux membres »', () async {
    final (ProviderContainer container, _FakeRideRepository repo) = await boot(
      twoGroups(),
    );
    repo.joinError = _apiError('FORBIDDEN', status: 403);

    await container.read(rideRegistrationProvider(key).notifier).join('g1');

    expect(
      container.read(rideRegistrationProvider(key)).failure!.reason,
      RegistrationFailureReason.notMember,
    );
  });

  test('se désinscrire est un appel unique, pas une boucle', () async {
    final (ProviderContainer container, _FakeRideRepository repo) = await boot(
      twoGroups(registeredIn: 'g1'),
    );

    await container.read(rideRegistrationProvider(key).notifier).leave('g1');

    expect(repo.left, <String>['g1']);
    expect(repo.joined, isEmpty);
  });

  test('changer de groupe bascule les deux groupes avant la réponse', () async {
    final (ProviderContainer container, _FakeRideRepository repo) = await boot(
      twoGroups(registeredIn: 'g1'),
    );
    repo.gate = Completer<void>();

    final Future<void> pending = container
        .read(rideRegistrationProvider(key).notifier)
        .switchGroup('g2');

    final RideRegistrationState optimistic = container.read(
      rideRegistrationProvider(key),
    );
    final RideDto ride = optimistic.ride.value!;
    expect(optimistic.pendingGroupId, 'g2');
    expect(ride.registeredGroupId, 'g2');
    expect(ride.groups[0].registered, isFalse);
    expect(ride.groups[0].countParticipants, 9);
    expect(ride.groups[1].registered, isTrue);
    expect(ride.groups[1].countParticipants, 18);
    expect(ride.groups[1].full, isTrue);

    repo.serve(twoGroups(registeredIn: 'g2'));
    repo.gate!.complete();
    await pending;
    expect(
      container.read(rideRegistrationProvider(key)).pendingGroupId,
      isNull,
    );
  });

  test('un échec du changement rétablit l\'inscription d\'avant', () async {
    final (ProviderContainer container, _FakeRideRepository repo) = await boot(
      twoGroups(registeredIn: 'g1'),
    );
    repo.switchError = _apiError('GROUP_FULL', status: 409);

    await container
        .read(rideRegistrationProvider(key).notifier)
        .switchGroup('g2');

    final RideRegistrationState after = container.read(
      rideRegistrationProvider(key),
    );
    expect(after.failure!.reason, RegistrationFailureReason.groupFull);
    expect(after.failure!.groupName, 'G1');
    expect(after.pendingGroupId, isNull);
    final RideDto ride = after.ride.value!;
    expect(ride.registeredGroupId, 'g1');
    expect(ride.groups[0].registered, isTrue);
    expect(ride.groups[0].countParticipants, 10);
    expect(ride.groups[1].registered, isFalse);
    expect(ride.groups[1].countParticipants, 17);
  });

  test(
    'changer sans inscription rejoint, et vers son groupe ne fait rien',
    () async {
      final (ProviderContainer container, _FakeRideRepository repo) =
          await boot(twoGroups());
      final RideRegistrationController controller = container.read(
        rideRegistrationProvider(key).notifier,
      );

      repo.serve(twoGroups(registeredIn: 'g1'));
      await controller.switchGroup('g1');
      expect(repo.joined, <String>['g1']);
      expect(repo.switched, isEmpty);

      await container.read(rideDetailProvider(key).future);
      await controller.switchGroup('g1');
      expect(repo.switched, isEmpty);
      expect(repo.joined, <String>['g1']);
    },
  );

  test('le bandeau se ferme et ne revient pas tout seul', () async {
    final (ProviderContainer container, _FakeRideRepository repo) = await boot(
      twoGroups(),
    );
    repo.joinError = _apiError('GROUP_FULL', status: 409);
    final RideRegistrationController controller = container.read(
      rideRegistrationProvider(key).notifier,
    );
    await controller.join('g2');
    expect(container.read(rideRegistrationProvider(key)).failure, isNotNull);

    controller.dismissFailure();
    expect(container.read(rideRegistrationProvider(key)).failure, isNull);
  });
}
