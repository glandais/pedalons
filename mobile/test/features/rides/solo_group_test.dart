import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/rides/domain/solo_group.dart';

import 'ride_fixtures.dart';

/// La règle de la sortie solo (ledger `MOB-69`) : un seul groupe, une seule
/// page. Les trois prédicats sont sa seule écriture côté mobile.
void main() {
  final RideDto none = fixtureRide(groups: const <RideGroupDto>[]);
  final RideDto one = fixtureRide(groups: <RideGroupDto>[fixtureGroup()]);
  final RideDto two = fixtureRide(
    groups: <RideGroupDto>[
      fixtureGroup(id: 'g1'),
      fixtureGroup(id: 'g2', sortOrder: 1),
    ],
  );

  group('soloGroupOf', () {
    test('le groupe unique, et seulement lui', () {
      expect(soloGroupOf(none), isNull);
      expect(soloGroupOf(one)?.id, 'g1');
      expect(soloGroupOf(two), isNull);
    });
  });

  group('leavesGroupPage', () {
    test('zéro ou un groupe : la page du groupe cède la place au détail', () {
      expect(leavesGroupPage(none), isTrue);
      expect(leavesGroupPage(one), isTrue);
      expect(leavesGroupPage(two), isFalse);
    });
  });

  group('rideOwnLeg', () {
    RideWeatherDto weather(List<WeatherLegDto> legs) =>
        fixtureWeather(status: 'OK', legs: legs);

    test('sans groupe : le leg unique sans groupId', () {
      final WeatherLegDto leg = fixtureLeg(groupId: null);
      expect(rideOwnLeg(weather(<WeatherLegDto>[leg]), none), leg);
    });

    test('un groupe : le leg de ce groupe', () {
      final WeatherLegDto leg = fixtureLeg(groupId: 'g1');
      expect(rideOwnLeg(weather(<WeatherLegDto>[leg]), one), leg);
    });

    test('un groupe : jamais le leg d\'un autre groupe', () {
      expect(
        rideOwnLeg(weather(<WeatherLegDto>[fixtureLeg(groupId: 'g9')]), one),
        isNull,
      );
    });

    test('deux groupes : aucun, chacun a sa page', () {
      expect(
        rideOwnLeg(
          weather(<WeatherLegDto>[
            fixtureLeg(groupId: 'g1'),
            fixtureLeg(groupId: 'g2'),
          ]),
          two,
        ),
        isNull,
      );
    });

    test('pas de leg : rien', () {
      expect(rideOwnLeg(weather(const <WeatherLegDto>[]), one), isNull);
      expect(rideOwnLeg(weather(const <WeatherLegDto>[]), none), isNull);
    });
  });
}
