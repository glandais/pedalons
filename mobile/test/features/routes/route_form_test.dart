import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/rides/domain/ride_form.dart'
    show kRideMarkdownMaxLength;
import 'package:pedalons/features/routes/domain/planner_result.dart';
import 'package:pedalons/features/routes/domain/route_form.dart';

import '../../support/content_permissions.dart';
import 'route_fixtures.dart'
    show fixturePlannerStateJson, fixtureRouteDetail, fixtureRouteTeam;

/// Le formulaire d'un parcours (ledger `MOB-79`) : ce qui part au serveur, qui
/// réécrit le parcours en entier.
TeamDetailDto _team({String visibility = 'PUBLIC'}) => TeamDetailDto(
  allowedContentVisibilities: contentVisibilitiesFor(visibility),
  defaultContentVisibility: visibility,
  publicContentAllowed: false,
  tier: 'FREE',
  timezone: 'Europe/Paris',
  id: 't1',
  slug: 'n-peloton',
  name: 'N-Peloton',
  about: const MediaDto(
    markdown: '',
    assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
  ),
  visibility: visibility,
  enableTrips: true,
  enableAds: true,
  enablePosts: true,
  enableRides: true,
  enableRoutes: true,
  visibilityEditable: true,
  joinable: true,
  addMemberAllowed: true,
  enableMemberDirectory: false,
  postsAsTeamByDefault: true,
  enableRoutePlanner: false,
  memberCount: 40,
  upcomingRideCount: 3,
  routeCount: 12,
  upcomingTripCount: 0,
  recentPostCount: 0,
  createdAt: '2024-01-01T00:00:00Z',
);

RouteDetailDto _route({
  String surfaceType = 'GRAVEL',
  List<TagDto> tags = const <TagDto>[],
  MediaDto? media,
}) => RouteDetailDto(
  permissions: kNoPermissions,
  id: 'r1',
  slug: 'col',
  elevationState: 'HD',
  team: const TeamPublicationDto(
    accessible: true,
    id: 't1',
    slug: 'n-peloton',
    name: 'N-Peloton',
    visibility: 'PUBLIC',
  ),
  name: 'Col de la Croix',
  media:
      media ??
      const MediaDto(
        markdown: 'Un beau col.',
        assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
      ),
  distance: 50000,
  elevationGain: 800,
  elevationLoss: 800,
  surfaceType: surfaceType,
  visibility: 'TEAM',
  createdBy: const PublicUserDto(id: 'u9', displayName: 'Créatrice'),
  createdAt: '2026-01-01T10:00:00Z',
  updatedAt: '2026-01-01T10:00:00Z',
  tracks: const <TrackDto>[],
  waypoints: const <WaypointDto>[],
  deleted: false,
  tags: tags,
);

