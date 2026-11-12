/**
 * The list gallery's data: the card gallery's objects (`../cardGallery/fixtures.ts`, same people,
 * same rides, same routes), arranged into the pages the list brief asks for
 * (`docs/plans/2026-11-10-etat-des-lieux-affichage/audit-listes/galerie.md`, « Données »): three
 * items on each list at rest, a total larger than the page.
 *
 * What the list brief changes: Camille is an **organizer** of the Vélo Club des Monts and a plain
 * member of Gravel Bretagne (the card gallery has it the other way round).
 */
import type {
  AdDto,
  CalendarEventDto,
  MemberDto,
  NotificationDto,
  PostDto,
  PublicUserDto,
  PublicationDto,
  RideTemplateDto,
  RouteDto,
  TagWithUsageDto,
  TeamDetailDto,
} from '@/api/dto'
import {
  AD_RENTAL,
  AD_SALE,
  AD_WANTED,
  CAMILLE,
  GRAVEL_TEAM,
  INES,
  JEANNE,
  KARIM,
  LEA,
  MALO,
  NOE,
  NOTIFICATION_READ,
  NOTIFICATION_UNREAD,
  NOTIFICATION_UPDATED,
  PEOPLE,
  ROUTE_B_SLUG,
  ROUTE_C_SLUG,
  SACHA,
  TAGS,
  TEMPLATE,
  TEMPLATE_DRAFT,
  VCM_REF,
  VCM_TEAM,
  WEEK_EVENTS,
  day,
  member,
  post,
  ride,
  rideWithoutRoute,
  route,
  trip,
} from '../cardGallery/fixtures'

export { CAMILLE, PEOPLE, VCM_REF }

// --- Teams ----------------------------------------------------------------------------------

/** Camille organizes the Vélo Club des Monts: the creation actions show. */
export const VCM_ORGANIZER: TeamDetailDto = { ...VCM_TEAM, role: 'ORGANIZER' }
/** The `-lecture` cases: the same team seen by a plain member. */
export const VCM_MEMBER: TeamDetailDto = { ...VCM_TEAM, role: 'MEMBER' }
/** Camille is a plain member of Gravel Bretagne. */
export const GRAVEL_MEMBER: TeamDetailDto = { ...GRAVEL_TEAM, role: 'MEMBER' }

/** A third team, Camille not a member: what « Toutes les équipes » adds. */
export const AULNE_TEAM: TeamDetailDto = {
  ...GRAVEL_TEAM,
  id: 't-aulne',
  name: 'Cyclos de l’Aulne',
  slug: 'cyclos-de-l-aulne',
  excerpt: 'Route et randonnée le long de l’Aulne, de Carhaix à Châteaulin.',
  memberCount: 38,
  routeCount: 22,
  role: undefined,
}

export const MY_TEAMS = [VCM_ORGANIZER, GRAVEL_MEMBER]
export const ALL_TEAMS = [AULNE_TEAM, GRAVEL_MEMBER, VCM_ORGANIZER]

/** The tags of the team, for the tag filters. */
export function teamTags(type: TagWithUsageDto['type']): TagWithUsageDto[] {
  return TAGS.map((tag, i) => ({ ...tag, type, usageCount: 12 - i * 5 }))
}
export const HILLY_TAG_ID = TAGS[0].id

// --- Publications ---------------------------------------------------------------------------

const RIDE_MONTS = ride()
const RIDE_RECUP = rideWithoutRoute()
const TRIP_MORVAN = trip()

/**
 * The home feed where its two sections meet (RL15): a ride and a trip ahead, then a post, in
 * « Plus tôt ».
 */
export const FEED: PublicationDto[] = [RIDE_MONTS, TRIP_MORVAN, post()]
/** « Toutes les équipes », « Sorties »: two rides, one of them Gravel Bretagne's. */
export const FEED_RIDES: PublicationDto[] = [
  RIDE_MONTS,
  ride(
    { offset: 6 },
    {
      id: 'r-gravel-menez',
      slug: 'gravel-du-menez-hom',
      name: 'Gravel du Menez-Hom',
      team: { ...VCM_REF, id: GRAVEL_TEAM.id, name: GRAVEL_TEAM.name, slug: GRAVEL_TEAM.slug },
      excerpt: 'Chemins de crête et descente sur Sainte-Marie-du-Menez-Hom.',
      surfaceType: 'GRAVEL',
    }
  ),
]

/** The posts of the team: « Bilan de la saison » and two more. */
export const POSTS: PostDto[] = [
  post(),
  post({
    id: 'p-assemblee',
    slug: 'assemblee-generale',
    name: 'Assemblée générale de décembre',
    excerpt: 'Ordre du jour, procurations et renouvellement du bureau : tout est dans ce message.',
    thumbnailUrl: undefined,
    dateTime: day(-6, '20:00'),
    createdAt: day(-6, '20:00'),
    commentCount: 1,
    createdBy: KARIM,
  }),
  post({
    id: 'p-monts-photos',
    slug: 'photos-des-monts',
    name: 'Les photos des Monts d’Arrée',
    excerpt: 'Une cinquantaine de photos de la boucle d’octobre, du Roc’h Trévézel au lac.',
    dateTime: day(-12, '19:00'),
    createdAt: day(-12, '19:00'),
    commentCount: 7,
    createdBy: NOE,
  }),
]

