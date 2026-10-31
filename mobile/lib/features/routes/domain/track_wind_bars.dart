import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import '../../../core/pdl/elevation/elevation_samples.dart';
import '../../../core/theme/enum_colors.dart';
import '../../../core/theme/pdl_tokens.dart';
import '../../rides/domain/ride_weather_map.dart';
import 'track_surfaces.dart';

/// Le vent sous le profil, en mode Météo (ledger `MOB-106`, le pendant de
/// `WEB-129`) : une bande dos / travers / face, une couleur par barre.
///
/// **Aucune conversion de distance.** Le vent se place en distance chaînée
/// sans saut ([chainedMeasures]), le profil en `PolylineIndex`, qui compte le
/// saut entre deux traces : convertir l'un dans l'autre décalerait la bande
/// dès la deuxième trace. On fait donc comme le revêtement et la pente des
/// montées — une valeur par segment des lignes brutes ([windSegmentColors],
/// la règle de la carte), puis la valeur dominante par barre ([barDominant],
/// qui ignore le pont entre deux traces).

/// Le vent et la couleur de chaque barre du profil, mémorisés avec lui :
/// `ElevationBandPainter` compare ses couleurs par identité.
@immutable
class WindBars {
  const WindBars({required this.winds, required this.colors});

  /// Le vent qui couvre la plus grande longueur de chaque barre, `null` quand
  /// il est inconnu (hors de tout tronçon, type que ce client ne connaît pas,
  /// pont entre deux traces).
  final List<RelativeWind?> winds;

  /// La couleur du tracé ([RelativeWindStroke.stroke]) de chaque vent,
  /// [slopeNeutral] d'un vent inconnu — jamais le gris, qui dit « travers ».
  final List<Color> colors;
}

/// L'ordre des égalités : celui de la légende (dos, travers, face), l'inconnu
/// en dernier.
const List<RelativeWind> _order = <RelativeWind>[
  RelativeWind.tail,
  RelativeWind.cross,
  RelativeWind.head,
  RelativeWind.$unknown,
];

/// Les barres de [samples] colorées par le vent de [leg] sur [tracks]. Un
/// segment au vent inconnu compte comme tel (`$unknown`) : une barre surtout
/// inconnue reste inconnue, plutôt que de prendre le vent d'un bout.
WindBars windBars(
  ElevationSamples samples,
  List<TrackDto> tracks,
  WeatherLegDto leg,
) {
  // Une valeur par intervalle des lignes brutes aplaties, comme la carte.
  final List<RelativeWind> flat = windSegmentColors<RelativeWind>(
    <List<List<double>>>[for (final TrackDto t in tracks) t.line.coordinates],
    leg.segments,
    (RelativeWind? wind) => wind ?? RelativeWind.$unknown,
  );
  final Map<TrackDto, List<RelativeWind>> byTrack =
      Map<TrackDto, List<RelativeWind>>.identity();
  int at = 0;
  for (final TrackDto t in tracks) {
    final int n = t.line.coordinates.length < 2
        ? 0
        : t.line.coordinates.length - 1;
    byTrack[t] = flat.sublist(at, at + n);
    at += n;
  }

  final List<RelativeWind?> dominant = barDominant<RelativeWind>(
    samples,
    tracks,
    (TrackDto t, List<List<double>> coords) {
      final List<RelativeWind>? own = byTrack[t];
      final int count = coords.length - 1;
      // Des coordonnées écartées (sans longitude/latitude) désaligneraient la
      // liste : le vent de cette trace se lit alors inconnu.
      return own != null && own.length == count
          ? own
          : List<RelativeWind>.filled(count, RelativeWind.$unknown);
    },
    order: _order,
  );

  final List<RelativeWind?> winds = <RelativeWind?>[
    for (final RelativeWind? w in dominant)
      w == RelativeWind.$unknown ? null : w,
  ];
  return WindBars(
    winds: List<RelativeWind?>.unmodifiable(winds),
    colors: List<Color>.unmodifiable(<Color>[
      for (final RelativeWind? w in winds) w?.stroke ?? slopeNeutral,
    ]),
  );
}

/// Le vent de la barre sous le réticule, pour l'info-bulle : `null` s'il est
/// inconnu.
RelativeWind? windTip(ElevationSamples samples, WindBars bars, double at) {
  final ElevationBar? bar = samples.barAt(at);
  if (bar == null) return null;
  final int index = samples.bars.indexOf(bar);
  if (index < 0 || index >= bars.winds.length) return null;
  return bars.winds[index];
}

/// La clé d'un provider de [WindBars] : un parcours et un leg, **le leg par
/// identité** — le comparer par valeur parcourrait tous ses points et
/// tronçons à chaque lecture, pour un leg que le provider de la météo garde
/// tel quel tant qu'il ne change pas.
@immutable
class WindBarsKey<K> {
  const WindBarsKey(this.route, this.leg);

  final K route;
  final WeatherLegDto leg;

  @override
  bool operator ==(Object other) =>
      other is WindBarsKey<K> &&
      other.route == route &&
      identical(other.leg, leg);

  @override
  int get hashCode => Object.hash(route, identityHashCode(leg));
}
