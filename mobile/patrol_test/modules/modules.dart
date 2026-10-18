import 'package:patrol/patrol.dart';

import 'ad.dart';
import 'ad_contact.dart';
import 'ad_location.dart';
import 'auth.dart';
import 'calendar.dart';
import 'detail_menus.dart';
import 'device.dart';
import 'home.dart';
import 'lists.dart';
import 'moderation.dart';
import 'navigation.dart';
import 'notifications.dart';
import 'peripheral.dart';
import 'post.dart';
import 'profile.dart';
import 'profile_settings.dart';
import 'ride.dart';
import 'ride_editor.dart';
import 'ride_templates.dart';
import 'route_editor.dart';
import 'routes.dart';
import 'share_sheet.dart';
import 'teams.dart';
import 'trip.dart';

final class Modules {
  Modules(this._$);

  final PatrolIntegrationTester _$;

  late final ad = Ad(_$);
  late final adContact = AdContact(_$);
  late final adLocation = AdLocation(_$);
  late final auth = Auth(_$);
  late final calendar = Calendar(_$);
  late final detailMenus = DetailMenus(_$);
  late final device = Device(_$);
  late final home = Home(_$);
  late final lists = Lists(_$);
  late final moderation = Moderation(_$);
  late final navigation = Navigation(_$);
  late final notifications = Notifications(_$);
  late final peripheral = Peripheral(_$);
  late final post = Post(_$);
  late final profile = Profile(_$);
  late final profileSettings = ProfileSettings(_$);
  late final ride = Ride(_$);
  late final rideEditor = RideEditor(_$);
  late final rideTemplates = RideTemplates(_$);
  late final routeEditor = RouteEditor(_$);
  late final routes = Routes(_$);
  late final shareSheet = ShareSheet(_$);
  late final teams = Teams(_$);
  late final trip = Trip(_$);
}
