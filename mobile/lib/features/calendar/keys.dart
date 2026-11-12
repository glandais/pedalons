import 'package:flutter/widgets.dart';

class _CalendarKey extends ValueKey<String> {
  const _CalendarKey(String value) : super('calendar_$value');
}

class CalendarKeys {
  /// La carte d'agenda d'un événement, par le slug de sa sortie ou de son
  /// étape (`CalendarEventDto.entitySlug`).
  ValueKey<String> agendaCard(String entitySlug) =>
      _CalendarKey('agendaCard_$entitySlug');

  /// Le lieu de départ d'une carte d'agenda, sur sa ligne (règle R11).
  ValueKey<String> agendaPlace(String entitySlug) =>
      _CalendarKey('agendaPlace_$entitySlug');

  /// La première ligne d'une carte d'agenda : heure · équipe · groupe.
  ValueKey<String> agendaMeta(String entitySlug) =>
      _CalendarKey('agendaMeta_$entitySlug');

  /// Le badge « J'y vais » d’une carte d’agenda.
  ValueKey<String> agendaRegisteredBadge(String entitySlug) =>
      _CalendarKey('agendaRegisteredBadge_$entitySlug');

  /// « Brouillon » sur une ligne de l'agenda (règle R1).
  ValueKey<String> agendaDraftBadge(String entitySlug) =>
      _CalendarKey('agendaDraftBadge_$entitySlug');

  final nextMonthButton = const _CalendarKey('nextMonthButton');

  /// « Aucun événement pour ces filtres », quand le mois en a (règle RL10).
  final filteredEmptyState = const _CalendarKey('filteredEmptyState');

  /// Le bloc d'abonnement : copier, régénérer, et le bandeau d'issue.
  final subscriptionCopyButton = const _CalendarKey('subscriptionCopyButton');
  final subscriptionNotice = const _CalendarKey('subscriptionNotice');
  final subscriptionRegenerateButton = const _CalendarKey(
    'subscriptionRegenerateButton',
  );
  final subscriptionRegenerateConfirmButton = const _CalendarKey(
    'subscriptionRegenerateConfirmButton',
  );
}
