/**
 * The gallery's data, built from the shared brief
 * (`docs/plans/2026-11-10-etat-des-lieux-affichage/audit-cartes/galerie.md`, « Données »), as DTOs
 * of the generated client. Every date is relative to the day the gallery is opened (J = today,
 * Europe/Paris), so a capture taken the same day as the app's reads the same « Demain », « En
 * cours » and « Terminée ».
 */
import { formatInTimeZone, fromZonedTime } from 'date-fns-tz'
import type {
  AdDto,
  ConfigDto,
  CalendarEventDto,
  CommentDto,
  ContentPermissionsDto,
  MediaDto,
  MemberDto,
  MyInvitationDto,
  NotificationDto,
  PairedDeviceDto,
  PlaceDetailDto,
  PostDto,
  PublicUserDto,
  RideDto,
  RideGroupDto,
  RideGroupSummaryDto,
  RideTemplateDto,
  RideWeatherSummaryDto,
  RouteDetailDto,
  RouteDto,
  RouteUsageDto,
  TagDto,
  TeamDetailDto,
  TeamPublicationDto,
  TripDto,
  TripStageDto,
  UserDto,
  WeatherLegDto,
} from '@/api/dto'
import { MAP_DARK_URL, MAP_LIGHT_URL, PHOTO_URL } from './images'

// --- Time -----------------------------------------------------------------------------------

/** The zone of every rendezvous, and the reader's own: no zone mention anywhere. */
export const ZONE = 'Europe/Paris'

/** The instant of `time` (HH:mm, Paris) on day J+`offset`. */
export function day(offset: number, time = '09:00'): string {
  const [y, m, d] = formatInTimeZone(new Date(), ZONE, 'yyyy-MM-dd').split('-').map(Number)
  const ymd = new Date(Date.UTC(y, m - 1, d + offset)).toISOString().slice(0, 10)
  return fromZonedTime(`${ymd}T${time}:00`, ZONE).toISOString()
}

/** Now plus `hours` (negative: in the past). */
export function hoursFromNow(hours: number): string {
  return new Date(Date.now() + hours * 3_600_000).toISOString()
}

/** The domain's configuration (`GET /api/config`). */
export const APP_CONFIG: ConfigDto = {
  webAuthnRpId: 'localhost',
  appName: 'Pédalons',
  singleTeam: false,
  enableGpxPlanner: false,
  mapStyles: [],
  tileServerBaseUrl: '',
  defaultCenter: { lat: 48.37, lon: -3.84, zoom: 9 },
  gpsAutoSyncEnabled: false,
}

// --- People, teams --------------------------------------------------------------------------

function person(id: string, displayName: string): PublicUserDto {
  return { id, displayName }
}

export const LEA = person('u-lea', 'Léa Martin')
export const KARIM = person('u-karim', 'Karim Benali')
export const CAMILLE = person('u-camille', 'Camille Durand')
export const NOE = person('u-noe', 'Noé Perrin')
export const INES = person('u-ines', 'Inès Roche')
export const SACHA = person('u-sacha', 'Sacha Morel')
export const JEANNE = person('u-jeanne', 'Jeanne Colin')
export const MALO = person('u-malo', 'Malo Guérin')

/** The eight people of the brief, in its order. */
export const PEOPLE = [LEA, KARIM, CAMILLE, NOE, INES, SACHA, JEANNE, MALO]
/** Everyone but the reader. */
const OTHERS = PEOPLE.filter((p) => p.id !== CAMILLE.id)

/** The reader: Camille Durand, metric, French, in Paris. */
export const READER: UserDto = {
  id: CAMILLE.id,
  email: 'camille.durand@example.org',
  displayName: CAMILLE.displayName,
  createdAt: day(-400),
  unitSystem: 'METRIC',
  theme: 'LIGHT',
  language: 'fr',
  timezone: ZONE,
  contactableByMembers: true,
  emailVerified: true,
  // A connected device: « Envoyer vers l'appareil » shows wherever a card offers it.
  connectedServices: [
    {
      serviceType: 'GARMIN',
      displayName: 'Garmin Connect',
      connectedAt: day(-120),
      autoSync: false,
      autoSyncState: 'OFF',
      autoSyncRouteCount: 0,
    },
  ],
}

export const VCM_SLUG = 'velo-club-des-monts'
export const GRAVEL_SLUG = 'gravel-bretagne'

