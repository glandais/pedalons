import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/features/rides/domain/ride_weather_display.dart';

import 'ride_fixtures.dart';

/// La table de rendu de la météo, et ses replis : les enums de la réponse
/// sont des `String`, et une valeur que l'app ne connaît pas ne doit ni
/// planter ni montrer n'importe quoi.
void main() {
  group('rideWeatherViewOf', () {
    test('chaque statut connu a son rendu', () {
      expect(
        rideWeatherViewOf('OK', canSeeNoLocation: false),
        RideWeatherView.forecast,
      );
      expect(
        rideWeatherViewOf('STALE', canSeeNoLocation: false),
        RideWeatherView.stale,
      );
      expect(
        rideWeatherViewOf('NOT_YET_AVAILABLE', canSeeNoLocation: false),
        RideWeatherView.notYetAvailable,
      );
      expect(
        rideWeatherViewOf('UNAVAILABLE', canSeeNoLocation: false),
        RideWeatherView.unavailable,
      );
      expect(
        rideWeatherViewOf('OUT_OF_RANGE', canSeeNoLocation: true),
        RideWeatherView.hidden,
      );
    });

    test('NO_LOCATION n\'est dit qu\'aux organisateurs', () {
      expect(
        rideWeatherViewOf('NO_LOCATION', canSeeNoLocation: false),
        RideWeatherView.hidden,
      );
      expect(
        rideWeatherViewOf('NO_LOCATION', canSeeNoLocation: true),
        RideWeatherView.noLocation,
      );
    });

    test('un statut inconnu ne montre rien', () {
      expect(
        rideWeatherViewOf('PARTIAL', canSeeNoLocation: true),
        RideWeatherView.hidden,
      );
    });
  });

  test('organisateur, administrateur ou admin de la plateforme', () {
    expect(
      canSeeWeatherNoLocation(
        teamRole: TeamRole.organizer,
        platformAdmin: false,
      ),
      isTrue,
    );
    expect(
      canSeeWeatherNoLocation(teamRole: TeamRole.admin, platformAdmin: false),
      isTrue,
    );
    expect(
      canSeeWeatherNoLocation(teamRole: TeamRole.member, platformAdmin: false),
      isFalse,
    );
    expect(
      canSeeWeatherNoLocation(
        teamRole: TeamRole.$unknown,
        platformAdmin: false,
      ),
      isFalse,
    );
    expect(
      canSeeWeatherNoLocation(teamRole: null, platformAdmin: true),
      isTrue,
    );
  });

  group('weatherLegOfGroup', () {
    final List<WeatherLegDto> legs = <WeatherLegDto>[
      fixtureLeg(groupId: 'g1'),
      fixtureLeg(groupId: 'g2'),
    ];

    test('le leg du groupe, et lui seul', () {
      expect(weatherLegOfGroup(legs, 'g2')!.groupId, 'g2');
      // Jamais de repli sur un autre leg : il prêterait au groupe la météo
      // d'un autre parcours.
      expect(weatherLegOfGroup(legs, 'gX'), isNull);
      expect(weatherLegOfGroup(const <WeatherLegDto>[], 'g1'), isNull);
      expect(
        weatherLegOfGroup(<WeatherLegDto>[fixtureLeg(groupId: null)], 'g1'),
        isNull,
      );
    });
  });

  group('icônes', () {
    test('jour et nuit pour un ciel dégagé', () {
      expect(
        WeatherCondition.clear.icon(daylight: true),
        PdlIcons.weatherClearDay,
      );
      expect(
        WeatherCondition.clear.icon(daylight: false),
        PdlIcons.weatherClearNight,
      );
    });

    test('une condition inconnue rend un nuage et « unknown »', () {
      final WeatherCondition c = weatherConditionOf('METEOR_SHOWER');
      expect(c, WeatherCondition.$unknown);
      expect(c.icon(daylight: true), PdlIcons.weatherUnknown);
      expect(c.labelKey, 'rides.weather.condition.unknown');
      expect(weatherConditionOf(null), WeatherCondition.$unknown);
    });

    test('chaque condition connue a sa clé', () {
      for (final WeatherCondition c in WeatherCondition.$valuesDefined) {
        expect(c.labelKey, 'rides.weather.condition.${c.name}');
      }
    });
  });

  test('vent relatif : inconnu ou absent → null', () {
    expect(relativeWindOf('HEAD'), RelativeWind.head);
    expect(relativeWindOf('SWIRL'), isNull);
    expect(relativeWindOf(null), isNull);
  });

  test('la flèche absolue pointe là où va le vent', () {
    // Vent du nord : il souffle vers le sud.
    expect(windArrowAngle(0), 180);
    // Vent d'ouest-sud-ouest (250°) : vers 70°.
    expect(windArrowAngle(250), 70);
  });

  group('showsWeatherSummary', () {
    RideWeatherSummaryDto summary(String status) =>
        RideWeatherSummaryDto(status: status, temperature: 12);

    test('OK, STALE et NOT_YET_AVAILABLE seulement', () {
      expect(showsWeatherSummary(summary('OK')), isTrue);
      expect(showsWeatherSummary(summary('STALE')), isTrue);
      expect(showsWeatherSummary(summary('NOT_YET_AVAILABLE')), isTrue);
      expect(showsWeatherSummary(summary('UNAVAILABLE')), isFalse);
      expect(showsWeatherSummary(summary('WHATEVER')), isFalse);
      expect(showsWeatherSummary(null), isFalse);
    });
  });
}
