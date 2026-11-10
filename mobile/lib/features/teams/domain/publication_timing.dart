import 'package:easy_localization/easy_localization.dart';

import '../../../api/generated/export.dart';
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

/// Où en est une sortie, un groupe, un voyage ou une étape : à venir, en
/// cours, terminé (décision du 2026-11-10, état des lieux `SYNTHESE` §6.2 :
/// « Terminé » seulement après l'arrivée, « En cours » entre les deux, la
/// météo gardée et « Rejoindre » masqué pendant qu'on roule).
///
/// Une notion **ajoutée** à côté de `isPast` (le `finished` du serveur, qui
/// ne dit que « départ passé ») : chaque écran choisit, usage par usage,
/// entre « parti » et « terminé » (plan `MOB-134`, risque transverse).
enum PublicationPhase {
  /// Le départ n'a pas eu lieu.
  upcoming,

  /// Parti, pas encore arrivé.
  underWay,

  /// Arrivé — ou annulé une fois son départ passé : il n'aura pas lieu, il
  /// n'est donc jamais « en cours ».
  finished;

  /// Le départ est passé : en cours ou terminé.
  bool get hasStarted => this != PublicationPhase.upcoming;
}

/// La durée d'une sortie quand rien ne la donne — groupe ou étape sans
/// vitesse ou sans parcours : 3 heures, la règle du serveur
/// (`PublicationEndCalculator.DEFAULT_DURATION`).
const Duration kDefaultOutingDuration = Duration(hours: 3);

/// La phase entre [start] et [end], deux instants du contrat (ISO 8601),
/// comparés tels quels en UTC. Sans [end] lisible, la fin est
/// [start] + [kDefaultOutingDuration]. Une publication annulée
/// ([status] `CANCELLED`) n'est jamais en cours : terminée dès son départ.
/// Un départ illisible donne [PublicationPhase.upcoming], ce qui ne masque
/// rien. [now] ne sert qu'aux tests.
PublicationPhase publicationPhase({
  required String start,
  String? end,
  String? status,
  DateTime? now,
}) {
  final DateTime? startAt = DateTime.tryParse(start);
  if (startAt == null) return PublicationPhase.upcoming;
  final DateTime endAt =
      (end == null ? null : DateTime.tryParse(end)) ??
      startAt.add(kDefaultOutingDuration);
  final DateTime at = (now ?? DateTime.now()).toUtc();
  if (startAt.isAfter(at)) return PublicationPhase.upcoming;
  if (status == 'CANCELLED') return PublicationPhase.finished;
  return at.isBefore(endAt)
      ? PublicationPhase.underWay
      : PublicationPhase.finished;
}

/// La phase d'une sortie entière : de son `dateTime` à son `endDateTime`,
/// la fin que le serveur calcule (le plus tardif de ses groupes).
PublicationPhase ridePhase(RideDto ride, {DateTime? now}) => publicationPhase(
  start: ride.dateTime,
  end: ride.endDateTime,
  status: ride.status,
  now: now,
);

/// La phase d'**un groupe** : de son départ (`startAt`) à son arrivée
/// estimée (`estimatedArrival`, contrat 13.4.0, ledger `API-172`). Sans
/// arrivée estimée (ni vitesse ni parcours), départ + 3 h — ce que le serveur
/// compte pour ce groupe dans `RideDto.endDateTime`. Le statut est celui de
/// la sortie.
PublicationPhase rideGroupPhase(
  RideDto ride,
  RideGroupDto group, {
  DateTime? now,
}) => publicationPhase(
  start: group.startAt,
  end: group.estimatedArrival,
  status: ride.status,
  now: now,
);

/// La phase d'un voyage : de son `dateTime` à son `endDateTime` (la fin de
/// sa dernière étape, calculée par le serveur).
PublicationPhase tripPhase(TripDto trip, {DateTime? now}) => publicationPhase(
  start: trip.dateTime,
  end: trip.endDateTime,
  status: trip.status,
  now: now,
);

/// La phase d'**une étape** : de son départ à son arrivée estimée
/// (`TripStageDto.estimatedArrival`), départ + 3 h sans elle, comme le
/// serveur. Le statut est celui du voyage.
PublicationPhase tripStagePhase(
  TripDto trip,
  TripStageDto stage, {
  DateTime? now,
}) => publicationPhase(
  start: stage.dateTime,
  end: stage.estimatedArrival,
  status: trip.status,
  now: now,
);

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