export const VCM_REF: TeamPublicationDto = {
  id: 't-vcm',
  name: 'Vélo Club des Monts',
  slug: VCM_SLUG,
  visibility: 'TEAM',
  accessible: true,
}

export const GRAVEL_REF: TeamPublicationDto = {
  id: 't-gravel',
  name: 'Gravel Bretagne',
  slug: GRAVEL_SLUG,
  visibility: 'PUBLIC',
  accessible: true,
}

export function media(overrides: Partial<MediaDto['assets']> = {}): MediaDto {
  return { markdown: '', assets: { images: [], attachments: [], ...overrides } }
}

function team(ref: TeamPublicationDto, overrides: Partial<TeamDetailDto>): TeamDetailDto {
  return {
    id: ref.id,
    name: ref.name,
    slug: ref.slug,
    about: media(),
    visibility: ref.visibility,
    enableTrips: true,
    enableAds: true,
    enablePosts: true,
    enableRides: true,
    enableRoutes: true,
    enableMemberDirectory: true,
    postsAsTeamByDefault: false,
    visibilityEditable: true,
    joinable: false,
    addMemberAllowed: false,
    enableRoutePlanner: false,
    memberCount: 0,
    upcomingRideCount: 0,
    routeCount: 0,
    upcomingTripCount: 0,
    recentPostCount: 0,
    createdAt: day(-900),
    timezone: ZONE,
    allowedContentVisibilities: {
      ride: ['TEAM', 'PUBLIC'],
      rideTemplate: ['TEAM', 'PUBLIC'],
      route: ['TEAM', 'PUBLIC'],
      post: ['TEAM', 'PUBLIC'],
      trip: ['TEAM', 'PUBLIC'],
      teamPage: ['TEAM', 'PUBLIC'],
      ad: ['TEAM', 'PUBLIC'],
    },
    defaultContentVisibility: 'TEAM',
    publicContentAllowed: true,
    ...overrides,
  }
}

/** Camille's team: private, 24 members, Camille a plain member. */
export const VCM_TEAM = team(VCM_REF, {
  excerpt: 'Le club des routes du centre Finistère : sorties le samedi, voyages au printemps.',
  memberCount: 24,
  upcomingRideCount: 3,
  upcomingTripCount: 1,
  recentPostCount: 2,
  routeCount: 18,
  role: 'MEMBER',
})

/** The second team: public, 112 members. */
export const GRAVEL_TEAM = team(GRAVEL_REF, {
  excerpt: 'Chemins, pistes et bonne humeur, de Brocéliande aux Monts d’Arrée.',
  visibility: 'PUBLIC',
  memberCount: 112,
  upcomingRideCount: 5,
  routeCount: 64,
  joinable: true,
  role: 'ADMIN',
})

// --- Shared bits ----------------------------------------------------------------------------

const TAGS: TagDto[] = [
  { id: 'tag-vallonne', label: 'vallonné', color: 'GREEN' },
  { id: 'tag-finistere', label: 'Finistère', color: 'BLUE' },
]

const MEMBER_PERMISSIONS: ContentPermissionsDto = {
  canEdit: false,
  canDelete: false,
  canRegister: true,
  canComment: true,
  canSeeParticipants: true,
  indexable: false,
}

const START_PLACE: PlaceDetailDto = {
  id: 'pl-huelgoat',
  name: 'Place de la Mairie, Huelgoat',
  startPlace: true,
  endPlace: false,
}

function place(id: string, name: string, start: boolean): PlaceDetailDto {
  return { id, name, startPlace: start, endPlace: !start }
}

// --- Weather --------------------------------------------------------------------------------

/** 9 to 13 °C, west wind 18 km/h, rain 20 %. */
export function weatherSummary(alert = false, rideDay = 4): RideWeatherSummaryDto {
  return {
    status: 'OK',
    weatherCode: alert ? 61 : 2,
    condition: alert ? 'RAIN' : 'PARTLY_CLOUDY',
    daylight: true,
    temperature: 11,
    temperatureMin: 9,
    temperatureMax: 13,
    maxPrecipitationProbability: alert ? 60 : 20,
    wind: { speed: 18, direction: 270, compass: 'W' },
    rainAlert: alert
      ? { probability: 60, time: day(rideDay, '11:00'), condition: 'RAIN' }
      : undefined,
    timezone: ZONE,
  }
}

