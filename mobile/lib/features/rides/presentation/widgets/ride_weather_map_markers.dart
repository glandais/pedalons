import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import '../../../../core/geo/polyline_index.dart';
import '../../../../core/pdl/pdl.dart';
import '../../../../core/theme/pdl_colors.dart';
import '../../../../core/theme/pdl_icons.dart';
import '../../../../core/theme/pdl_tokens.dart';
import '../../../../core/theme/pdl_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../keys.dart';
import '../../domain/ride_weather_display.dart';
import '../../domain/ride_weather_map.dart';
import 'ride_weather_widgets.dart';

/// Les pastilles météo de la carte d'un groupe, en mode « Météo » (palier 2
/// de `docs/plans/archive/2026-10-24-weather-on-map.md`, ledger `MOB-92`),
/// encastrée comme en plein écran (ledger `MOB-107`).
///
/// Une pastille **compacte** par point de passage qui porte une météo —
/// icône du ciel, température, flèche du vent **absolue** (vers le nord de la
/// carte, même tournée : voir [windArrowOnMap]) —,
/// toutes égales : les verdicts restent dans la frise. Une goutte au point de
/// l'alerte pluie (`leg.rainAlert`, seuil du serveur, jamais recalculé). En
/// plein écran, un toucher ouvre une `PdlSheet` courte avec le détail, comme
/// un point de parcours (`MOB-84`) ; sur la carte encastrée, il ouvre le plein
/// écran.
///
/// Les positions viennent des distances **chaînées sans saut**
/// ([pointsAtDistances]) : la convention des distances météo, pas celle de
/// `PolylineIndex`.

/// L'id de marqueur d'un point de passage.
String weatherCheckpointMarkerId(int index) => 'weather.checkpoint.$index';

/// L'id de marqueur de la goutte de l'alerte pluie.
const String weatherRainMarkerId = 'weather.rain';

/// La taille visuelle d'une pastille : la cible, elle, fait 44 px de haut.
const Size _pastilleSize = Size(96, 32);
const Size _dropSize = Size(32, 32);

/// Les positions des marqueurs météo d'un [leg] sur les [lines] de son
/// parcours : un point par point de passage qui porte une météo, dans
/// l'ordre, puis celui de l'alerte pluie si elle a une distance. `null` pour
/// une distance hors du tracé.
///
/// C'est la partie coûteuse — elle chaîne toutes les distances du parcours :
/// l'écran la mémorise, pas les libellés, qui suivent la langue et le format
/// horaire du téléphone.
List<LngLat?> rideWeatherMarkerPoints(
  List<List<List<double>>> lines,
  WeatherLegDto leg,
) => pointsAtDistances(lines, <double>[
  for (final WeatherCheckpointDto c in leg.checkpoints)
    if (c.weather != null) c.distance,
  ?leg.rainAlert?.distance,
]);

/// Les marqueurs météo d'un leg sur les [lines] de son parcours, ou sur les
/// [points] déjà calculés par [rideWeatherMarkerPoints] pour ce leg.
///
/// La pastille se pose **au-dessus** de son point, la goutte **en dessous** :
/// l'alerte pluie tombe le plus souvent sur un point de passage, et les deux
/// ne se recouvrent pas. Un point sans météo n'a pas de pastille ; une alerte
/// sans distance n'a pas de goutte.
///
/// [idPrefix] précède chaque id : plusieurs legs sur une même carte (les
/// étapes d'un voyage, ledger `MOB-94`) gardent des ids distincts.
/// [openWeatherMapMarker] reçoit le même.
List<PdlMapMarker> rideWeatherMapMarkers({
  List<List<List<double>>>? lines,
  List<LngLat?>? points,
  required WeatherLegDto leg,
  required UnitSystem units,
  required String? timezone,
  String idPrefix = '',
}) {
  assert(lines != null || points != null);
  final List<WeatherCheckpointDto> withWeather = <WeatherCheckpointDto>[
    for (final WeatherCheckpointDto c in leg.checkpoints)
      if (c.weather != null) c,
  ];
  final double? rainDistance = leg.rainAlert?.distance;
  points ??= rideWeatherMarkerPoints(lines!, leg);

  final List<PdlMapMarker> markers = <PdlMapMarker>[];
  for (int i = 0; i < withWeather.length; i++) {
    final LngLat? at = points[i];
    if (at == null) continue;
    final WeatherCheckpointDto c = withWeather[i];
    markers.add(
      PdlMapMarker(
        id: '$idPrefix${weatherCheckpointMarkerId(c.indexField)}',
        lon: at.lng,
        lat: at.lat,
        size: _pastilleSize,
        alignment: Alignment.bottomCenter,
        semanticLabel: weatherCheckpointSummary(c, units, timezone),
        child: RideWeatherPastille(
          key: keys.rideGroup.weatherMapPastille(c.indexField),
          weather: c.weather!,
          units: units,
        ),
      ),
    );
  }
  final WeatherRainAlertDto? alert = leg.rainAlert;
  final LngLat? rainAt = rainDistance == null ? null : points.last;
  if (alert != null && rainAt != null) {
    markers.add(
      PdlMapMarker(
        id: '$idPrefix$weatherRainMarkerId',
        lon: rainAt.lng,
        lat: rainAt.lat,
        size: _dropSize,
        alignment: Alignment.topCenter,
        semanticLabel: formatRainAlert(alert, units, timezone),
        child: RideWeatherRainMark(key: keys.rideGroup.weatherMapRainDrop),
      ),
    );
  }
  return markers;
}

