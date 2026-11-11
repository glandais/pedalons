// Les données fixes de la galerie de cartes — page de DEBUG.
//
// Elles suivent le cahier commun à l'app et au site
// (`docs/plans/2026-11-10-etat-des-lieux-affichage/audit-cartes/galerie.md`,
// § Données) : mêmes équipes, mêmes personnes, mêmes chiffres. Les dates sont
// relatives au jour d'exécution (J), à l'heure de Paris, pour que les cartes
// calculent « Demain », « En cours » ou « Terminée » d'après l'horloge.

import '../../api/generated/export.dart';
import '../../core/utils/formatters.dart';

/// Le fuseau des sorties et de la lectrice : aucune mention de fuseau.
const String kGalleryZone = 'Europe/Paris';

/// Les adresses des images de substitution. Elles ne désignent aucun serveur
/// (`.invalid`) : la galerie dépose les octets dans le cache d'images sous ces
/// clés avant d'afficher les cartes (`gallery_images.dart`).
abstract final class GalleryImageUrls {
  static const String mapLight = 'https://galerie.invalid/parcours-clair.png';
  static const String mapDark = 'https://galerie.invalid/parcours-sombre.png';
  static const String photo = 'https://galerie.invalid/photo.png';
  static const String adPhoto = 'https://galerie.invalid/annonce.png';

  static const List<String> all = <String>[mapLight, mapDark, photo, adPhoto];
}

const String kRideName = 'Boucle des Monts d’Arrée';
const String kRideSlug = 'boucle-des-monts-d-arree';
const String kTripName = 'Traversée du Morvan';
const String kTripSlug = 'traversee-du-morvan';
const String kPostName = 'Bilan de la saison';
const String kRouteSlug = 'boucle-des-monts-d-arree';

/// Tout ce que la galerie montre, calculé à partir de [nowUtc].
class GalleryData {
  GalleryData({DateTime? now, this.images = true})
    : nowUtc = (now ?? DateTime.now()).toUtc() {
    _today = AppFormatters.toZoneTime(nowUtc, kGalleryZone);
  }

  final DateTime nowUtc;

  /// Faux dans les tests : pas d'image, donc rien à charger.
  final bool images;

  late final DateTime _today;

  String? _img(String url) => images ? url : null;

  /// J + [day] à [hour]:[minute], heure de Paris, en instant du contrat.
  String at(int day, int hour, [int minute = 0]) =>
      AppFormatters.zoneWallClockToUtc(
        DateTime(_today.year, _today.month, _today.day + day, hour, minute),
        kGalleryZone,
      ).toUtc().toIso8601String();

  /// Il y a [d].
  String ago(Duration d) => nowUtc.subtract(d).toIso8601String();

  /// Dans [d].
  String later(Duration d) => nowUtc.add(d).toIso8601String();

  // ───────────────────────────────────────────────────────────── personnes

  static const PublicUserDto lea = PublicUserDto(
    id: 'u-lea',
    displayName: 'Léa Martin',
  );
  static const PublicUserDto karim = PublicUserDto(
    id: 'u-karim',
    displayName: 'Karim Benali',
  );
  static const PublicUserDto camille = PublicUserDto(
    id: 'u-camille',
    displayName: 'Camille Durand',
  );
  static const PublicUserDto noe = PublicUserDto(
    id: 'u-noe',
    displayName: 'Noé Perrin',
  );
  static const PublicUserDto ines = PublicUserDto(
    id: 'u-ines',
    displayName: 'Inès Roche',
  );
  static const PublicUserDto sacha = PublicUserDto(
    id: 'u-sacha',
    displayName: 'Sacha Morel',
  );
  static const PublicUserDto jeanne = PublicUserDto(
    id: 'u-jeanne',
    displayName: 'Jeanne Colin',
  );
  static const PublicUserDto malo = PublicUserDto(
    id: 'u-malo',
    displayName: 'Malo Guérin',
  );

  static const List<PublicUserDto> people = <PublicUserDto>[
    lea,
    karim,
    camille,
    noe,
    ines,
    sacha,
    jeanne,
    malo,
  ];

  /// La lectrice.
  UserDto get reader => const UserDto(
    id: 'u-camille',
    email: 'camille.durand@example.org',
    displayName: 'Camille Durand',
    contactableByMembers: true,
    emailVerified: true,
    timezone: kGalleryZone,
    unitSystem: 'METRIC',
    language: 'fr',
    connectedServices: <GpsServiceConnectionDto>[],
  );

