import 'package:flutter/widgets.dart';

class _CalendarKey extends ValueKey<String> {
  const _CalendarKey(String value) : super('calendar_$value');
}

class CalendarKeys {
  /// La carte d'agenda d'un événement, par le slug de sa sortie ou de son
  /// étape (`CalendarEventDto.entitySlug`).
  ValueKey<String> agendaCard(String entitySlug) =>
      _CalendarKey('agendaCard_$entitySlug');

  /// Le badge « Inscrit · groupe » d’une carte d’agenda.
  ValueKey<String> agendaRegisteredBadge(String entitySlug) =>
      _CalendarKey('agendaRegisteredBadge_$entitySlug');

  /// « Brouillon » sur une ligne de l'agenda (règle R1).
  ValueKey<String> agendaDraftBadge(String entitySlug) =>
      _CalendarKey('agendaDraftBadge_$entitySlug');

  final nextMonthButton = const _CalendarKey('nextMonthButton');

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
