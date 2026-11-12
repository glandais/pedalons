/**
 * The list brief's sections and cases
 * (`docs/plans/2026-11-10-etat-des-lieux-affichage/audit-listes/galerie.md`, « Cas, par liste »),
 * in its order. A case is the address the real page is opened at (its filters, page and view in
 * the query string, as `useUrlFilters` reads them) and the answers the fake API gives it
 * (`listFakeApi.ts`); a `-criteres` or `-tri` case adds the clicks that open the panel or the
 * list, made by the capture script (a real click) and by the gallery's test.
 */
import { paths } from '@/config/paths'
import { PENDING, SERVER_ERROR, ok, page, type Scenario } from './listFakeApi'
import {
  AGENDA,
  AGENDA_MINE,
  AGENDA_PAST,
  FEED,
  ALL_ROUTES_ROAD,
  AULNE_TEAM,
  ALL_TEAMS,
  FEED_RIDES,
  GRAVEL_MEMBER,
  GROUP_B_SEARCH,
  HILLY_TAG_ID,
  LATER_EVENTS,
  MONTH_RIDES_ONLY,
  ORGANIZERS,
  POSTS,
  ROUTES_FILTERED,
  TEMPLATES,
  UNREAD_NOTIFICATIONS,
  VCM_MEMBER,
  teamTags,
} from './listFixtures'
import { AD_SALE, RIDE_SLUG, VCM_SLUG } from '../cardGallery/fixtures'

/** A click the capture makes before its shot: a button or a field, by its accessible name. */
export type ClickStep = { role: 'button' | 'combobox'; name: string } | { placeholder: string }

export interface ListCase {
  /** The brief's identifier, e.g. `parcours-vide-filtre`. */
  id: string
  /** What the case shows. */
  label: string
  /** The address the page is opened at, in the router. */
  url: () => string
  /** The fake API's answers that differ from the answers at rest. */
  api?: Scenario
  /** Opens a panel or a list before the shot. */
  clicks?: ClickStep[]
  /** The list, when it is not at the top of the page: the capture scrolls it into view. */
  scrollTo?: string
}

/** A case of the brief the site cannot show: listed, with the reason, never replaced. */
export interface OmittedListCase {
  id: string
  label: string
  omitted: string
}

export type ListEntry = ListCase | OmittedListCase

export interface ListSection {
  id: string
  title: string
  entries: ListEntry[]
}

export const isOmittedCase = (entry: ListEntry): entry is OmittedListCase => 'omitted' in entry

const EMPTY = (key: string, size = 12) => page(key, [], 0, size)
const q = (base: string, params: Record<string, string>) =>
  `${base}?${new URLSearchParams(params).toString()}`

const FEED_SECTION = '#home-feed-title'

const home: ListSection = {
  id: 'accueil',
  title: 'Fil d’accueil',
  entries: [
    {
      id: 'accueil-repos',
      label: 'trois publications sur 47',
      url: paths.home,
      scrollTo: FEED_SECTION,
    },
    {
      id: 'accueil-sections',
      label: '« À venir » puis « Plus tôt » : deux sorties et voyages, puis une publication',
      url: paths.home,
      api: { feed: page('publications', FEED, 47, 12, 2) },
      scrollTo: FEED_SECTION,
    },
    {
      id: 'accueil-filtre',
      label: 'portée « Toutes les équipes », type « Sorties »',
      url: () => q(paths.home(), { role: 'all', type: 'ride' }),
      api: { feed: page('publications', FEED_RIDES, 2, 12, 2) },
      scrollTo: FEED_SECTION,
    },
    {
      id: 'accueil-criteres',
      label: 'contrôle de portée ouvert',
      url: paths.home,
      clicks: [{ role: 'combobox', name: 'Portée' }],
      scrollTo: FEED_SECTION,
    },
    {
      id: 'accueil-vide',
      label: 'aucune publication',
      url: paths.home,
      api: { feed: EMPTY('publications') },
      scrollTo: FEED_SECTION,
    },
    {
      id: 'accueil-vide-filtre',
      label: 'aucune publication pour « monts », type « Voyages »',
      url: () => q(paths.home(), { q: 'monts', type: 'trip' }),
      api: { feed: EMPTY('publications') },
      scrollTo: FEED_SECTION,
    },
    {
      id: 'accueil-erreur',
      label: 'le fil n’a pas pu être chargé',
      url: paths.home,
      api: { feed: SERVER_ERROR },
      scrollTo: FEED_SECTION,
    },
    {
      id: 'accueil-chargement',
      label: 'chargement initial (fil, semaine, équipes)',
      url: paths.home,
      api: { feed: PENDING, myParticipations: PENDING, calendar: PENDING, myTeams: PENDING },
    },
  ],
}