/** A group's forecast along its route, in the shape `GroupWeatherLine` reads. */
export function weatherLeg(
  group: RideGroupDto,
  options: { alert?: boolean; rideDay?: number } = {}
): WeatherLegDto {
  const { alert = false, rideDay = 4 } = options
  const distance = group.distance ?? 0
  const speed = group.averageSpeed ?? 25
  const arrival = new Date(Date.parse(group.startAt) + (distance / 1000 / speed) * 3_600_000)
  const conditions = (time: string, temperature: number, rain: number) => ({
    time,
    weatherCode: 2,
    condition: 'PARTLY_CLOUDY' as const,
    daylight: true,
    temperature,
    apparentTemperature: temperature - 2,
    precipitationProbability: rain,
    precipitation: 0,
    wind: { speed: 18, direction: 270, compass: 'W' as const },
  })
  return {
    groupId: group.id,
    status: 'OK',
    startTime: group.startAt,
    averageSpeed: speed,
    speedIsDefault: false,
    distance,
    arrivalTime: arrival.toISOString(),
    checkpoints: [
      {
        index: 0,
        kind: 'START',
        distance: 0,
        time: group.startAt,
        weather: conditions(group.startAt, 9, 10),
        relativeWind: 'CROSS',
        headwind: 0,
        relativeWindAngle: 90,
      },
      {
        index: 1,
        kind: 'FINISH',
        distance,
        time: arrival.toISOString(),
        weather: conditions(arrival.toISOString(), 13, alert ? 60 : 20),
        relativeWind: 'TAIL',
        headwind: -8,
        relativeWindAngle: 0,
      },
    ],
    segments: [{ fromDistance: 0, toDistance: distance, relativeWind: 'CROSS', headwind: 0 }],
    windExposure: { head: distance * 0.3, cross: distance * 0.4, tail: distance * 0.3 },
    prevailingWind: { speed: 18, direction: 270, compass: 'W' },
    rainAlert: alert
      ? { probability: 60, time: day(rideDay, '11:00'), condition: 'RAIN' }
      : undefined,
  }
}

// --- Routes ---------------------------------------------------------------------------------

export const ROUTE_SLUG = 'boucle-des-monts-d-arree'
export const ROUTE_B_SLUG = 'boucle-des-monts-d-arree-groupe-b'
export const ROUTE_C_SLUG = 'boucle-des-monts-d-arree-groupe-c'

export function route(overrides: Partial<RouteDto> = {}): RouteDto {
  return {
    id: 'rt-arree',
    slug: ROUTE_SLUG,
    team: VCM_REF,
    name: "Boucle des Monts d'Arrée",
    media: media({
      thumbnailLight: {
        id: 'as-tl',
        fileName: 'light.png',
        contentType: 'image/svg+xml',
        url: MAP_LIGHT_URL,
        imageUrl: MAP_LIGHT_URL,
      },
      thumbnailDark: {
        id: 'as-td',
        fileName: 'dark.png',
        contentType: 'image/svg+xml',
        url: MAP_DARK_URL,
        imageUrl: MAP_DARK_URL,
      },
    }),
    excerpt: 'Par Léa Martin. Le Roc’h Trévézel, le lac du Drennec et la descente sur Huelgoat.',
    thumbnailUrl: MAP_LIGHT_URL,
    distance: 92_400,
    elevationGain: 1_240,
    elevationLoss: 1_240,
    elevationState: 'HD',
    surfaceType: 'ROAD',
    visibility: 'PUBLIC',
    createdAt: day(-30),
    deleted: false,
    commentCount: 0,
    tags: TAGS,
    permissions: { ...MEMBER_PERMISSIONS, canRegister: undefined },
    ...overrides,
  }
}

/** The routes the group cards read their GPX/FIT links from, by slug. */
export function routeDetails(): Map<string, RouteDetailDto> {
  const detail = (slug: string, distance: number, elevationGain: number): RouteDetailDto => ({
    ...route({ slug, distance, elevationGain, elevationLoss: elevationGain }),
    media: media({
      gpx: { id: `${slug}-gpx`, fileName: `${slug}.gpx`, contentType: 'application/gpx', url: '#' },
      fit: { id: `${slug}-fit`, fileName: `${slug}.fit`, contentType: 'application/fit', url: '#' },
    }),
    updatedAt: day(-30),
    tracks: [],
    waypoints: [],
  })
  return new Map([
    [ROUTE_SLUG, detail(ROUTE_SLUG, 92_400, 1_240)],
    [ROUTE_B_SLUG, detail(ROUTE_B_SLUG, 78_000, 980)],
    [ROUTE_C_SLUG, detail(ROUTE_C_SLUG, 61_000, 720)],
  ])
}