  ConfigDto get config => const ConfigDto(
    webAuthnRpId: 'localhost',
    appName: 'Pédalons',
    singleTeam: false,
    enableGpxPlanner: false,
    mapStyles: <MapStyleDto>[],
    tileServerBaseUrl: '',
    defaultCenter: MapCenterDto(lat: 48.4, lon: -3.9, zoom: 8),
    gpsAutoSyncEnabled: false,
  );

  // ─────────────────────────────────────────────────────────────── équipes

  static const TeamPublicationDto vcm = TeamPublicationDto(
    id: 't-vcm',
    name: 'Vélo Club des Monts',
    slug: 'velo-club-des-monts',
    visibility: 'TEAM',
    accessible: true,
  );
  static const TeamPublicationDto gravel = TeamPublicationDto(
    id: 't-gravel',
    name: 'Gravel Bretagne',
    slug: 'gravel-bretagne',
    visibility: 'PUBLIC',
    accessible: true,
  );

  static const MediaDto emptyMedia = MediaDto(
    markdown: '',
    assets: AssetsDto(images: <AssetDto>[], attachments: <AssetDto>[]),
  );

  /// Ce que le serveur calcule pour une membre de l'équipe : s'inscrire,
  /// commenter, voir les noms ; rien à modifier.
  static const ContentPermissionsDto memberPermissions = ContentPermissionsDto(
    canEdit: false,
    canDelete: false,
    indexable: false,
    canRegister: true,
    canComment: true,
    canSeeParticipants: true,
  );

  static const List<TagDto> routeTags = <TagDto>[
    TagDto(id: 'tag-vallonne', label: 'vallonné', color: 'teal'),
    TagDto(id: 'tag-finistere', label: 'Finistère', color: 'blue'),
  ];

  static const List<Visibility> _teamOnly = <Visibility>[Visibility.team];
  static const List<Visibility> _all = <Visibility>[
    Visibility.team,
    Visibility.publicUnlisted,
    Visibility.public,
  ];

  TeamDetailDto teamDetail({required bool clubDesMonts, String? role}) {
    final List<Visibility> v = clubDesMonts ? _teamOnly : _all;
    final TeamPublicationDto t = clubDesMonts ? vcm : gravel;
    return TeamDetailDto(
      id: t.id,
      name: t.name,
      slug: t.slug,
      about: emptyMedia,
      visibility: t.visibility,
      enableTrips: true,
      enableAds: true,
      enablePosts: true,
      enableRides: true,
      enableRoutes: true,
      enableMemberDirectory: false,
      postsAsTeamByDefault: true,
      visibilityEditable: false,
      joinable: !clubDesMonts,
      addMemberAllowed: false,
      enableRoutePlanner: false,
      memberCount: clubDesMonts ? 24 : 112,
      upcomingRideCount: clubDesMonts ? 2 : 0,
      routeCount: clubDesMonts ? 18 : 64,
      upcomingTripCount: clubDesMonts ? 1 : 0,
      recentPostCount: clubDesMonts ? 1 : 0,
      createdAt: '2021-03-01T10:00:00Z',
      timezone: kGalleryZone,
      allowedContentVisibilities: ContentVisibilitiesDto(
        ride: v,
        rideTemplate: v,
        route: v,
        post: v,
        trip: v,
        teamPage: v,
        ad: _teamOnly,
      ),
      defaultContentVisibility: t.visibility,
      publicContentAllowed: false,
      excerpt: clubDesMonts
          ? 'Sorties route et gravel au départ de Huelgoat, toute l’année.'
          : 'Le gravel en Bretagne, des Monts d’Arrée aux Montagnes Noires.',
      role: role,
    );
  }

  MyInvitationDto get invitation => MyInvitationDto(
    id: 'inv-gravel',
    team: gravel,
    inviterName: 'Inès Roche',
    role: 'MEMBER',
    expiresAt: at(7, 23, 59),
  );

  MemberDto member(PublicUserDto user, String role, String joinedAt) =>
      MemberDto(
        team: vcm,
        id: 'm-${user.id}',
        user: user,
        role: role,
        joinedAt: joinedAt,
      );

  // ─────────────────────────────────────────────────────────────── météo

