import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/providers/calendar_month_provider.dart';
import '../../feed/providers/publication_feed_provider.dart';
import '../../home/providers/next_ride_provider.dart';
import '../../home/providers/week_events_provider.dart';
import '../../teams/providers/team_dashboard_provider.dart';
import 'ride_detail_provider.dart';
import 'ride_weather_provider.dart';

/// **Le** point où l'app dit « un organisateur vient de changer une sortie »
/// — créée, réécrite, publiée, annulée, supprimée ou restaurée (ledger
/// `MOB-76`). Le pendant de `notifyParticipationChanged` pour l'écriture.
///
/// Une sortie paraît dans le fil de l'équipe, son tableau de bord, l'accueil
/// et le calendrier, chacun dans son cache : tous sont invalidés ici, et le
/// détail de la sortie aussi quand [rideKey] le nomme. Invalider un provider
/// que personne n'écoute ne coûte rien.
///
/// Les fils paginés repartent du début : contrairement à une inscription, la
/// liste elle-même change (une sortie y entre, en sort, change de date).
void notifyRideChanged(WidgetRef ref, {RideKey? rideKey}) {
  if (rideKey != null) {
    ref.invalidate(rideDetailProvider(rideKey));
    ref.invalidate(rideWeatherProvider(rideKey));
  }
  ref.invalidate(publicationFeedProvider);
  ref.invalidate(teamDashboardProvider);
  ref.invalidate(nextRideProvider);
  ref.invalidate(weekEventsProvider);
  ref.invalidate(calendarMonthProvider);
}