// --- Rides ----------------------------------------------------------------------------------

export const RIDE_SLUG = 'boucle-des-monts-d-arree'

interface GroupSpec {
  id: string
  name: string
  time: string
  speed: number
  count: number
  routeSlug: string
  distance: number
  elevationGain: number
  leader?: PublicUserDto
}

const GROUP_SPECS: GroupSpec[] = [
  {
    id: 'g-a',
    name: 'A',
    time: '09:00',
    speed: 28,
    count: 8,
    routeSlug: ROUTE_SLUG,
    distance: 92_400,
    elevationGain: 1_240,
    leader: LEA,
  },
  {
    id: 'g-b',
    name: 'B',
    time: '09:30',
    speed: 25,
    count: 11,
    routeSlug: ROUTE_B_SLUG,
    distance: 78_000,
    elevationGain: 980,
  },
  {
    id: 'g-c',
    name: 'C',
    time: '10:00',
    speed: 22,
    count: 12,
    routeSlug: ROUTE_C_SLUG,
    distance: 61_000,
    elevationGain: 720,
  },
]

export interface RideOptions {
  /** Day of the ride, J + offset. */
  offset?: number
  /** Camille is registered in group B. */
  registered?: boolean
  /** Every group leaves at the ride's time (09:00). */
  sameTime?: boolean
  /** Rain alert on the forecast. */
  rainAlert?: boolean
}

export function rideGroups(options: RideOptions = {}): RideGroupDto[] {
  const { offset = 4, registered = false, sameTime = false } = options
  return GROUP_SPECS.map((spec, index) => {
    const mine = registered && spec.id === 'g-b'
    const pool = mine ? [CAMILLE, ...OTHERS] : OTHERS
    return {
      id: spec.id,
      name: spec.name,
      time: `${sameTime ? '09:00' : spec.time}:00`,
      startAt: day(offset, sameTime ? '09:00' : spec.time),
      routeSlug: spec.routeSlug,
      averageSpeed: spec.speed,
      maxParticipants: 12,
      countParticipants: spec.count,
      participants: pool.slice(0, Math.min(spec.count, pool.length)),
      sortOrder: index,
      registered: mine,
      full: spec.count >= 12,
      distance: spec.distance,
      elevationGain: spec.elevationGain,
      leader: spec.leader,
      thumbnailLightUrl: MAP_LIGHT_URL,
      thumbnailDarkUrl: MAP_DARK_URL,
    }
  })
}

export function summaryOf(group: RideGroupDto): RideGroupSummaryDto {
  return {
    id: group.id,
    name: group.name,
    time: group.time,
    startAt: group.startAt,
    averageSpeed: group.averageSpeed,
    countParticipants: group.countParticipants,
    maxParticipants: group.maxParticipants,
    full: group.full,
    routeSlug: group.routeSlug,
    distance: group.distance,
    elevationGain: group.elevationGain,
    sortOrder: group.sortOrder,
  }
}