  RideWeatherSummaryDto weather({bool rainAlert = false}) =>
      RideWeatherSummaryDto(
        status: 'OK',
        condition: rainAlert ? 'RAIN' : 'PARTLY_CLOUDY',
        daylight: true,
        temperature: 11,
        temperatureMin: 9,
        temperatureMax: 13,
        maxPrecipitationProbability: rainAlert ? 60 : 20,
        wind: const WindDto(speed: 18, direction: 270, compass: 'W'),
        rainAlert: rainAlert
            ? WeatherRainAlertDto(
                probability: 60,
                time: at(4, 11),
                condition: 'RAIN',
              )
            : null,
        timezone: kGalleryZone,
      );

  WeatherLegDto _leg(RideGroupDto group) => WeatherLegDto(
    status: 'OK',
    groupId: group.id,
    startTime: group.startAt,
    averageSpeed: group.averageSpeed ?? 25,
    speedIsDefault: false,
    distance: group.distance ?? 0,
    arrivalTime: group.startAt,
    checkpoints: const <WeatherCheckpointDto>[],
    segments: const <WindSegmentDto>[],
    windExposure: const WindExposureDto(head: 0, cross: 0, tail: 0),
    summary: weather(),
  );

  /// La prévision d'une sortie, un leg par groupe.
  RideWeatherDto rideWeather(RideDto ride) => RideWeatherDto(
    status: 'OK',
    departure: const DepartureWeatherDto(status: 'OK'),
    legs: <WeatherLegDto>[for (final RideGroupDto g in ride.groups) _leg(g)],
    attribution: const WeatherAttributionDto(
      name: 'Open-Meteo.com',
      url: 'https://open-meteo.com/',
    ),
  );

  // ─────────────────────────────────────────────────────────────── groupes

  /// Un groupe de la sortie : « A » 28 km/h 8/12 avec Léa Martin pour
  /// capitaine, « B » 25 km/h 11/12, « C » 22 km/h 12/12, complet.
  RideGroupDto group(
    String letter, {
    bool registered = false,
    bool sameTime = false,
    bool withMax = true,
    bool withRoute = true,
    bool forceFull = false,
  }) {
    final (
      double speed,
      int count,
      int hour,
      int minute,
      double distance,
      double elevation,
      String route,
      List<PublicUserDto> faces,
    ) = switch (letter) {
      'A' => (
        28.0,
        8,
        9,
        0,
        92400.0,
        1240.0,
        kRouteSlug,
        <PublicUserDto>[lea, karim, noe, ines, sacha],
      ),
      'B' => (
        25.0,
        11,
        9,
        30,
        78000.0,
        980.0,
        'monts-d-arree-b',
        <PublicUserDto>[if (registered) camille, jeanne, malo, karim, noe],
      ),
      _ => (
        22.0,
        12,
        10,
        0,
        61000.0,
        720.0,
        'monts-d-arree-c',
        <PublicUserDto>[sacha, ines, malo, jeanne, lea],
      ),
    };
    final int max = 12;
    final int countShown = forceFull ? max : count;
    return RideGroupDto(
      id: 'g-${letter.toLowerCase()}',
      name: letter,
      startAt: sameTime ? at(4, 9) : at(4, hour, minute),
      countParticipants: countShown,
      participants: faces,
      sortOrder: letter.codeUnitAt(0) - 'A'.codeUnitAt(0),
      registered: registered,
      full: withMax && countShown >= max,
      maxParticipants: withMax ? max : null,
      averageSpeed: speed,
      distance: withRoute ? distance : null,
      elevationGain: withRoute ? elevation : null,
      routeSlug: withRoute ? route : null,
      leader: letter == 'A' ? lea : null,
      thumbnailLightUrl: withRoute ? _img(GalleryImageUrls.mapLight) : null,
      thumbnailDarkUrl: withRoute ? _img(GalleryImageUrls.mapDark) : null,
    );
  }

  RideGroupSummaryDto _summary(RideGroupDto g) => RideGroupSummaryDto(
    id: g.id,
    name: g.name,
    startAt: g.startAt,
    countParticipants: g.countParticipants,
    full: g.full,
    sortOrder: g.sortOrder,
    averageSpeed: g.averageSpeed,
    maxParticipants: g.maxParticipants,
    routeSlug: g.routeSlug,
    distance: g.distance,
    elevationGain: g.elevationGain,
  );

