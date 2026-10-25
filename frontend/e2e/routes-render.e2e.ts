import type { Locator, Page } from '@playwright/test'
import { signIn } from './support/data'
import { DEVICE_PAGE, ensureHammerheadOffered } from './support/device'
import { stack } from './support/stack'
import { expect, test } from './support/fixtures'
import { configuredAuth, contractWebRoutes, fillPath, type ContractRoute } from './support/contract'
import {
  buildDataset,
  releaseDataset,
  englishPath,
  RENDER_ROLES,
  type Dataset,
  type RenderRole,
} from './support/routes-render'
import { pageAs, pageHydrated, watchHydration, watchPrefetchAudit } from './support/ui'

/**
 * Every web route of contracts/routes.yaml, for every role: the screen for those who may see it,
 * the page's own fallback for those it turns away.
 *
 * One test per (route, role). Each one opens the route in a fresh context as that role and checks
 * that the document answers 200, the app lands where it should — the page itself, the redirect its
 * guard is meant to do, or the fallback of a page that refuses the role — that nothing threw
 * (`pageerror`) or failed to hydrate (`[hydration]`), that no error screen is shown, and that
 * something only the landing screen has is visible. A refused role also checks that nothing of the
 * protected screen shows (`guards`): a page whose `<Navigate>` went missing would render its admin
 * form, and that test would fail on it. A screen that renders on its own path also checks that the
 * server prefetched every query it reads (`[prefetch-audit]`, frontend/docs/SSR-data-loading.md):
 * a gap still renders, but fetches after hydration, behind a loader the server painted.
 *
 * The guard redirects are derived from each route's `auth` in routes.config.ts: an `authenticated`
 * route sends an anonymous visitor to the login page, an `unauthenticated` one sends a signed-in
 * visitor home. Who may see a screen beyond that (an outsider, a member, an organizer, an admin of
 * the team, the platform admin), and where the others go, is the table below. Every (route, role)
 * pair has exactly one outcome: a coverage test fails on a pair left undeclared or declared twice.
 *
 * All the params come from one dataset per worker: a public team of its own with a member, an
 * organizer and an admin, a signed-in outsider, and one entity of every kind a route names.
 */

type Main = Locator

interface Expectation {
  /** Where the app ends up, when not on the requested path. */
  lands?: (data: Dataset) => string
  /** What only that screen shows. `main` is the page's <main>, or the page for a bare layout. */
  sees: (main: Main, data: Dataset, page: Page) => Promise<void>
}

type Outcome = Expectation & {
  why: string
  /**
   * A known defect keeps the app from this outcome today: the test is declared `test.fail` with
   * this reason, and turns red the day the fix lands — then drop the field.
   */
  defect?: string
}

interface Screen extends Expectation {
  /** Who may see the screen. The guard's own redirects are added from routes.config.ts. */
  roles: readonly RenderRole[]
  /** Rendered outside the app shell (`layout: 'bare'`): no <main>. */
  bare?: boolean
  /** The params the route is opened with, when the dataset's own (`d.params`) do not fit. */
  params?: (data: Dataset) => Record<string, string>
  /** What only the screen shows to these roles, when it renders differently for them. */
  seesAs?: Partial<Record<RenderRole, Expectation['sees']>>
  /** Per-role outcomes that differ from the screen itself — the page's own redirects. */
  otherwise?: Partial<Record<RenderRole, Outcome>>
  /** The roles the page turns away, and the fallback each one lands on. */
  denied?: Partial<Record<RenderRole, Outcome>>
  /** What only the protected screen shows: absent wherever the page turns a role away. */
  guards?: (page: Page, data: Dataset) => Locator
}

const EVERYONE = RENDER_ROLES
const SIGNED_IN = ['outsider', 'member', 'organizer', 'teamAdmin', 'platformAdmin'] as const
// The platform admin is not a member of the dataset's team, but the backend lets it read and
// manage every team (TeamAdminPage sends it to the ride templates like a team admin).
const MEMBERS = ['member', 'organizer', 'teamAdmin', 'platformAdmin'] as const
const ORGANIZERS = ['organizer', 'teamAdmin', 'platformAdmin'] as const
const ADMINS = ['teamAdmin', 'platformAdmin'] as const
// Their complements among the signed-in roles: who the team-scoped pages turn away.
const BELOW_ORGANIZER = ['outsider', 'member'] as const
const BELOW_ADMIN = ['outsider', 'member', 'organizer'] as const
const NOT_PLATFORM_ADMIN = ['outsider', 'member', 'organizer', 'teamAdmin'] as const

const heading = (name: string) => async (main: Main) => {
  await expect(main.getByRole('heading', { name, exact: true })).toBeVisible()
}

/** The current entry of a NavButtons row (`aria-current="page"`), by the row's landmark name. */
const currentTab = (page: Page, landmark: string, name: string) =>
  expect(
    page.getByRole('navigation', { name: landmark }).getByRole('link', { name, exact: true })
  ).toHaveAttribute('aria-current', 'page')

/** A fullscreen map page: its back link to the detail page, its title, and the map itself. */
const fullscreenMap =
  (title: (d: Dataset) => string, back: (d: Dataset) => string) =>
  async (page: Main, data: Dataset) => {
    await expect(page.getByRole('link', { name: 'Retour' })).toHaveAttribute('href', back(data))
    await expect(page.getByText(title(data), { exact: true })).toBeVisible()
    await expect(page.locator('canvas.maplibregl-canvas')).toBeVisible()
  }

const teamPath = (d: Dataset) => `/equipes/${d.team.slug}`

/**
 * The path of the contract's route `id`, filled from the dataset (or from `params`, read from it).
 * Read at run time.
 */