const POST_TAGS = { tags: ok(teamTags('POST')) }

const posts: ListSection = {
  id: 'publications',
  title: 'Publications d’une équipe',
  entries: [
    {
      id: 'publications-repos',
      label: 'trois publications sur 47',
      url: () => paths.teamPosts(VCM_SLUG),
      api: POST_TAGS,
    },
    {
      id: 'publications-filtre',
      label: 'recherche « monts » et tag « vallonné »',
      url: () => q(paths.teamPosts(VCM_SLUG), { q: 'monts', tags: HILLY_TAG_ID }),
      api: { ...POST_TAGS, posts: page('publications', [POSTS[2]]) },
    },
    {
      id: 'publications-vide',
      label: 'aucune publication',
      url: () => paths.teamPosts(VCM_SLUG),
      api: { ...POST_TAGS, posts: EMPTY('publications') },
    },
    {
      id: 'publications-vide-filtre',
      label: 'aucune publication pour « monts »',
      url: () => q(paths.teamPosts(VCM_SLUG), { q: 'monts' }),
      api: { ...POST_TAGS, posts: EMPTY('publications') },
    },
    {
      id: 'publications-erreur',
      label: 'erreur serveur',
      url: () => paths.teamPosts(VCM_SLUG),
      api: { ...POST_TAGS, posts: SERVER_ERROR },
    },
    {
      id: 'publications-lecture',
      label: 'vue d’une personne membre',
      url: () => paths.teamPosts(VCM_SLUG),
      api: { ...POST_TAGS, team: ok(VCM_MEMBER) },
    },
  ],
}

const RIDE_TAGS = { tags: ok(teamTags('RIDE')) }

const agenda: ListSection = {
  id: 'agenda',
  title: 'Agenda d’une équipe',
  entries: [
    {
      id: 'agenda-repos',
      label: 'trois événements sur 47',
      url: () => paths.teamAgenda(VCM_SLUG),
      api: RIDE_TAGS,
    },
    {
      id: 'agenda-sections',
      label: '« À venir » (deux) puis « Plus tôt » (45) sur une même page',
      url: () => paths.teamAgenda(VCM_SLUG),
      api: {
        ...RIDE_TAGS,
        agenda: page('publications', [...AGENDA.slice(0, 2), ...AGENDA_PAST], 47, 12, 2),
      },
    },
    {
      id: 'agenda-filtre',
      label: '« Sorties », « Je participe »',
      url: () => q(paths.teamAgenda(VCM_SLUG), { type: 'ride', w: 'me' }),
      api: { ...RIDE_TAGS, agenda: page('publications', AGENDA_MINE, 1, 12, 1) },
    },
    {
      id: 'agenda-criteres',
      label: 'panneau des filtres ouvert',
      omitted:
        'le site n’a plus de panneau à l’agenda (RL6) : recherche et tags sont en tête de liste, période et type en dessous, toujours visibles (agenda-repos)',
    },
    {
      id: 'agenda-vide',
      label: 'rien à l’agenda',
      url: () => paths.teamAgenda(VCM_SLUG),
      api: { ...RIDE_TAGS, agenda: EMPTY('publications') },
    },
    {
      id: 'agenda-vide-filtre',
      label: '« Voyages », « Je participe » : rien',
      url: () => q(paths.teamAgenda(VCM_SLUG), { type: 'trip', w: 'me' }),
      api: { ...RIDE_TAGS, agenda: EMPTY('publications') },
    },
    {
      id: 'agenda-erreur',
      label: 'erreur serveur',
      url: () => paths.teamAgenda(VCM_SLUG),
      api: { ...RIDE_TAGS, agenda: SERVER_ERROR },
    },
    {
      id: 'agenda-lecture',
      label: 'vue d’une personne membre',
      url: () => paths.teamAgenda(VCM_SLUG),
      api: { ...RIDE_TAGS, team: ok(VCM_MEMBER) },
    },
  ],
}