  List<RideGroupDto> groups({
    String? registeredIn,
    bool sameTime = false,
    bool withMaxInB = true,
    bool withRoute = true,
    bool allFull = false,
  }) => <RideGroupDto>[
    for (final String l in <String>['A', 'B', 'C'])
      group(
        l,
        registered: l == registeredIn,
        sameTime: sameTime,
        withMax: l != 'B' || withMaxInB,
        withRoute: withRoute,
        forceFull: allFull,
      ),
  ];

  // ─────────────────────────────────────────────────────────────── sorties

  static const PlaceDetailDto startPlace = PlaceDetailDto(
    id: 'p-mairie-huelgoat',
    name: 'Place de la Mairie',
    address: 'Huelgoat',
    startPlace: true,
    endPlace: false,
  );

  /// La sortie « Boucle des Monts d'Arrée », J+4 à 09:00, en ligne de fil.
  PublicationDtoRide feedRide({
    String slug = kRideSlug,
    String name = kRideName,
    String? dateTime,
    String? endDateTime,
    String status = 'PUBLISHED',
    bool finished = false,
    String? registeredIn,
    bool withGroups = true,
    bool deleted = false,
    bool rainAlert = false,
    bool allFull = false,
    bool withRoute = true,
    int? commentCount = 2,
  }) {
    final List<RideGroupDto> gs = withGroups
        ? groups(registeredIn: registeredIn, allFull: allFull)
        : const <RideGroupDto>[];
    final RideGroupDto? mine = gs
        .where((RideGroupDto g) => g.registered)
        .firstOrNull;
    final bool routed = withGroups && withRoute;
    final String start = dateTime ?? at(4, 9);
    return PublicationDtoRide(
      full: gs.isNotEmpty && gs.every((RideGroupDto g) => g.full),
      id: 'r-$slug',
      slug: slug,
      name: name,
      media: emptyMedia,
      dateTime: start,
      timezone: kGalleryZone,
      endDateTime:
          endDateTime ??
          DateTime.parse(start)
              .add(const Duration(hours: 4))
              .toUtc()
              .toIso8601String(),
      status: status,
      finished: finished,
      visibility: 'TEAM',
      team: vcm,
      participantCount: gs.fold<int>(
        0,
        (int sum, RideGroupDto g) => sum + g.countParticipants,
      ),
      groupCount: gs.length,
      // Une ligne de liste ne porte pas ses groupes, seulement leur résumé.
      groups: const <RideGroupDto>[],
      groupSummaries: <RideGroupSummaryDto>[
        for (final RideGroupDto g in gs)
          _summary(
            routed
                ? g
                : g.copyWith(
                    routeSlug: null,
                    distance: null,
                    elevationGain: null,
                  ),
          ),
      ],
      tags: const <TagDto>[],
      deleted: deleted,
      registered: mine != null,
      registeredGroupId: mine?.id,
      registeredGroup: mine,
      permissions: memberPermissions,
      topParticipants: withGroups
          ? const <PublicUserDto>[lea, karim, jeanne, malo, noe]
          : const <PublicUserDto>[],
      surfaceType: 'ROAD',
      startPlace: startPlace,
      distance: routed ? 92400 : null,
      elevationGain: routed ? 1240 : null,
      routeSlug: routed ? kRouteSlug : null,
      thumbnailLightUrl: routed ? _img(GalleryImageUrls.mapLight) : null,
      thumbnailDarkUrl: routed ? _img(GalleryImageUrls.mapDark) : null,
      thumbnailUrl: routed ? _img(GalleryImageUrls.mapLight) : null,
      commentCount: commentCount,
      excerpt: 'Trois groupes, trois allures, un café à l’arrivée au Roc’h Trévézel.',
      weather: rainAlert ? weather(rainAlert: true) : weather(),
    );
  }

