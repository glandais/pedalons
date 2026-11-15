import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/generated/export.dart';
import '../../calendar/providers/calendar_month_provider.dart';
import '../../feed/providers/publication_feed_provider.dart';
import '../../home/providers/week_events_provider.dart';
import '../../rides/providers/ride_editor_providers.dart';
import '../../tags/providers/team_tags_provider.dart';
import '../../teams/providers/team_dashboard_provider.dart';
import '../domain/trip_form.dart';
import 'trip_detail_provider.dart';
import 'trip_weather_provider.dart';

/// L'utilisateur peut-il créer un voyage dans [teamSlug] ? `null` tant que
/// « Mes équipes » n'est pas chargé et qu'il n'est pas admin de plateforme :
/// l'écran n'affiche alors ni bouton ni refus (docs/LEDGER_*.md MOB-162).
///
/// La règle est celle du serveur ([canManageTeamTrips]) : organisateur ou
/// administrateur, modules voyages **et** parcours actifs.
final canManageTripsProvider = Provider.family<bool?, String>(
  (Ref ref, String teamSlug) =>
      teamManagePermission(ref, teamSlug, canManageTeamTrips),
);

/// **Le** point où l'app dit « un organisateur vient de changer un voyage » —
/// créé, réécrit, publié, annulé, renommé d'adresse, supprimé ou restauré
/// (ledger `MOB-162`). Le pendant de `notifyRideChanged`.
///
/// Un voyage paraît dans les fils, le tableau de bord de l'équipe, « Cette
/// semaine », le calendrier et les compteurs d'usage des tags ; son détail et
/// sa météo ne sont invalidés que si [tripKey] le nomme.
void notifyTripChanged(
  WidgetRef ref, {
  required String teamSlug,
  TripKey? tripKey,
}) {
  if (tripKey != null) {
    ref.invalidate(tripDetailProvider(tripKey));
    ref.invalidate(tripWeatherProvider(tripKey));
  }
  ref.invalidate(publicationFeedProvider);
  ref.invalidate(teamDashboardProvider);
  ref.invalidate(weekEventsProvider);
  ref.invalidate(calendarMonthProvider);
  ref.invalidate(teamTagsProvider((teamSlug: teamSlug, type: TagTarget.trip)));
}