/** « Boucle des Monts d'Arrée », J+4 at 09:00, three groups, 2 comments. */
export function ride(options: RideOptions = {}, overrides: Partial<RideDto> = {}): RideDto {
  const { offset = 4, rainAlert = false } = options
  const groups = rideGroups(options)
  const mine = groups.find((g) => g.registered)
  return {
    type: 'RIDE',
    team: VCM_REF,
    id: 'r-arree',
    slug: RIDE_SLUG,
    name: "Boucle des Monts d'Arrée",
    media: media(),
    excerpt: 'Trois groupes, trois allures : café au retour à la boulangerie de la place.',
    dateTime: day(offset, '09:00'),
    endDateTime: day(offset, '14:30'),
    timezone: ZONE,
    status: 'PUBLISHED',
    finished: offset < 0,
    visibility: 'TEAM',
    createdAt: day(-10),
    routeSlug: ROUTE_SLUG,
    participantCount: groups.reduce((sum, g) => sum + g.countParticipants, 0),
    groupCount: groups.length,
    groups,
    groupSummaries: groups.map(summaryOf),
    distance: 92_400,
    elevationGain: 1_240,
    surfaceType: 'ROAD',
    startPlace: START_PLACE,
    topParticipants: OTHERS.slice(0, 5),
    thumbnailLightUrl: MAP_LIGHT_URL,
    thumbnailDarkUrl: MAP_DARK_URL,
    deleted: false,
    registered: !!mine,
    registeredGroupId: mine?.id,
    registeredGroup: mine,
    full: groups.every((g) => g.full),
    commentCount: 2,
    tags: [],
    weather: offset >= 0 ? weatherSummary(rainAlert, offset) : undefined,
    permissions: { ...MEMBER_PERMISSIONS, canRegister: offset >= 0 && !mine },
    ...overrides,
  }
}

/** A ride under way: left an hour ago, back in four. */
export function rideUnderWay(): RideDto {
  const start = hoursFromNow(-1)
  const base = ride({ offset: 0 })
  const groups = base.groups.map((g) => ({ ...g, startAt: start }))
  return {
    ...base,
    dateTime: start,
    endDateTime: hoursFromNow(4),
    groups,
    groupSummaries: groups.map(summaryOf),
  }
}

/** A ride with neither group nor route. */
export function rideWithoutGroups(): RideDto {
  return ride(
    {},
    {
      groups: [],
      groupSummaries: [],
      groupCount: 0,
      participantCount: 0,
      routeSlug: undefined,
      distance: undefined,
      elevationGain: undefined,
      thumbnailLightUrl: undefined,
      thumbnailDarkUrl: undefined,
      topParticipants: [],
      excerpt: 'Rendez-vous libre : chaque personne roule à son allure, sans inscription.',
      permissions: { ...MEMBER_PERMISSIONS, canRegister: false },
    }
  )
}

// --- Trip -----------------------------------------------------------------------------------

export const TRIP_SLUG = 'traversee-du-morvan'

interface StageSpec {
  slug: string
  name: string
  from: string
  to: string
  dayOffset: number
  time: string
  distance: number
  elevationGain: number
  speed?: number
}

const STAGE_SPECS: StageSpec[] = [
  {
    slug: 'autun-chateau-chinon',
    name: 'Autun → Château-Chinon',
    from: 'Autun',
    to: 'Château-Chinon',
    dayOffset: 0,
    time: '08:30',
    distance: 74_000,
    elevationGain: 1_380,
    speed: 22,
  },
  {
    slug: 'chateau-chinon-saulieu',
    name: 'Château-Chinon → Saulieu',
    from: 'Château-Chinon',
    to: 'Saulieu',
    dayOffset: 1,
    time: '09:00',
    distance: 68_000,
    elevationGain: 1_120,
  },
  {
    slug: 'saulieu-avallon',
    name: 'Saulieu → Avallon',
    from: 'Saulieu',
    to: 'Avallon',
    dayOffset: 2,
    time: '09:00',
    distance: 59_000,
    elevationGain: 840,
  },
]

export function stages(firstDay = 10, options: { withRoute?: boolean } = {}): TripStageDto[] {
  const { withRoute = true } = options
  return STAGE_SPECS.map((spec, index) => ({
    id: `st-${spec.slug}`,
    slug: spec.slug,
    name: spec.name,
    dateTime: day(firstDay + spec.dayOffset, spec.time),
    timezone: ZONE,
    averageSpeed: spec.speed,
    route: withRoute
      ? route({
          id: `rt-${spec.slug}`,
          slug: spec.slug,
          name: spec.name,
          distance: spec.distance,
          elevationGain: spec.elevationGain,
          elevationLoss: spec.elevationGain,
          media: media({
            gpx: {
              id: `${spec.slug}-gpx`,
              fileName: `${spec.slug}.gpx`,
              contentType: 'application/gpx',
              url: '#',
            },
          }),
        })
      : undefined,
    startPlace: place(`pl-${spec.slug}-from`, spec.from, true),
    endPlace: place(`pl-${spec.slug}-to`, spec.to, false),
    media: media(),
    sortOrder: index,
    stageIndex: index,
    stageCount: STAGE_SPECS.length,
    commentCount: 0,
    permissions: MEMBER_PERMISSIONS,
  }))
}