  /// La même sortie en détail (`RideDto`), ses trois groupes embarqués.
  RideDto ride({
    String? registeredIn,
    bool sameTime = false,
    bool withMaxInB = true,
  }) {
    final List<RideGroupDto> gs = groups(
      registeredIn: registeredIn,
      sameTime: sameTime,
      withMaxInB: withMaxInB,
    );
    final RideGroupDto? mine = gs
        .where((RideGroupDto g) => g.registered)
        .firstOrNull;
    return RideDto(
      full: false,
      team: vcm,
      id: 'r-$kRideSlug',
      slug: kRideSlug,
      name: kRideName,
      media: emptyMedia,
      groupSummaries: <RideGroupSummaryDto>[
        for (final RideGroupDto g in gs) _summary(g),
      ],
      dateTime: at(4, 9),
      timezone: kGalleryZone,
      endDateTime: at(4, 13),
      status: 'PUBLISHED',
      finished: false,
      visibility: 'TEAM',
      type: 'RIDE',
      participantCount: gs.fold<int>(
        0,
        (int sum, RideGroupDto g) => sum + g.countParticipants,
      ),
      groupCount: gs.length,
      groups: gs,
      topParticipants: const <PublicUserDto>[lea, karim, jeanne, malo, noe],
      tags: const <TagDto>[],
      registered: mine != null,
      registeredGroupId: mine?.id,
      registeredGroup: mine,
      deleted: false,
      permissions: memberPermissions,
      surfaceType: 'ROAD',
      startPlace: startPlace,
      distance: 92400,
      elevationGain: 1240,
      routeSlug: kRouteSlug,
      thumbnailLightUrl: _img(GalleryImageUrls.mapLight),
      thumbnailDarkUrl: _img(GalleryImageUrls.mapDark),
      thumbnailUrl: _img(GalleryImageUrls.mapLight),
      commentCount: 2,
      weather: weather(),
    );
  }

  // ─────────────────────────────────────────────────────────────── voyages

  /// « Traversée du Morvan », J+10 → J+12, départ 08:30, 12 personnes.
  PublicationDtoTrip feedTrip({
    String status = 'PUBLISHED',
    bool underWay = false,
    bool registered = false,
  }) {
    final String start = underWay ? at(-1, 8, 30) : at(10, 8, 30);
    final String lastStage = underWay ? at(1, 9) : at(12, 9);
    final String end = underWay ? at(1, 16) : at(12, 16);
    return PublicationDtoTrip(
      team: vcm,
      id: 'trip-$kTripSlug',
      slug: kTripSlug,
      name: kTripName,
      media: emptyMedia,
      dateTime: start,
      timezone: kGalleryZone,
      endDateTime: end,
      endDate: lastStage,
      status: status,
      // Terminé une fois la dernière étape commencée (ledger `API-16`).
      finished: false,
      visibility: 'TEAM',
      participantCount: 12,
      stageCount: 3,
      stages: const <TripStageDto>[],
      participants: <PublicUserDto>[
        if (registered) camille,
        lea,
        karim,
        sacha,
        jeanne,
      ],
      deleted: false,
      registered: registered,
      tags: const <TagDto>[],
      permissions: memberPermissions,
      excerpt: 'Trois jours d’Autun à Avallon, par les lacs et les crêtes.',
      totalDistance: 201000,
      totalElevationGain: 3340,
      thumbnailLightUrl: _img(GalleryImageUrls.mapLight),
      thumbnailDarkUrl: _img(GalleryImageUrls.mapDark),
      commentCount: 0,
    );
  }

  RouteDto route({
    String slug = kRouteSlug,
    String name = kRideName,
    double distance = 92400,
    double elevationGain = 1240,
    bool thumbnail = true,
    bool deleted = false,
    List<TagDto> tags = routeTags,
    String visibility = 'PUBLIC',
    String surfaceType = 'ROAD',
  }) => RouteDto(
    id: 'route-$slug',
    slug: slug,
    team: vcm,
    name: name,
    media: MediaDto(
      markdown: '',
      assets: AssetsDto(
        images: const <AssetDto>[],
        attachments: const <AssetDto>[],
        thumbnailLight: thumbnail && images
            ? AssetDto(
                id: 'a-$slug-light',
                fileName: 'parcours-clair.png',
                contentType: 'image/png',
                url: GalleryImageUrls.mapLight,
              )
            : null,
        thumbnailDark: thumbnail && images
            ? AssetDto(
                id: 'a-$slug-dark',
                fileName: 'parcours-sombre.png',
                contentType: 'image/png',
                url: GalleryImageUrls.mapDark,
              )
            : null,
      ),
    ),
    distance: distance,
    elevationGain: elevationGain,
    elevationLoss: elevationGain,
    elevationState: 'HD',
    surfaceType: surfaceType,
    visibility: visibility,
    createdAt: at(-20, 18),
    deleted: deleted,
    tags: tags,
    permissions: memberPermissions,
    excerpt: 'Par Léa Martin : le Roc’h Trévézel et le mont Saint-Michel.',
    thumbnailUrl: thumbnail ? _img(GalleryImageUrls.mapLight) : null,
  );