/// Ce qu'annonce une pastille : où, quand, et le temps qu'il fait.
String weatherCheckpointSummary(
  WeatherCheckpointDto c,
  UnitSystem units,
  String? timezone,
) {
  final WeatherConditionsDto? w = c.weather;
  return <String>[
    weatherCheckpointKindLabel(c.kind),
    formatWeatherTime(c.time, timezone),
    AppFormatters.formatDistance(c.distance, units),
    if (w != null) ...<String>[
      AppFormatters.formatTemperature(w.temperature, units),
      weatherConditionOf(w.condition).labelKey.tr(),
      formatWind(w.wind, units, gusts: false),
    ],
  ].join(', ');
}

/// « Départ », « En route », « Arrivée ».
String weatherCheckpointKindLabel(String kind) =>
    switch (WeatherCheckpointKind.fromJson(kind)) {
      WeatherCheckpointKind.start => 'rides.weather.checkpointKind.start',
      WeatherCheckpointKind.finish => 'rides.weather.checkpointKind.finish',
      WeatherCheckpointKind.enRoute ||
      WeatherCheckpointKind.$unknown => 'rides.weather.checkpointKind.enRoute',
    }.tr();

/// Ouvre le détail du marqueur [markerId] du [leg], posé avec [idPrefix]. Rien
/// pour un id inconnu. [PdlSheet.show] est le seul appelant de
/// `showModalBottomSheet`.
Future<void> openWeatherMapMarker(
  BuildContext context,
  String markerId, {
  required WeatherLegDto leg,
  required UnitSystem units,
  required String? timezone,
  String idPrefix = '',
}) async {
  if (!markerId.startsWith(idPrefix)) return;
  final String id = markerId.substring(idPrefix.length);
  if (id == weatherRainMarkerId) {
    final WeatherRainAlertDto? alert = leg.rainAlert;
    if (alert == null) return;
    await PdlSheet.show<void>(
      context: context,
      builder: (BuildContext context) => RideWeatherRainDetails(
        alert: alert,
        units: units,
        timezone: timezone,
      ),
    );
    return;
  }
  for (final WeatherCheckpointDto c in leg.checkpoints) {
    if (weatherCheckpointMarkerId(c.indexField) == id && c.weather != null) {
      await PdlSheet.show<void>(
        context: context,
        builder: (BuildContext context) => RideWeatherCheckpointDetails(
          checkpoint: c,
          units: units,
          timezone: timezone,
        ),
      );
      return;
    }
  }
}

/// L'angle à l'écran de la flèche absolue du vent qui vient de
/// [fromDirection], sur une carte tournée de [bearing] degrés : le nord de la
/// carte, pas le haut de l'écran. Dans [0, 360).
double windArrowOnMap(double fromDirection, double bearing) =>
    (windArrowAngle(fromDirection) - bearing) % 360;

/// La pastille au repos : icône du ciel, température, flèche absolue.
/// Opaque, jamais du texte nu sur la tuile.
class RideWeatherPastille extends StatelessWidget {
  const RideWeatherPastille({
    super.key,
    required this.weather,
    required this.units,
  });

  final WeatherConditionsDto weather;
  final UnitSystem units;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.overlaySolid,
        borderRadius: PdlRadii.pillAll,
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PdlSpacing.chipGap),
        // À 130 % d'agrandissement, le contenu se réduit plutôt que de
        // déborder de la pastille, dont la taille est fixée pour la carte.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              WeatherConditionIcon(
                condition: weather.condition,
                daylight: weather.daylight,
                size: 18,
              ),
              const SizedBox(width: PdlSpacing.badgeGap),
              Text(
                AppFormatters.formatTemperature(weather.temperature, units),
                style: t.bodyStrong.copyWith(color: c.text),
              ),
              const SizedBox(width: PdlSpacing.badgeGap),
              // Absolue, donc par rapport au nord **de la carte** : la
              // pastille reste droite quand la carte tourne, la flèche
              // retranche le cap pour montrer encore le vrai vent.
              PdlWindArrow(
                angle: windArrowOnMap(
                  weather.wind.direction,
                  PdlMapBearing.of(context),
                ),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La goutte de l'alerte pluie. La pluie n'a pas de couleur (BRANDING §3.6) :
/// la goutte est au texte courant, sur fond opaque.
class RideWeatherRainMark extends StatelessWidget {
  const RideWeatherRainMark({super.key});

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.overlaySolid,
        shape: BoxShape.circle,
        border: Border.all(color: c.border),
      ),
      child: Center(
        child: Icon(PdlIcons.precipitation, size: 18, color: c.text),
      ),
    );
  }
}