const calendar: ListSection = {
  id: 'calendrier',
  title: 'Calendrier global, calendrier d’une équipe',
  entries: [
    { id: 'calendrier-repos', label: 'le mois, cinq événements', url: paths.calendar },
    {
      id: 'calendrier-filtre',
      label: 'type « Sorties »',
      url: () => q(paths.calendar(), { type: 'ride' }),
    },
    {
      id: 'calendrier-equipe',
      label: 'calendrier du Vélo Club des Monts',
      url: () => paths.teamCalendar(VCM_SLUG),
    },
    {
      id: 'calendrier-vide',
      label: 'mois sans rien, une sortie dans quarante jours',
      url: paths.calendar,
      api: { calendar: ok({ events: LATER_EVENTS }) },
    },
    {
      id: 'calendrier-vide-filtre',
      label: 'type « Voyages », le mois n’a que des sorties',
      url: () => q(paths.calendar(), { type: 'trip' }),
      api: { calendar: ok({ events: MONTH_RIDES_ONLY }) },
    },
    {
      id: 'calendrier-erreur',
      label: 'erreur serveur',
      url: paths.calendar,
      api: { calendar: SERVER_ERROR },
    },
    {
      id: 'calendrier-chargement',
      label: 'chargement initial',
      url: paths.calendar,
      api: { calendar: PENDING },
    },
  ],
}

const FILTERS_BUTTON: ClickStep = { role: 'button', name: 'Filtres' }

const routes: ListSection = {
  id: 'parcours',
  title: 'Parcours d’une équipe',
  entries: [
    {
      id: 'parcours-repos',
      label: 'vignettes, trois parcours sur 47',
      url: () => paths.routes(VCM_SLUG),
    },
    {
      id: 'parcours-lignes',
      label: 'vue compacte',
      url: () => q(paths.routes(VCM_SLUG), { view: 'row' }),
    },
    {
      id: 'parcours-carte',
      label: 'vue carte (la barre seule compte)',
      url: () => paths.routesMap(VCM_SLUG),
    },
    {
      id: 'parcours-filtre',
      label: 'distance 50–100 km, tag « vallonné »',
      url: () => q(paths.routes(VCM_SLUG), { dmin: '50000', dmax: '100000', tags: HILLY_TAG_ID }),
      api: { routes: page('routes', ROUTES_FILTERED) },
    },
    {
      id: 'parcours-criteres',
      label: 'panneau des filtres ouvert',
      url: () => paths.routes(VCM_SLUG),
      clicks: [FILTERS_BUTTON],
    },
    {
      id: 'parcours-tri',
      label: 'liste de tri ouverte (hors du panneau, RL6)',
      url: () => paths.routes(VCM_SLUG),
      clicks: [{ role: 'combobox', name: 'Trier par' }],
    },
    {
      id: 'parcours-vide',
      label: 'aucun parcours',
      url: () => paths.routes(VCM_SLUG),
      api: { routes: EMPTY('routes') },
    },
    {
      id: 'parcours-vide-filtre',
      label: 'aucun parcours entre 150 et 200 km',
      url: () => q(paths.routes(VCM_SLUG), { dmin: '150000', dmax: '200000' }),
      api: { routes: EMPTY('routes') },
    },
    {
      id: 'parcours-erreur',
      label: 'erreur serveur',
      url: () => paths.routes(VCM_SLUG),
      api: { routes: SERVER_ERROR },
    },
    {
      id: 'parcours-lecture',
      label: 'vue d’une personne membre',
      url: () => paths.routes(VCM_SLUG),
      api: { team: ok(VCM_MEMBER) },
    },
  ],
}

const explore: ListSection = {
  id: 'explorer',
  title: 'Tous les parcours',
  entries: [
    { id: 'explorer-repos', label: 'trois parcours sur 47', url: paths.allRoutes },
    {
      id: 'explorer-filtre',
      label: 'portée « Toutes les équipes », pratique « Route »',
      url: () => q(paths.allRoutes(), { role: 'all', surf: 'ROAD' }),
      api: { allRoutes: page('routes', ALL_ROUTES_ROAD) },
    },
    {
      id: 'explorer-criteres',
      label: 'panneau des filtres ouvert',
      url: paths.allRoutes,
      clicks: [FILTERS_BUTTON],
    },
    {
      id: 'explorer-vide-filtre',
      label: 'aucun parcours pour « monts » en gravel',
      url: () => q(paths.allRoutes(), { q: 'monts', surf: 'GRAVEL' }),
      api: { allRoutes: EMPTY('routes') },
    },
    {
      id: 'explorer-erreur',
      label: 'erreur serveur',
      url: paths.allRoutes,
      api: { allRoutes: SERVER_ERROR },
    },
  ],
}

