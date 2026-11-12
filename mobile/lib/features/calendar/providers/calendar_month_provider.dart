import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../api/generated/export.dart';
import '../../../core/utils/formatters.dart';
import '../data/calendar_repository.dart';

/// Les trois valeurs de la chip de type, **exclusives entre elles**.
///
/// La maquette ne dit pas si elles se combinent ; le plan tranche (§3.2) :
/// type exclusif d'un côté, équipe exclusive de l'autre, les deux groupes se
/// combinant. Le type se filtre côté client — le mois entier est déjà chargé —
/// là où l'équipe **change d'endpoint**.
enum CalendarTypeFilter { all, rides, trips }

/// Ce qu'un mois de calendrier demande : une fenêtre et une portée.
///
/// Le type n'en fait **pas** partie : le faire entrer ici relancerait un appel
/// réseau pour un filtre qui se joue en mémoire.
@immutable
class CalendarMonthKey {
  const CalendarMonthKey({
    required this.year,
    required this.month,
    this.teamSlug,
  });

  final int year;
  final int month;
  final String? teamSlug;

  DateTime get start => DateTime(year, month);

  /// Fin de mois inclusive, à la seconde près : l'API prend un intervalle, et
  /// couper à minuit perdrait les sorties du dernier jour.
  DateTime get end => DateTime(year, month + 1, 0, 23, 59, 59);

  CalendarMonthKey shifted(int months) {
    final DateTime target = DateTime(year, month + months);
    return CalendarMonthKey(
      year: target.year,
      month: target.month,
      teamSlug: teamSlug,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarMonthKey &&
          other.year == year &&
          other.month == month &&
          other.teamSlug == teamSlug;

  @override
  int get hashCode => Object.hash(year, month, teamSlug);
}

/// Un mois lu **une fois**, indexé de façon à ce que ni la grille ni l'agenda
/// n'aient à re-parcourir la liste à chaque cadre.
@immutable
class CalendarMonth {
  const CalendarMonth({required this.events, required this.byDay});

  /// Tous les événements du mois, dans l'ordre chronologique.
  final List<CalendarEventDto> events;

  /// Les mêmes, regroupés par jour local, clés triées.
  final Map<DateTime, List<CalendarEventDto>> byDay;

  static const CalendarMonth empty = CalendarMonth(
    events: <CalendarEventDto>[],
    byDay: <DateTime, List<CalendarEventDto>>{},
  );

  bool get isEmpty => events.isEmpty;

  /// Les jours renseignés, dans l'ordre.
  List<DateTime> get days => byDay.keys.toList();

  /// Le mois filtré par type, et sur ce où l'on est inscrit quand
  /// [registeredOnly] (« Je participe » de l'Agenda d'une équipe). Aucun
  /// appel : le tri est en mémoire.
  CalendarMonth filtered(
    CalendarTypeFilter type, {
    bool registeredOnly = false,
  }) {
    if (type == CalendarTypeFilter.all && !registeredOnly) return this;
    return CalendarMonth.fromEvents(
      events
          .where(
            (CalendarEventDto e) =>
                matchesType(e, type) && (!registeredOnly || e.registered),
          )
          .toList(),
    );
  }

  static bool matchesType(CalendarEventDto event, CalendarTypeFilter type) =>
      switch (type) {
        CalendarTypeFilter.all => true,
        CalendarTypeFilter.rides => event.type == 'RIDE',
        CalendarTypeFilter.trips => event.type == 'TRIP_STAGE',
      };

  /// Le jour local d'un événement — **fuseau d'affichage**, parité web
  /// (§1.0.3-11, docs/LEDGER_*.md API-15). `CalendarEventDto.start` est un instant UTC ; le convertir
  /// une fois ici est la seule conversion, et c'est ce qui interdit la double
  /// conversion que le cas de test §5.3-3 traque.
  static DateTime dayOf(CalendarEventDto event) {
    final DateTime local = AppFormatters.toDisplayTime(
      DateTime.parse(event.start),
    );
    return DateTime(local.year, local.month, local.day);
  }

  factory CalendarMonth.fromEvents(List<CalendarEventDto> events) {
    final List<CalendarEventDto> sorted = <CalendarEventDto>[...events]
      ..sort(
        (CalendarEventDto a, CalendarEventDto b) => a.start.compareTo(b.start),
      );
    final Map<DateTime, List<CalendarEventDto>> byDay =
        <DateTime, List<CalendarEventDto>>{};
    for (final CalendarEventDto event in sorted) {
      byDay.putIfAbsent(dayOf(event), () => <CalendarEventDto>[]).add(event);
    }
    return CalendarMonth(events: sorted, byDay: byDay);
  }
}

/// Un mois, un appel.
///
/// Le critère de fin de S22-2 se vérifie au journal réseau : une ouverture du
/// calendrier ne doit produire qu'un `GET /api/calendar/events` par mois et par
/// portée, et **aucun** `GET …/rides/{slug}`.
final calendarMonthProvider = FutureProvider.autoDispose
    .family<CalendarMonth, CalendarMonthKey>((ref, key) async {
      final List<CalendarEventDto> events = await ref
          .watch(calendarRepositoryProvider)
          .getEvents(start: key.start, end: key.end, teamSlug: key.teamSlug);
      return CalendarMonth.fromEvents(events);
    });

/// Le mois affiché, et le jour sélectionné dans l'agenda.
final calendarMonthKeyProvider = StateProvider.autoDispose
    .family<CalendarMonthKey, String?>((ref, teamSlug) {
      final DateTime now = AppFormatters.displayNow();
      return CalendarMonthKey(
        year: now.year,
        month: now.month,
        teamSlug: teamSlug,
      );
    });

/// Le filtre de type, exclusif.
final calendarTypeFilterProvider =
    StateProvider.autoDispose<CalendarTypeFilter>(
      (ref) => CalendarTypeFilter.all,
    );

/// Le jour sur lequel l'agenda est calé. `null` tant que l'utilisateur n'a
/// touché aucune case.
final calendarSelectedDayProvider = StateProvider.autoDispose<DateTime?>(
  (ref) => null,
);

/// Combien de mois consécutifs on sonde en cherchant le prochain à contenir
/// quelque chose. Six : au-delà, on fait payer six appels pour une réponse qui
/// n'intéresse plus.
const int kCalendarLookaheadMonths = 6;

/// Le prochain mois à partir de [from] qui contient au moins un événement.
///
/// Comportement **conservé** de `_findFirstMonthWithEvents` : il sert
/// désormais l'action « Aller au prochain mois avec une sortie » de l'état vide
/// plutôt que de décider en silence du mois d'ouverture — le calendrier ouvre
/// sur le mois courant, comme le veut §3.2.
final calendarNextMonthWithEventsProvider = FutureProvider.autoDispose
    .family<CalendarMonthKey?, CalendarMonthKey>((ref, from) async {
      final CalendarRepository repository = ref.watch(
        calendarRepositoryProvider,
      );
      for (int i = 1; i <= kCalendarLookaheadMonths; i++) {
        final CalendarMonthKey candidate = from.shifted(i);
        final List<CalendarEventDto> events = await repository.getEvents(
          start: candidate.start,
          end: candidate.end,
          teamSlug: candidate.teamSlug,
        );
        if (events.isNotEmpty) return candidate;
      }
      return null;
    });