  /// Les trois étapes du voyage.
  TripStageDto stage(
    int index, {
    bool withRoute = true,
    bool withSpeed = true,
  }) {
    final (String name, String date, double km, double up) = switch (index) {
      1 => ('Autun → Château-Chinon', at(10, 8, 30), 74000.0, 1380.0),
      2 => ('Château-Chinon → Saulieu', at(11, 9), 68000.0, 1120.0),
      _ => ('Saulieu → Avallon', at(12, 9), 59000.0, 840.0),
    };
    return TripStageDto(
      id: 'stage-$index',
      slug: 'etape-$index',
      name: name,
      dateTime: date,
      timezone: kGalleryZone,
      media: emptyMedia,
      sortOrder: index * 10,
      stageIndex: index,
      stageCount: 3,
      permissions: memberPermissions,
      // L'allure n'est donnée qu'à la première étape (cahier, § Données).
      averageSpeed: withSpeed && index == 1 ? 22 : null,
      route: withRoute
          ? route(
              slug: 'morvan-etape-$index',
              name: name,
              distance: km,
              elevationGain: up,
              tags: const <TagDto>[],
            )
          : null,
    );
  }

  // ───────────────────────────────────────────────────────── publications

  PublicationDtoPost feedPost({bool draft = false}) => PublicationDtoPost(
    team: vcm,
    id: draft ? 'post-brouillon' : 'post-bilan',
    slug: draft ? 'calendrier-hiver' : 'bilan-de-la-saison',
    name: draft ? 'Calendrier des sorties d’hiver' : kPostName,
    media: emptyMedia,
    dateTime: draft ? at(0, 8) : at(-2, 18, 30),
    timezone: kGalleryZone,
    status: draft ? 'DRAFT' : 'PUBLISHED',
    visibility: 'TEAM',
    deleted: false,
    signedAsTeam: false,
    tags: const <TagDto>[],
    permissions: memberPermissions,
    excerpt: draft
        ? 'Les dates sont à confirmer.'
        : 'Quarante-deux sorties, trois voyages et un record de participation '
              'en juin. Merci à toutes les personnes qui ont mené un groupe '
              'cette année, et rendez-vous à l’assemblée de décembre.',
    thumbnailUrl: draft ? null : _img(GalleryImageUrls.photo),
    createdAt: draft ? at(0, 8) : at(-2, 18, 30),
    commentCount: draft ? 0 : 4,
    createdBy: draft ? karim : lea,
  );

  // ─────────────────────────────────────────────────────────── calendrier

  CalendarEventDto event({
    required String id,
    required String title,
    required String start,
    String type = 'RIDE',
    String entitySlug = kRideSlug,
    bool registered = false,
    String status = 'PUBLISHED',
    bool finished = false,
    String? groupName,
    String? tripSlug,
    double? distance = 92400,
    double? elevationGain = 1240,
    String? place = 'Place de la Mairie',
  }) => CalendarEventDto(
    id: id,
    title: title,
    start: start,
    end: DateTime.parse(start)
        .add(const Duration(hours: 4))
        .toUtc()
        .toIso8601String(),
    allDay: false,
    type: type,
    teamSlug: vcm.slug,
    teamName: vcm.name,
    entitySlug: entitySlug,
    registered: registered,
    status: status,
    timezone: kGalleryZone,
    finished: finished,
    tripSlug: tripSlug,
    startPlaceName: place,
    distance: distance,
    elevationGain: elevationGain,
    groupName: groupName,
  );

