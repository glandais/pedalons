import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/trips/data/trip_repository.dart';
import 'package:pedalons/features/trips/providers/trip_detail_provider.dart';
import 'package:pedalons/features/trips/providers/trip_participation_controller.dart';

import 'trip_fixtures.dart';

/// S24-6 — la participation à un voyage.
///
/// Trois choses s'y vérifient, et ce sont les trois que la v1 ratait : la
/// bascule est optimiste, un échec rétablit l'état d'avant au lieu d'en
/// inventer un, et `registered` fait foi — plus aucune déduction en cherchant
/// l'utilisateur courant dans `participants[]`, une liste vide sans droit de
/// lecture.
class _FakeTripRepository implements TripRepository {
  _FakeTripRepository(this._trip);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  TripDto _trip;

  int joins = 0;
  int leaves = 0;
  Object? error;

  /// Bloque l'appel jusqu'à ce que le test le libère, pour observer l'état
  /// pendant que la requête est en vol.
  Completer<void>? gate;

  void serve(TripDto trip) => _trip = trip;

  @override
  Future<TripDto> getTrip(String teamSlug, String tripSlug) async => _trip;

  @override
  Future<TripWeatherDto> getTripWeather(String t, String s) =>
      throw UnimplementedError('la météo ne concerne pas ces tests');

  @override
  Future<TripParticipationDto> joinTrip(
    String teamSlug,
    String tripSlug,
  ) async {
    joins++;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return const TripParticipationDto(id: 'p1', userId: 'u0');
  }

  @override
  Future<void> leaveTrip(String teamSlug, String tripSlug) async {
    leaves++;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
  }
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
  const TripKey key = TripKey(teamSlug: 'n-peloton', tripSlug: 'gtmc-bromance');

  Future<(ProviderContainer, _FakeTripRepository)> boot(TripDto trip) async {
    final _FakeTripRepository repo = _FakeTripRepository(trip);
    final ProviderContainer container = ProviderContainer(
      overrides: [tripRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.listen(
      tripParticipationProvider(key),
      (TripParticipationState? previous, TripParticipationState next) {},
      fireImmediately: true,
    );
    await container.read(tripDetailProvider(key).future);
    return (container, repo);
  }

  test('participer bascule avant la réponse du réseau', () async {
    final (ProviderContainer container, _FakeTripRepository repo) = await boot(
      fixtureTrip(participantCount: 3),
    );
    repo.gate = Completer<void>();

    final Future<void> pending = container
        .read(tripParticipationProvider(key).notifier)
        .join();

    final TripParticipationState optimistic = container.read(
      tripParticipationProvider(key),
    );
    expect(optimistic.pending, isTrue);
    expect(optimistic.trip.value!.registered, isTrue);
    expect(optimistic.trip.value!.participantCount, 4);

    repo.serve(fixtureTrip(registered: true, participantCount: 4));
    repo.gate!.complete();
    await pending;

    expect(repo.joins, 1);
    expect(container.read(tripParticipationProvider(key)).failure, isNull);
    expect(container.read(tripParticipationProvider(key)).pending, isFalse);
  });

  test('un échec rétablit l\'état d\'avant, entier', () async {
    final (ProviderContainer container, _FakeTripRepository repo) = await boot(
      fixtureTrip(participantCount: 3),
    );
    repo.error = _apiError('CONFLICT', status: 409);

    await container.read(tripParticipationProvider(key).notifier).join();

    final TripParticipationState after = container.read(
      tripParticipationProvider(key),
    );
    expect(after.failure, isNotNull);
    expect(after.pending, isFalse);
    expect(after.trip.value!.registered, isFalse);
    expect(after.trip.value!.participantCount, 3);
  });

  test('un 403 devient le motif « réservé aux membres »', () async {
    final (ProviderContainer container, _FakeTripRepository repo) = await boot(
      fixtureTrip(),
    );
    repo.error = _apiError('FORBIDDEN', status: 403);

    await container.read(tripParticipationProvider(key).notifier).join();

    expect(
      container.read(tripParticipationProvider(key)).failure!.reason,
      TripParticipationFailureReason.notMember,
    );
  });

  test('se désinscrire est un appel unique', () async {
    final (ProviderContainer container, _FakeTripRepository repo) = await boot(
      fixtureTrip(registered: true, participantCount: 4),
    );

    await container.read(tripParticipationProvider(key).notifier).leave();

    expect(repo.leaves, 1);
    expect(repo.joins, 0);
  });

  test('une seconde demande pendant un appel en vol est ignorée', () async {
    final (ProviderContainer container, _FakeTripRepository repo) = await boot(
      fixtureTrip(),
    );
    repo.gate = Completer<void>();

    final Future<void> first = container
        .read(tripParticipationProvider(key).notifier)
        .join();
    await container.read(tripParticipationProvider(key).notifier).join();

    expect(repo.joins, 1, reason: 'pas de file d\'attente, une seule demande');
    repo.gate!.complete();
    await first;
  });

  test('participer à ce à quoi on participe déjà n\'appelle rien', () async {
    final (ProviderContainer container, _FakeTripRepository repo) = await boot(
      fixtureTrip(registered: true),
    );

    await container.read(tripParticipationProvider(key).notifier).join();

    expect(repo.joins, 0, reason: '`registered` fait foi');
  });

  test('un voyage se juge passé sur sa date de fin, pas de départ', () {
    final TripDto ongoing = fixtureTrip(
      dateTime: '2020-08-12T07:00:00Z',
      endDate: '2099-08-18T07:00:00Z',
    );
    expect(ongoing.isPast, isFalse);

    final TripDto done = fixtureTrip(
      dateTime: '2020-08-12T07:00:00Z',
      endDate: '2020-08-18T07:00:00Z',
    );
    expect(done.isPast, isTrue);

    // Sans étape, `endDate` est nul par contrat : le voyage tient en un jour et
    // c'est `dateTime` qui décide.
    final TripDto single = fixtureTrip(
      dateTime: '2020-08-12T07:00:00Z',
      endDate: null,
      stages: <TripStageDto>[],
    );
    expect(single.isPast, isTrue);
  });

  test('les étapes se trient sur stageIndex, pas sur l\'ordre reçu', () {
    final TripDto trip = fixtureTrip(
      stages: <TripStageDto>[
        fixtureStage(index: 3),
        fixtureStage(index: 1),
        fixtureStage(index: 2),
      ],
    );
    expect(
      trip.orderedStages.map((TripStageDto s) => s.stageIndex).toList(),
      <int>[1, 2, 3],
    );
    expect(trip.orderedStages.first.paletteIndex, 0);
  });
}