const AD_TAGS = { tags: ok(teamTags('AD')) }

const ads: ListSection = {
  id: 'annonces',
  title: 'Annonces d’une équipe',
  entries: [
    {
      id: 'annonces-repos',
      label: 'trois annonces sur 2 585',
      url: () => paths.ads(VCM_SLUG),
      api: AD_TAGS,
    },
    {
      id: 'annonces-filtre',
      label: 'type « Vente »',
      url: () => q(paths.ads(VCM_SLUG), { type: 'SALE' }),
      api: { ...AD_TAGS, ads: page('ads', [AD_SALE], 1_204) },
    },
    {
      id: 'annonces-criteres',
      label: 'panneau des filtres ouvert',
      omitted:
        'le site n’a pas de panneau aux annonces : type (segmenté, RL6), prix et tags sont dans la barre, toujours visibles (annonces-repos)',
    },
    {
      id: 'annonces-tri',
      label: 'liste de tri ouverte',
      url: () => paths.ads(VCM_SLUG),
      api: AD_TAGS,
      clicks: [{ role: 'combobox', name: 'Trier par' }],
    },
    {
      id: 'annonces-vide',
      label: 'aucune annonce',
      url: () => paths.ads(VCM_SLUG),
      api: { ...AD_TAGS, ads: EMPTY('ads') },
    },
    {
      id: 'annonces-vide-filtre',
      label: 'aucune annonce pour « monts »',
      url: () => q(paths.ads(VCM_SLUG), { q: 'monts' }),
      api: { ...AD_TAGS, ads: EMPTY('ads') },
    },
    {
      id: 'annonces-erreur',
      label: 'erreur serveur',
      url: () => paths.ads(VCM_SLUG),
      api: { ...AD_TAGS, ads: SERVER_ERROR },
    },
  ],
}

const teams: ListSection = {
  id: 'equipes',
  title: 'Mes équipes, découvrir',
  entries: [
    { id: 'equipes-repos', label: 'mes équipes (deux)', url: paths.teams },
    {
      id: 'equipes-decouvrir',
      label: 'toutes les équipes, trois sur 47',
      url: () => q(paths.teams(), { role: 'all' }),
      api: { teamList: page('teams', ALL_TEAMS, 47) },
    },
    {
      id: 'equipes-filtre',
      label: 'recherche « bretagne »',
      url: () => q(paths.teams(), { q: 'bretagne', role: 'all' }),
      api: { teamList: page('teams', [GRAVEL_MEMBER]) },
    },
    {
      id: 'equipes-vide',
      label: 'aucune équipe',
      url: paths.teams,
      api: { teamList: EMPTY('teams'), myTeams: EMPTY('teams', 20) },
    },
    {
      id: 'equipes-vide-filtre',
      label: 'aucune équipe pour « aulne » parmi les miennes',
      url: () => q(paths.teams(), { q: 'aulne' }),
      api: { teamList: EMPTY('teams') },
    },
    {
      id: 'equipes-erreur',
      label: 'erreur serveur',
      url: paths.teams,
      api: { teamList: SERVER_ERROR },
    },
  ],
}
// Keeps the third team's name in one place for the test's content check.
export const DISCOVERED_TEAM = AULNE_TEAM.name

const members: ListSection = {
  id: 'membres',
  title: 'Membres d’une équipe',
  entries: [
    { id: 'membres-repos', label: 'trois membres sur 24', url: () => paths.teamMembers(VCM_SLUG) },
    {
      id: 'membres-filtre',
      label: 'rôle « Organisateur »',
      url: () => q(paths.teamMembers(VCM_SLUG), { role: 'ORGANIZER' }),
      api: { members: page('members', ORGANIZERS, ORGANIZERS.length, 50) },
    },
    {
      id: 'membres-vide-filtre',
      label: 'personne pour « zoé »',
      url: () => q(paths.teamMembers(VCM_SLUG), { q: 'zoé' }),
      api: { members: EMPTY('members', 50) },
    },
    {
      id: 'membres-erreur',
      label: 'erreur serveur',
      url: () => paths.teamMembers(VCM_SLUG),
      api: { members: SERVER_ERROR },
    },
  ],
}