const pathTo =
  (id: string, params: (d: Dataset) => Record<string, string> = (d) => d.params) =>
  (d: Dataset) => {
    const route = contract.find((candidate) => candidate.id === id)
    if (!route) throw new Error(`no web route ${id} in the contract`)
    return fillPath(route, params(d))
  }

/** The dataset's params, on its solo ride (one group) instead of its ride of two groups. */
const soloRideParams = (d: Dataset) => ({ ...d.params, rideSlug: d.soloRide.slug })

/** The same page-level outcome for each of `roles` — a redirect, or a refusal. */
const redirects = (
  roles: readonly RenderRole[],
  outcome: Outcome
): Partial<Record<RenderRole, Outcome>> => Object.fromEntries(roles.map((role) => [role, outcome]))
const denies = redirects

// The fallbacks a refusing page sends to, and what proves the visitor got there.
const teamHome = (why: string): Outcome => ({
  why,
  lands: teamPath,
  sees: (main, d) =>
    expect(main.getByRole('heading', { level: 1, name: d.team.name })).toBeVisible(),
})
const routeList = (why: string): Outcome => ({
  why,
  lands: pathTo('routes'),
  sees: async (main, d) => {
    await expect(main.getByRole('radio', { name: 'Vignettes' })).toBeChecked()
    await expect(main.getByRole('link', { name: d.route.name }).first()).toBeVisible()
  },
})
/**
 * The team's ads tab as an outsider sees it: settled on its members-only notice, so that the
 * absence of the ad the next checks assert is not vacuous.
 */
const settledAdList = async (main: Main) => {
  await heading('Annonces')(main)
  await expect(
    main.getByRole('heading', { name: 'Réservées aux membres', exact: true })
  ).toBeVisible()
}
const adList = (why: string): Outcome => ({ why, lands: pathTo('ads'), sees: settledAdList })
const home = (why: string): Outcome => ({
  why,
  lands: () => '/',
  sees: heading('Dernières publications'),
})

// The protected screens' own marks. A team admin tab is framed by the admin navigation, which
// neither the team page nor any fallback shows; the forms each have their own title.
const teamAdminNav = (page: Page) =>
  page.getByRole('navigation', { name: "Navigation de la gestion de l'équipe" })
const platformAdminNav = (page: Page) =>
  page.getByRole('navigation', { name: "Navigation de l'administration" })
const titled =
  (name: string) =>
  (page: Page): Locator =>
    page.getByRole('heading', { name, exact: true })

const NOT_ORGANIZER = 'only the team organizers manage it'
const NOT_ADMIN = 'only the team admins manage it'