/** The agenda at rest: soonest first. */
export const AGENDA: PublicationDto[] = [RIDE_RECUP, RIDE_MONTS, TRIP_MORVAN]
/** « Sorties », « Je participe ». */
export const AGENDA_MINE: PublicationDto[] = [ride({ registered: true })]
/** « Plus tôt », the agenda's second section: latest first. */
export const AGENDA_PAST: PublicationDto[] = [
  ride(
    { offset: -2 },
    { id: 'r-passee-1', slug: 'boucle-des-monts-passee', commentCount: 5, weather: undefined }
  ),
  trip(-16, {
    id: 'tr-passe',
    slug: 'traversee-du-morvan-2025',
    finished: true,
    endDateTime: day(-14, '16:00'),
  }),
  ride(
    { offset: -9 },
    {
      id: 'r-passee-2',
      slug: 'tour-du-lac-du-drennec',
      name: 'Tour du lac du Drennec',
      distance: 54_000,
      elevationGain: 610,
      weather: undefined,
    }
  ),
]
/**
 * The home feed's « Plus tôt » (`when=EARLIER`): « Tout » without what is ahead — the rides and
 * trips that are over and the posts, at their date, latest first, one list.
 */
export const FEED_EARLIER: PublicationDto[] = [post(), ...AGENDA_PAST]

// --- Routes ---------------------------------------------------------------------------------

export const ROUTES: RouteDto[] = [
  route(),
  route({
    id: 'rt-arree-b',
    slug: ROUTE_B_SLUG,
    name: 'Boucle des Monts d’Arrée — groupe B',
    excerpt: 'Par Léa Martin : la boucle sans le mont Saint-Michel.',
    distance: 78_000,
    elevationGain: 980,
    elevationLoss: 980,
    createdAt: day(-21, '18:00'),
  }),
  route({
    id: 'rt-arree-c',
    slug: ROUTE_C_SLUG,
    name: 'Boucle des Monts d’Arrée — groupe C',
    excerpt: 'Par Léa Martin : par la vallée, sans le Roc’h Trévézel.',
    distance: 61_000,
    elevationGain: 720,
    elevationLoss: 720,
    tags: [TAGS[1]],
    createdAt: day(-22, '18:00'),
  }),
]
/** 50–100 km, « vallonné »: the two routes carrying the tag. */
export const ROUTES_FILTERED = ROUTES.slice(0, 2)

/** « Tous les parcours »: the team's, and one of Gravel Bretagne. */
export const ALL_ROUTES: RouteDto[] = [
  ROUTES[0],
  route({
    id: 'rt-menez',
    slug: 'gravel-du-menez-hom',
    team: { ...VCM_REF, id: GRAVEL_TEAM.id, name: GRAVEL_TEAM.name, slug: GRAVEL_TEAM.slug },
    name: 'Gravel du Menez-Hom',
    excerpt: 'Chemins de crête et descente sur Sainte-Marie-du-Menez-Hom.',
    distance: 64_000,
    elevationGain: 1_050,
    elevationLoss: 1_050,
    surfaceType: 'GRAVEL',
    tags: [],
  }),
  ROUTES[1],
]
/** Scope « Toutes les équipes », practice « Route ». */
export const ALL_ROUTES_ROAD = [ROUTES[0], ROUTES[1]]

// --- Ads, members, people, notifications, templates -----------------------------------------

export const ADS: AdDto[] = [AD_SALE, AD_RENTAL, AD_WANTED]
export const ADS_TOTAL = 2_585

export const MEMBERS: MemberDto[] = [
  member(LEA, 'ADMIN', day(-1_500)),
  member(KARIM, 'ORGANIZER', day(-1_200)),
  member(CAMILLE, 'ORGANIZER', day(-400)),
]
export const ORGANIZERS = MEMBERS.slice(1)

/** Group B's eight people. */
export const GROUP_B_PEOPLE: PublicUserDto[] = [JEANNE, MALO, KARIM, NOE, CAMILLE, INES, SACHA, LEA]
/** « ma »: Léa Martin and Malo Guérin. */
export const GROUP_B_SEARCH = [MALO, LEA]

export const NOTIFICATIONS: NotificationDto[] = [
  NOTIFICATION_UPDATED,
  NOTIFICATION_UNREAD,
  NOTIFICATION_READ,
]
export const UNREAD_NOTIFICATIONS = [NOTIFICATION_UPDATED, NOTIFICATION_UNREAD]

export const TEMPLATES: RideTemplateDto[] = [
  TEMPLATE,
  TEMPLATE_DRAFT,
  {
    ...TEMPLATE,
    id: 'tpl-gravel',
    slug: 'gravel-du-samedi',
    name: 'Gravel du samedi',
    markdown: 'Une allure unique, chemins et pistes forestières, retour avant midi.',
    groupCount: 1,
    groups: [TEMPLATE.groups[1]],
    nextNumber: 4,
    updatedAt: day(-8, '21:00'),
  },
]

// --- Calendar -------------------------------------------------------------------------------

/** The month: the five events of the week (a ride, Camille's, a stage, a cancelled one, a draft). */
export const MONTH_EVENTS: CalendarEventDto[] = WEEK_EVENTS
export const MONTH_RIDES_ONLY = WEEK_EVENTS.filter((e) => e.type === 'RIDE')
/**
 * Nothing this month, a ride some forty days on: the empty month offers « Aller au prochain mois
 * avec une sortie » (RL10), found in the loaded window without another read.
 */
export const LATER_EVENTS: CalendarEventDto[] = [
  { ...WEEK_EVENTS[0], id: 'ev-later', start: day(40, '09:30'), end: day(40, '13:30') },
]
