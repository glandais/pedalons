import 'package:flutter/material.dart';

import '../../../../api/generated/export.dart';
import 'ride_weather_summary_line.dart';

/// La ligne météo d'un groupe — **non cliquable** (ledger `MOB-67`) : la ligne
/// météo d'une carte ([RideWeatherSummaryLine], KIT §8, ledger `MOB-134`) lue
/// sur le résumé du leg **du groupe** (`WeatherLegDto.summary`, API 13.5.0) —
/// sa plage de températures, son vent au départ, sa pluie ou son alerte.
/// Plus de ciel en toutes lettres ni de badges Face / Dos dans la carte : la
/// section Météo de la page du groupe les porte.
///
/// Rien n'est rendu sans résumé à montrer : la carte d'un groupe ne réserve
/// pas de place à une ligne vide. Portée par la carte d'un groupe du détail
/// et par l'aperçu de sa page.
class RideGroupWeatherLine extends StatelessWidget {
  const RideGroupWeatherLine({
    super.key,
    required this.leg,
    required this.timezone,
    required this.units,
  });

  final WeatherLegDto? leg;

  /// Le fuseau de la sortie, où se lit l'heure de l'alerte pluie.
  final String? timezone;
  final UnitSystem units;

  /// La ligne a-t-elle quelque chose à montrer ?
  static bool shows(WeatherLegDto? leg) =>
      RideWeatherSummaryLine.shows(leg?.summary);

  @override
  Widget build(BuildContext context) => RideWeatherSummaryLine(
    summary: leg?.summary,
    timezone: timezone,
    units: units,
  );
}