/** « Traversée du Morvan », J+10 → J+12, 12 people, 201 km. */
export function trip(firstDay = 10, overrides: Partial<TripDto> = {}): TripDto {
  const list = stages(firstDay)
  return {
    type: 'TRIP',
    team: VCM_REF,
    id: 'tr-morvan',
    slug: TRIP_SLUG,
    name: 'Traversée du Morvan',
    media: media(),
    excerpt: 'Trois jours, trois étapes, les bagages suivent en voiture.',
    dateTime: day(firstDay, '08:30'),
    endDateTime: day(firstDay + 2, '16:30'),
    timezone: ZONE,
    status: 'PUBLISHED',
    finished: false,
    visibility: 'TEAM',
    createdAt: day(-20),
    participantCount: 12,
    stageCount: list.length,
    totalDistance: 201_000,
    totalElevationGain: 3_340,
    stages: list,
    participants: OTHERS.slice(0, 5),
    thumbnailLightUrl: MAP_LIGHT_URL,
    thumbnailDarkUrl: MAP_DARK_URL,
    deleted: false,
    registered: false,
    commentCount: 0,
    tags: [],
    permissions: MEMBER_PERMISSIONS,
    ...overrides,
  }
}

// --- Post -----------------------------------------------------------------------------------

/** « Bilan de la saison », J−2 at 18:30 by Léa Martin, 4 comments, a photo. */
export function post(overrides: Partial<PostDto> = {}): PostDto {
  return {
    type: 'POST',
    team: VCM_REF,
    id: 'p-bilan',
    slug: 'bilan-de-la-saison',
    name: 'Bilan de la saison',
    media: media(),
    excerpt:
      'Quarante-deux sorties, trois voyages et pas une seule crevaison dans le groupe C. Merci à toutes les personnes qui ont ouvert la route cette année ; rendez-vous à l’assemblée de décembre pour le programme 2027.',
    thumbnailUrl: PHOTO_URL,
    dateTime: day(-2, '18:30'),
    timezone: ZONE,
    status: 'PUBLISHED',
    visibility: 'TEAM',
    createdAt: day(-2, '18:30'),
    deleted: false,
    commentCount: 4,
    signedAsTeam: false,
    createdBy: LEA,
    tags: [],
    permissions: MEMBER_PERMISSIONS,
    ...overrides,
  }
}

// --- Ads ------------------------------------------------------------------------------------

function ad(overrides: Partial<AdDto>): AdDto {
  return {
    team: VCM_REF,
    id: 'ad',
    slug: 'ad',
    name: '',
    media: media(),
    images: [],
    status: 'PUBLISHED',
    visibility: 'TEAM',
    adType: 'SALE',
    locationDescription: 'Brest',
    createdAt: day(-5, '18:42'),
    updatedAt: day(-5, '18:42'),
    createdById: KARIM.id,
    createdByDisplayName: KARIM.displayName,
    deleted: false,
    tags: [],
    permissions: { ...MEMBER_PERMISSIONS, canRegister: undefined },
    ...overrides,
  }
}

export const AD_SALE = ad({
  id: 'ad-carbone',
  slug: 'velo-de-route-carbone-taille-m',
  name: 'Vélo de route carbone taille M',
  excerpt: 'Cadre carbone, groupe 105 en 11 vitesses, 8 000 km, révisé en septembre.',
  thumbnailUrl: PHOTO_URL,
  adType: 'SALE',
  price: 1_200,
})

export const AD_RENTAL = ad({
  id: 'ad-remorque',
  slug: 'remorque-enfant',
  name: 'Remorque enfant',
  excerpt: 'Deux places, attache universelle, housse de pluie fournie.',
  adType: 'RENTAL',
  price: 15,
  rentalPeriod: 'DAY',
  createdAt: day(-3, '10:15'),
  updatedAt: day(-3, '10:15'),
})

export const AD_WANTED = ad({
  id: 'ad-roues',
  slug: 'roues-gravel-700',
  name: 'Roues gravel 700',
  excerpt: 'Paire de roues 700C pour pneus de 40 mm, freins à disque.',
  adType: 'WANTED',
  price: undefined,
  createdAt: day(-1, '21:05'),
  updatedAt: day(-1, '21:05'),
})

