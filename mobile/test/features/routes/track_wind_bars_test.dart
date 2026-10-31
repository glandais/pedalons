import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/pdl/elevation/elevation_samples.dart';
import 'package:pedalons/core/theme/enum_colors.dart';
import 'package:pedalons/core/theme/pdl_tokens.dart';
import 'package:pedalons/features/routes/domain/route_elevation_builder.dart';
import 'package:pedalons/features/routes/domain/track_wind_bars.dart';

import '../rides/ride_fixtures.dart';

/// Le vent sous le profil (ledger `MOB-106`) : une valeur par segment des
/// lignes brutes (distance chaînée sans saut), puis la dominante par barre du
/// profil (qui compte le saut entre deux traces) — sans conversion de
/// distance.

/// Une trace de [km] kilomètres plein nord, un sommet par kilomètre, `M`
/// repartant de zéro.
TrackDto _northbound(int km, {double lon = 5}) => TrackDto(
  line: GeoJsonLineString(
    type: GeoJsonLineStringTypeType.lineString,
    coordinates: <List<double>>[
      for (int i = 0; i <= km; i++)
        <double>[lon, 45 + i * 0.009, 300, i * 1000.0],
    ],
  ),
  climbs: const <ClimbDto>[],
);

WindSegmentDto _segment(double from, double to, String wind) => WindSegmentDto(
  fromDistance: from,
  toDistance: to,
  relativeWind: wind,
  headwind: 0,
);

WeatherLegDto _leg(List<WindSegmentDto> segments) =>
    fixtureLeg().copyWith(segments: segments);

void main() {
  test('deux traces : la bande de la seconde est sous ses barres, '
      'le pont entre elles inconnu', () {
    // La seconde trace commence ~55 km à l'est : le profil compte ce saut,
    // les distances du vent non (dos sur 0–10 km, face sur 10–20 km).
    final List<TrackDto> tracks = <TrackDto>[
      _northbound(10),
      _northbound(10, lon: 5.7),
    ];
    final ElevationSamples samples = elevationSamplesFromLines(
      tracks.map((TrackDto t) => t.line.coordinates),
      targetBars: 200,
    )!;
    final double firstEnd = samples.points[10].distance;
    final double secondStart = samples.points[11].distance;
    expect(secondStart - firstEnd, greaterThan(50000));

    final WindBars bars = windBars(
      samples,
      tracks,
      _leg(<WindSegmentDto>[
        _segment(0, 10000, 'TAIL'),
        _segment(10000, 20000, 'HEAD'),
      ]),
    );

    expect(bars.winds, hasLength(samples.bars.length));
    expect(bars.colors, hasLength(samples.bars.length));
    for (int i = 0; i < samples.bars.length; i++) {
      final ElevationBar bar = samples.bars[i];
      if (bar.end <= firstEnd) {
        expect(bars.winds[i], RelativeWind.tail, reason: 'barre $i');
        expect(bars.colors[i], RelativeWind.tail.stroke);
      } else if (bar.start >= secondStart) {
        expect(bars.winds[i], RelativeWind.head, reason: 'barre $i');
        expect(bars.colors[i], RelativeWind.head.stroke);
      } else if (bar.start >= firstEnd && bar.end <= secondStart) {
        expect(bars.winds[i], isNull, reason: 'barre $i (pont)');
        expect(bars.colors[i], slopeNeutral);
      }
    }
    // L'info-bulle lit la barre sous le réticule.
    expect(windTip(samples, bars, secondStart + 5000), RelativeWind.head);
    expect(windTip(samples, bars, 5000), RelativeWind.tail);
  });

  test('un vent inconnu — hors tronçon ou d\'un type inconnu — prend le bleu '
      'neutre, jamais le gris', () {
    final List<TrackDto> tracks = <TrackDto>[_northbound(10)];
    final ElevationSamples samples = elevationSamplesFromLines(
      tracks.map((TrackDto t) => t.line.coordinates),
      targetBars: 10,
    )!;
    final WindBars bars = windBars(
      samples,
      tracks,
      _leg(<WindSegmentDto>[
        _segment(0, 3000, 'CROSS'),
        _segment(3000, 6000, 'GUSTY'),
      ]),
    );

    expect(bars.winds.sublist(0, 3), everyElement(RelativeWind.cross));
    expect(bars.colors[0], RelativeWind.cross.stroke);
    expect(bars.winds.sublist(3), everyElement(isNull));
    expect(bars.colors.sublist(3), everyElement(slopeNeutral));
    expect(windTip(samples, bars, 8000), isNull);
  });

  test('la clé compare le leg par identité', () {
    final WeatherLegDto leg = fixtureLeg();
    expect(WindBarsKey<String>('a', leg), WindBarsKey<String>('a', leg));
    expect(
      WindBarsKey<String>('a', leg) == WindBarsKey<String>('a', leg.copyWith()),
      isFalse,
    );
  });
}
