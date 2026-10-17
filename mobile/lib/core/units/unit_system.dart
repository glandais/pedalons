/// Table de conversion entre le système métrique et le système impérial.
///
/// **Pur Dart** : ni Flutter, ni `easy_localization`, ni `intl`. La conversion
/// est de l'arithmétique, elle se teste sans binding et sans locale. Le
/// rendu — séparateurs, espaces, arrondis — appartient à `AppFormatters`, et
/// à lui seul.
///
/// L'API parle **toujours** en unités SI : mètres pour les distances et les
/// dénivelés, km/h pour les vitesses. La conversion n'a lieu qu'au moment de
/// l'affichage ; rien de converti ne repart jamais vers le serveur.
library;

import '../../api/generated/models/unit_system.dart';

/// Un mille international, en mètres. Valeur exacte par définition.
const double kMetersPerMile = 1609.344;

/// Un pied international, en mètres. Valeur exacte par définition.
const double kMetersPerFoot = 0.3048;

/// Les symboles d'unité.
///
/// Ils ne sont **pas** traduits : « km », « mi », « ft », « mph » sont des
/// symboles normalisés, identiques en français et en anglais. Les mettre dans
/// les fichiers de traduction inviterait à les traduire, ce qui serait une
/// faute. Seuls les *noms* des systèmes (« Métrique », « Impérial ») vivent
/// dans `assets/l10n`.
abstract final class UnitSymbols {
  static const String kilometer = 'km';
  static const String mile = 'mi';
  static const String meter = 'm';
  static const String foot = 'ft';
  static const String kilometerPerHour = 'km/h';
  static const String milePerHour = 'mph';
  static const String percent = '%';
  static const String celsius = '°C';
  static const String fahrenheit = '°F';

  /// Hauteur de précipitation. Elle ne se convertit pas : le plan météo
  /// (`docs/plans/archive/2026-10-05-weather.md` §1) ne convertit que les
  /// températures et les vitesses.
  static const String millimeter = 'mm';
}

/// Conversions dérivées de [UnitSystem], l'énumération générée depuis le
/// contrat (`METRIC` / `IMPERIAL`).
///
/// [UnitSystem.$unknown] — une valeur que le serveur aurait ajoutée sans que
/// cette version de l'app la connaisse — **se comporte comme
/// [UnitSystem.metric]**, le défaut du produit. Aucun appelant n'a donc à
/// traiter le cas.
extension UnitSystemConversion on UnitSystem {
  bool get isImperial => this == UnitSystem.imperial;

  /// Distance de parcours : mètres → kilomètres ou milles.
  double longDistance(num meters) =>
      isImperial ? meters / kMetersPerMile : meters / 1000;

  String get longDistanceSymbol =>
      isImperial ? UnitSymbols.mile : UnitSymbols.kilometer;

  /// Dénivelé, altitude, écart vertical : mètres → mètres ou pieds.
  double shortDistance(num meters) =>
      isImperial ? meters / kMetersPerFoot : meters.toDouble();

  String get shortDistanceSymbol =>
      isImperial ? UnitSymbols.foot : UnitSymbols.meter;

  /// Vitesse : km/h → km/h ou mph.
  double speed(num kilometersPerHour) => isImperial
      ? kilometersPerHour * 1000 / kMetersPerMile
      : kilometersPerHour.toDouble();

  String get speedSymbol =>
      isImperial ? UnitSymbols.milePerHour : UnitSymbols.kilometerPerHour;

  /// Température : degrés Celsius → Celsius ou Fahrenheit. L'API parle
  /// toujours en °C (prévisions météo).
  double temperature(num celsius) =>
      isImperial ? celsius * 9 / 5 + 32 : celsius.toDouble();

  String get temperatureSymbol =>
      isImperial ? UnitSymbols.fahrenheit : UnitSymbols.celsius;

  /// Chemin inverse, pour les rares endroits qui saisissent dans l'unité
  /// affichée et doivent rendre des mètres à l'API.
  double longDistanceToMeters(num displayed) =>
      isImperial ? displayed * kMetersPerMile : displayed * 1000;

  double shortDistanceToMeters(num displayed) =>
      isImperial ? displayed * kMetersPerFoot : displayed.toDouble();

  /// Une vitesse saisie dans l'unité affichée, rendue en km/h — l'unité du
  /// contrat (`GroupRequest.averageSpeed`).
  double speedToKilometersPerHour(num displayed) =>
      isImperial ? displayed * kMetersPerMile / 1000 : displayed.toDouble();

  /// Clé de traduction du nom du système, pour l'écran de préférences.
  String get labelKey => isImperial ? 'units.imperial' : 'units.metric';
}
