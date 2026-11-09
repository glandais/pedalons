import '../../../api/generated/export.dart';
import '../../../core/utils/formatters.dart';

/// L'instant de départ **qui concerne la personne** : celui du groupe qu'elle a
/// rejoint [joined], sinon celui de la sortie [rideDateTime] — un instant du
/// contrat, à lire dans le fuseau de la sortie.
///
/// La source unique de « mon heure » (docs/LEDGER_*.md MOB-112) : un écran qui
/// prend `ride.dateTime` alors que le groupe rejoint est connu montre une autre
/// heure que son voisin dès que ce groupe part plus tôt ou plus tard.
/// `RideGroupDto.startAt` est toujours renseigné ; `time`, déprécié, n'est
/// jamais lu.
String myStartAt(String rideDateTime, RideGroupDto? joined) =>
    joined?.startAt ?? rideDateTime;

/// Vrai quand un groupe part à une autre heure que sa sortie.
///
/// `RideGroupDto.startAt` est toujours renseigné — il vaut `RideDto.dateTime`
/// pour un groupe qui part avec la sortie — et `time` est déprécié
/// (docs/LEDGER_*.md API-60) : la règle « pas d'heure propre, rien
/// d'affiché » se lit donc en comparant les deux **instants**, jamais les
/// chaînes, qui peuvent différer d'écriture pour un même instant.
bool groupLeavesAtOwnTime(String startAt, String rideDateTime) {
  final DateTime? start = DateTime.tryParse(startAt);
  final DateTime? ride = DateTime.tryParse(rideDateTime);
  if (start == null || ride == null) return false;
  return !start.isAtSameMomentAs(ride);
}

/// Les groupes d'une sortie affichent-ils leur départ ? Dès que l'un part à
/// une autre heure que [reference] (l'heure d'en-tête), tous l'affichent : un
/// groupe sans heure se lirait comme « pas d'heure ». Même règle que
/// `someGroupLeavesAtOwnTime` au web.
bool someGroupLeavesAtOwnTime(Iterable<String> startAts, String reference) =>
    startAts.any((String startAt) => groupLeavesAtOwnTime(startAt, reference));

/// L'heure de départ d'un groupe, dans le fuseau de sa sortie [timezone] :
/// « 08:30 » ou « 8:30 AM » selon le réglage du téléphone — jamais le
/// « 08:30:00 » brut de l'ancien champ `time`.
String formatGroupStart(String startAt, String timezone) {
  final DateTime? wall = AppFormatters.tryParseZoneTime(startAt, timezone);
  return wall == null ? '—' : AppFormatters.formatTime(wall);
}
