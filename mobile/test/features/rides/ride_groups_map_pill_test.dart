import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/core/config/config_provider.dart';
import 'package:pedalons/core/pdl/pdl.dart';
import 'package:pedalons/core/preferences/user_preferences_provider.dart';
import 'package:pedalons/core/theme/pdl_icons.dart';
import 'package:pedalons/core/theme/pedalons_theme.dart';
import 'package:pedalons/features/rides/presentation/widgets/ride_groups_map.dart';
import 'package:pedalons/features/rides/providers/ride_detail_provider.dart';
import 'package:pedalons/features/rides/providers/ride_group_selection_provider.dart';
import 'package:pedalons/keys.dart';

import '../../support/localization.dart';
import 'ride_fixtures.dart';
import '../../support/content_permissions.dart';

/// La pilule du parcours sélectionné, sur la carte d'une sortie à plusieurs
/// parcours : posée par la coquille (`PdlMapHero.pill`), plus par les
/// `overlays` de la carte — en plein écran, elle s'écarte de « Fermer »
/// (ledger `MOB-129`). Les tests Patrol la trouvent par sa clé.
void main() {
  setUpAll(loadTestTranslations);
  setUp(() => RideGroupsMap.debugSkipNativeMap = true);
  tearDown(() => RideGroupsMap.debugSkipNativeMap = false);

  const RideKey key = RideKey(teamSlug: 'n-peloton', rideSlug: 'np-665');
  final RideDto ride = fixtureRide(
    groups: <RideGroupDto>[
      fixtureGroup(id: 'chill', name: 'Chill', sortOrder: 0),
      fixtureGroup(
        id: 'sportif',
        name: 'Sportif',
        sortOrder: 1,
        routeSlug: 'long',
      ),
    ],
  ).copyWith(routeSlug: 'principal');

  RouteDetailDto route(String slug) => RouteDetailDto(
    permissions: kNoPermissions,
    elevationState: 'HD',
    tags: const [],
    id: 'r-$slug',
    slug: slug,
    team: ride.team,
    name: slug,
    media: ride.media,
    distance: 10000,
    elevationGain: 0,
    elevationLoss: 0,
    surfaceType: 'ROAD',
    visibility: 'PUBLIC',
    createdBy: const PublicUserDto(id: 'u9', displayName: 'Créatrice'),
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
    tracks: <TrackDto>[
      TrackDto(
        line: GeoJsonLineString(
          type: GeoJsonLineStringTypeType.lineString,
          coordinates: <List<double>>[
            for (int i = 0; i <= 10; i++)
              <double>[5, 45 + i * 0.009, 300, i * 1000.0],
          ],
        ),
        climbs: const <ClimbDto>[],
      ),
    ],
    waypoints: const <WaypointDto>[],
    deleted: false,
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final ProviderContainer container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(
          (Ref ref) => Completer<ConfigDto>().future,
        ),
        mapStyleProvider.overrideWith(
          (Ref ref, Brightness b) => const AsyncValue<ResolvedMapStyle?>.data(
            ResolvedMapStyle(
              selectedId: 's',
              style: MapStyleDto(
                id: 'plan',
                label: 'Plan',
                group: 'vector',
                url: 'https://tiles.example/plan.json',
              ),
              url: 'https://tiles.example/plan.json',
            ),
          ),
        ),
        // Pas de lot à charger : les géométries viennent du provider unitaire.
        rideRouteGeometriesProvider.overrideWith(
          (Ref ref, RideKey k) => RideRouteGeometriesController(ref, k),
        ),
        rideRouteGeometryProvider.overrideWith(
          (Ref ref, RouteRef r) =>
              AsyncValue<RouteDetailDto>.data(route(r.routeSlug)),
        ),
        unitSystemProvider.overrideWithValue(UnitSystem.metric),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: PedalonsTheme.build(Brightness.light),
          home: Scaffold(
            body: ListView(
              children: <Widget>[RideGroupsMap(rideKey: key, ride: ride)],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('la pilule nomme le parcours sélectionné, encastrée et en plein '
      'écran, à l\'écart de « Fermer »', (WidgetTester tester) async {
    await pump(tester);
    final Finder pill = find.byKey(keys.ride.groupsMapPill);
    expect(pill, findsOneWidget);
    expect(
      find.descendant(of: pill, matching: find.text('Chill')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(PdlIcons.fullscreen));
    await tester.pumpAndSettle();

    expect(pill, findsOneWidget);
    final Rect close = tester.getRect(
      find.ancestor(
        of: find.byIcon(PdlIcons.close),
        matching: find.byType(PdlMapButton),
      ),
    );
    expect(tester.getRect(pill).overlaps(close), isFalse);
  });
}
