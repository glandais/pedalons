import 'package:pedalons/api/generated/export.dart';

/// Jeux de données du lot 4 pour les voyages.
///
/// Un `TripDto` coûte quinze champs obligatoires ; deux copies de ce coût
/// divergent dès qu'un champ s'ajoute au contrat. Les tests de la carte de
/// synthèse, du contrôleur de participation et des deux écrans partagent
/// celui-ci.
const MediaDto kEmptyMedia = MediaDto(
  markdown: '',
  assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
);

const TeamPublicationDto kFixtureTeam = TeamPublicationDto(
  id: 't1',
  slug: 'n-peloton',
  name: 'N-Peloton',
  visibility: 'PUBLIC',
);

RouteDto fixtureStageRoute({
  String slug = 'gtmc-j1',
  String name = 'GTMC J1',
  double distance = 78400,
  double elevationGain = 1120,
}) => RouteDto(
  elevationState: 'HD',
  tags: const [],
  id: 'route-$slug',
  slug: slug,
  team: kFixtureTeam,
  name: name,
  media: kEmptyMedia,
  distance: distance,
  elevationGain: elevationGain,
  elevationLoss: 1285,
  surfaceType: 'GRAVEL',
  visibility: 'PUBLIC',
  createdAt: '2026-01-01T10:00:00Z',
  deleted: false,
);

TripStageDto fixtureStage({
  required int index,
  int stageCount = 3,
  String? slug,
  String? name,
  String dateTime = '2099-08-12T07:00:00Z',
  RouteDto? route,
  String? startPlaceName,
  String? startAddress,
  String? endPlaceName,
  int? commentCount,
  String timezone = 'Europe/Paris',
}) => TripStageDto(
  timezone: timezone,
  id: 's$index',
  slug: slug ?? 'j$index',
  name: name ?? 'J$index',
  dateTime: dateTime,
  media: kEmptyMedia,
  sortOrder: index * 10,
  stageIndex: index,
  stageCount: stageCount,
  commentCount: commentCount,
  route: route,
  startPlace: startPlaceName == null
      ? null
      : PlaceDetailDto(
          id: 'p-start-$index',
          name: startPlaceName,
          startPlace: true,
          endPlace: false,
          address: startAddress,
        ),
  endPlace: endPlaceName == null
      ? null
      : PlaceDetailDto(
          id: 'p-end-$index',
          name: endPlaceName,
          startPlace: false,
          endPlace: true,
        ),
);

TripDto fixtureTrip({
  String status = 'PUBLISHED',
  String dateTime = '2099-08-12T07:00:00Z',
  String? endDate = '2099-08-18T07:00:00Z',
  bool registered = false,
  int participantCount = 3,
  List<TripStageDto>? stages,
  List<PublicUserDto>? participants,
  double? totalDistance = 612000,
  double? totalElevationGain = 9840,
  int? commentCount = 2,
}) {
  final List<TripStageDto> ss =
      stages ??
      <TripStageDto>[
        fixtureStage(index: 1, route: fixtureStageRoute()),
        fixtureStage(
          index: 2,
          route: fixtureStageRoute(slug: 'gtmc-j2', name: 'GTMC J2'),
        ),
        fixtureStage(index: 3),
      ];
  return TripDto(
    timezone: 'Europe/Paris',
    tags: const [],
    type: 'TRIP',
    team: kFixtureTeam,
    id: 'trip1',
    slug: 'gtmc-bromance',
    name: 'GTMC Bromance',
    media: kEmptyMedia,
    dateTime: dateTime,
    endDateTime: DateTime.parse(
      endDate ?? dateTime,
    ).add(const Duration(hours: 3)).toUtc().toIso8601String(),
    endDate: endDate,
    status: status,
    // La règle du serveur (docs/LEDGER_*.md API-16) : terminé une fois la dernière étape commencée.
    finished: DateTime.parse(endDate ?? dateTime).isBefore(DateTime.now()),
    visibility: 'PUBLIC',
    participantCount: participantCount,
    stageCount: ss.length,
    stages: ss,
    participants:
        participants ??
        <PublicUserDto>[
          for (int i = 0; i < participantCount; i++)
            PublicUserDto(id: 'u$i', displayName: 'Membre $i'),
        ],
    deleted: false,
    registered: registered,
    totalDistance: totalDistance,
    totalElevationGain: totalElevationGain,
    commentCount: commentCount,
  );
}
