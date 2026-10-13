import '../../../core/utils/formatters.dart';

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

/// L'heure de départ d'un groupe, dans le fuseau de sa sortie [timezone] :
/// « 08:30 » ou « 8:30 AM » selon le réglage du téléphone — jamais le
/// « 08:30:00 » brut de l'ancien champ `time`.
String formatGroupStart(String startAt, String timezone) {
  final DateTime? wall = AppFormatters.tryParseZoneTime(startAt, timezone);
  return wall == null ? '—' : AppFormatters.formatTime(wall);
}

/// Où se place le départ d'un groupe par rapport à celui de sa sortie.
enum GroupStartRelation {
  /// Le groupe part avant l'heure de la sortie.
  before,

  /// Le groupe part avec la sortie — le cas courant.
  same,

  /// Le groupe part après l'heure de la sortie.
  after;

  /// La clé de traduction : « avant / avec / après la sortie ».
  String get labelKey => 'rides.groupPage.stats.$name';
}

/// [startAt] comparé à [rideDateTime], **en instants** — jamais en chaînes,
/// qui peuvent s'écrire autrement pour un même instant. Illisible : `same`.
GroupStartRelation groupStartRelation(String startAt, String rideDateTime) {
  final DateTime? start = DateTime.tryParse(startAt);
  final DateTime? ride = DateTime.tryParse(rideDateTime);
  if (start == null || ride == null || start.isAtSameMomentAs(ride)) {
    return GroupStartRelation.same;
  }
  return start.isBefore(ride)
      ? GroupStartRelation.before
      : GroupStartRelation.after;
}
