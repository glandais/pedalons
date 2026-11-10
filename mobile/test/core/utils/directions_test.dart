import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/models/geo_json_point.dart';
import 'package:pedalons/api/generated/models/geo_json_point_type_type.dart';
import 'package:pedalons/api/generated/models/place_detail_dto.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/core/utils/directions.dart';
import 'package:pedalons/core/utils/link_launcher.dart';

/// L'itinéraire vers un lieu (ledger `MOB-134`) : un lien https de cartes,
/// les coordonnées d'abord, l'adresse sinon, rien sans l'une ni l'autre.
void main() {
  setUpAll(() {
    final Map<String, dynamic> fr = json.decode(
      File('assets/l10n/fr.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    Localization.load(
      const Locale('fr'),
      translations: Translations(fr),
      fallbackTranslations: Translations(fr),
    );
  });

  tearDown(() => debugLinkOpener = null);

  group('directionsUri', () {
    test('iOS : Plans, vers les coordonnées', () {
      final Uri uri = directionsUri(
        latitude: 48.36,
        longitude: -3.74,
        address: 'Place de la Mairie, Huelgoat',
        platform: TargetPlatform.iOS,
      )!;
      expect(uri.scheme, 'https');
      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters, <String, String>{'daddr': '48.36,-3.74'});
    });

    test('Android : Google Maps, vers les coordonnées', () {
      final Uri uri = directionsUri(
        latitude: 48.36,
        longitude: -3.74,
        platform: TargetPlatform.android,
      )!;
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters, <String, String>{
        'api': '1',
        'destination': '48.36,-3.74',
      });
    });

    test('sans coordonnées, l’adresse', () {
      final Uri uri = directionsUri(
        address: ' Place de la Mairie, Huelgoat ',
        platform: TargetPlatform.android,
      )!;
      expect(
        uri.queryParameters['destination'],
        'Place de la Mairie, Huelgoat',
      );
    });

    test('ni coordonnées ni adresse : rien', () {
      expect(directionsUri(platform: TargetPlatform.iOS), isNull);
      expect(directionsUri(address: '  ', latitude: 48.3), isNull);
    });
  });

  group('placeDirectionsUri', () {
    PlaceDetailDto place({GeoJsonPoint? geometry, String? address}) =>
        PlaceDetailDto(
          id: '1',
          name: 'Place de la Mairie',
          startPlace: true,
          endPlace: false,
          address: address,
          link: 'https://exemple.fr/rdv',
          geometry: geometry,
        );

    test('GeoJSON est [longitude, latitude]', () {
      final Uri uri = placeDirectionsUri(
        place(
          geometry: const GeoJsonPoint(
            type: GeoJsonPointTypeType.point,
            coordinates: <double>[-3.74, 48.36],
          ),
        ),
        platform: TargetPlatform.iOS,
      )!;
      expect(uri.queryParameters['daddr'], '48.36,-3.74');
    });

    test('le lien libre du lieu n’est jamais employé', () {
      expect(placeDirectionsUri(place()), isNull);
      expect(
        placeDirectionsUri(
          place(address: 'Huelgoat'),
          platform: TargetPlatform.android,
        )!.host,
        'www.google.com',
      );
    });
  });

  testWidgets('openDirections confie l’URL au système par openLink', (
    WidgetTester tester,
  ) async {
    final List<Uri> opened = <Uri>[];
    debugLinkOpener = (Uri url) async {
      opened.add(url);
      return true;
    };
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: PedalonsTheme.build(Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(
      await openDirections(context, name: 'Mairie', latitude: 1, longitude: 2),
      LinkOutcome.external,
    );
    expect(await openDirections(context, name: 'Mairie'), isNull);
    expect(opened, hasLength(1));
    expect(opened.single.scheme, 'https');
  });
}