const screens: Record<string, Screen> = {
  // A visitor gets the presentation and the sign-in form, a signed-in user the member home.
  home: {
    roles: EVERYONE,
    sees: heading('Dernières publications'),
    seesAs: {
      anonymous: heading('Organisez vos sorties. Partagez vos parcours. Roulez ensemble.'),
    },
  },
  login: {
    roles: ['anonymous'],
    sees: (main) =>
      expect(main.getByRole('button', { name: 'Se connecter', exact: true })).toBeVisible(),
  },
  // The e-mail links land here with a token; without one, each page says the link is unusable.
  // Following a real link is the journeys' job (auth, invitations).
  verifyEmail: { roles: EVERYONE, sees: heading('Lien invalide') },
  invitation: { roles: EVERYONE, sees: heading('Invitation indisponible') },
  // biketeam sends a team admin here with a request it signed (?request=); without one the page
  // says the link is incomplete. Following a real request needs biketeam itself.
  biketeamMigration: {
    roles: EVERYONE,
    sees: async (main) => {
      await heading('Demande de migration indisponible')(main)
      await expect(main.getByText('Le lien est incomplet.', { exact: false })).toBeVisible()
    },
  },
  forgotPassword: { roles: ['anonymous'], sees: heading('Mot de passe oublié') },
  resetPassword: { roles: EVERYONE, sees: heading('Lien invalide') },
  deviceVerifyGarmin: { roles: SIGNED_IN, sees: heading('Entrez le code') },
  deviceVerifyKaroo: { roles: SIGNED_IN, sees: heading('Entrez le code') },
  // The Karoo's fallback QR: the Hammerhead step alone. Offered on localhost by the beforeAll, else
  // the page says the Karoo is ready instead (docs/LEDGER_*.md API-63).
  deviceHammerhead: { roles: SIGNED_IN, sees: heading(DEVICE_PAGE.hammerhead) },
  apps: { roles: EVERYONE, sees: heading('Applications') },
  features: { roles: EVERYONE, sees: heading("Tout ce qu'il faut pour faire rouler une équipe") },
  // The legal pages repeat their title in their own markdown: two level-1 headings.
  privacy: {
    roles: EVERYONE,
    sees: (main) =>
      expect(
        main.getByRole('heading', { level: 1, name: 'Politique de confidentialité' })
      ).toHaveCount(2),
  },
  terms: {
    roles: EVERYONE,
    sees: (main) =>
      expect(main.getByRole('heading', { level: 1, name: "Conditions d'utilisation" })).toHaveCount(
        2
      ),
  },
  support: { roles: EVERYONE, sees: heading('Aide et contact') },
  // The profile: its overview, then one page per subject, each under the sidebar on a desktop.
  profile: { roles: SIGNED_IN, sees: heading('Profil') },
  profilePreferences: { roles: SIGNED_IN, sees: heading('Préférences') },
  profileNotifications: { roles: SIGNED_IN, sees: heading('Notifications') },
  profileDevices: { roles: SIGNED_IN, sees: heading('Appareils et services') },
  profileSecurity: { roles: SIGNED_IN, sees: heading('Connexion et sécurité') },
  profilePrivacy: { roles: SIGNED_IN, sees: heading('Confidentialité') },
  blockedUsers: { roles: SIGNED_IN, sees: heading('Personnes bloquées') },
  profileAccount: { roles: SIGNED_IN, sees: heading('Mon compte') },
  profileHelp: { roles: SIGNED_IN, sees: heading('Aide et à propos') },
  notifications: { roles: SIGNED_IN, sees: heading('Notifications') },
  calendar: { roles: SIGNED_IN, sees: heading('Calendrier') },
  allRoutes: {
    roles: EVERYONE,
    // Vignettes or Lignes: the density follows the size of the whole stack's library (WEB-69).
    sees: (main) => expect(main.getByRole('radio', { name: 'Carte' })).not.toBeChecked(),
  },
  allRoutesMap: {
    roles: EVERYONE,
    sees: async (main) => {
      await expect(main.getByRole('radio', { name: 'Carte' })).toBeChecked()
      await expect(main.locator('canvas.maplibregl-canvas')).toBeVisible()
    },
  },
  gpxTools: { roles: SIGNED_IN, sees: heading('Outils GPX') },
  gpxToolsList: { roles: SIGNED_IN, sees: heading('Lister mes fichiers') },
  gpxToolsNew: {
    roles: [],
    sees: async () => {},
    // The e2e domain keeps the planner closed (GET /api/config: enableGpxPlanner=false), and the
    // page sends the visitor back to the hub rather than render an editor that cannot submit.
    otherwise: redirects(SIGNED_IN, {
      why: 'the planner is closed on this domain',
      lands: () => '/outils-gpx',
      sees: heading('Outils GPX'),
    }),
  },
  // A map with no track: public, reads nothing but /api/config.
  gpxToolsBlankMap: {
    roles: EVERYONE,
    bare: true,
    sees: fullscreenMap(
      () => 'Carte',
      () => '/outils-gpx'
    ),
  },
  gpxToolsView: { roles: EVERYONE, sees: (main, d) => heading(d.preview.name)(main) },
  gpxToolsMap: {
    roles: EVERYONE,
    bare: true,
    sees: fullscreenMap(
      (d) => d.preview.name,
      (d) => `/outils-gpx/${d.preview.id}`
    ),
  },
  gpxToolsEdit: {
    // The preview belongs to the member.
    roles: ['member'],
    sees: heading('Modifier le fichier GPX'),
    otherwise: redirects(['outsider', ...ORGANIZERS], {
      why: 'editing a preview is owner-only: the page sends others to the read view',
      lands: (d) => `/outils-gpx/${d.preview.id}`,
      sees: (main, d) => heading(d.preview.name)(main),
    }),
  },
  teams: { roles: EVERYONE, sees: heading('Équipes') },
  teamsNew: { roles: SIGNED_IN, sees: heading('Créer une équipe') },
  team: {
    roles: EVERYONE,
    sees: async (main, d) => {
      await expect(main.getByRole('heading', { level: 1, name: d.team.name })).toBeVisible()
      await expect(main.getByRole('link', { name: d.ride.name }).first()).toBeVisible()
    },
  },
  teamAbout: { roles: EVERYONE, sees: heading("À propos de l'équipe") },
  // The members' directory (WEB-1). The dataset's team has it open (teamRequest sets
  // enableMemberDirectory): the API lets its members read it, and the platform admin (API-39); an
  // outsider gets a 403, which the page shows as its own refusal, in place.
  teamMembers: {
    roles: MEMBERS,
    sees: async (main, d) => {
      await heading('Membres')(main)
      await expect(main.getByText(d.sessions.organizer.user.displayName).first()).toBeVisible()
    },
    denied: {
      outsider: {
        why: 'the member directory is for the team members',
        sees: heading('Liste des membres non partagée'),
      },
    },
    guards: (page) => page.getByRole('main').getByRole('searchbox', { name: 'Rechercher' }),
  },
  // The agenda's calendar view (WEB-69): for the members, an outsider gets the agenda's lists.
  teamCalendar: {
    roles: MEMBERS,
    sees: async (main, d) => {
      await expect(main.getByRole('heading', { level: 1, name: d.team.name })).toBeVisible()
      await heading('Agenda')(main)
      await expect(main.getByRole('radio', { name: 'Calendrier' })).toBeChecked()
    },
    denied: {
      outsider: {
        why: 'the team calendar is for its members',
        lands: pathTo('teamAgenda'),
        sees: async (main) => {
          await heading('Agenda')(main)
          await expect(main.getByRole('radio', { name: 'Calendrier' })).toHaveCount(0)
        },
      },
    },
    guards: (page) =>
      titled('Calendrier')(page).or(page.getByRole('textbox', { name: "URL du flux d'équipe" })),
  },
  // The agenda — rides and trips — and the posts, each a tab of the team (WEB-68): public.
  teamAgenda: {
    roles: EVERYONE,
    sees: async (main, d, page) => {
      await currentTab(page, "Navigation de l'équipe", 'Agenda')
      await expect(main.getByRole('link', { name: d.ride.name }).first()).toBeVisible()
      await expect(main.getByRole('link', { name: d.post.name, exact: true })).toHaveCount(0)
    },
  },
  teamPosts: {
    roles: EVERYONE,
    sees: async (main, d, page) => {
      await currentTab(page, "Navigation de l'équipe", 'Publications')
      await expect(main.getByRole('link', { name: d.post.name }).first()).toBeVisible()
      await expect(main.getByRole('link', { name: d.ride.name, exact: true })).toHaveCount(0)
    },
  },
  // The former « Sorties » and « Voyages » tabs (WEB-64): their loader redirects to the agenda,
  // for everyone (`teamTrips` with `?type=trip`).
  teamRides: {
    roles: [],
    sees: async () => {},
    otherwise: redirects(EVERYONE, {
      why: 'the former « Sorties » tab is the agenda now',
      lands: pathTo('teamAgenda'),
      sees: async (main, d) => {
        await expect(main.getByRole('link', { name: d.ride.name }).first()).toBeVisible()
      },
    }),
  },
  teamTrips: {
    roles: [],
    sees: async () => {},
    otherwise: redirects(EVERYONE, {
      why: 'the former « Voyages » tab is the agenda narrowed to trips now',
      lands: pathTo('teamAgenda'),
      sees: async (main, d) => {
        await expect(main.getByRole('link', { name: d.trip.name }).first()).toBeVisible()
        await expect(main.getByRole('link', { name: d.ride.name, exact: true })).toHaveCount(0)
      },
    }),
  },
  teamPage: {
    roles: EVERYONE,
    sees: async (main, d) => {
      await heading(d.page.title)(main)
      await expect(main.getByText('Une page pour vérifier les écrans.')).toBeVisible()
    },
  },
  teamAdmin: {
    roles: [],
    sees: async () => {},
    // The admin area has no page of its own: TeamAdminPage opens its first tab.
    otherwise: redirects(ORGANIZERS, {
      why: 'the admin area opens on its ride templates tab',
      lands: (d) => `${teamPath(d)}/admin/modeles-sortie`,
      sees: (main, d, page) => rideTemplates(main, d, page),
    }),
    // TeamAdminPage's effect, not TeamAdminLayout: the area has no tab to render for them.
    denied: denies(BELOW_ORGANIZER, teamHome(NOT_ORGANIZER)),
    guards: teamAdminNav,
  },
  teamAdminPlaces: {
    roles: ORGANIZERS,
    sees: async (main, d, page) => {
      await currentTab(page, "Navigation de la gestion de l'équipe", 'Lieux')
      await expect(main.getByText(d.place.name)).toBeVisible()
    },
    denied: denies(BELOW_ORGANIZER, teamHome(NOT_ORGANIZER)),
    guards: teamAdminNav,
  },
  teamAdminTags: {
    roles: ADMINS,
    sees: async (main, _d, page) => {
      await currentTab(page, "Navigation de la gestion de l'équipe", 'Tags')
      await expect(
        main.getByText('Chaque type de contenu a ses propres tags.', { exact: false })
      ).toBeVisible()
    },
    // TeamTagsPage's own redirect (WEB-40): the vocabulary is the admins' alone.
    denied: denies(BELOW_ADMIN, teamHome(NOT_ADMIN)),
    guards: teamAdminNav,
  },
  teamAdminPages: {
    roles: ADMINS,
    sees: async (main, d, page) => {
      await currentTab(page, "Navigation de la gestion de l'équipe", 'Pages')
      await expect(main.getByText(d.page.title)).toBeVisible()
    },
    denied: denies(BELOW_ADMIN, teamHome(NOT_ADMIN)),
    guards: teamAdminNav,
  },
  teamAdminPageNew: {
    roles: ADMINS,
    sees: heading('Créer une page'),
    denied: denies(BELOW_ADMIN, teamHome(NOT_ADMIN)),
    guards: (page) => teamAdminNav(page).or(titled('Créer une page')(page)),
  },
  teamAdminPageEdit: {
    roles: ADMINS,
    sees: (main, d) => heading(`Modifier ${d.page.title}`)(main),
    denied: denies(BELOW_ADMIN, teamHome(NOT_ADMIN)),
    guards: (page, d) => teamAdminNav(page).or(titled(`Modifier ${d.page.title}`)(page)),
  },
  teamAdminMembers: {
    roles: ADMINS,
    sees: async (main, d, page) => {
      await currentTab(page, "Navigation de la gestion de l'équipe", 'Gestion des membres')
      await expect(main.getByText(d.sessions.member.user.displayName).first()).toBeVisible()
    },
    denied: denies(BELOW_ADMIN, teamHome(NOT_ADMIN)),
    guards: teamAdminNav,
  },
  teamAdminReports: {
    roles: ORGANIZERS,
    sees: async (main, _d, page) => {
      await currentTab(page, "Navigation de la gestion de l'équipe", 'Signalements')
      await heading('Aucun signalement en attente')(main)
    },
    // TeamAdminLayout lets a platform admin who is no organizer into this one tab; the others go.
    denied: denies(BELOW_ORGANIZER, teamHome(NOT_ORGANIZER)),
    guards: teamAdminNav,
  },
  teamSettings: {
    roles: ADMINS,
    sees: heading("Paramètres de l'équipe"),
    denied: denies(BELOW_ADMIN, teamHome(NOT_ADMIN)),
    guards: (page) => teamAdminNav(page).or(titled("Paramètres de l'équipe")(page)),
  },
  rideNew: {
    roles: ORGANIZERS,
    sees: heading('Créer une sortie'),
    denied: denies(BELOW_ORGANIZER, teamHome(NOT_ORGANIZER)),
    guards: titled('Créer une sortie'),
  },
  ride: { roles: EVERYONE, sees: (main, d) => heading(d.ride.name)(main) },
  rideGroup: { roles: EVERYONE, sees: heading('Groupe Groupe A') },
  // Groupe A has a route of its own (`otherRoute`), so its map draws instead of sending back.
  rideGroupMap: {
    roles: EVERYONE,
    bare: true,
    sees: fullscreenMap((d) => `${d.ride.name} · Groupe Groupe A`, pathTo('rideGroup')),
  },
  // A solo ride's map (WEB-118), on the dataset's ride of a single group: the shared `rideSlug`
  // names a ride of two groups, which has no such map — that redirect is tested on its own, below.
  rideMap: {
    roles: EVERYONE,
    bare: true,
    params: soloRideParams,
    sees: fullscreenMap((d) => d.soloRide.name, pathTo('ride', soloRideParams)),
  },
  rideEdit: {
    roles: ORGANIZERS,
    sees: heading('Modifier la sortie'),
    denied: denies(BELOW_ORGANIZER, {
      why: NOT_ORGANIZER,
      lands: pathTo('ride'),
      sees: (main, d) => heading(d.ride.name)(main),
    }),
    guards: titled('Modifier la sortie'),
  },
  rideTemplates: {
    roles: ORGANIZERS,
    sees: (main, d, page) => rideTemplates(main, d, page),
    denied: denies(BELOW_ORGANIZER, teamHome(NOT_ORGANIZER)),
    guards: teamAdminNav,
  },
  // The template pages send a refused role to the templates list, whose admin layout sends it on.
  rideTemplateNew: {
    roles: ORGANIZERS,
    sees: heading('Créer un modèle'),
    denied: denies(BELOW_ORGANIZER, teamHome(NOT_ORGANIZER)),
    guards: (page) => teamAdminNav(page).or(titled('Créer un modèle')(page)),
  },
  rideTemplateEdit: {
    roles: ORGANIZERS,
    sees: heading('Modifier le modèle'),
    // GET /ride-templates/{slug} answers 403 below organizer. Regression (d222e6ea): the server's
    // QueryClient keeps retryOnMount, so that failed loader renders pending on both sides — before,
    // the server rendered the error branch and hydration broke (#418).
    denied: denies(BELOW_ORGANIZER, teamHome(NOT_ORGANIZER)),
    guards: (page) => teamAdminNav(page).or(titled('Modifier le modèle')(page)),
  },
  tripNew: {
    roles: ORGANIZERS,
    sees: heading('Créer un voyage'),
    denied: denies(BELOW_ORGANIZER, teamHome(NOT_ORGANIZER)),
    guards: titled('Créer un voyage'),
  },
  trip: { roles: EVERYONE, sees: (main, d) => heading(d.trip.name)(main) },
  tripEdit: {
    roles: ORGANIZERS,
    sees: heading('Modifier le voyage'),
    denied: denies(BELOW_ORGANIZER, {
      why: NOT_ORGANIZER,
      lands: pathTo('trip'),
      sees: (main, d) => heading(d.trip.name)(main),
    }),
    guards: titled('Modifier le voyage'),
  },
  stage: {
    roles: EVERYONE,
    sees: async (main, d) => {
      await expect(main.getByRole('heading', { name: d.trip.stages[0].name }).first()).toBeVisible()
      await heading(d.route.name)(main)
    },
  },
  stageMap: {
    roles: EVERYONE,
    bare: true,
    sees: fullscreenMap(
      (d) => d.trip.stages[0].name,
      (d) => `${teamPath(d)}/voyages/${d.trip.slug}/etapes/${d.trip.stages[0].slug}`
    ),
  },
  postNew: {
    roles: ORGANIZERS,
    sees: heading('Nouvelle publication'),
    denied: denies(BELOW_ORGANIZER, teamHome(NOT_ORGANIZER)),
    guards: titled('Nouvelle publication'),
  },
  post: {
    roles: EVERYONE,
    sees: async (main, d) => {
      await heading(d.post.name)(main)
      await expect(main.getByText('Un article pour vérifier les écrans.')).toBeVisible()
    },
  },
  postEdit: {
    roles: ORGANIZERS,
    sees: heading('Modifier la publication'),
    denied: denies(BELOW_ORGANIZER, {
      why: NOT_ORGANIZER,
      lands: pathTo('post'),
      sees: (main, d) => heading(d.post.name)(main),
    }),
    guards: titled('Modifier la publication'),
  },
  routes: {
    roles: EVERYONE,
    sees: async (main, d) => {
      await expect(main.getByRole('radio', { name: 'Vignettes' })).toBeChecked()
      await expect(main.getByRole('link', { name: d.route.name }).first()).toBeVisible()
    },
  },
  routesMap: {
    roles: EVERYONE,
    sees: async (main) => {
      await expect(main.getByRole('radio', { name: 'Carte' })).toBeChecked()
      await expect(main.locator('canvas.maplibregl-canvas')).toBeVisible()
    },
  },
  routeNew: {
    roles: ORGANIZERS,
    sees: heading('Créer un nouveau parcours'),
    denied: denies(BELOW_ORGANIZER, routeList(NOT_ORGANIZER)),
    guards: titled('Créer un nouveau parcours'),
  },
  route: { roles: EVERYONE, sees: (main, d) => heading(d.route.name)(main) },
  routeMap: {
    roles: EVERYONE,
    bare: true,
    sees: fullscreenMap(
      (d) => d.route.name,
      (d) => `${teamPath(d)}/parcours/${d.route.slug}`
    ),
  },
  routeEdit: {
    roles: ORGANIZERS,
    sees: heading('Modifier le parcours'),
    denied: denies(BELOW_ORGANIZER, routeList(NOT_ORGANIZER)),
    guards: titled('Modifier le parcours'),
  },
  ads: {
    roles: MEMBERS,
    sees: async (main, d) => {
      await heading('Annonces')(main)
      await expect(main.getByRole('link', { name: d.ad.name }).first()).toBeVisible()
    },
    // No redirect: AdListPage keeps an outsider on the team's tab and says the ads are for its
    // members (AdAccessChecker LIST needs a team role). What matters is that no ad, nor the way to
    // post one, shows.
    denied: {
      outsider: { why: 'the ads are for the team members', sees: settledAdList },
    },
    guards: (page, d) =>
      page
        .getByRole('link', { name: d.ad.name })
        .or(page.getByRole('link', { name: 'Créer une annonce' })),
  },
  adNew: {
    roles: MEMBERS,
    sees: heading('Nouvelle annonce'),
    denied: denies(['outsider'], adList('any member of the team may post an ad, no one else')),
    guards: titled('Nouvelle annonce'),
  },
  ad: {
    roles: MEMBERS,
    sees: (main, d) => heading(d.ad.name)(main),
    denied: {
      outsider: {
        // Where CreateAdPage and EditAdPage send an outsider.
        ...adList('the ads are for the team members'),
      },
    },
    guards: (page, d) => titled(d.ad.name)(page),
  },
  // The ad belongs to the member; the team's admins may edit any ad.
  adEdit: {
    roles: ['member', ...ADMINS],
    sees: heading("Modifier l'annonce"),
    // An organizer is neither the author nor an admin: GET /ads/{slug}/edit answers 403
    // (AdAccessChecker UPDATE), and EditAdPage, left without an ad, falls back to the list.
    // An outsider meets the same 403, and an ads list that shows them nothing.
    // Regression (d222e6ea): both hydrate that 403 cleanly — see rideTemplateEdit.
    denied: {
      outsider: adList('only its author and the team admins edit an ad'),
      organizer: {
        why: 'only its author and the team admins edit an ad',
        lands: pathTo('ads'),
        sees: async (main, d) => {
          await heading('Annonces')(main)
          await expect(main.getByRole('link', { name: d.ad.name }).first()).toBeVisible()
        },
      },
    },
    guards: titled("Modifier l'annonce"),
  },
  admin: platformAdmin('Tableau de bord'),
  adminDomains: platformAdmin('Domaines'),
  adminTeams: platformAdmin('Équipes'),
  adminUsers: platformAdmin('Comptes'),
  adminReports: platformAdmin('Signalements'),
  adminMaintenance: platformAdmin('Maintenance'),
}

