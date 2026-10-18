import 'package:flutter_test/flutter_test.dart';
import 'package:pedalons/api/generated/export.dart';
import 'package:pedalons/features/rides/domain/ride_form.dart'
    show kRideMarkdownMaxLength;
import 'package:pedalons/features/routes/domain/route_form.dart';

/// Le formulaire d'un parcours (ledger `MOB-79`) : ce qui part au serveur, qui
/// réécrit le parcours en entier.
TeamDetailDto _team({String visibility = 'PUBLIC'}) => TeamDetailDto(
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
  id: 'r1',
  slug: 'col',
  elevationState: 'HD',
  team: const TeamPublicationDto(
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
      final RouteRequest request = RouteForm.initial(
        _team(),
      ).copyWith(name: 'abc', tagIds: <String>['a', 'b']).toRequest();
      expect(request.tagIds, <String>['a', 'b']);
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