/// Le détail d'un point de passage : heure de passage (fuseau de la sortie),
/// distance, ciel et température, probabilité de pluie si le modèle en
/// donne une, quantité de précipitations si elle n'est pas nulle, vent et
/// rafales — **rien** quand le modèle n'a pas de rafales, jamais « 0 ».
class RideWeatherCheckpointDetails extends StatelessWidget {
  const RideWeatherCheckpointDetails({
    super.key,
    required this.checkpoint,
    required this.units,
    required this.timezone,
  });

  final WeatherCheckpointDto checkpoint;
  final UnitSystem units;
  final String? timezone;

  @override
  Widget build(BuildContext context) {
    final PdlColors c = context.pdl;
    final PdlTypography t = context.pdlText;
    final WeatherCheckpointDto p = checkpoint;
    final WeatherConditionsDto w = p.weather!;
    final int? probability = w.precipitationProbability;
    final double? gusts = w.wind.gusts;

    return PdlSheet(
      key: keys.rideGroup.weatherMapSheet,
      header: Row(
        children: <Widget>[
          WeatherConditionIcon(
            condition: w.condition,
            daylight: w.daylight,
            size: 28,
          ),
          const SizedBox(width: PdlSpacing.sectionTightV),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  weatherCheckpointKindLabel(p.kind),
                  style: t.xs.copyWith(color: c.textDimmed),
                ),
                Text(
                  'rides.weather.mapPassage'.tr(
                    namedArgs: <String, String>{
                      'time': formatWeatherTime(p.time, timezone),
                    },
                  ),
                  style: t.sectionTitle,
                ),
              ],
            ),
          ),
        ],
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PdlSpacing.sectionTightH,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'rides.weather.mapFromStart'.tr(
                  namedArgs: <String, String>{
                    'distance': AppFormatters.formatDistance(p.distance, units),
                  },
                ),
                style: t.mono.copyWith(color: c.textDimmed),
              ),
              const SizedBox(height: PdlSpacing.sectionTightV),
              Text(
                '${AppFormatters.formatTemperature(w.temperature, units)}'
                ' · ${weatherConditionOf(w.condition).labelKey.tr()}',
                style: t.bodyStrong,
              ),
              if (probability != null)
                _line(
                  context,
                  PdlIcons.precipitation,
                  'rides.weather.rainChance'.tr(
                    namedArgs: <String, String>{
                      'probability': AppFormatters.formatPercent(probability),
                    },
                  ),
                ),
              if (w.precipitation > 0)
                _line(
                  context,
                  PdlIcons.precipitation,
                  'rides.weather.precipitation'.tr(
                    namedArgs: <String, String>{
                      'amount': AppFormatters.formatPrecipitation(
                        w.precipitation,
                      ),
                    },
                  ),
                ),
              _line(
                context,
                null,
                formatWind(w.wind, units, gusts: false),
                leading: PdlWindArrow(
                  angle: windArrowAngle(w.wind.direction),
                  size: 18,
                ),
              ),
              if (gusts != null)
                _line(
                  context,
                  PdlIcons.wind,
                  'rides.weather.mapGusts'.tr(
                    namedArgs: <String, String>{
                      'speed': AppFormatters.formatSpeed(gusts, units),
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _line(
    BuildContext context,
    IconData? icon,
    String text, {
    Widget? leading,
  }) {
    final PdlColors c = context.pdl;
    return Padding(
      padding: const EdgeInsets.only(top: PdlSpacing.chipGap),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 20,
            child: leading ?? Icon(icon, size: 18, color: c.textDimmed),
          ),
          const SizedBox(width: PdlSpacing.chipGap),
          Expanded(child: Text(text, style: context.pdlText.body)),
        ],
      ),
    );
  }
}

/// Le détail de la goutte : la phrase de l'alerte pluie, son heure dans le
/// fuseau de la sortie.
class RideWeatherRainDetails extends StatelessWidget {
  const RideWeatherRainDetails({
    super.key,
    required this.alert,
    required this.units,
    required this.timezone,
  });

  final WeatherRainAlertDto alert;
  final UnitSystem units;
  final String? timezone;

  @override
  Widget build(BuildContext context) {
    final PdlTypography t = context.pdlText;
    return PdlSheet(
      key: keys.rideGroup.weatherMapSheet,
      header: Row(
        children: <Widget>[
          WeatherConditionIcon(
            condition: alert.condition,
            daylight: true,
            size: 28,
          ),
          const SizedBox(width: PdlSpacing.sectionTightV),
          Expanded(
            child: Text(
              'rides.weather.mapRainTitle'.tr(),
              style: t.sectionTitle,
            ),
          ),
        ],
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PdlSpacing.sectionTightH,
          ),
          child: Text(formatRainAlert(alert, units, timezone), style: t.body),
        ),
      ],
    );
  }
}
