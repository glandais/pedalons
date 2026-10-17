import 'package:pedalons/api/generated/export.dart';

/// Jeux de données des modèles de sortie (ledger `MOB-78`), partagés par les
/// tests du formulaire, de la liste et de l'éditeur : un `RideTemplateDto`
/// compte une douzaine de champs obligatoires, et trois copies de ce coût
/// divergent dès qu'un champ s'ajoute au contrat.
const TeamPublicationDto kFixtureTemplateTeam = TeamPublicationDto(
  id: 't1',
  slug: 'n-peloton',
  name: 'N-Peloton',
  visibility: 'PUBLIC',
);

RideTemplateGroupDto fixtureTemplateGroup({
  String id = 'tg1',
  String name = 'Groupe A',
  int sortOrder = 0,
  String? time,
  double? averageSpeed,
  int? maxParticipants,
}) => RideTemplateGroupDto(
  id: id,
  name: name,
  sortOrder: sortOrder,
  time: time,
  averageSpeed: averageSpeed,
  maxParticipants: maxParticipants,
);

RideTemplateDto fixtureTemplate({
  String id = 'tpl-1',
  String slug = 'dimanche',
  String name = 'Sortie du dimanche',
  String markdown = '',
  String visibility = 'PUBLIC',
  String status = 'PUBLISHED',
  int? nextNumber = 42,
  List<RideTemplateGroupDto>? groups,
  List<TagDto> tags = const <TagDto>[],
}) {
  final List<RideTemplateGroupDto> gs =
      groups ??
      <RideTemplateGroupDto>[
        fixtureTemplateGroup(id: 'tg1', name: 'Groupe A'),
        fixtureTemplateGroup(id: 'tg2', name: 'Groupe B', sortOrder: 1),
        fixtureTemplateGroup(id: 'tg3', name: 'Groupe C', sortOrder: 2),
      ];
  return RideTemplateDto(
    team: kFixtureTemplateTeam,
    id: id,
    slug: slug,
    name: name,
    markdown: markdown,
    visibility: visibility,
    status: status,
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
    groupCount: gs.length,
    groups: gs,
    tags: tags,
    nextNumber: nextNumber,
  );
}

TeamDetailDto fixtureTemplateTeamDetail({
  String? role,
  String visibility = 'PUBLIC',
}) => TeamDetailDto(
  timezone: 'Europe/Paris',
  role: role,
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
