import 'core/adaptive/keys.dart';
import 'features/ads/keys.dart';
import 'features/apps/keys.dart';
import 'features/auth/keys.dart';
import 'features/calendar/keys.dart';
import 'features/comments/keys.dart';
import 'features/device/keys.dart';
import 'features/feed/keys.dart';
import 'features/feedback/keys.dart';
import 'features/home/keys.dart';
import 'features/legal/keys.dart';
import 'features/moderation/keys.dart';
import 'features/notifications/keys.dart';
import 'features/participants/keys.dart';
import 'features/posts/keys.dart';
import 'features/profile/keys.dart';
import 'features/rides/keys.dart';
import 'features/routes/keys.dart';
import 'features/tags/keys.dart';
import 'features/teams/keys.dart';
import 'features/trips/keys.dart';

/// Les clés des widgets que les tests de bout en bout (`patrol_test/`)
/// trouvent. Une clé n'existe ici que si un widget la porte.
final keys = Keys();

class Keys {
  final login = LoginPageKeys();
  final navigation = NavigationKeys();
  final profile = ProfilePageKeys();
  final teams = TeamsPageKeys();
  final teamsDiscover = TeamsDiscoverKeys();
  final team = TeamPageKeys();
  final teamDashboard = TeamDashboardKeys();
  final teamAgenda = TeamAgendaKeys();
  final ride = RideDetailKeys();
  final rideGroup = RideGroupPageKeys();
  final rideEditor = RideEditorKeys();
  final rideManage = RideManageKeys();
  final rideTemplates = RideTemplateKeys();
  final rideTemplateEditor = RideTemplateEditorKeys();
  final participants = ParticipantsSheetKeys();
  final ad = AdDetailKeys();
  final adContact = AdContactKeys();
  final apps = AppsPageKeys();
  final feedback = FeedbackKeys();
  final legal = LegalPageKeys();
  final post = PostDetailKeys();
  final comments = CommentKeys();
  final moderation = ModerationKeys();
  final notifications = NotificationsKeys();
  final device = DeviceVerifyKeys();
  final home = HomeKeys();
  final trip = TripDetailKeys();
  final calendar = CalendarKeys();
  final routes = RoutesKeys();
  final routeDetail = RouteDetailKeys();
  final routeWaypoints = RouteWaypointsKeys();
  final routeEditor = RouteEditorKeys();
  final routeManage = RouteManageKeys();
  final feed = FeedKeys();
  final adsList = AdsListKeys();
  final tags = TagKeys();
}
