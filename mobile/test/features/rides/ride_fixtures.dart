import 'package:pedalons/api/generated/export.dart';

/// Jeux de données du lot 2 pour les sorties.
///
/// Partagés par les tests de la carte de groupe, du contrôleur d'inscription
/// et de l'écran : construire un `RideDto` à la main coûte une quinzaine de
/// champs obligatoires, et deux copies de ce coût divergent dès qu'un champ
/// s'ajoute au contrat.
RideGroupDto fixtureGroup({
  String id = 'g1',
  String name = 'Chill Route Long',
  bool registered = false,
  bool full = false,
  int countParticipants = 3,
  int? maxParticipants = 16,
  int sortOrder = 0,
  PublicUserDto? leader,
  String? routeSlug,
  String startAt = '2026-10-11T06:00:00Z',
}) => RideGroupDto(
  startAt: startAt,
  id: id,
  name: name,
  countParticipants: countParticipants,
  participants: <PublicUserDto>[
    for (int i = 0; i < countParticipants; i++)
      PublicUserDto(id: 'u$i', displayName: 'Membre $i'),
  ],
  sortOrder: sortOrder,
  registered: registered,
  full: full,
  maxParticipants: maxParticipants,
  averageSpeed: 26,
  distance: 66500,
  elevationGain: 413,
  leader: leader,
  routeSlug: routeSlug,
);

RideDto fixtureRide({
  String status = 'PUBLISHED',
  String dateTime = '2099-07-29T19:30:00Z',
  bool registered = false,
  String? registeredGroupId,
  bool full = false,
  List<RideGroupDto>? groups,
}) {
  final List<RideGroupDto> gs = groups ?? <RideGroupDto>[fixtureGroup()];
  return RideDto(
    timezone: 'Europe/Paris',
    tags: const [],
    type: 'RIDE',
    team: const TeamPublicationDto(
      id: 't1',
      slug: 'n-peloton',
      name: 'N-Peloton',
      visibility: 'PUBLIC',
    ),
    id: 'r1',
    slug: 'np-665',
    name: 'N-Peloton #665',
    media: const MediaDto(
      markdown: '',
      assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
    ),
    dateTime: dateTime,
    endDateTime: DateTime.parse(dateTime)
        .add(const Duration(hours: 3))
        .toUtc()
        .toIso8601String(),
    status: status,
    // La règle du serveur (docs/LEDGER_*.md API-16) : terminée dès que le départ est passé.
    finished: DateTime.parse(dateTime).isBefore(DateTime.now()),
    visibility: 'PUBLIC',
    participantCount: 40,
    groupCount: gs.length,
    groups: gs,
    groupSummaries: const [],
    topParticipants: const <PublicUserDto>[],
    deleted: false,
    registered: registered,
    registeredGroupId: registeredGroupId,
    full: full,
  );
}

/// Une heure de prévision.
WeatherConditionsDto fixtureConditions({
  String time = '2099-07-29T19:00:00Z',
  String condition = 'PARTLY_CLOUDY',
  bool daylight = true,
  double temperature = 14.4,
  double apparentTemperature = 12.2,
  int? precipitationProbability = 20,
  double precipitation = 0,
  double windSpeed = 18,
  double windDirection = 315,
  String compass = 'NW',
  double? gusts = 32,
}) => WeatherConditionsDto(
  time: time,
  weatherCode: 2,
  condition: condition,
  daylight: daylight,
  temperature: temperature,
  apparentTemperature: apparentTemperature,
  precipitationProbability: precipitationProbability,
  precipitation: precipitation,
  wind: WindDto(
    speed: windSpeed,
    direction: windDirection,
    compass: compass,
    gusts: gusts,
  ),
);

/// L'étape météo d'un groupe : départ, un point en route, arrivée.
WeatherLegDto fixtureLeg({
  String? groupId = 'g1',
  String status = 'OK',
  bool speedIsDefault = false,
  WeatherRainAlertDto? rainAlert,
  String relativeWind = 'HEAD',
}) => WeatherLegDto(
  status: status,
  groupId: groupId,
  startTime: '2099-07-29T19:30:00Z',
  averageSpeed: speedIsDefault ? 25 : 26,
  speedIsDefault: speedIsDefault,
  distance: 30000,
  arrivalTime: '2099-07-29T20:40:00Z',
  checkpoints: <WeatherCheckpointDto>[
    WeatherCheckpointDto(
      indexField: 0,
      kind: 'START',
      distance: 0,
      time: '2099-07-29T19:30:00Z',
      weather: fixtureConditions(),
      relativeWind: relativeWind,
      headwind: 12,
      relativeWindAngle: 180,
    ),
    WeatherCheckpointDto(
      indexField: 1,
      kind: 'EN_ROUTE',
      distance: 15000,
      time: '2099-07-29T20:05:00Z',
      weather: fixtureConditions(condition: 'RAIN'),
      relativeWind: 'TAIL',
      headwind: -10,
      relativeWindAngle: 10,
    ),
    const WeatherCheckpointDto(
      indexField: 2,
      kind: 'FINISH',
      distance: 30000,
      time: '2099-07-29T20:40:00Z',
    ),
  ],
  segments: <WindSegmentDto>[
    WindSegmentDto(
      fromDistance: 0,
      toDistance: 15000,
      relativeWind: relativeWind,
      headwind: 12,
    ),
    const WindSegmentDto(
      fromDistance: 15000,
      toDistance: 30000,
      relativeWind: 'TAIL',
      headwind: -10,
    ),
  ],
  windExposure: const WindExposureDto(head: 15000, cross: 0, tail: 15000),
  prevailingWind: const WindDto(speed: 17, direction: 300, compass: 'NW'),
  rainAlert: rainAlert,
);

/// La réponse de `getRideWeather`. Par défaut `OUT_OF_RANGE` : rien n'est
/// rendu, ce qui laisse les tests qui ne parlent pas de météo inchangés.
RideWeatherDto fixtureWeather({
  String status = 'OUT_OF_RANGE',
  List<WeatherLegDto> legs = const <WeatherLegDto>[],
  WeatherConditionsDto? departure,
  String? availableFrom,
  String? fetchedAt,
}) => RideWeatherDto(
  status: status,
  availableFrom: availableFrom,
  fetchedAt: fetchedAt,
  departure: DepartureWeatherDto(
    status: departure == null ? status : 'OK',
    conditions: departure,
    sunrise: departure == null ? null : '2099-07-29T04:30:00Z',
    sunset: departure == null ? null : '2099-07-29T19:45:00Z',
  ),
  legs: legs,
  attribution: const WeatherAttributionDto(
    name: 'Open-Meteo.com',
    url: 'https://open-meteo.com/',
  ),
);
