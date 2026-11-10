import 'api/rides_home_trips_seed.dart';
import 'common.dart';

/// Web counterpart: `flow-trips.e2e.ts` › registration › « a member registers to a trip from its
/// page, then leaves it », and « a team admin cancels a trip: it says « Annulé » and takes no more
/// registrations ».
///
/// The trip started yesterday and ends the day after tomorrow: « passé » is judged on the end
/// (`endDate`, the last stage — `trip_detail_provider.dart`, `isPast`), so it is still open to
/// members. Once cancelled — behind the app, seen through pull-to-refresh — neither « Rejoindre »
/// nor « Se désinscrire » is offered.
void main() {
  testApp(
    'A multi-day trip that has started stays open: join, leave, stages rail, then cancelled offers nothing',
    ($, modules, apiClients) async {
      final backend = apiClients.backend;
      final owner = await backend.newUser('Trip owner');
      final member = await backend.newUser('Trip member');
      final team = await backend.newTeam(owner, 'Equipe voyage');
      final teamSlug = team['slug'] as String;
      await backend.addMember(teamSlug, member);

      final today = DateTime.now();
      DateTime at(int days) =>
          DateTime(today.year, today.month, today.day + days, 8);
      final stageNames = [
        unique('Etape depart'),
        unique('Etape montagne'),
        unique('Etape arrivee'),
      ];
      final trip = await backend.newTrip(
        owner,
        teamSlug,
        'Voyage commence',
        dateTime: at(-1),
        stages: [
          (name: stageNames[0], at: at(-1)),
          (name: stageNames[1], at: at(1)),
          (name: stageNames[2], at: at(2)),
        ],
      );
      final tripSlug = trip['slug'] as String;
      final stageSlugs = <String>[
        for (final name in stageNames)
          (trip['stages'] as List).cast<Json>().firstWhere(
                (stage) => stage['name'] == name,
              )['slug']
              as String,
      ];

      await openAppSignedIn($, member);
      await openLink($, Paths.trip(teamSlug, tripSlug));
      await modules.trip.waitUntilShown();
      expect(modules.trip.saysFinished, isFalse);
      expect(modules.trip.saysCancelled, isFalse);
      for (final slug in stageSlugs) {
        expect(await modules.trip.listsStage(slug), isTrue);
      }
      expect(await modules.trip.offersJoin(), isTrue);

      await modules.trip.join();
      await eventually(
        () => backend.trip(member, teamSlug, tripSlug),
        until: (Json t) => t['registered'] == true,
        description: 'the registration to the trip',
        timeout: const Duration(seconds: 15),
      );

      // The stages: the second from its card, the third from the rail, then back to the trip.
      await modules.trip.openStage(stageSlugs[1], stageNames[1]);
      expect(modules.trip.stagePositionIs(2, 3), isTrue);
      await modules.trip.tapRail(3);
      await modules.trip.waitUntilStageIs(stageNames[2]);
      expect(modules.trip.stagePositionIs(3, 3), isTrue);
      await modules.trip.tapRail(0);
      await modules.trip.waitUntilShown();

      await modules.trip.leave();
      expect(
        (await backend.trip(member, teamSlug, tripSlug))['registered'],
        isFalse,
      );

      // Cancelled behind the app: pulling the page down reads it again.
      await backend.cancelTrip(owner, teamSlug, tripSlug);
      await modules.trip.pullToRefresh();
      await modules.trip.waitUntilCancelled();
      expect(await modules.trip.offersJoin(), isFalse);
      expect(await modules.trip.offersLeave(), isFalse);
    },
  );
}
