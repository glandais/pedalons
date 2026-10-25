import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../../api/pedalons_api_client.dart';
import '../../../core/utils/formatters.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.watch(calendarClientProvider));
});

class CalendarRepository {
  final CalendarClient _calendarClient;

  CalendarRepository(this._calendarClient);

  /// Les événements d'une fenêtre, pour une portée.
  ///
  /// **Un seul appel, et aucun appel de détail derrière** : depuis la 1.5.0,
  /// `CalendarEventDto` porte `distance`, `elevationGain`, `groupName`,
  /// `registered`, `startPlaceName`, `status` et `thumbnailUrl`. La carte
  /// d'agenda se rend donc entièrement avec ce que ce seul appel a rendu — le
  /// `getRide` par événement disparaît, et c'est le gain principal de l'écran.
  ///
  /// [teamSlug] nul interroge toutes les équipes de l'utilisateur ; sinon
  /// l'endpoint change, la chip d'équipe ne filtre pas côté client.
  Future<List<CalendarEventDto>> getEvents({
    required DateTime start,
    required DateTime end,
    String? teamSlug,
  }) async {
    final String from = AppFormatters.displayWallClockToUtc(start)
        .toIso8601String();
    final String to = AppFormatters.displayWallClockToUtc(end)
        .toIso8601String();
    final CalendarEventsResponse response = teamSlug == null
        ? await _calendarClient.getEvents(from: from, to: to)
        : await _calendarClient.getTeamEvents(
            teamSlug: teamSlug,
            from: from,
            to: to,
          );
    return response.events;
  }

  /// Le jeton du flux ICS et ses deux gabarits d'URL.
  ///
  /// **Il n'est jamais mis en cache, ni ici ni ailleurs** (§3.2) : il se relit
  /// à chaque ouverture du bloc d'abonnement et ne survit pas à sa fermeture.
  Future<CalendarTokenDto> getToken() => _calendarClient.getToken();

  /// Invalide le jeton courant et en rend un neuf. L'ancien cesse
  /// immédiatement de fonctionner sur tous les appareils abonnés.
  Future<CalendarTokenDto> regenerateToken() =>
      _calendarClient.regenerateToken();
}