  /// Les cinq lignes de « Cette semaine » : une sortie, la sortie où Camille
  /// est inscrite, une annulée, un brouillon et une étape, dans l'ordre des
  /// dates.
  List<CalendarEventDto> get weekEvents => <CalendarEventDto>[
    event(
      id: 'e-recup',
      title: 'Sortie récupération',
      start: at(1, 18, 30),
      entitySlug: 'sortie-recuperation',
      distance: 35000,
      elevationGain: 280,
    ),
    event(
      id: 'e-monts',
      title: kRideName,
      start: at(4, 9, 30),
      registered: true,
      groupName: 'B',
      distance: 78000,
      elevationGain: 980,
    ),
    event(
      id: 'e-drennec',
      title: 'Tour du lac du Drennec',
      start: at(5, 9),
      entitySlug: 'tour-du-lac-du-drennec',
      status: 'CANCELLED',
      distance: 54000,
      elevationGain: 610,
    ),
    event(
      id: 'e-brouillon',
      title: 'Sortie découverte',
      start: at(6, 14),
      entitySlug: 'sortie-decouverte',
      status: 'DRAFT',
      distance: 30000,
      elevationGain: 250,
    ),
    stageEvent(),
  ];

  CalendarEventDto stageEvent() => event(
    id: 'e-etape-1',
    title: 'Autun → Château-Chinon',
    start: at(10, 8, 30),
    type: 'TRIP_STAGE',
    entitySlug: 'etape-1',
    tripSlug: kTripSlug,
    distance: 74000,
    elevationGain: 1380,
    place: 'Autun',
  );

  // ──────────────────────────────────────────────────────────── annonces

  AdDto ad(String kind, {bool draft = false}) {
    final (
      String slug,
      String name,
      num? price,
      String? period,
      String sector,
      String excerpt,
      bool photo,
    ) = switch (kind) {
      'RENTAL' => (
        'remorque-enfant',
        'Remorque enfant',
        15,
        'DAY',
        'Morlaix',
        'Deux places, attelage universel, housse de pluie fournie.',
        false,
      ),
      'WANTED' => (
        'roues-gravel-700',
        'Roues gravel 700',
        null,
        null,
        'Carhaix',
        'Paire de roues 700, frein à disque, corps Shimano.',
        false,
      ),
      _ => (
        draft ? 'velo-carbone-brouillon' : 'velo-route-carbone-m',
        'Vélo de route carbone taille M',
        1200,
        null,
        'Brest',
        'Cadre carbone, groupe 105 en 2 × 11, très bon état, révisé en '
            'septembre.',
        true,
      ),
    };
    return AdDto(
      team: vcm,
      id: 'ad-$slug',
      slug: slug,
      name: name,
      media: emptyMedia,
      images: <String>[if (photo && images) GalleryImageUrls.adPhoto],
      status: draft ? 'DRAFT' : 'PUBLISHED',
      visibility: 'TEAM',
      adType: kind,
      createdAt: at(-5, 18, 42),
      updatedAt: at(-5, 18, 42),
      createdById: karim.id,
      createdByDisplayName: karim.displayName,
      deleted: false,
      tags: const <TagDto>[],
      permissions: memberPermissions,
      excerpt: excerpt,
      thumbnailUrl: photo ? _img(GalleryImageUrls.adPhoto) : null,
      price: price,
      rentalPeriod: period,
      locationDescription: sector,
    );
  }

  // ─────────────────────────────────────────────────────── tableau de bord

  PublicationListResponse list(List<PublicationDto> items) =>
      PublicationListResponse(
        publications: items,
        total: items.length,
        page: 0,
        size: 5,
      );

  TeamDashboardOrganizerDto get organizerDashboard => TeamDashboardOrganizerDto(
    drafts: list(<PublicationDto>[
      feedRide(
        slug: 'sortie-decouverte',
        name: 'Sortie découverte',
        status: 'DRAFT',
        dateTime: at(6, 14),
      ),
      feedPost(draft: true),
    ]),
    ridesWithoutRoute: list(<PublicationDto>[
      feedRide(
        slug: 'sortie-recuperation',
        name: 'Sortie récupération',
        dateTime: at(1, 18, 30),
        withRoute: false,
      ),
    ]),
    ridesWithFullGroup: list(<PublicationDto>[feedRide()]),
    reports: TeamDashboardReportsDto(
      openCount: 1,
      latestReason: 'SPAM',
      latestTargetType: 'COMMENT',
      latestExcerpt: 'Promo sur les pneus, lien en bio',
      latestReportedAt: ago(const Duration(hours: 6)),
    ),
  );

  // ───────────────────────────────────────────────────────── notifications

