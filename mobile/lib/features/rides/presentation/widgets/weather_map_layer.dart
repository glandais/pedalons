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
/// **mémorisées par (leg, parcours, couleur de repli)** : sur un parcours de
/// plusieurs milliers de sommets, les recalculer à chaque `build` coûterait
/// une recherche par segment pour un résultat identique — et
/// `PdlMapTrack.==` compare la liste élément par élément.
///
/// La mémoire s'accroche au leg (même objet tant que le provider de la météo
/// le garde) et part avec lui ; deux étapes d'un voyage qui roulent le même
/// parcours ont chacune la leur. Un tronçon sans vent connu garde
/// [fallback], le trait du tracé — **jamais le gris**, qui dit « travers ».
List<Color> weatherTrackColors(
  RouteDetailDto route,
  WeatherLegDto leg,
  Color fallback,
) {
  final _WindColors? memo = _windMemo[leg];
  if (memo != null &&
      identical(memo.route, route) &&
      memo.fallback == fallback) {
    return memo.colors;
  }
  final List<Color> colors = windSegmentColors<Color>(
    routeLinesOf(route),
    leg.segments,
    (RelativeWind? wind) => wind?.stroke ?? fallback,
  );
  _windMemo[leg] = _WindColors(route, fallback, colors);
  return colors;
}

/// Les pastilles et la goutte de [leg] sur [route] (plein écran seulement,
/// ledger `MOB-92`). Seules les **positions** sont mémorisées, par (leg,
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
  const _WindColors(this.route, this.fallback, this.colors);

  final RouteDetailDto route;
  final Color fallback;
  final List<Color> colors;
}

/// Une entrée de la mémoire des positions météo d'un leg.
class _WeatherPoints {
  const _WeatherPoints(this.route, this.points);

  final RouteDetailDto route;
  final List<LngLat?> points;
}

/// La puce « Météo » sous une carte encastrée : celle-ci ne se manipule pas,
/// la bascule ne peut donc pas vivre dans la vue native (ledger `MOB-91`). En
/// plein écran, la même bascule est dans la feuille des couches
/// ([weatherMapModeSwitch]).
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
/// écran, à côté de l'ombrage.
PdlMapHeroSwitch weatherMapModeSwitch({
  required bool value,
  required ValueChanged<bool> onChanged,
}) => PdlMapHeroSwitch(
  id: 'wind',
  label: 'rides.weather.mapModeSwitch'.tr(),
  value: value,
  onChanged: onChanged,
);

/// La légende posée en bas à gauche d'une carte, dans le `foreground` de
/// `PdlMapHero` : elle vit dans la coquille et non dans les `overlays` de la
/// carte, qui n'apparaissent qu'une fois la vue native prête — la légende se
/// lit sans elle. Le coin droit reste au crédit ⓘ des tuiles.
///
/// [passTouches] : sur une vignette qui s'ouvre au toucher, la légende ne
/// garde pas le doigt pour elle.
Widget weatherMapLegendLayer({
  required bool fullscreen,
  required Widget legend,
  bool passTouches = false,
}) => Positioned(
  left: PdlSpacing.sectionTightV,
  right: PdlMetrics.tapTarget + PdlSpacing.sectionTightV,
  bottom: PdlSpacing.sectionTightV,
  child: SafeArea(
    top: false,
    left: fullscreen,
    right: false,
    bottom: fullscreen,
    child: Align(
      alignment: Alignment.bottomLeft,
      child: IgnorePointer(ignoring: passTouches, child: legend),
    ),
  ),
);