export const AD_DRAFT: AdDto = { ...AD_SALE, id: 'ad-brouillon', status: 'DRAFT' }

// --- Calendar (home « Les 7 prochains jours ») -----------------------------------------------

function event(overrides: Partial<CalendarEventDto>): CalendarEventDto {
  return {
    id: 'ev',
    title: "Boucle des Monts d'Arrée",
    start: day(4, '09:00'),
    end: day(4, '14:30'),
    allDay: false,
    type: 'RIDE',
    teamSlug: VCM_SLUG,
    teamName: VCM_REF.name,
    entitySlug: RIDE_SLUG,
    startPlaceName: START_PLACE.name,
    distance: 92_400,
    elevationGain: 1_240,
    registered: false,
    status: 'PUBLISHED',
    timezone: ZONE,
    finished: false,
    ...overrides,
  }
}

/** Five rows: a ride, a registered one, a cancelled one, a trip stage, a draft. */
export const WEEK_EVENTS: CalendarEventDto[] = [
  event({
    id: 'ev-1',
    title: 'Sortie du mercredi',
    entitySlug: 'sortie-du-mercredi',
    start: day(1, '18:30'),
    end: day(1, '20:30'),
  }),
  event({
    id: 'ev-2',
    title: "Boucle des Monts d'Arrée",
    registered: true,
    groupName: 'B',
    start: day(4, '09:30'),
  }),
  event({
    id: 'ev-3',
    title: 'Côtes de Crozon',
    entitySlug: 'cotes-de-crozon',
    status: 'CANCELLED',
    start: day(5, '09:00'),
    end: day(5, '13:00'),
  }),
  event({
    id: 'ev-4',
    type: 'TRIP_STAGE',
    title: 'Autun → Château-Chinon',
    entitySlug: 'autun-chateau-chinon',
    tripSlug: TRIP_SLUG,
    start: day(6, '08:30'),
    end: day(6, '16:00'),
    startPlaceName: 'Autun',
    distance: 74_000,
    elevationGain: 1_380,
  }),
  event({
    id: 'ev-5',
    title: 'Reconnaissance du Ménez-Hom',
    entitySlug: 'reco-menez-hom',
    status: 'DRAFT',
    start: day(6, '14:00'),
    end: day(6, '17:00'),
  }),
]

// --- Members, participants, invitations -----------------------------------------------------

export function member(user: PublicUserDto, role: MemberDto['role'], joinedAt: string): MemberDto {
  return { team: VCM_REF, id: `m-${user.id}`, user, role, joinedAt }
}

export const INVITATION: MyInvitationDto = {
  id: 'inv-gravel',
  team: GRAVEL_REF,
  inviterName: KARIM.displayName,
  role: 'MEMBER',
  expiresAt: day(12),
}

// --- Dashboard ------------------------------------------------------------------------------

export function draftRide(): RideDto {
  return ride(
    { offset: 8 },
    {
      id: 'r-menez-hom',
      slug: 'reco-menez-hom',
      name: 'Reconnaissance du Ménez-Hom',
      status: 'DRAFT',
      weather: undefined,
    }
  )
}

export function rideWithoutRoute(): RideDto {
  const groups = rideGroups({ offset: 6 }).map((g) => ({
    ...g,
    routeSlug: undefined,
    distance: undefined,
    elevationGain: undefined,
    thumbnailLightUrl: undefined,
    thumbnailDarkUrl: undefined,
  }))
  return ride(
    { offset: 6 },
    {
      id: 'r-crozon',
      slug: 'cotes-de-crozon',
      name: 'Côtes de Crozon',
      routeSlug: undefined,
      distance: undefined,
      elevationGain: undefined,
      surfaceType: undefined,
      thumbnailLightUrl: undefined,
      thumbnailDarkUrl: undefined,
      groups,
      groupSummaries: groups.map(summaryOf),
      weather: undefined,
    }
  )
}

/** Every group full. */
export function fullRide(): RideDto {
  const groups = rideGroups().map((g) => ({
    ...g,
    countParticipants: 12,
    participants: OTHERS,
    full: true,
  }))
  return ride(
    {},
    {
      groups,
      groupSummaries: groups.map(summaryOf),
      participantCount: 36,
      full: true,
      permissions: { ...MEMBER_PERMISSIONS, canRegister: false },
    }
  )
}