void main() {
  group('RouteForm.initial', () {
    test("route, visibilité de l'équipe, sans tag ni texte", () {
      final RouteForm form = RouteForm.initial(_team(visibility: 'TEAM'));
      expect(form.name, isEmpty);
      expect(form.surfaceType, SurfaceType.road);
      expect(form.visibility, Visibility.team);
      expect(form.tagIds, isEmpty);
      expect(form.media.markdown, isEmpty);
      expect(form.media.assets.images, isEmpty);
      expect(form.media.assets.attachments, isEmpty);
      expect(RouteForm.initial(_team()).visibility, Visibility.public);
    });
  });

  group('RouteForm.fromRoute', () {
    test('reprend le parcours, médias tels quels, tags en identifiants', () {
      final RouteDetailDto route = _route(
        tags: const <TagDto>[
          TagDto(id: 'a', label: 'Gravel', color: 'blue'),
          TagDto(id: 'b', label: 'Col', color: 'red'),
        ],
      );
      final RouteForm form = RouteForm.fromRoute(route);
      expect(form.name, 'Col de la Croix');
      expect(form.surfaceType, SurfaceType.gravel);
      expect(form.visibility, Visibility.team);
      expect(form.tagIds, <String>['a', 'b']);
      expect(identical(form.media, route.media), isTrue);
    });

    test('une surface inconnue de cette version retombe sur « route »', () {
      expect(
        RouteForm.fromRoute(_route(surfaceType: 'HOVERBOARD')).surfaceType,
        SurfaceType.road,
      );
    });
  });

  group('RouteForm.toRequest', () {
    test('nom rogné, pas de points, tagIds toujours envoyé', () {
      final RouteForm form = RouteForm.initial(
        _team(),
      ).copyWith(name: '  Boucle du Vercors  ', surfaceType: SurfaceType.mtb);
      final RouteRequest request = form.toRequest();
      expect(request.name, 'Boucle du Vercors');
      expect(request.surfaceType, 'MTB');
      expect(request.visibility, 'PUBLIC');
      expect(request.points, isNull);
      // `[]` veut dire « plus aucun » ; nul laisserait les tags en place.
      expect(request.tagIds, isNotNull);
      expect(request.tagIds, isEmpty);
      expect(request.toJson()['tagIds'], <String>[]);
      expect(request.toJson()['points'], isNull);
    });

    test('les tags posés partent tels quels', () {
      final RouteRequest request = RouteForm.initial(_team())
          .copyWith(name: 'abc', tagIds: <String>['a', 'b'])
          .toRequest();
      expect(request.tagIds, <String>['a', 'b']);
    });

    test('sans planificateur : la requête de MOB-79, rien de plus', () {
      final Map<String, dynamic> json = RouteForm.initial(_team())
          .copyWith(name: 'abc')
          .toRequest()
          .toJson();
      expect(json['points'], isNull);
      expect(json['plannerState'], isNull);
      expect(json['waypoints'], isNull);
      expect(json['excludedFromGenerator'], isNull);
    });
  });

  // Ce que le planificateur embarqué rend (`done.payload`) fusionné dans la
  // requête : la règle est celle de la page, recopiée telle quelle (ledger
  // `MOB-170`).
  group('RouteForm.toRequest(planner:)', () {
    final RouteForm form = RouteForm.initial(_team()).copyWith(name: 'Boucle');

    PlannerResult result(Map<String, dynamic> payload, {String? notice}) =>
        PlannerResult.fromMessage(<String, dynamic>{
          'type': 'done',
          'payload': payload,
          'stats': <String, dynamic>{
            'distance': 1000,
            'ascend': 10,
            'pointCount': 2,
            'line': '',
          },
          'dirty': true,
          'notice': ?notice,
        });

    const List<Map<String, dynamic>> points = <Map<String, dynamic>>[
      <String, dynamic>{'lng': 5.0, 'lat': 45.0},
      <String, dynamic>{'lng': 5.01, 'lat': 45.01},
    ];
    const List<Map<String, dynamic>> waypoints = <Map<String, dynamic>>[
      <String, dynamic>{
        'position': <String, dynamic>{'lng': 5.0, 'lat': 45.0},
        'type': 'WATER',
        'name': 'Fontaine',
      },
    ];

    test('`plannerState` : l\'état part, pas de points', () {
      final PlannerResult drawn = result(<String, dynamic>{
        'plannerState': fixturePlannerStateJson,
      });
      final RouteRequest request = form.toRequest(planner: drawn);
      expect(
        request.plannerState,
        PlannerState.fromJson(fixturePlannerStateJson),
      );
      expect(request.points, isNull);
      expect(request.waypoints, isNull);
      expect(drawn.hasTrack, isTrue);
      expect(drawn.file, isFalse);
      // Le reste du formulaire n'a pas bougé.
      expect(request.name, 'Boucle');
      expect(request.tagIds, isEmpty);
    });

    test('`points` : les points partent, pas d\'état ; `tooLarge` se lit', () {
      final PlannerResult drawn = result(<String, dynamic>{
        'points': points,
      }, notice: 'tooLarge');
      final RouteRequest request = form.toRequest(planner: drawn);
      expect(request.plannerState, isNull);
      expect(request.points, const <GeoPoint>[
        GeoPoint(lng: 5, lat: 45),
        GeoPoint(lng: 5.01, lat: 45.01),
      ]);
      expect(drawn.tooLarge, isTrue);
    });

    test('jamais les deux : l\'état gagne sur des points', () {
      final RouteRequest request = form.toRequest(
        planner: result(<String, dynamic>{
          'plannerState': fixturePlannerStateJson,
          'points': points,
        }),
      );
      expect(request.plannerState, isNotNull);
      expect(request.points, isNull);
    });

    test('`file: true` : rien dans la requête, le fichier part à part', () {
      final PlannerResult drawn = result(<String, dynamic>{
        'file': true,
        'fileId': '3',
      });
      final RouteRequest request = form.toRequest(planner: drawn);
      expect(request.plannerState, isNull);
      expect(request.points, isNull);
      expect(drawn.file, isTrue);
      expect(drawn.fileId, '3');
      expect(drawn.hasTrack, isTrue);
    });

    test('fragment vide (parcours laissé tel quel) : aucun tracé', () {
      final PlannerResult drawn = result(<String, dynamic>{});
      final RouteRequest request = form.toRequest(planner: drawn);
      expect(request.plannerState, isNull);
      expect(request.points, isNull);
      expect(request.waypoints, isNull);
      expect(drawn.hasTrack, isFalse);
      expect(drawn.isEmpty, isTrue);
    });

    test(
      '`waypoints` seulement quand ils sont là — seuls, ou avec le tracé',
      () {
        final PlannerResult alone = result(<String, dynamic>{
          'waypoints': waypoints,
        });
        final RouteRequest request = form.toRequest(planner: alone);
        expect(request.waypoints!.single.name, 'Fontaine');
        expect(request.waypoints!.single.type, 'WATER');
        expect(request.plannerState, isNull);
        expect(alone.hasTrack, isFalse);
        expect(alone.isEmpty, isFalse);

        final RouteRequest both = form.toRequest(
          planner: result(<String, dynamic>{
            'plannerState': fixturePlannerStateJson,
            'waypoints': waypoints,
          }),
        );
        expect(both.plannerState, isNotNull);
        expect(both.waypoints, hasLength(1));
        // Une liste vide veut dire « plus aucun point » : elle part.
        expect(
          form
              .toRequest(
                planner: result(<String, dynamic>{'waypoints': <dynamic>[]}),
              )
              .waypoints,
          isEmpty,
        );
      },
    );

    test('un fragment hors contrat lève, il n\'est pas deviné', () {
      expect(
        () => result(<String, dynamic>{
          'plannerState': <String, dynamic>{'version': 1},
        }),
        throwsA(anything),
      );
    });
  });

  group('« Ne pas utiliser pour générer des parcours »', () {
    test('planificateur fermé : jamais envoyé, le serveur garde sa valeur', () {
      expect(RouteForm.initial(_team()).excludedFromGenerator, isNull);
      expect(
        RouteForm.fromRoute(fixtureRouteDetail(excludedFromGenerator: true))
            .toRequest()
            .excludedFromGenerator,
        isNull,
      );
    });

    test('planificateur ouvert : la valeur du parcours, faux par défaut', () {
      expect(
        RouteForm.initial(fixtureRouteTeam(enableRoutePlanner: true))
            .toRequest()
            .excludedFromGenerator,
        isFalse,
      );
      expect(
        RouteForm.fromRoute(
          fixtureRouteDetail(excludedFromGenerator: true),
          planner: true,
        ).excludedFromGenerator,
        isTrue,
      );
      final RouteForm unset = RouteForm.fromRoute(
        fixtureRouteDetail(),
        planner: true,
      );
      expect(unset.excludedFromGenerator, isFalse);
      expect(
        unset
            .copyWith(excludedFromGenerator: true)
            .toRequest()
            .excludedFromGenerator,
        isTrue,
      );
    });
  });

  group('decodePolyline6', () {
    test('latitude d\'abord, précision 6', () {
      final List<List<double>> line = <List<double>>[
        for (final p in decodePolyline6('_sqytA_sdpH_pR_pR'))
          <double>[p.lng, p.lat],
      ];
      expect(line, <List<double>>[
        <double>[5, 45],
        <double>[5.01, 45.01],
      ]);
    });

    test('vide ou tronquée : ce qui a pu être lu', () {
      expect(decodePolyline6(''), isEmpty);
      expect(decodePolyline6('_sqytA_sdpH_pR'), hasLength(1));
    });
  });

  group('validation', () {
    final RouteForm base = RouteForm.initial(_team());

    test('le nom compte entre 3 et 200 caractères, espaces rognés', () {
      expect(base.copyWith(name: '').nameValid, isFalse);
      expect(base.copyWith(name: '  ab  ').nameValid, isFalse);
      expect(base.copyWith(name: 'abc').nameValid, isTrue);
      expect(base.copyWith(name: 'a' * 200).nameValid, isTrue);
      expect(base.copyWith(name: 'a' * 201).nameValid, isFalse);
    });

    test('la description a la borne de la sortie', () {
      final MediaDto media = base.media;
      expect(
        base
            .copyWith(
              media: media.copyWith(markdown: 'a' * kRideMarkdownMaxLength),
            )
            .markdownValid,
        isTrue,
      );
      expect(
        base
            .copyWith(
              media: media.copyWith(
                markdown: 'a' * (kRideMarkdownMaxLength + 1),
              ),
            )
            .markdownValid,
        isFalse,
      );
    });

    test('dix tags au plus', () {
      List<String> ids(int n) => <String>[for (int i = 0; i < n; i++) 't$i'];
      expect(base.copyWith(tagIds: ids(kRouteMaxTags)).tagsValid, isTrue);
      expect(base.copyWith(tagIds: ids(kRouteMaxTags + 1)).tagsValid, isFalse);
    });

    test('isValid est la conjonction', () {
      expect(base.isValid, isFalse);
      expect(base.copyWith(name: 'Boucle').isValid, isTrue);
      expect(
        base
            .copyWith(
              name: 'Boucle',
              tagIds: <String>[for (int i = 0; i < 11; i++) 't$i'],
            )
            .isValid,
        isFalse,
      );
    });
  });
}
