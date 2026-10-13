import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';

import '../../../api/generated/export.dart';
import '../../../core/theme/pdl_icons.dart';
import '../../../core/utils/formatters.dart';

/// La seule table de rendu de la météo côté mobile : condition → icône et
/// libellé, vent relatif et rose des vents → libellé, statut → ce que
/// l'écran montre.
///
/// Les enums de la réponse arrivent en `String` : chaque lecture passe par le
/// `fromJson` généré, dont le repli `$unknown` est traité ici **une fois**.
/// Un statut inconnu ne montre rien (`docs/plans/archive/2026-10-05-weather.md` §3),
/// une condition inconnue un nuage, un vent relatif ou un point cardinal
/// inconnu est simplement omis.
///
/// Aucun calcul météo : le serveur fait tout (passages, vent relatif,
/// exposition, alerte pluie) ; l'app traduit et convertit les unités.

/// Ce que la carte et l'écran rendent pour un statut donné.
enum RideWeatherView {
  /// Rien : sortie terminée ou annulée (`OUT_OF_RANGE`), statut inconnu, ou
  /// `NO_LOCATION` pour qui n'organise pas.
  hidden,

  /// La prévision (`OK`).
  forecast,

  /// La prévision, signalée comme ancienne (`STALE`).
  stale,

  /// « Prévision disponible à partir du… » (`NOT_YET_AVAILABLE`).
  notYetAvailable,

  /// « Météo indisponible » et « Réessayer » (`UNAVAILABLE`).
  unavailable,

  /// Le mot aux organisateurs : il manque un lieu ou un parcours.
  noLocation,
}

/// Le rendu d'un statut de `RideWeatherDto` (ou d'une étape).
RideWeatherView rideWeatherViewOf(
  String status, {
  required bool canSeeNoLocation,
}) => switch (WeatherStatus.fromJson(status)) {
  WeatherStatus.ok => RideWeatherView.forecast,
  WeatherStatus.stale => RideWeatherView.stale,
  WeatherStatus.notYetAvailable => RideWeatherView.notYetAvailable,
  WeatherStatus.unavailable => RideWeatherView.unavailable,
  WeatherStatus.noLocation =>
    canSeeNoLocation ? RideWeatherView.noLocation : RideWeatherView.hidden,
  WeatherStatus.outOfRange => RideWeatherView.hidden,
  WeatherStatus.$unknown => RideWeatherView.hidden,
};

/// Peut-on voir le message `NO_LOCATION` ? Les organisateurs et
/// administrateurs de l'équipe, et l'administrateur de la plateforme — ceux
/// qui peuvent corriger la sortie. Un rôle inconnu n'ouvre rien.
bool canSeeWeatherNoLocation({
  required TeamRole? teamRole,
  required bool platformAdmin,
}) =>
    platformAdmin ||
    teamRole == TeamRole.organizer ||
    teamRole == TeamRole.admin;

/// La ligne de résumé d'une carte se montre-t-elle ? Seulement pour les trois
/// statuts que le serveur y met — un statut inconnu ne montre rien.
bool showsWeatherSummary(RideWeatherSummaryDto? summary) {
  if (summary == null) return false;
  return switch (WeatherStatus.fromJson(summary.status)) {
    WeatherStatus.ok ||
    WeatherStatus.stale ||
    WeatherStatus.notYetAvailable => true,
    _ => false,
  };
}

/// Le leg **de ce groupe** — celui qui porte son `groupId` —, et lui seul :
/// `null` s'il n'en a pas. Jamais de repli sur un autre leg, qui prêterait au
/// groupe la météo d'un autre parcours (ledger `MOB-67`).
WeatherLegDto? weatherLegOfGroup(List<WeatherLegDto> legs, String groupId) {
  for (final WeatherLegDto leg in legs) {
    if (leg.groupId == groupId) return leg;
  }
  return null;
}

/// L'angle d'une flèche de vent **absolu**, nord en haut : le vent souffle
/// vers l'opposé de la direction d'où il vient.
double windArrowAngle(double fromDirection) => (fromDirection + 180) % 360;