// --- Notifications, templates, devices, comments --------------------------------------------

function notification(overrides: Partial<NotificationDto>): NotificationDto {
  return {
    id: 'n',
    type: 'RIDE_PUBLISHED',
    read: false,
    createdAt: hoursFromNow(-2),
    actorName: LEA.displayName,
    teamSlug: VCM_SLUG,
    teamName: VCM_REF.name,
    subjectType: 'RIDE',
    subjectSlug: RIDE_SLUG,
    subjectName: "Boucle des Monts d'Arrée",
    subjectDateTime: day(4, '09:00'),
    subjectTimezone: ZONE,
    changes: [],
    ...overrides,
  }
}

export const NOTIFICATION_UNREAD = notification({ id: 'n-1' })
export const NOTIFICATION_READ = notification({
  id: 'n-2',
  type: 'RIDE_JOINED',
  read: true,
  actorName: KARIM.displayName,
  createdAt: hoursFromNow(-26),
})
export const NOTIFICATION_UPDATED = notification({
  id: 'n-3',
  type: 'RIDE_UPDATED',
  createdAt: hoursFromNow(-0.5),
  changes: ['DATE_TIME', 'START_PLACE'],
})

function template(overrides: Partial<RideTemplateDto>): RideTemplateDto {
  return {
    team: VCM_REF,
    id: 'tpl',
    slug: 'tpl',
    name: 'Sortie du samedi',
    markdown: 'Départ de la place de la Mairie, trois allures. **Café au retour.**',
    visibility: 'TEAM',
    status: 'PUBLISHED',
    createdAt: day(-200),
    updatedAt: day(-15),
    groupCount: 3,
    groups: GROUP_SPECS.map((spec, index) => ({
      id: `tg-${spec.id}`,
      name: spec.name,
      time: `${spec.time}:00`,
      averageSpeed: spec.speed,
      maxParticipants: 12,
      sortOrder: index,
    })),
    tags: TAGS.slice(0, 1),
    ...overrides,
  }
}

export const TEMPLATE = template({ id: 'tpl-samedi', slug: 'sortie-du-samedi' })
export const TEMPLATE_DRAFT = template({
  id: 'tpl-nocturne',
  slug: 'nocturne-d-ete',
  name: 'Nocturne d’été',
  status: 'DRAFT',
  groupCount: 1,
  groups: [{ id: 'tg-n', name: 'Tous', time: '20:00:00', averageSpeed: 24, sortOrder: 0 }],
  tags: [],
})

export const DEVICES: PairedDeviceDto[] = [
  { id: 'dev-karoo', type: 'KAROO', pairedAt: day(-60), lastUsedAt: hoursFromNow(-20) },
  { id: 'dev-garmin', type: 'GARMIN', pairedAt: day(-200) },
]

export const COMMENTS: CommentDto[] = [
  {
    id: 'c-1',
    content: 'Je prends la voiture-balai pour le groupe C si personne ne s’est proposé.',
    author: KARIM,
    createdAt: hoursFromNow(-5),
    replies: [
      {
        id: 'c-1-1',
        content: 'Merci Karim ! Je te passe la trousse de réparation samedi.',
        author: LEA,
        createdAt: hoursFromNow(-3),
        parentId: 'c-1',
        replies: [],
        replyCount: 0,
        deleted: false,
      },
    ],
    replyCount: 1,
    deleted: false,
  },
  {
    id: 'c-2',
    content: '',
    author: { id: 'u-deleted', displayName: '' },
    createdAt: hoursFromNow(-30),
    replies: [],
    replyCount: 0,
    deleted: true,
  },
]

export const ROUTE_USAGES: RouteUsageDto[] = [
  {
    type: 'RIDE',
    slug: RIDE_SLUG,
    name: "Boucle des Monts d'Arrée",
    dateTime: day(4, '09:00'),
    timezone: ZONE,
    teamSlug: VCM_SLUG,
    referencedDirectly: true,
    viaChildNames: [],
  },
  {
    type: 'TRIP',
    slug: TRIP_SLUG,
    name: 'Traversée du Morvan',
    dateTime: day(10, '08:30'),
    timezone: ZONE,
    endDate: day(12, '16:30'),
    teamSlug: VCM_SLUG,
    referencedDirectly: false,
    viaChildNames: ['Autun → Château-Chinon'],
  },
]