  NotificationDto notification(String kind) => switch (kind) {
    'unread' => NotificationDto(
      id: 'n-publiee',
      type: 'RIDE_PUBLISHED',
      read: false,
      createdAt: ago(const Duration(hours: 2)),
      teamSlug: vcm.slug,
      teamName: vcm.name,
      subjectType: 'RIDE',
      subjectSlug: kRideSlug,
      subjectName: kRideName,
      changes: const <NotificationChange>[],
      actorName: lea.displayName,
    ),
    'read' => NotificationDto(
      id: 'n-rappel',
      type: 'RIDE_REMINDER',
      read: true,
      createdAt: ago(const Duration(hours: 20)),
      teamSlug: vcm.slug,
      teamName: vcm.name,
      subjectType: 'RIDE',
      subjectSlug: 'sortie-recuperation',
      subjectName: 'Sortie récupération',
      changes: const <NotificationChange>[],
      subjectDateTime: at(1, 18, 30),
      subjectTimezone: kGalleryZone,
    ),
    _ => NotificationDto(
      id: 'n-modifiee',
      type: 'RIDE_UPDATED',
      read: false,
      createdAt: ago(const Duration(minutes: 35)),
      teamSlug: vcm.slug,
      teamName: vcm.name,
      subjectType: 'RIDE',
      subjectSlug: kRideSlug,
      subjectName: kRideName,
      changes: const <NotificationChange>[NotificationChange.dateTime],
      actorName: karim.displayName,
      subjectDateTime: at(4, 9),
      subjectTimezone: kGalleryZone,
    ),
  };

  // ───────────────────────────────────────────────────────────── modèles

  RideTemplateDto template({bool draft = false}) => RideTemplateDto(
    team: vcm,
    id: draft ? 'tpl-hiver' : 'tpl-dimanche',
    slug: draft ? 'sortie-d-hiver' : 'sortie-du-dimanche',
    name: draft ? 'Sortie d’hiver' : 'Sortie du dimanche',
    markdown: '',
    visibility: 'TEAM',
    status: draft ? 'DRAFT' : 'PUBLISHED',
    createdAt: '2025-09-01T10:00:00Z',
    updatedAt: at(-3, 20),
    groupCount: draft ? 1 : 3,
    groups: <RideTemplateGroupDto>[
      const RideTemplateGroupDto(
        id: 'tg-a',
        name: 'A',
        sortOrder: 0,
        time: '09:00:00',
        averageSpeed: 28,
        maxParticipants: 12,
      ),
      if (!draft) ...const <RideTemplateGroupDto>[
        RideTemplateGroupDto(
          id: 'tg-b',
          name: 'B',
          sortOrder: 1,
          time: '09:30:00',
          averageSpeed: 25,
          maxParticipants: 12,
        ),
        RideTemplateGroupDto(
          id: 'tg-c',
          name: 'C',
          sortOrder: 2,
          time: '10:00:00',
          averageSpeed: 22,
          maxParticipants: 12,
        ),
      ],
    ],
    tags: const <TagDto>[],
    nextNumber: draft ? null : 12,
  );

  // ─────────────────────────────────────────────────────────── appareils

  List<PairedDeviceDto> get pairedDevices => <PairedDeviceDto>[
    PairedDeviceDto(
      id: 'dev-karoo',
      type: 'KAROO',
      pairedAt: at(-30, 19),
      lastUsedAt: at(-1, 9),
    ),
    PairedDeviceDto(id: 'dev-garmin', type: 'GARMIN', pairedAt: at(-90, 21)),
  ];

  // ───────────────────────────────────────────────────────── commentaires

  /// Un commentaire et sa réponse, puis un commentaire supprimé.
  List<CommentDto> get comments => <CommentDto>[
    CommentDto(
      id: 'c-karim',
      content: 'Je roule avec le B. On se retrouve au café avant le départ ?',
      author: karim,
      createdAt: ago(const Duration(hours: 5)),
      replies: <CommentDto>[
        CommentDto(
          id: 'c-lea',
          content: 'Oui, 8 h 45 au café de la place, je prends les clés.',
          author: lea,
          createdAt: ago(const Duration(hours: 4)),
          replies: const <CommentDto>[],
          replyCount: 0,
          deleted: false,
          parentId: 'c-karim',
        ),
      ],
      replyCount: 1,
      deleted: false,
    ),
    CommentDto(
      id: 'c-supprime',
      content: '',
      author: ines,
      createdAt: ago(const Duration(hours: 3)),
      replies: const <CommentDto>[],
      replyCount: 0,
      deleted: true,
    ),
  ];
}