async function rideTemplates(main: Main, d: Dataset, page: Page) {
  await currentTab(page, "Navigation de la gestion de l'équipe", 'Modèles de sortie')
  await expect(main.getByText(d.template.name)).toBeVisible()
}

/** A platform administration tab: the platform admin's alone, AdminLayout sends anyone else home. */
function platformAdmin(tab: string): Screen {
  return {
    roles: ['platformAdmin'],
    sees: async (main, _d, page) => {
      await heading('Administration plateforme')(main)
      await currentTab(page, "Navigation de l'administration", tab)
    },
    denied: denies(NOT_PLATFORM_ADMIN, home('only the platform admin administers the platform')),
    guards: (page) => platformAdminNav(page).or(titled('Administration plateforme')(page)),
  }
}

const auth = configuredAuth()
const contract = contractWebRoutes()

let dataset: Promise<Dataset> | undefined
function data(): Promise<Dataset> {
  if (!dataset) {
    const building = buildDataset(`${process.pid}-${Date.now().toString(36)}`)
    dataset = building
    // A failed build is not cached: the next test tries again.
    building.catch(() => {
      if (dataset === building) dataset = undefined
    })
  }
  return dataset
}

test.beforeAll(async () => {
  test.setTimeout(120_000)
  await Promise.all([data(), ensureHammerheadOffered()])
})

