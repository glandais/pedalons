import 'package:flutter/foundation.dart';

import '../../../api/generated/export.dart';
import '../../../core/utils/formatters.dart';
import '../../rides/domain/ride_form.dart';

/// Les bornes de la vitesse moyenne en km/h, copie de
/// `GpxLimits.MIN_AVERAGE_SPEED_KMH` et `MAX_AVERAGE_SPEED_KMH` du serveur
/// (et de `departure.ts` du site) : une vitesse minuscule pousserait les
/// passages hors de la prévision.
const double kMinAverageSpeedKmh = 10;
const double kMaxAverageSpeedKmh = 60;

/// Un aperçu est purgé au bout de ce nombre de jours : un départ plus
/// lointain partirait avec lui.
const int kPreviewRetentionDays = 30;

/// Ce que portent les champs du départ d'un aperçu (docs/LEDGER_*.md
/// MOB-178) : l'heure **au point de départ du tracé**, une heure murale sans
/// fuseau (`yyyy-MM-ddTHH:mm:ss`, le serveur la lit dans le fuseau du premier
/// point), et une vitesse moyenne, toujours en km/h. Les deux sont
/// facultatives et indépendantes.
@immutable
class PreviewDeparture {
  const PreviewDeparture({this.departure, this.averageSpeed});

  /// Le départ enregistré de [preview], tel que le formulaire l'ouvre.
  factory PreviewDeparture.of(GpxPreviewDto preview) {
    final DateTime? instant = DateTime.tryParse(preview.departureTime ?? '');
    final String? zone = preview.departureTimezone;
    return PreviewDeparture(
      departure: instant == null || zone == null
          ? null
          : wallTimeOf(AppFormatters.toZoneTime(instant, zone)),
      averageSpeed: preview.averageSpeed,
    );
  }

  final String? departure;
  final double? averageSpeed;

  PreviewDeparture copyWith({
    String? Function()? departure,
    double? Function()? averageSpeed,
  }) => PreviewDeparture(
    departure: departure == null ? this.departure : departure(),
    averageSpeed: averageSpeed == null ? this.averageSpeed : averageSpeed(),
  );

  @override
  bool operator ==(Object other) =>
      other is PreviewDeparture &&
      other.departure == departure &&
      other.averageSpeed == averageSpeed;

  @override
  int get hashCode => Object.hash(departure, averageSpeed);
}

/// Ce que le serveur apprend, à la forme de `GpxPreviewUpdateRequest` : rien
/// pour ce qui n'a pas bougé (le serveur le garde, et fait suivre la date au
/// tracé), une valeur pour ce qui a été posé ou changé, un `clear…` pour ce
/// qui a été vidé. La règle de `departureChange` du site.
typedef PreviewDepartureChange = ({
  String? departure,
  bool clearDeparture,
  double? averageSpeed,
  bool clearAverageSpeed,
});

PreviewDepartureChange previewDepartureChange(
  PreviewDeparture initial,
  PreviewDeparture current,
) {
  final bool dateMoved = current.departure != initial.departure;
  final bool speedMoved = current.averageSpeed != initial.averageSpeed;
  return (
    departure: dateMoved ? current.departure : null,
    clearDeparture: dateMoved && current.departure == null,
    averageSpeed: speedMoved ? current.averageSpeed : null,
    clearAverageSpeed: speedMoved && current.averageSpeed == null,
  );
}

/// La vitesse est-elle dans les bornes du serveur ? `null` (aucune) l'est.
bool averageSpeedValid(double? kmh) =>
    kmh == null || (kmh >= kMinAverageSpeedKmh && kmh <= kMaxAverageSpeedKmh);
