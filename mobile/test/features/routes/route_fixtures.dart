import 'package:pedalons/api/generated/export.dart';

/// Jeux de données de l'éditeur de parcours (ledger `MOB-79`) : l'équipe, un
/// parcours, et un GPX minimal.
const MediaDto fixtureEmptyMedia = MediaDto(
  markdown: '',
  assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
);

TeamDetailDto fixtureRouteTeam({
  String? role,
  String visibility = 'PUBLIC',
  bool enableRoutes = true,
}) => TeamDetailDto(
  timezone: 'Europe/Paris',
  role: role,
  id: 't1',
  slug: 'n-peloton',
  name: 'N-Peloton',
  about: fixtureEmptyMedia,
  visibility: visibility,
  enableTrips: true,
  enableAds: true,
  enablePosts: true,
  enableRides: true,
  enableRoutes: enableRoutes,
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

RouteDetailDto fixtureRouteDetail({
  String slug = 'col-de-la-croix',
  String name = 'Col de la Croix',
  String surfaceType = 'GRAVEL',
  bool deleted = false,
  String createdBy = 'u9',
}) => RouteDetailDto(
  id: 'r1',
  slug: slug,
  elevationState: 'HD',
  team: const TeamPublicationDto(
    id: 't1',
    slug: 'n-peloton',
    name: 'N-Peloton',
    visibility: 'PUBLIC',
  ),
  name: name,
  media: fixtureEmptyMedia.copyWith(markdown: 'Un beau col.'),
  distance: 50000,
  elevationGain: 800,
  elevationLoss: 800,
  surfaceType: surfaceType,
  visibility: 'PUBLIC',
  createdBy: PublicUserDto(id: createdBy, displayName: 'Créatrice'),
  createdAt: '2026-01-01T10:00:00Z',
  updatedAt: '2026-01-01T10:00:00Z',
  tracks: const <TrackDto>[],
  waypoints: const <WaypointDto>[],
  deleted: deleted,
  tags: const <TagDto>[],
);

/// Un GPX minimal dont la première trace s'appelle [trackName].
String fixtureGpx({String trackName = 'Col de test'}) =>
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<gpx version="1.1" creator="test" xmlns="http://www.topografix.com/GPX/1/1">'
    '<trk><name>$trackName</name><trkseg>'
    '<trkpt lat="45.0" lon="5.0"><ele>200</ele></trkpt>'
    '<trkpt lat="45.01" lon="5.01"><ele>230</ele></trkpt>'
    '</trkseg></trk></gpx>';

/// Un point de parcours. [distance] nul : hors tracé. [id] nul : un point du
/// GPX pas encore enregistré (clé de repli `i<rang>`).
WaypointDto fixtureWaypoint({
  String? id = 'w1',
  String type = 'SUPPLY',
  String name = 'Café du Port',
  String? description,
  double? distance = 12300,
  double lon = 5.0,
  double lat = 45.0,
}) => WaypointDto(
  id: id,
  geometry: GeoJsonPoint(
    type: GeoJsonPointTypeType.point,
    coordinates: <double>[lon, lat],
  ),
  name: name,
  type: type,
  description: description,
  distance: distance,
  origin: 'AUTHOR',
);