// A worker may come back to this file after its afterAll (fully parallel): the next beforeAll then
// builds a dataset again rather than reuse the one whose platform admin was just demoted.
test.afterAll(async () => {
  const done = dataset
  dataset = undefined
  // A build that failed promoted nobody, or reported it already.
  const built = await done?.catch(() => undefined)
  if (built) await releaseDataset(built)
})

type Kind = 'renders' | 'redirects' | 'denied'

/**
 * The declarations of `role` on `route`: the guard's redirect from routes.config.ts, the page's own
 * redirect (`otherwise`), the screen itself (`roles`), the page's refusal (`denied`). Exactly one
 * is expected — see the coverage test.
 */
function declarations(route: ContractRoute, role: RenderRole) {
  const screen = screens[route.id]
  const requirement = auth.get(route.id)
  const found: { kind: Kind; source: string; outcome: Expectation & { why?: string } }[] = []
  if (requirement === 'authenticated' && role === 'anonymous')
    found.push({
      kind: 'redirects',
      source: 'auth: authenticated',
      outcome: {
        why: 'authenticated route',
        lands: () => '/connexion',
        sees: (main) =>
          expect(main.getByRole('button', { name: 'Se connecter', exact: true })).toBeVisible(),
      },
    })
  if (requirement === 'unauthenticated' && role !== 'anonymous')
    found.push({
      kind: 'redirects',
      source: 'auth: unauthenticated',
      outcome: {
        why: 'unauthenticated route',
        lands: () => '/',
        sees: heading('Dernières publications'),
      },
    })
  if (!screen) return found
  const otherwise = screen.otherwise?.[role]
  if (otherwise) found.push({ kind: 'redirects', source: 'otherwise', outcome: otherwise })
  if (screen.roles.includes(role)) found.push({ kind: 'renders', source: 'roles', outcome: screen })
  const denial = screen.denied?.[role]
  if (denial) found.push({ kind: 'denied', source: 'denied', outcome: denial })
  return found
}

