import 'package:easy_localization/easy_localization.dart';

import '../../../core/utils/formatters.dart';

/// « En cours » : une sortie ou un voyage parti et pas encore rentré —
/// `dateTime <= now < endDateTime`, la fin que le serveur stocke (ledger
/// `API-85`). Un état dérivé côté client, comme « J'y vais » : le `finished`
/// de l'API ne dit que « départ passé ». Une sortie annulée n'est jamais en
/// cours. Une telle sortie garde sa place dans « À venir » de l'Agenda
/// (`when=UPCOMING` lit la même fin). Même règle que `isUnderWay` au web
/// (`frontend/src/utils/publicationTiming.ts`).
///
/// Les instants du contrat se comparent tels quels, en UTC — jamais leur
/// heure de cadran convertie.
bool isUnderWay({
  required String dateTime,
  required String endDateTime,
  required String status,
  DateTime? now,
}) {
  if (status == 'CANCELLED') return false;
  final DateTime? start = DateTime.tryParse(dateTime);
  final DateTime? end = DateTime.tryParse(endDateTime);
  if (start == null || end == null) return false;
  final DateTime at = (now ?? DateTime.now()).toUtc();
  return !start.isAfter(at) && at.isBefore(end);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Le départ et le retour d'une sortie : « demain 08:30 → retour vers 14:10 ».
/// « vers », la fin étant estimée sur la distance et l'allure des groupes ;
/// un retour un autre jour nomme ce jour (« retour vers sam. 17 oct. 02:00 »).
///
/// Les deux bouts se lisent dans le fuseau de la sortie [timezone] — ce sont
/// des rendez-vous (docs/LEDGER_*.md API-60, plan §7) ; « aujourd'hui » et
/// « demain » restent relatifs au lecteur. La mention, une seule pour la plage,
/// est à l'appelant : `AppFormatters.formatZoneMention` au départ.
///
/// `null` quand l'une des deux dates est illisible : l'appelant garde alors
/// la date seule.
String? rideTimeSpan(
  String dateTime,
  String endDateTime, {
  required String timezone,
  DateTime? now,
}) {
  final DateTime? instant = DateTime.tryParse(dateTime);
  final DateTime? start = AppFormatters.tryParseZoneTime(dateTime, timezone);
  final DateTime? end = AppFormatters.tryParseZoneTime(endDateTime, timezone);
  if (instant == null || start == null || end == null) return null;
  final String back = _sameDay(start, end)
      ? AppFormatters.formatTime(end)
      : '${_shortDay(end, withMonth: true)} ${AppFormatters.formatTime(end)}';
  return '${AppFormatters.formatRideDate(instant, now: now, zone: timezone)} → '
      '${'teams.agenda.returnAround'.tr(namedArgs: <String, String>{'time': back})}';
}

/// Les jours d'un voyage : « ven. 16 → dim. 18 oct. », le mois une seule fois
/// quand il ne change pas ; « ven. 16 oct. » sur un seul jour.
///
/// Le départ se lit dans le fuseau du voyage [timezone] (celui de sa première
/// étape), la fin dans [endTimezone] (celui de sa dernière, quand on le
/// connaît) — docs/LEDGER_*.md API-60, plan §7.
String? tripDaySpan(
  String dateTime,
  String endDateTime, {
  required String timezone,
  String? endTimezone,
}) {
  final DateTime? start = AppFormatters.tryParseZoneTime(dateTime, timezone);
  final DateTime? end = AppFormatters.tryParseZoneTime(
    endDateTime,
    endTimezone ?? timezone,
  );
  if (start == null || end == null) return null;
  if (_sameDay(start, end)) return _shortDay(start, withMonth: true);
  final bool sameMonth = start.year == end.year && start.month == end.month;
  return '${_shortDay(start, withMonth: !sameMonth)} → '
      '${_shortDay(end, withMonth: true)}';
}

/// « ven. 16 » ou « ven. 16 oct. », d'une heure de cadran déjà convertie.
String _shortDay(DateTime wall, {required bool withMonth}) {
  final String day = '${AppFormatters.dayAbbrev(wall.weekday)} ${wall.day}';
  return withMonth ? '$day ${DateFormat.MMM().format(wall)}' : day;
}
