import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pagination/pagination.dart';
import 'package:pedalons/features/places/data/places_repository.dart';
import 'package:pedalons/features/places/domain/place_filters.dart';
import 'package:pedalons/features/places/providers/places_provider.dart';
import 'package:pedalons/features/rides/data/ride_editor_repository.dart';

/// Ce qu'une liste de lieux fait d'un lieu réécrit (ledger `MOB-168`, revue
/// du lot 4) : la liste est triée par nom côté serveur — un lieu renommé y
/// change de rang, et le garder à sa place fausserait la page suivante.
class _Places implements PlacesRepository {
  _Places(this.places);

  /// Les lieux du serveur, **dans son ordre** : par nom.
  List<PlaceDetailDto> places;
  final List<int> pages = <int>[];

  @override
  Future<PageResult<PlaceDetailDto>> fetchPlaces({
    required PlaceFilters filters,
    int page = 0,
    int size = kDefaultPageSize,
  }) async {
    pages.add(page);
    final List<PlaceDetailDto> sorted = <PlaceDetailDto>[...places]
      ..sort(
        (PlaceDetailDto a, PlaceDetailDto b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    return PageResult<PlaceDetailDto>(
      items: sorted.skip(page * size).take(size).toList(),
      total: sorted.length,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Editors implements RideEditorRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlaceDetailDto _place(int index, {String? name, String? address}) =>
    PlaceDetailDto(
      id: 'p$index',
      // « Lieu 00 » … « Lieu 24 » : l'ordre des noms est celui des index.
      name: name ?? 'Lieu ${index.toString().padLeft(2, '0')}',
      address: address,
      startPlace: true,
      endPlace: true,
    );

void main() {
  const PlaceFilters filters = PlaceFilters(teamSlug: 'n-peloton');

  Future<(ProviderContainer, _Places)> open(int count) async {
    final _Places places = _Places(<PlaceDetailDto>[
      for (int i = 0; i < count; i++) _place(i),
    ]);
    final ProviderContainer container = ProviderContainer(
      overrides: [
        placesRepositoryProvider.overrideWithValue(places),
        rideEditorRepositoryProvider.overrideWithValue(_Editors()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(teamPlacesProvider(filters), (_, _) {});
    await pumpEventQueue();
    return (container, places);
  }

  List<String> names(ProviderContainer container) => <String>[
    for (final PlaceDetailDto p
        in container.read(teamPlacesProvider(filters)).items)
      p.name,
  ];

  test('un lieu renommé alors que des pages restent à lire : la liste est '
      'relue, et la page suivante ne saute aucun lieu', () async {
    final (ProviderContainer container, _Places places) = await open(25);
    expect(names(container), hasLength(20));
    expect(places.pages, <int>[0]);

    // « Lieu 03 » devient « Zénith » : le serveur le range en dernier.
    final PlaceDetailDto renamed = _place(3, name: 'Zénith');
    places.places = <PlaceDetailDto>[
      for (final PlaceDetailDto p in places.places) p.id == 'p3' ? renamed : p,
    ];
    notifyPlacesChanged(container, PlaceChange.updated('n-peloton', renamed));
    await pumpEventQueue();

    // Relue depuis la première page : « Lieu 20 » y a glissé.
    expect(places.pages, <int>[0, 0]);
    expect(names(container), isNot(contains('Zénith')));
    expect(names(container).last, 'Lieu 20');

    await container.read(teamPlacesProvider(filters).notifier).loadNextPage();
    final List<String> all = names(container);
    expect(all, hasLength(25));
    expect(all.toSet(), hasLength(25));
    expect(all.last, 'Zénith');
  });

  test('un lieu réécrit sans changer de nom reste à sa place, sans requête, '
      'même quand des pages restent à lire', () async {
    final (ProviderContainer container, _Places places) = await open(25);

    final PlaceDetailDto rewritten = _place(3, address: '1 rue du Col');
    notifyPlacesChanged(container, PlaceChange.updated('n-peloton', rewritten));
    await pumpEventQueue();

    expect(places.pages, <int>[0]);
    expect(
      container.read(teamPlacesProvider(filters)).items[3].address,
      '1 rue du Col',
    );
  });

  test('la casse seule ne change pas le rang : remplacé à sa place', () async {
    final (ProviderContainer container, _Places places) = await open(25);

    notifyPlacesChanged(
      container,
      PlaceChange.updated('n-peloton', _place(3, name: 'LIEU 03')),
    );
    await pumpEventQueue();

    expect(places.pages, <int>[0]);
    expect(names(container)[3], 'LIEU 03');
  });

  test('un lieu renommé dans une liste entièrement lue est remplacé à sa '
      'place : aucune page ne reste à fausser', () async {
    final (ProviderContainer container, _Places places) = await open(5);

    notifyPlacesChanged(
      container,
      PlaceChange.updated('n-peloton', _place(3, name: 'Zénith')),
    );
    await pumpEventQueue();

    expect(places.pages, <int>[0]);
    expect(names(container)[3], 'Zénith');
  });

  test('21 lieux, 20 lus, un supprimé : le 21e glisse dans la liste — rien '
      'n\'est perdu', () async {
    final (ProviderContainer container, _Places places) = await open(21);
    expect(names(container), hasLength(20));

    places.places = <PlaceDetailDto>[
      for (final PlaceDetailDto p in places.places)
        if (p.id != 'p4') p,
    ];
    notifyPlacesChanged(
      container,
      const PlaceChange.deleted('n-peloton', 'p4'),
    );
    await pumpEventQueue();

    final PagedListState<PlaceDetailDto> state = container.read(
      teamPlacesProvider(filters),
    );
    expect(state.items, hasLength(20));
    expect(state.items.last.name, 'Lieu 20');
    expect(state.total, 20);
    expect(state.hasMore, isFalse);
  });
}