test('the table covers every web route of the contract, and nothing else', () => {
  expect(Object.keys(screens).sort()).toEqual(contract.map((route) => route.id).sort())
  for (const route of contract)
    expect(auth.get(route.id), `routes.config.ts registers ${route.id}`).toBeDefined()
})

test('every (route, role) pair has exactly one outcome', () => {
  const undeclared: string[] = []
  const ambiguous: string[] = []
  for (const route of contract)
    for (const role of RENDER_ROLES) {
      const found = declarations(route, role)
      if (found.length === 0) undeclared.push(`${route.id} as ${role}`)
      if (found.length > 1)
        ambiguous.push(`${route.id} as ${role}: ${found.map((f) => f.source).join(' + ')}`)
    }
  expect(undeclared, 'pairs with no outcome: declare the screen, a redirect or a refusal').toEqual(
    []
  )
  expect(ambiguous, 'pairs declared twice').toEqual([])
  // A refusal is only worth its test if it checks the protected screen is gone.
  const unguarded = Object.entries(screens)
    .filter(([, screen]) => screen.denied && !screen.guards)
    .map(([id]) => id)
  expect(unguarded, 'screens that refuse a role without saying what they protect').toEqual([])
})

for (const route of contract) {
  const screen = screens[route.id]
  if (!screen) continue

  for (const role of RENDER_ROLES) {
    const found = declarations(route, role)
    // The coverage test above names the pair; no test to run for it.
    if (found.length !== 1) continue
    const [{ kind, outcome }] = found
    const expected: Expectation & { why?: string; defect?: string } = outcome

    const title =
      kind === 'renders'
        ? `${route.id} ${route.path} as ${role}: renders`
        : kind === 'denied'
          ? `${route.id} ${route.path} as ${role}: denied, ${expected.why}`
          : `${route.id} ${route.path} as ${role}: ${expected.why}, redirects`

    test(title, async ({ page }) => {
      test.fail(!!expected.defect, expected.defect)
      const d = await data()
      const path = fillPath(route, screen.params?.(d) ?? d.params)
      const where = `${route.id} as ${role} (${path})`

      const { pageErrors, hydrationErrors } = await watchHydration(page)
      const prefetchAudit = watchPrefetchAudit(page)
      if (role !== 'anonymous') await signIn(page.context(), d.sessions[role])

      const response = await page.goto(path)
      expect(response?.status(), `${where}: document status`).toBe(200)
      await pageHydrated(page)

      const lands = expected.lands?.(d) ?? path
      await expect
        // A page-level redirect waits for the team read, which a loaded stack can make slow.
        .poll(() => new URL(page.url()).pathname, {
          message: `${where}: lands on ${lands}`,
          timeout: 15_000,
        })
        .toBe(lands)

      const main = screen.bare && !expected.lands ? page.locator('body') : page.getByRole('main')
      const sees = (kind === 'renders' && screen.seesAs?.[role]) || expected.sees
      await sees(main, d, page)

      // The page is up: now the absences mean something.
      for (const failure of [
        page.getByText('Une erreur est survenue'),
        page.getByText('Chargement impossible'),
        page.getByRole('heading', { name: 'Introuvable' }),
        page.getByRole('heading', { name: '404', exact: true }),
      ])
        await expect(failure, `${where}: no error screen`).toHaveCount(0)
      if (kind === 'denied')
        await expect(
          screen.guards!(page, d),
          `${where}: nothing of the protected screen`
        ).toHaveCount(0)
      expect(pageErrors, `${where}: uncaught errors`).toEqual([])

      // The edit and create forms (a DateTimePicker hydrated in the SSR server's zone, a default
      // date computed in the process's zone), the platform dashboard's counts and the paginated
      // lists on a phone used to fail hydration (fixed 2026-09-25). The browser runs in
      // Europe/Paris and the SSR server in UTC, so a zone-dependent render shows up here.
      expect(hydrationErrors, `${where}: hydration errors`).toEqual([])

      // Only on the screen's own path: a redirect, or a refusal's fallback, is not the screen
      // whose prefetch is declared. The audit disarms on a redirect anyway (`discarded`).
      if (kind === 'renders' && !expected.lands) {
        const audit = await prefetchAudit.result()
        expect(audit.verdict, `${where}: prefetch — ${audit.text}`).toBe('covered')
      }
    })
  }
}

