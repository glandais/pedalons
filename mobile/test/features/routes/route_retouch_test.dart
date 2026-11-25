import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/routes/domain/route_retouch.dart';

/// La retouche dans l'app (docs/LEDGER_*.md MOB-185) : les règles du site
/// (`frontend/src/lib/routeRetouch.ts`).
void main() {
  const RouteRetouchOfferDto offer = RouteRetouchOfferDto(
    available: true,
    operations: <RouteRetouchOperation>[
      RouteRetouchOperation.resize,
      RouteRetouchOperation.moveEnd,
    ],
    originalDistanceM: 82000,
    minDistanceKm: 62,
    maxDistanceKm: 103,
    minChangeKm: 2,
    maxChangeShare: 0.25,
    rideType: 'GRAVEL',
  );

  test('retouchBounds : lues dans l’offre', () {
    final RetouchBounds bounds = retouchBounds(offer)!;
    expect(bounds.currentKm, 82);
    expect(bounds.minKm, 62);
    expect(bounds.maxKm, 103);
    expect(bounds.minChangeKm, 2);
    expect(retouchBounds(null), isNull);
    expect(
      retouchBounds(
        const RouteRetouchOfferDto(
          available: false,
          operations: <RouteRetouchOperation>[],
        ),
      ),
      isNull,
    );
  });

  test('retouchEntryOf : offerte, en analyse, ou rien', () {
    expect(retouchEntryOf(offer), RetouchEntry.available);
    expect(retouchEntryOf(null), RetouchEntry.none);
    expect(
      retouchEntryOf(
        const RouteRetouchOfferDto(
          available: false,
          operations: <RouteRetouchOperation>[],
          unavailableReason: 'NOT_READY',
        ),
      ),
      RetouchEntry.notReady,
    );
    expect(
      retouchEntryOf(
        const RouteRetouchOfferDto(
          available: false,
          operations: <RouteRetouchOperation>[],
          unavailableReason: 'NOT_ALLOWED',
        ),
      ),
      RetouchEntry.none,
    );
  });

  test('zone morte, bornes, raccourcissement', () {
    final RetouchBounds bounds = retouchBounds(offer)!;
    expect(isDeadZone(83, bounds), isTrue);
    expect(isDeadZone(84, bounds), isFalse);
    expect(isOutOfRange(61, bounds), isTrue);
    expect(isOutOfRange(103.04, bounds), isFalse);
    expect(clampTarget(110, bounds), 103);
    expect(isShortening(70, bounds.currentKm), isTrue);
  });

  test(
    'routeRetouchRequest : une distance ou une arrivée, jamais les deux',
    () {
      final RouteRetouchRequest resize = routeRetouchRequest(
        const RetouchResize(95.04),
        2,
      );
      expect(resize.targetDistanceKm, 95.0);
      expect(resize.end, isNull);
      expect(resize.seed, 2);

      final RouteRetouchRequest place = routeRetouchRequest(
        const RetouchMoveEnd(placeId: 'p1'),
        0,
      );
      expect(place.targetDistanceKm, isNull);
      expect(place.end?.placeId, 'p1');
      expect(place.end?.point, isNull);

      final RouteRetouchRequest point = routeRetouchRequest(
        const RetouchMoveEnd(point: GeoPoint(lng: 2, lat: 48)),
        0,
      );
      expect(point.end?.point, const GeoPoint(lng: 2, lat: 48));
    },
  );

  test('changedCoords : le tronçon neuf, borné à la ligne', () {
    final List<int> line = <int>[0, 1, 2, 3, 4];
    expect(changedCoords(line, 1, 3), <int>[1, 2, 3]);
    expect(changedCoords(line, -2, 9), line);
    expect(changedCoords(line, 3, 1), isEmpty);
  });

  test('retouchHandoff : le type de l’offre', () {
    const RetouchedRouteDto candidate = RetouchedRouteDto(
      polyline: 'abc',
      distanceM: 95300,
      kind: 'LENGTHEN',
      keptShare: 0.88,
      unmatchedM: 0,
      changed: RetouchedSpanDto(
        fromM: 10000,
        toM: 19600,
        newM: 22900,
        startIndex: 1,
        endIndex: 3,
        teamShare: 0.5,
        unpavedShare: 0.1,
        crossings: 0,
      ),
      bounds: BoundsDto(minLon: 0, minLat: 0, maxLon: 1, maxLat: 1),
    );
    final handoff = retouchHandoff(candidate, offer, 'Boucle (retouché)');
    expect(handoff.type, RouteGeneratorType.gravel);
    expect(handoff.polyline, 'abc');
    expect(handoff.name, 'Boucle (retouché)');
    expect(isTruncation(candidate), isFalse);
  });

  group('erreurs', () {
    DioException refusal(String code) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: 400,
        data: <String, dynamic>{'code': code},
      ),
    );

    test('une réponse en bleu, une panne en rouge', () {
      expect(isInfoRetouchError(refusal('ROUTE_RETOUCH_NO_SHORTER')), isTrue);
      expect(isInfoRetouchError(refusal('GENERATOR_UNAVAILABLE')), isFalse);
    });

    test('« Réessayer » seulement quand une même requête peut aboutir', () {
      expect(isRetryableRetouchError(refusal('ROUTE_GENERATOR_BUSY')), isTrue);
      expect(
        isRetryableRetouchError(refusal('ROUTE_RETOUCH_NO_SHORTER')),
        isFalse,
      );
    });

    test('une autre graine aide sur « aucune proposition »', () {
      expect(isOtherSeedUseful(refusal('ROUTE_RETOUCH_NO_PROPOSAL')), isTrue);
      expect(isOtherSeedUseful(refusal('GENERATOR_END_TOO_FAR')), isFalse);
      expect(isNoShorter(refusal('ROUTE_RETOUCH_NO_SHORTER')), isTrue);
    });
  });
}