const PARTICIPANTS_SECTION = 'section[aria-labelledby="group-participants-title"]'
const groupB = () => paths.rideGroup(VCM_SLUG, RIDE_SLUG, 'g-b')

const participants: ListSection = {
  id: 'inscrits',
  title: 'Personnes inscrites',
  entries: [
    {
      id: 'inscrits-repos',
      label: 'huit personnes, groupe B',
      url: groupB,
      scrollTo: PARTICIPANTS_SECTION,
    },
    {
      id: 'inscrits-filtre',
      label: 'recherche « ma »',
      url: () => q(groupB(), { q: 'ma' }),
      api: { participants: page('participants', GROUP_B_SEARCH, GROUP_B_SEARCH.length, 50) },
      scrollTo: PARTICIPANTS_SECTION,
    },
    {
      id: 'inscrits-vide',
      label: 'personne dans le groupe',
      url: groupB,
      api: { participants: EMPTY('participants', 50) },
      scrollTo: PARTICIPANTS_SECTION,
    },
    {
      id: 'inscrits-vide-filtre',
      label: 'personne pour « zoé »',
      url: () => q(groupB(), { q: 'zoé' }),
      api: { participants: EMPTY('participants', 50) },
      scrollTo: PARTICIPANTS_SECTION,
    },
    {
      id: 'inscrits-erreur',
      label: 'erreur serveur',
      url: groupB,
      api: { participants: SERVER_ERROR },
      scrollTo: PARTICIPANTS_SECTION,
    },
  ],
}

const notifications: ListSection = {
  id: 'notifications',
  title: 'Notifications',
  entries: [
    { id: 'notifications-repos', label: 'trois notifications sur 47', url: paths.notifications },
    {
      id: 'notifications-filtre',
      label: '« Non lues »',
      url: () => q(paths.notifications(), { unread: 'true' }),
      api: {
        notifications: ok({
          items: UNREAD_NOTIFICATIONS,
          total: 2,
          unreadCount: 2,
          page: 0,
          size: 20,
        }),
      },
    },
    {
      id: 'notifications-vide',
      label: 'aucune notification',
      url: paths.notifications,
      api: {
        notifications: ok({ items: [], total: 0, unreadCount: 0, page: 0, size: 20 }),
        unreadCount: ok({ count: 0 }),
      },
    },
    {
      id: 'notifications-vide-filtre',
      label: '« Non lues » : tout est lu',
      url: () => q(paths.notifications(), { unread: 'true' }),
      api: {
        notifications: ok({ items: [], total: 0, unreadCount: 0, page: 0, size: 20 }),
        unreadCount: ok({ count: 0 }),
      },
    },
    {
      id: 'notifications-erreur',
      label: 'erreur serveur',
      url: paths.notifications,
      api: { notifications: SERVER_ERROR },
    },
  ],
}

const templates: ListSection = {
  id: 'modeles',
  title: 'Modèles de sortie',
  entries: [
    {
      id: 'modeles-repos',
      label: 'trois modèles sur 47',
      url: () => paths.rideTemplates(VCM_SLUG),
    },
    {
      id: 'modeles-filtre',
      label: 'recherche « dimanche »',
      url: () => q(paths.rideTemplates(VCM_SLUG), { q: 'dimanche' }),
      api: { templates: page('templates', [TEMPLATES[0]], 1, 20) },
    },
    {
      id: 'modeles-vide',
      label: 'aucun modèle',
      url: () => paths.rideTemplates(VCM_SLUG),
      api: { templates: EMPTY('templates', 20) },
    },
    {
      id: 'modeles-vide-filtre',
      label: 'aucun modèle pour « col »',
      url: () => q(paths.rideTemplates(VCM_SLUG), { q: 'col' }),
      api: { templates: EMPTY('templates', 20) },
    },
    {
      id: 'modeles-erreur',
      label: 'erreur serveur',
      url: () => paths.rideTemplates(VCM_SLUG),
      api: { templates: SERVER_ERROR },
    },
  ],
}

/** The brief's sections, in its order. */
export const LIST_SECTIONS: ListSection[] = [
  home,
  posts,
  agenda,
  calendar,
  routes,
  explore,
  ads,
  teams,
  members,
  participants,
  notifications,
  templates,
]

export function findCase(sectionId: string | null, caseId: string | null) {
  const section = LIST_SECTIONS.find((s) => s.id === sectionId)
  const entry = section?.entries.find((e) => e.id === caseId)
  return { section, entry }
}