/**
 * The other half of `rideMap`'s contract: a ride with several groups has no map of its own, and its
 * loader (`rideMapDataRedirect`) sends the visitor to the ride's page, server side.
 */
test('rideMap of a ride with several groups: redirects to the ride', async ({ page }) => {
  const d = await data()
  const { pageErrors, hydrationErrors } = await watchHydration(page)
  const response = await page.goto(pathTo('rideMap')(d))
  expect(response?.status()).toBe(200)
  await pageHydrated(page)
  await expect.poll(() => new URL(page.url()).pathname, { timeout: 15_000 }).toBe(pathTo('ride')(d))
  await heading(d.ride.name)(page.getByRole('main'))
  expect(pageErrors).toEqual([])
  expect(hydrationErrors).toEqual([])
})

/**
 * The English paths of the contract. The router registers every locale's path whatever the
 * interface language (RouteGenerator.tsx), so a link shared from an English interface opens in a
 * French one: the document answers 200, in French, and the page then replaces the address with its
 * French path (useCanonicalPath). The other way round, an interface in English writes English links.
 */
test.describe('English paths', () => {
  // A sample: team-scoped screens of every kind, public ones as an anonymous visitor, an admin
  // screen as the team's admin.
  const teamScoped: { id: string; role: RenderRole }[] = [
    { id: 'team', role: 'anonymous' },
    { id: 'teamAbout', role: 'anonymous' },
    { id: 'routes', role: 'anonymous' },
    { id: 'route', role: 'anonymous' },
    { id: 'ride', role: 'anonymous' },
    { id: 'post', role: 'anonymous' },
    { id: 'stage', role: 'anonymous' },
    { id: 'ads', role: 'member' },
    { id: 'teamSettings', role: 'teamAdmin' },
  ]
  for (const { id, role } of teamScoped)
    test(`${id} under its English path, in a French interface, as ${role}: 200, then its French path`, async ({
      page,
    }) => {
      await expectCanonicalFrench(page, id, role)
    })

  // The global screens are registered under their English paths too, but only the pages calling
  // useCanonicalPath (the team-scoped ones, and the GPX map) replace the address: /teams, /routes,
  // /apps, /login, /profile… keep the English path under a French interface. Decided on 2026-09-28
  // not to redirect them (not worth a Layout-wide canonicalisation): the page must only serve, in
  // French, without an error. For crawlers the server's canonical and og:url name the French path
  // (lib/seo.ts buildCanonicalUrl), which folds the two variants into one.
  const global: { id: string; role: RenderRole }[] = [
    { id: 'teams', role: 'anonymous' },
    { id: 'allRoutes', role: 'anonymous' },
    { id: 'apps', role: 'anonymous' },
    { id: 'login', role: 'anonymous' },
    { id: 'profile', role: 'member' },
  ]
  for (const { id, role } of global)
    test(`${id} under its English path, in a French interface, as ${role}: 200, in French (global screen, kept English)`, async ({
      page,
    }) => {
      await expectServedInFrench(page, id, role)
    })

  test('in English, the team page and its tabs use the English paths', async ({ browser }) => {
    const d = await data()
    const { context, page } = await pageAs(browser, undefined)
    try {
      // The language a visitor picked (LanguageSwitcher's cookie), which the server reads first.
      await context.addCookies([{ name: 'lang', value: 'en', url: stack.baseURL }])
      const { pageErrors, hydrationErrors } = await watchHydration(page)

      // The French link a member shared: the page switches it to English.
      const response = await page.goto(`/equipes/${d.team.slug}`)
      expect(response?.status()).toBe(200)
      await pageHydrated(page)
      await expect(page.locator('html')).toHaveAttribute('lang', 'en')
      await expect(page.getByRole('heading', { level: 1, name: d.team.name })).toBeVisible()
      await expect
        .poll(() => new URL(page.url()).pathname, { timeout: 15_000 })
        .toBe(`/teams/${d.team.slug}`)

      const tabs = page.getByRole('navigation', { name: 'Team navigation' }).getByRole('link')
      await expect(tabs.first()).toBeVisible()
      const hrefs = await tabs.evaluateAll((links) => links.map((l) => l.getAttribute('href')))
      const english = ['team', 'teamAbout', 'routes', 'teamCalendar', 'ads']
        .map((id) => englishPath(id, d.params))
        // The calendar and the ads are the members'; an anonymous visitor has neither tab.
        .filter((path) => !/\/(calendar|classifieds)$/.test(path))
      expect(hrefs).toEqual(expect.arrayContaining(english))
      for (const href of hrefs)
        expect(href, 'every tab is an English path').toMatch(
          new RegExp(`^/teams/${d.team.slug}(/|$)`)
        )

      // And following one stays in English.
      await tabs.filter({ hasText: 'About' }).first().click()
      await expect(page).toHaveURL(new RegExp(`${englishPath('teamAbout', d.params)}$`))
      expect(pageErrors).toEqual([])
      expect(hydrationErrors).toEqual([])
    } finally {
      await context.close()
    }
  })
})

