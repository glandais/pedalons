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

/// Les jours d'un voyage, au format unique du départ (BRANDING §8.3, ledger
/// `BRAND-8`) : « ven. 16 → dim. 18 oct. », le mois une seule fois quand il
/// ne change pas ; « ven. 16 oct. » sur un seul jour ; l'année seulement hors
/// de l'année en cours (« ven. 16 → dim. 18 oct. 2036 »), comme
/// `formatPublicationSpan` au web.
///
/// Le départ se lit dans le fuseau du voyage [timezone] (celui de sa première
/// étape), la fin dans [endTimezone] (celui de sa dernière, quand on le
/// connaît) — docs/LEDGER_*.md API-60, plan §7. [now] ne sert qu'aux tests.
String? tripDaySpan(
  String dateTime,
  String endDateTime, {
  required String timezone,
  String? endTimezone,
  DateTime? now,
}) {
  final DateTime? startAt = DateTime.tryParse(dateTime);
  final DateTime? endAt = DateTime.tryParse(endDateTime);
  if (startAt == null || endAt == null) return null;
  final String endZone = endTimezone ?? timezone;
  final DateTime start = AppFormatters.toZoneTime(startAt, timezone);
  final DateTime end = AppFormatters.toZoneTime(endAt, endZone);
  final String first = AppFormatters.formatDepartureDate(
    startAt,
    timezone,
    now: now,
  );
  if (_sameDay(start, end)) return first;
  final bool sameMonth = start.year == end.year && start.month == end.month;
  final String last = AppFormatters.formatDepartureDate(
    endAt,
    endZone,
    now: now,
  );
  return '${sameMonth ? _shortDay(start, withMonth: false) : first} → $last';
}

/// « ven. 16 » ou « ven. 16 oct. », d'une heure de cadran déjà convertie.
String _shortDay(DateTime wall, {required bool withMonth}) {
  final String day = '${AppFormatters.dayAbbrev(wall.weekday)} ${wall.day}';
  return withMonth ? '$day ${DateFormat.MMM().format(wall)}' : day;
}
