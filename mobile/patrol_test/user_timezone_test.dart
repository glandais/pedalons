import 'package:pedalons/core/utils/formatters.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'api/profile_seed.dart';
import 'api/rides_home_trips_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-account.e2e.ts` › time zone. A member's preference (`UserDto.timezone`,
/// docs/LEDGER_*.md API-15) is the zone of *their* clock: since API-60 a rendezvous reads in its
/// entity's zone, and the preference shows in the mention after it. Choosing it in the app is
/// `profile_timezone_test`.
///
/// A stage at 08:00 in its team's Paris, read by a member whose preference is `Pacific/Auckland`:
/// « 08:00 » and that day in Paris, then « heure de Paris (… chez vous) » with the Auckland time —
/// not the device's, which would read the same instant otherwise.
///
/// Clock times are written by [AppFormatters.formatTime], whose shape depends on the phone's
/// 12/24 h setting and on the app's language (« 8:00 AM » in English on a 12 h phone). The expected
/// strings go through it too — it reads the same globals the running app set — rather than
/// hard-coding « 08:00 ».
void main() {
  const String zone = 'Pacific/Auckland';
  const String teamZone = 'Europe/Paris';

  testApp(
    'A member who chose a timezone reads a stage at its own time, with their time in the mention',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Timezone owner');
      final member = await backend.newUser('Timezone member');
      final team = await backend.newTeam(owner, 'Equipe fuseau');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, member);
      await backend.setTimezone(member, zone);

      tz_data.initializeTimeZones();
      final DateTime inTen = DateTime.now().add(const Duration(days: 10));
      final tz.TZDateTime start = tz.TZDateTime(
        tz.getLocation(teamZone),
        inTen.year,
        inTen.month,
        inTen.day,
        8,
      );
      final tz.TZDateTime inAuckland = tz.TZDateTime.from(
        start,
        tz.getLocation(zone),
      );
      // The device's reading of the same instant: the test only means something if it differs.
      final DateTime onDevice = start.toUtc().toLocal();
      expect(
        onDevice.hour != inAuckland.hour || onDevice.day != inAuckland.day,
        isTrue,
        reason: 'the device runs in a zone that reads like $zone',
      );

      final stageName = unique('Etape antipodes');
      final trip = await backend.newTrip(
        owner,
        teamSlug,
        'Voyage antipodes',
        dateTime: start,
        stages: [(name: stageName, at: start)],
      );
      final tripSlug = trip['slug'] as String;
      final stageSlug =
          ((trip['stages'] as List).cast<Json>().single)['slug'] as String;

      await openAppSignedIn($, member);
      await openLink($, Paths.stage(teamSlug, tripSlug, stageSlug));
      await modules.trip.waitUntilStageIs(stageName);

      // The stage's own clock, in Paris.
      final DateTime wall = DateTime(start.year, start.month, start.day, 8);
      expect($(AppFormatters.formatLongDate(wall)).exists, isTrue);
      final String at = RegExp.escape(AppFormatters.formatTime(wall));
      expect($(RegExp('\\b$at\\b')).exists, isTrue);
      // The member's, in Auckland: the day only when it is not the stage's.
      final String hour = RegExp.escape(
        AppFormatters.formatTime(
          DateTime(
            inAuckland.year,
            inAuckland.month,
            inAuckland.day,
            inAuckland.hour,
            inAuckland.minute,
          ),
        ),
      );
      expect(
        $(RegExp('heure de Paris \\((\\S+\\. )?$hour chez vous\\)')).exists,
        isTrue,
      );
    },
  );
}