extension WeatherConditionDisplay on WeatherCondition {
  /// L'icône, de jour ou de nuit. Repli : un nuage.
  IconData icon({required bool daylight}) => switch (this) {
    WeatherCondition.clear || WeatherCondition.mostlyClear =>
      daylight ? PdlIcons.weatherClearDay : PdlIcons.weatherClearNight,
    WeatherCondition.partlyCloudy =>
      daylight
          ? PdlIcons.weatherPartlyCloudyDay
          : PdlIcons.weatherPartlyCloudyNight,
    WeatherCondition.overcast => PdlIcons.weatherOvercast,
    WeatherCondition.fog => PdlIcons.weatherFog,
    WeatherCondition.drizzle => PdlIcons.weatherDrizzle,
    WeatherCondition.rain => PdlIcons.weatherRain,
    WeatherCondition.heavyRain => PdlIcons.weatherHeavyRain,
    WeatherCondition.freezingRain => PdlIcons.weatherFreezingRain,
    WeatherCondition.showers => PdlIcons.weatherShowers,
    WeatherCondition.snow => PdlIcons.weatherSnow,
    WeatherCondition.thunderstorm => PdlIcons.weatherThunderstorm,
    WeatherCondition.$unknown => PdlIcons.weatherUnknown,
  };

  String get labelKey => this == WeatherCondition.$unknown
      ? 'rides.weather.condition.unknown'
      : 'rides.weather.condition.$name';
}

/// Lecture tolérante d'une condition du contrat.
WeatherCondition weatherConditionOf(String? condition) => condition == null
    ? WeatherCondition.$unknown
    : WeatherCondition.fromJson(condition);

/// Lecture tolérante d'un vent relatif : `null` pour une valeur absente ou
/// inconnue — l'écran omet alors libellé et teinte.
RelativeWind? relativeWindOf(String? value) {
  if (value == null) return null;
  final RelativeWind wind = RelativeWind.fromJson(value);
  return wind == RelativeWind.$unknown ? null : wind;
}

extension RelativeWindDisplay on RelativeWind {
  String get labelKey => 'rides.weather.relativeWind.$name';
  String get shortLabelKey => 'rides.weather.relativeWindShort.$name';
}

/// Le point cardinal traduit (« NO », « SW »), ou `null` s'il est inconnu.
String? compassLabel(String compass) {
  final CompassPoint point = CompassPoint.fromJson(compass);
  if (point == CompassPoint.$unknown) return null;
  return 'rides.weather.compass.${point.name}'.tr();
}

/// « Vent NO 18 km/h », ou « Vent 18 km/h » sans point cardinal connu. Les
/// rafales suivent quand elles sont connues.
String formatWind(WindDto wind, UnitSystem units, {bool gusts = true}) {
  final String speed = AppFormatters.formatSpeed(wind.speed, units);
  final String? compass = compassLabel(wind.compass);
  final String base = compass == null
      ? 'rides.weather.wind'.tr(namedArgs: <String, String>{'speed': speed})
      : 'rides.weather.windFrom'.tr(
          namedArgs: <String, String>{'speed': speed, 'compass': compass},
        );
  if (!gusts || wind.gusts == null) return base;
  final String g = 'rides.weather.gusts'.tr(
    namedArgs: <String, String>{
      'speed': AppFormatters.formatSpeed(wind.gusts!, units),
    },
  );
  return '$base, $g';
}

/// L'heure d'un passage météo (24 h ou 12 h selon le téléphone) ; `—` s'il est
/// illisible.
///
/// Un passage — départ et arrivée d'un leg, point de la frise, alerte pluie,
/// lever et coucher du soleil — est un **rendez-vous** : il se lit dans le
/// fuseau [zone] de la sortie ou de l'étape (`RideDto.timezone`,
/// `TripStageDto.timezone`), comme son heure de départ, et **sans mention** —
/// la carte ou l'en-tête de l'entité la porte déjà, une fois. Un fuseau absent
/// ou inconnu retombe sur le fuseau d'affichage. Les legs partent du
/// `start_at` stocké de leur groupe (docs/LEDGER_*.md API-60).
String formatWeatherTime(String iso, String? zone) {
  final DateTime? at = DateTime.tryParse(iso);
  return at == null
      ? '—'
      : AppFormatters.formatTime(AppFormatters.toZoneTime(at, zone));
}

/// L'alerte pluie, en une phrase, son heure dans le fuseau [zone] de l'entité.
String formatRainAlert(
  WeatherRainAlertDto alert,
  UnitSystem units,
  String? zone,
) {
  final Map<String, String> args = <String, String>{
    'probability': AppFormatters.formatPercent(alert.probability),
    'time': formatWeatherTime(alert.time, zone),
  };
  if (alert.distance == null) {
    return 'rides.weather.rainAlert'.tr(namedArgs: args);
  }
  return 'rides.weather.rainAlertAt'.tr(
    namedArgs: <String, String>{
      ...args,
      'distance': AppFormatters.formatDistance(alert.distance!, units),
    },
  );
}
