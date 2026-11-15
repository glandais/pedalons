import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/config/locale_context.dart';
import 'package:pedalons/core/material.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/geocoding/data/place_search_repository.dart';
import 'package:pedalons/features/geocoding/presentation/geocoded_place_picker.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';

/// Le sélecteur de lieu géocodé commun (ledger `MOB-165`) : une recherche,
/// puis **une** résolution pour l'adresse choisie, et un échec typé.
class _Places implements PlaceSearchRepository {
  _Places({this.withPosition = false});

  /// La suggestion porte déjà sa position : rien à résoudre.
  final bool withPosition;

  final List<String> searches = <String>[];
  final List<String> resolved = <String>[];
  Object? resolveError;

  /// Si posé, la résolution attend qu'il se complète.
  Completer<void>? gate;

  /// La résolution rend une réponse sans position.
  bool resolveWithoutPosition = false;

  @override
  Future<List<GeocodeResultDto>> search(String query) async {
    if (query.trim().length < PlaceSearchRepository.minQueryLength) {
      return const <GeocodeResultDto>[];
    }
    searches.add(query);
    return <GeocodeResultDto>[
      GeocodeResultDto(
        id: 'place:1',
        displayName: 'Gare de Lyon-Perrache',
        lat: withPosition ? 45.75 : null,
        lon: withPosition ? 4.83 : null,
      ),
    ];
  }

  @override
  Future<GeocodeResultDto> resolve(String id) async {
    resolved.add(id);
    await gate?.future;
    final Object? error = resolveError;
    if (error != null) throw error;
    if (resolveWithoutPosition) {
      return const GeocodeResultDto(id: 'place:1', displayName: 'Lyon');
    }
    return const GeocodeResultDto(
      id: 'place:1',
      displayName: 'Lyon',
      lat: 45.7485,
      lon: 4.8262,
    );
  }
}

DioException _apiError(int status, String code) => DioException(
  requestOptions: RequestOptions(path: '/api/geocode/place'),
  type: DioExceptionType.badResponse,
  response: Response<Map<String, Object?>>(
    requestOptions: RequestOptions(path: '/api/geocode/place'),
    statusCode: status,
    data: <String, Object?>{'code': code},
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadTestTranslations);
  setUp(() => setCurrentLocale('fr'));

  /// Ce que le sélecteur a rendu, et la suite des signaux « résolution en
  /// cours ».
  late List<GeocodedPick?> picks;
  late List<bool> resolving;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester tester, _Places places) async {
    picks = <GeocodedPick?>[];
    resolving = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [placeSearchRepositoryProvider.overrideWithValue(places)],
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? _) =>
                  TextButton(
                    onPressed: () async => picks.add(
                      await pickGeocodedPlace(
                        context,
                        ref,
                        title: 'Où ?',
                        onResolvingChange: resolving.add,
                      ),
                    ),
                    child: const Text('choisir'),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('choisir'));
    await settle(tester);
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(keys.rideEditor.pickerSearch), text);
    await settle(tester);
  }

  Future<void> choose(WidgetTester tester) async {
    await tester.tap(find.byKey(keys.rideEditor.pickerOption('place:1')));
    await settle(tester);
  }

  testWidgets('la feuille porte le titre donné, les libellés neutres et le '
      'crédit du fournisseur', (WidgetTester tester) async {
    await open(tester, _Places());

    expect(find.text('Où ?'), findsOneWidget);
    expect(find.text('Rechercher une adresse…'), findsOneWidget);
    expect(
      find.text('Aucune adresse. Tapez au moins 3 caractères.'),
      findsOneWidget,
    );
    expect(find.textContaining('Stadia Maps'), findsOneWidget);
  });

  testWidgets('en dessous de 3 caractères, rien n\'est cherché', (
    WidgetTester tester,
  ) async {
    final _Places places = _Places();
    await open(tester, places);
    await search(tester, 'Pe');

    expect(places.searches, isEmpty);
    expect(find.byKey(keys.rideEditor.pickerOption('place:1')), findsNothing);
  });

  testWidgets('une adresse choisie : une résolution, le nom lu dans la liste, '
      '[longitude, latitude]', (WidgetTester tester) async {
    final _Places places = _Places();
    await open(tester, places);
    await search(tester, 'Perrache');
    await choose(tester);

    expect(places.searches, <String>['Perrache']);
    expect(places.resolved, <String>['place:1']);
    final GeocodedPlace place = picks.single! as GeocodedPlace;
    expect(place.name, 'Gare de Lyon-Perrache');
    expect(place.lat, 45.7485);
    expect(place.lon, 4.8262);
    expect(place.coordinates, <double>[4.8262, 45.7485]);
    expect(resolving, <bool>[true, false]);
  });

  testWidgets('le signal « résolution en cours » tient tant que la position '
      'n\'est pas là', (WidgetTester tester) async {
    final _Places places = _Places()..gate = Completer<void>();
    await open(tester, places);
    await search(tester, 'Perrache');
    await choose(tester);

    expect(resolving, <bool>[true]);
    expect(picks, isEmpty);

    places.gate!.complete();
    await settle(tester);
    expect(resolving, <bool>[true, false]);
    expect(picks.single, isA<GeocodedPlace>());
  });

  testWidgets('une suggestion qui porte sa position n\'est pas résolue', (
    WidgetTester tester,
  ) async {
    final _Places places = _Places(withPosition: true);
    await open(tester, places);
    await search(tester, 'Perrache');
    await choose(tester);

    expect(places.resolved, isEmpty);
    expect(resolving, isEmpty);
    expect((picks.single! as GeocodedPlace).coordinates, <double>[4.83, 45.75]);
  });

  testWidgets('GEOCODING_UNAVAILABLE : un échec « indisponible »', (
    WidgetTester tester,
  ) async {
    final _Places places = _Places()
      ..resolveError = _apiError(503, 'GEOCODING_UNAVAILABLE');
    await open(tester, places);
    await search(tester, 'Perrache');
    await choose(tester);

    final GeocodedPlaceFailure failure = picks.single! as GeocodedPlaceFailure;
    expect(failure.reason, GeocodeFailure.unavailable);
    expect(
      failure.reason.message,
      contains('recherche d\'adresse est indisponible'),
    );
    expect(resolving, <bool>[true, false]);
  });

  testWidgets('tout autre échec, ou une réponse sans position : « échec »', (
    WidgetTester tester,
  ) async {
    final _Places places = _Places()
      ..resolveError = _apiError(404, 'NOT_FOUND');
    await open(tester, places);
    await search(tester, 'Perrache');
    await choose(tester);
    expect(
      (picks.single! as GeocodedPlaceFailure).reason,
      GeocodeFailure.failed,
    );

    final _Places empty = _Places()..resolveWithoutPosition = true;
    await open(tester, empty);
    await search(tester, 'Perrache');
    await choose(tester);
    final GeocodedPlaceFailure failure = picks.single! as GeocodedPlaceFailure;
    expect(failure.reason, GeocodeFailure.failed);
    expect(
      failure.reason.message,
      contains('Impossible d\'obtenir la position'),
    );
  });

  testWidgets('feuille fermée sans choix : null', (WidgetTester tester) async {
    await open(tester, _Places());
    await tester.tap(find.text('Annuler'));
    await settle(tester);

    expect(picks, <GeocodedPick?>[null]);
    expect(resolving, isEmpty);
  });
}
