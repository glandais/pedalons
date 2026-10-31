import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/geo/polyline_index.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/enum_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../domain/ride_weather_map.dart';
import 'ride_weather_map_markers.dart';

/// Le mode « Météo » d'une carte, **hors de la page d'un groupe** : les
/// briques que la carte d'un groupe (`RideGroupsMap`), la carte du détail
/// d'une étape (`RouteMap`) et la carte d'ensemble d'un voyage (`TripMap`)
/// partagent (palier 3 lot B de `docs/plans/archive/2026-10-24-weather-on-map.md`,
/// ledger `MOB-94`).
///
/// Un leg météo (`WeatherLegDto`) a la même forme pour le groupe d'une sortie
/// et pour une étape (`TripStageWeatherDto.leg`) : mêmes points de passage,
/// mêmes tronçons, mêmes statuts, mêmes distances chaînées. Rien ici ne
/// connaît donc la sortie, le groupe ou le voyage — seulement un parcours, un
/// leg et le fuseau des heures de passage.

/// Les lignes brutes d'un parcours, une par trace, dans l'ordre reçu.
List<List<List<double>>> routeLinesOf(RouteDetailDto route) =>
    <List<List<double>>>[
      for (final TrackDto t in route.tracks) t.line.coordinates,
    ];

/// Les couleurs du vent sur [route] pour [leg] (`PdlMapTrack.segmentColors`),
/// **mémorisées par (leg, parcours)** : sur un parcours de
/// plusieurs milliers de sommets, les recalculer à chaque `build` coûterait
/// une recherche par segment pour un résultat identique — et
/// `PdlMapTrack.==` compare la liste élément par élément.
///
/// La mémoire s'accroche au leg (même objet tant que le provider de la météo
/// le garde) et part avec lui ; deux étapes d'un voyage qui roulent le même
/// parcours ont chacune la leur. Un tronçon sans vent connu prend le bleu
/// neutre de la pente ([slopeNeutral], le `NEUTRAL_COLOR` du site) **partout**
/// — groupe, sortie solo, étape, voyage (ledger `MOB-105`) : ni la couleur
/// d'un groupe ou d'une étape, qui pourrait se lire comme un vent, ni le gris,
/// qui dit « travers ».
List<Color> weatherTrackColors(RouteDetailDto route, WeatherLegDto leg) {
  final _WindColors? memo = _windMemo[leg];
  if (memo != null && identical(memo.route, route)) return memo.colors;
  final List<Color> colors = windSegmentColors<Color>(
    routeLinesOf(route),
    leg.segments,
    (RelativeWind? wind) => wind?.stroke ?? slopeNeutral,
  );
  _windMemo[leg] = _WindColors(route, colors);
  return colors;
}

/// Les pastilles et la goutte de [leg] sur [route] (ledger `MOB-92`), sur la
/// carte encastrée comme en plein écran (ledger `MOB-107`) : encastrée, leur
/// toucher ouvre le plein écran (`PdlMapHero.openFullscreen`), en plein
/// écran leur feuille ([openWeatherMapMarker]). Seules les **positions** sont mémorisées, par (leg,
/// parcours) : elles chaînent toutes les distances du parcours. Les libellés
/// se refont à chaque appel — ils suivent la langue et le format horaire du
/// téléphone, que la mémoire ne verrait pas changer.
///
/// [idPrefix] distingue les marqueurs de plusieurs legs sur une même carte
/// (les étapes d'un voyage) ; [openWeatherMapMarker] le reçoit à l'identique.
List<PdlMapMarker> weatherMarkersOnRoute(
  RouteDetailDto route,
  WeatherLegDto leg, {
  required UnitSystem units,
  required String? timezone,
  String idPrefix = '',
}) {
  final _WeatherPoints? memo = _pointsMemo[leg];
  final List<LngLat?> points;
  if (memo != null && identical(memo.route, route)) {
    points = memo.points;
  } else {
    points = rideWeatherMarkerPoints(routeLinesOf(route), leg);
    _pointsMemo[leg] = _WeatherPoints(route, points);
  }
  return rideWeatherMapMarkers(
    points: points,
    leg: leg,
    units: units,
    timezone: timezone,
    idPrefix: idPrefix,
  );
}

final Expando<_WindColors> _windMemo = Expando<_WindColors>(
  'weatherMapWindColors',
);

final Expando<_WeatherPoints> _pointsMemo = Expando<_WeatherPoints>(
  'weatherMapPoints',
);

/// Une entrée de la mémoire des couleurs du vent d'un leg.
class _WindColors {
  const _WindColors(this.route, this.colors);

  final RouteDetailDto route;
  final List<Color> colors;
}

/// Une entrée de la mémoire des positions météo d'un leg.
class _WeatherPoints {
  const _WeatherPoints(this.route, this.points);

  final RouteDetailDto route;
  final List<LngLat?> points;
}

/// La puce « Météo » sous une carte aux couleurs de ses couches — celle d'une
/// sortie solo dont le groupe roule un autre parcours que la sortie : celle-ci
/// ne se manipule pas, la bascule ne
/// peut donc pas vivre dans la vue native (ledger `MOB-91`). En plein écran,
/// la même bascule est dans la feuille des couches ([weatherMapModeSwitch]).
/// Une carte colorée comme un parcours — groupe, sortie solo à un parcours,
/// étape — a l'interrupteur Pente | Revêtement | Météo à la place
/// (`RouteColorModeSwitch`, ledger `MOB-105`), et la carte d'ensemble d'un
/// voyage son interrupteur Étapes | Météo (`TripMap`).
class WeatherMapChip extends StatelessWidget {
  const WeatherMapChip({
    super.key,
    required this.chipKey,
    required this.selected,
    required this.onChanged,
    this.inset = true,
  });

  /// Vrai : la gouttière de section de chaque côté, sous une carte pleine
  /// largeur. Faux dans un bloc déjà encarté.
  final bool inset;

  /// La clé de la puce elle-même (et non de sa rangée) : c'est elle qu'un
  /// test touche.
  final Key chipKey;

  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: inset ? PdlSpacing.section : 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: PdlChip(
        key: chipKey,
        label: 'rides.weather.mapMode'.tr(),
        icon: PdlIcons.wind,
        selected: selected,
        onTap: () => onChanged(!selected),
      ),
    ),
  );
}

/// L'interrupteur « Vent sur le tracé » de la feuille des couches du plein
/// écran, à côté de l'ombrage, sur les cartes de [WeatherMapChip].
PdlMapHeroSwitch weatherMapModeSwitch({
  required bool value,
  required ValueChanged<bool> onChanged,
}) => PdlMapHeroSwitch(
  id: 'wind',
  label: 'rides.weather.mapModeSwitch'.tr(),
  value: value,
  onChanged: onChanged,
);