/**
 * Opens route `id` under its English path in a French interface as `role`: a 200 document, in
 * French, showing its screen, hydrated without an error.
 */
async function expectServedInFrench(page: Page, id: string, role: RenderRole) {
  const d = await data()
  const english = englishPath(id, d.params)
  const { pageErrors, hydrationErrors } = await watchHydration(page)
  if (role !== 'anonymous') await signIn(page.context(), d.sessions[role])

  const response = await page.goto(english)
  expect(response?.status(), `${english}: document status`).toBe(200)
  await pageHydrated(page)
  await expect(page.locator('html')).toHaveAttribute('lang', 'fr')
  // The same screen as under its French path: what the table says only that screen shows.
  const screen = screens[id]
  await screen.sees(screen.bare ? page.locator('body') : page.getByRole('main'), d, page)
  expect(pageErrors, `${english}: uncaught errors`).toEqual([])
  expect(hydrationErrors, `${english}: hydration errors`).toEqual([])
}

/**
 * Opens route `id` under its English path in a French interface as `role`: a 200 document, in
 * French, then the French path in the address bar.
 */
async function expectCanonicalFrench(page: Page, id: string, role: RenderRole, timeout = 15_000) {
  const d = await data()
  const route = contract.find((candidate) => candidate.id === id)
  if (!route) throw new Error(`no web route ${id} in the contract`)
  const english = englishPath(id, d.params)
  const french = fillPath(route, d.params)
  expect(english, `precondition: ${id} has an English path of its own`).not.toBe(french)
  const { pageErrors, hydrationErrors } = await watchHydration(page)
  if (role !== 'anonymous') await signIn(page.context(), d.sessions[role])

  const response = await page.goto(english)
  expect(response?.status(), `${english}: document status`).toBe(200)
  await pageHydrated(page)
  await expect(page.locator('html')).toHaveAttribute('lang', 'fr')
  await expect
    .poll(() => new URL(page.url()).pathname, {
      message: `${english} is replaced by ${french}`,
      timeout,
    })
    .toBe(french)
  expect(pageErrors, `${english}: uncaught errors`).toEqual([])
  expect(hydrationErrors, `${english}: hydration errors`).toEqual([])
}
