import { pages } from './pageComponents'
import type { RoutesConfig, RouteParams } from './routes.types'
import { pathVariants } from './paths'
import { tRegister } from '@/lib/i18nUtils'
import { prefetchGetTeamQuery } from '@/api/endpoints/teams/teams'
import { prefetchTeamSwitcher } from '@/components/team/teamSwitcherData'
import {
  prefetchRideDetail,
  prefetchRideMap,
  rideMapDataRedirect,
} from '@/pages/ride/rideDetailData'
import {
  prefetchRideGroup,
  prefetchRideGroupMap,
  rideGroupDataRedirect,
  rideGroupMapDataRedirect,
} from '@/pages/ride/rideGroupData'
import { prefetchRouteList } from '@/pages/route/routeListData'
import { prefetchTripDetail } from '@/pages/trip/tripDetailData'
import { prefetchStageDetail } from '@/pages/trip/stageDetailData'
import { prefetchPostDetail } from '@/pages/post/postDetailData'
import { prefetchRouteDetail, prefetchRouteMap } from '@/pages/route/routeDetailData'
import {
  prefetchBlockedUsers,
  prefetchProfileDevices,
  prefetchProfileNotifications,
  prefetchProfileOverview,
  prefetchProfilePrivacy,
  prefetchProfileSecurity,
} from '@/pages/profile/profileData'
import { prefetchCalendar } from '@/pages/calendar/calendarData'
import { prefetchGpxPreview, prefetchGpxPreviewView } from '@/pages/gpxtool/gpxPreviewData'
import { prefetchGpxPreviewList } from '@/pages/gpxtool/gpxPreviewListData'
import { prefetchGpxPreviewForm } from '@/pages/gpxtool/gpxPreviewFormData'
import { prefetchTeamCalendar } from '@/pages/calendar/teamCalendarData'
import { prefetchRoutesMap } from '@/pages/route/routesMapData'
import { prefetchStageMap } from '@/pages/trip/stageMapData'
import { prefetchTeamForm } from '@/pages/team/teamFormData'
import { prefetchDeviceVerify } from '@/pages/device/deviceVerifyData'
import {
  prefetchCreateRideTemplateForm,
  prefetchEditRideTemplateForm,
} from '@/pages/ridetemplate/rideTemplateFormData'
import { prefetchAdminDashboard } from '@/pages/admin/adminDashboardData'
import { prefetchAdminDomains } from '@/pages/admin/adminDomainsData'
import { prefetchAdminTeams } from '@/pages/admin/adminTeamsData'
import { prefetchAdminUsers } from '@/pages/admin/adminUsersData'
import { prefetchAdminBetaSignups } from '@/pages/admin/adminBetaSignupsData'
import { prefetchAdminMaintenance } from '@/pages/admin/adminMaintenanceData'
import { prefetchAdminReports } from '@/pages/admin/adminReportsData'
import { prefetchTeamAbout } from '@/pages/team/teamAboutData'
import { prefetchTeamPage } from '@/pages/team/teamPageData'
import { prefetchTeamPagesAdmin } from '@/pages/team/teamPagesAdminData'
import { prefetchEditTeamPageForm } from '@/pages/team/teamPageFormData'
import { prefetchCreateTripForm, prefetchEditTripForm } from '@/pages/trip/tripFormData'
import { prefetchCreatePostForm, prefetchEditPostForm } from '@/pages/post/postFormData'
import { prefetchCreateRouteForm, prefetchEditRouteForm } from '@/pages/route/routeFormData'
import { prefetchAdDetail } from '@/pages/ad/adDetailData'
import { prefetchCreateAdForm, prefetchEditAdForm } from '@/pages/ad/adFormData'
import { prefetchTeamSettings } from '@/pages/team/teamSettingsData'
import { prefetchNotificationList } from '@/pages/notification/notificationListData'
import { prefetchTeamPlaces } from '@/pages/team/teamPlacesData'
import { prefetchTeamTagsAdmin } from '@/pages/team/teamTagsData'
import { prefetchTeamDirectory, prefetchTeamMembers } from '@/pages/team/teamMembersData'
import { prefetchTeamReports } from '@/pages/team/teamReportsData'
import { prefetchRideTemplateList } from '@/pages/ridetemplate/rideTemplateListData'
import { prefetchCreateRideForm, prefetchEditRideForm } from '@/pages/ride/rideFormData'
import { prefetchHomeFeed } from '@/pages/home/homeFeedData'
import { prefetchTeamList } from '@/pages/team/teamListData'
import { prefetchTeamHome } from '@/pages/team/teamHomeData'
import { prefetchTeamAgenda } from '@/pages/team/teamAgendaData'
import { prefetchTeamPosts } from '@/pages/team/teamPostsData'
import {
  teamHomeRedirect,
  teamRidesRedirect,
  teamTripsRedirect,
} from '@/pages/team/teamLegacyRedirects'
import { prefetchAdList } from '@/pages/ad/adListData'
import { prefetchAllRouteList, prefetchAllRoutesMap } from '@/pages/route/allRouteListData'
import {
  homeMeta,
  teamsMeta,
  teamDetailMeta,
  teamAboutMeta,
  teamPageMeta,
  rideMeta,
  rideGroupMeta,
  tripMeta,
  stageMeta,
  postMeta,
  routeMeta,
  gpxBlankMapMeta,
  gpxPreviewMeta,
  appsMeta,
  featuresMeta,
} from './routeMeta'
import { useAuthStore } from '@/store/authStore'
import type { QueryClient } from '@tanstack/react-query'

/**
 * `prefetch` for an authenticated, team-scoped screen — every form and admin page under
 * `/teams/{slug}/…`.
 *
 * They all render the team's name (breadcrumb, layout header) yet none of them used to prefetch
 * it, so `GET /api/teams/{slug}` was the single most repeated prefetch gap found: ~20 routes
 * fetching the same already-cacheable object after the first paint. `extra` adds whatever else the
 * page reads — pass the same `prefetchXxxQuery` its read-only sibling route uses, so the query key
 * matches by construction rather than by hand-copying params.
 *
 * Skipped entirely for an anonymous request: these routes render a redirect, not a page, so the
 * fetch would be wasted (and the API call pointless) before the guard sends the visitor away.
 */
function teamScopedPrefetch(
  extra?: (queryClient: QueryClient, params: RouteParams, url: URL) => Promise<unknown>
): (queryClient: QueryClient, params: RouteParams, url: URL) => Promise<void> {
  return async (queryClient, params, url) => {
    if (!useAuthStore.getState().isAuthenticated) return
    await Promise.all([
      prefetchGetTeamQuery(queryClient, params.teamSlug!),
      extra ? extra(queryClient, params, url) : Promise.resolve(),
    ])
  }
}

/**
 * A route that mounts `TeamLayout` adds the team switcher's listing to its own data
 * (docs/LEDGER_*.md WEB-111) — the same on every such route, so it is not repeated in each page's
 * companion module.
 */
async function withTeamSwitcher(queryClient: QueryClient, page: Promise<unknown>): Promise<void> {
  await Promise.all([page, prefetchTeamSwitcher(queryClient)])
}

export const routesConfig: RoutesConfig = [
  // === Home ===
  {
    id: 'home',
    paths: pathVariants.home(),
    component: pages.HomePage,
    auth: 'public',
    parentId: null,
    index: true,
    navGroup: 'home',
    breadcrumb: { type: 'static', i18nKey: tRegister('home.tabs.feed') },
    // Resolves the feed the URL actually asks for, filters and page included, the same way
    // HomePage does: the membership probe of `useMembershipDefault` feeds the schema's default,
    // the query string overrides it, and `publicationApiParams` projects the result.
    prefetch: (queryClient, _params, url) => prefetchHomeFeed(queryClient, url),
    meta: homeMeta,
  },
  {
    id: 'all-routes',
    paths: pathVariants.allRoutes(),
    component: pages.AllRoutesPage,
    auth: 'public',
    // Not indexed: routes are a map and a GPX rather than a text to index, which is why they are
    // left out of the sitemap (docs/LEDGER_*.md WEB-31) — and this catalogue lists nothing else,
    // under as many URLs as there are filter combinations.
    noindex: true,
    parentId: null,
    navGroup: 'home',
    breadcrumb: { type: 'static', i18nKey: tRegister('nav.explore') },
    // Matches AllRoutesPage's initial useListAllRoutes key when no URL filters are set. Signed
    // in, the list's `minRole` depends on team membership (see useMembershipDefault) —
    // replicated here so the resolved variant, not a guess, lands in the cache (same pattern as
    // the `home` and `teams` routes).
    prefetch: (queryClient, _params, url) => prefetchAllRouteList(queryClient, url),
  },
  {
    id: 'all-routes-map',
    paths: pathVariants.allRoutesMap(),
    component: pages.AllRoutesMapPage,
    auth: 'public',
    // Not indexed, like `all-routes`: a map page (docs/LEDGER_*.md WEB-31).
    noindex: true,
    parentId: 'all-routes',
    navGroup: 'home',
    breadcrumb: { type: 'static', i18nKey: tRegister('routes.view.map') },
    // Matches AllRoutesMapPage's initial useGetAllRoutesBounds key when no URL filters are set —
    // same minRole resolution as `all-routes` above.
    prefetch: (queryClient, _params, url) => prefetchAllRoutesMap(queryClient, url),
  },

  // === GPX Tools Routes ===
  {
    id: 'gpx-tools',
    paths: pathVariants.gpxTools(),
    component: pages.GpxToolsPage,
    auth: 'authenticated',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('gpxTools.title') },
  },
  {
    id: 'gpx-tools-list',
    paths: pathVariants.gpxToolsList(),
    component: pages.MyGpxPreviewsPage,
    auth: 'authenticated',
    parentId: 'gpx-tools',
    breadcrumb: { type: 'static', i18nKey: tRegister('gpxTools.listFiles.title') },
    prefetch: (queryClient, _params, url) => prefetchGpxPreviewList(queryClient, url),
  },
  {
    id: 'gpx-tools-new',
    paths: pathVariants.gpxToolsNew(),
    component: pages.CreateGpxPreviewPage,
    auth: 'authenticated',
    parentId: 'gpx-tools',
    breadcrumb: { type: 'static', i18nKey: tRegister('gpxTools.createFromScratch.title') },
  },
  {
    id: 'gpx-tools-blank-map',
    paths: pathVariants.gpxToolsBlankMap(),
    component: pages.GpxBlankMapPage,
    // A map with nothing on it reads only /api/config: anyone may open it, signed in or not.
    auth: 'public',
    // Nothing to index — an empty map is the same page on every domain.
    noindex: true,
    layout: 'bare',
    parentId: 'gpx-tools',
    breadcrumb: { type: 'static', i18nKey: tRegister('gpxTools.blankMap.pageTitle') },
    meta: gpxBlankMapMeta,
  },
  {
    id: 'gpx-tools-view',
    paths: pathVariants.gpxToolsView(':previewId'),
    component: pages.GpxPreviewPage,
    // The link is shareable: holding the unguessable id is enough to view it.
    auth: 'public',
    // Not indexed: a member's own file, shown to whoever holds the link — like unlisted content
    // (docs/LEDGER_*.md WEB-4).
    noindex: true,
    parentId: 'gpx-tools',
    breadcrumb: { type: 'static', i18nKey: tRegister('gpxTools.preview.title') },
    // Public/anonymous endpoint — prefetches fine under stateless SSR, and feeds gpxPreviewMeta.
    prefetch: (queryClient, params) => prefetchGpxPreviewView(queryClient, params.previewId!),
    meta: gpxPreviewMeta,
  },
  {
    id: 'gpx-tools-map',
    paths: pathVariants.gpxToolsMap(':previewId'),
    component: pages.GpxPreviewFullscreenMapPage,
    // The link is shareable: holding the unguessable id is enough to view it.
    auth: 'public',
    // Not indexed: a member's own file, shown to whoever holds the link — like unlisted content
    // (docs/LEDGER_*.md WEB-4).
    noindex: true,
    layout: 'bare',
    parentId: 'gpx-tools-view',
    breadcrumb: { type: 'static', i18nKey: tRegister('map.fullscreen.title') },
    // Public/anonymous endpoint — prefetches fine under stateless SSR, and feeds gpxPreviewMeta.
    prefetch: (queryClient, params) => prefetchGpxPreview(queryClient, params.previewId!),
    meta: gpxPreviewMeta,
  },
  {
    id: 'gpx-tools-edit',
    paths: pathVariants.gpxToolsEdit(':previewId'),
    component: pages.EditGpxPreviewPage,
    // Editing is owner-only; the page itself redirects non-owners to the read view.
    auth: 'authenticated',
    parentId: 'gpx-tools-view',
    breadcrumb: { type: 'static', i18nKey: tRegister('gpxTools.edit.title') },
    prefetch: (queryClient, params) => prefetchGpxPreviewForm(queryClient, params.previewId!),
  },

  // === Apps ===
  {
    id: 'apps',
    paths: pathVariants.apps(),
    component: pages.AppsPage,
    auth: 'public',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('apps.title') },
    meta: appsMeta,
  },

  // === Features (static presentation of the product, no prefetch: no API call) ===
  {
    id: 'features',
    paths: pathVariants.features(),
    component: pages.FeaturesPage,
    auth: 'public',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('nav.features') },
    meta: featuresMeta,
  },

  // === Legal Routes ===
  {
    id: 'privacy',
    paths: pathVariants.privacy(),
    component: pages.PrivacyPolicyPage,
    auth: 'public',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('legal.privacy.title') },
  },
  {
    id: 'terms',
    paths: pathVariants.terms(),
    component: pages.TermsOfServicePage,
    auth: 'public',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('legal.terms.title') },
  },
  {
    id: 'support',
    paths: pathVariants.support(),
    component: pages.SupportPage,
    auth: 'public',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('legal.support.title') },
  },

  // === Auth Routes ===
  {
    id: 'login',
    paths: pathVariants.login(),
    component: pages.LoginPage,
    auth: 'unauthenticated',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('auth.login.title') },
  },
  {
    id: 'device-verify-garmin',
    paths: pathVariants.deviceVerifyGarmin(),
    component: pages.DeviceVerifyPage,
    auth: 'authenticated',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('device.title') },
    prefetch: (queryClient) => prefetchDeviceVerify(queryClient),
  },
  {
    id: 'device-verify-karoo',
    paths: pathVariants.deviceVerifyKaroo(),
    component: pages.DeviceVerifyPage,
    auth: 'authenticated',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('device.title') },
    prefetch: (queryClient) => prefetchDeviceVerify(queryClient),
  },
  {
    // The Hammerhead step of a Karoo pairing alone (docs/LEDGER_*.md API-63).
    id: 'device-hammerhead',
    paths: pathVariants.deviceHammerhead(),
    component: pages.DeviceVerifyPage,
    auth: 'authenticated',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('device.title') },
    prefetch: (queryClient) => prefetchDeviceVerify(queryClient),
  },
  {
    id: 'verify-email',
    paths: pathVariants.verifyEmail(),
    component: pages.VerifyEmailPage,
    auth: 'public',
    // Not indexed: transactional, opened from a link carrying its token in the query string.
    noindex: true,
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('auth.verifyEmail.title') },
  },
  {
    // Public, not authenticated: the page has to be able to say who is inviting and to what before
    // anyone signs in, or a signed-out invitee lands on a bare login form with no explanation.
    id: 'invitation',
    paths: pathVariants.invitation(),
    component: pages.AcceptInvitationPage,
    auth: 'public',
    // Not indexed: transactional, opened from a link carrying its token in the query string.
    noindex: true,
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('invitations.accept.pageTitle') },
  },
  {
    // Public for the same reason as `invitation`: a signed-out admin arriving from biketeam must see
    // what is being moved before signing in. The signed request in ?request= is not a credential;
    // confirming needs a session. See docs/plans/2026-09-22-biketeam-live-migration.md §4.3.
    id: 'biketeam-migration',
    paths: pathVariants.biketeamMigration(),
    component: pages.BiketeamMigrationPage,
    auth: 'public',
    // Not indexed: transactional, opened from a link carrying its token in the query string.
    noindex: true,
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('biketeamMigration.pageTitle') },
  },
  {
    id: 'forgot-password',
    paths: pathVariants.forgotPassword(),
    component: pages.ForgotPasswordPage,
    auth: 'unauthenticated',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('auth.forgotPassword.title') },
  },
  {
    id: 'reset-password',
    paths: pathVariants.resetPassword(),
    component: pages.ResetPasswordPage,
    auth: 'public',
    // Not indexed: transactional, opened from a link carrying its token in the query string.
    noindex: true,
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('auth.resetPassword.title') },
  },
  // === Profile: the overview, then one page per subject (contracts/routes.yaml) ===
  {
    id: 'profile',
    paths: pathVariants.profile(),
    component: pages.ProfileOverviewPage,
    auth: 'authenticated',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('nav.profile') },
    // `/me` is seeded by the server with the session; the summary carries every state line.
    prefetch: (queryClient) => prefetchProfileOverview(queryClient),
  },
  {
    id: 'profile-preferences',
    paths: pathVariants.profilePreferences(),
    component: pages.ProfilePreferencesPage,
    auth: 'authenticated',
    parentId: 'profile',
    breadcrumb: { type: 'static', i18nKey: tRegister('profile.nav.preferences') },
    // Reads `/me` only, which the server seeds.
  },
  {
    id: 'profile-notifications',
    paths: pathVariants.profileNotifications(),
    component: pages.ProfileNotificationsPage,
    auth: 'authenticated',
    parentId: 'profile',
    breadcrumb: { type: 'static', i18nKey: tRegister('profile.nav.notifications') },
    prefetch: (queryClient) => prefetchProfileNotifications(queryClient),
  },
  {
    id: 'profile-devices',
    paths: pathVariants.profileDevices(),
    component: pages.ProfileDevicesPage,
    auth: 'authenticated',
    parentId: 'profile',
    breadcrumb: { type: 'static', i18nKey: tRegister('profile.nav.devices') },
    prefetch: (queryClient) => prefetchProfileDevices(queryClient),
  },
  {
    id: 'profile-security',
    paths: pathVariants.profileSecurity(),
    component: pages.ProfileSecurityPage,
    auth: 'authenticated',
    parentId: 'profile',
    breadcrumb: { type: 'static', i18nKey: tRegister('profile.nav.security') },
    prefetch: (queryClient) => prefetchProfileSecurity(queryClient),
  },
  {
    id: 'profile-privacy',
    paths: pathVariants.profilePrivacy(),
    component: pages.ProfilePrivacyPage,
    auth: 'authenticated',
    parentId: 'profile',
    breadcrumb: { type: 'static', i18nKey: tRegister('profile.nav.privacy') },
    prefetch: (queryClient) => prefetchProfilePrivacy(queryClient),
  },
  {
    id: 'blocked-users',
    paths: pathVariants.blockedUsers(),
    component: pages.BlockedUsersPage,
    auth: 'authenticated',
    parentId: 'profile-privacy',
    breadcrumb: { type: 'static', i18nKey: tRegister('profile.blockedUsers.title') },
    prefetch: (queryClient) => prefetchBlockedUsers(queryClient),
  },
  {
    id: 'profile-account',
    paths: pathVariants.profileAccount(),
    component: pages.ProfileAccountPage,
    auth: 'authenticated',
    parentId: 'profile',
    breadcrumb: { type: 'static', i18nKey: tRegister('profile.nav.account') },
    // Reads `/me` only; the deletion impact is read when its confirmation opens.
  },
  {
    id: 'profile-help',
    paths: pathVariants.profileHelp(),
    component: pages.ProfileHelpPage,
    auth: 'authenticated',
    parentId: 'profile',
    breadcrumb: { type: 'static', i18nKey: tRegister('profile.nav.help') },
    // The version is the footer's, which the server prefetches for every document.
  },
  {
    id: 'notifications',
    paths: pathVariants.notifications(),
    component: pages.NotificationListPage,
    auth: 'authenticated',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('notifications.title') },
    prefetch: (queryClient, _params, url) => prefetchNotificationList(queryClient, url),
  },
  {
    id: 'calendar',
    paths: pathVariants.calendar(),
    component: pages.CalendarPage,
    auth: 'authenticated',
    parentId: null,
    navGroup: 'home',
    breadcrumb: { type: 'static', i18nKey: tRegister('calendar.title') },
    // CalendarPage's first events query, keyed on the same `getInitialCalendarRange()` the hook
    // seeds its state with. The window is wider than any single view on purpose, so the visible
    // grid `CalendarView` reports on mount — and every step within six months — is served from it.
    prefetch: (queryClient) => prefetchCalendar(queryClient),
  },

  // === Team Routes ===
  {
    id: 'teams',
    paths: pathVariants.teams(),
    component: pages.TeamListPage,
    auth: 'public',
    parentId: null,
    navGroup: 'home',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.title') },
    hideWhenSingleTeam: true,
    // Matches TeamListPage's initial useListTeams key when no URL filters are set (search
    // undefined, page 0). Signed in, the list's `minRole` depends on team membership (see
    // useMembershipDefault) — replicated here so the resolved variant, not a guess, lands in the
    // cache. Without this, a signed-in visitor's real first query misses the SSR cache and
    // refetches after hydration (member: wrong shape cached; non-member: the optimistic
    // "member" default used while the probe is loading fires one fetch, then correcting to
    // "all" fires a second) — hydrating with the resolved probe result upfront skips that
    // optimistic guess entirely.
    prefetch: (queryClient, _params, url) => prefetchTeamList(queryClient, url),
    meta: teamsMeta,
  },
  {
    id: 'teams-new',
    paths: pathVariants.teamsNew(),
    component: pages.CreateTeamPage,
    auth: 'authenticated',
    parentId: 'teams',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.create.title') },
    prefetch: (queryClient) => prefetchTeamForm(queryClient),
    showBackLink: true,
    hideWhenSingleTeam: true,
  },
  {
    id: 'team-detail',
    paths: pathVariants.team(':teamSlug'),
    component: pages.TeamHomePage,
    auth: 'public',
    parentId: 'teams',
    navGroup: 'team',
    breadcrumb: { type: 'dynamic', entity: 'team' },
    // The dashboard, for everyone (API-86): a member gets their own blocks on top of the public
    // part — see pages/team/teamHomeData.ts. The former feed's addresses (`?tab=publications`, a
    // visitor's `?type=…`) lead to the agenda or the posts (ledger WEB-68).
    redirect: (params, url) => teamHomeRedirect(params.teamSlug!, url.searchParams),
    prefetch: (queryClient, params) =>
      withTeamSwitcher(queryClient, prefetchTeamHome(queryClient, params.teamSlug!)),
    meta: teamDetailMeta,
  },
  // « Agenda » — the team's rides and trips, upcoming first — and « Publications », its posts,
  // newest first (ledger WEB-68, plan docs/plans/archive/2026-10-06-team-agenda.md). A ride's and a trip's
  // page hang under the agenda, a post's under the posts.
  {
    id: 'team-agenda',
    paths: pathVariants.teamAgenda(':teamSlug'),
    component: pages.TeamAgendaPage,
    auth: 'public',
    parentId: 'team-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.detail.tabs.agenda') },
    prefetch: (queryClient, params, url) =>
      withTeamSwitcher(queryClient, prefetchTeamAgenda(queryClient, params.teamSlug!, url)),
  },
  {
    id: 'team-posts',
    paths: pathVariants.teamPosts(':teamSlug'),
    component: pages.TeamPostsPage,
    auth: 'public',
    parentId: 'team-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.detail.tabs.posts') },
    prefetch: (queryClient, params, url) =>
      withTeamSwitcher(queryClient, prefetchTeamPosts(queryClient, params.teamSlug!, url)),
  },
  // The former « Sorties » and « Voyages » tabs (WEB-64), kept for the links already out there:
  // their loader redirects to the agenda, so the page never renders.
  {
    id: 'team-rides',
    paths: pathVariants.teamRides(':teamSlug'),
    component: pages.TeamAgendaPage,
    auth: 'public',
    parentId: 'team-detail',
    redirect: (params, url) => teamRidesRedirect(params.teamSlug!, url.searchParams),
  },
  {
    id: 'team-trips',
    paths: pathVariants.teamTrips(':teamSlug'),
    component: pages.TeamAgendaPage,
    auth: 'public',
    parentId: 'team-detail',
    redirect: (params, url) => teamTripsRedirect(params.teamSlug!, url.searchParams),
  },
  {
    id: 'team-about',
    paths: pathVariants.teamAbout(':teamSlug'),
    component: pages.TeamAboutPage,
    auth: 'public',
    parentId: 'team-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.detail.tabs.about') },
    prefetch: (queryClient, params) =>
      withTeamSwitcher(queryClient, prefetchTeamAbout(queryClient, params.teamSlug!)),
    meta: teamAboutMeta,
  },
  {
    // The members' own directory (docs/LEDGER_*.md WEB-1); `team-members` is the admin screen.
    // Signed-in only: the server lets an organiser, or a member of a team that opened its
    // directory, read it (API-39), and the page shows its 403 to anyone else.
    id: 'team-directory',
    paths: pathVariants.teamMembers(':teamSlug'),
    component: pages.TeamDirectoryPage,
    auth: 'authenticated',
    // A team section of its own (WEB-112): the team is its parent, like the row's other tabs.
    parentId: 'team-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.detail.members.title') },
    prefetch: teamScopedPrefetch((qc, p, url) =>
      withTeamSwitcher(qc, prefetchTeamDirectory(qc, p.teamSlug!, url))
    ),
  },
  {
    id: 'team-calendar',
    paths: pathVariants.teamCalendar(':teamSlug'),
    component: pages.TeamCalendarPage,
    // Member-only server-side: `@PermitAll` on TeamCalendarResource only lets the token-authed ICS
    // feed through, while `CalendarAccessChecker` LIST requires a signed-in user *and* a team role.
    // The agenda's calendar view (WEB-69): its own path, under the agenda.
    auth: 'authenticated',
    parentId: 'team-agenda',
    breadcrumb: { type: 'static', i18nKey: tRegister('calendar.title') },
    prefetch: (queryClient, params) =>
      withTeamSwitcher(queryClient, prefetchTeamCalendar(queryClient, params.teamSlug!)),
  },
  {
    id: 'team-page',
    paths: pathVariants.teamPage(':teamSlug', ':pageSlug'),
    component: pages.TeamPageDetailPage,
    auth: 'public',
    parentId: 'team-detail',
    breadcrumb: { type: 'dynamic', entity: 'teamPage' },
    prefetch: (queryClient, params) =>
      withTeamSwitcher(
        queryClient,
        prefetchTeamPage(queryClient, params.teamSlug!, params.pageSlug!)
      ),
    meta: teamPageMeta,
  },
  // === Team Admin Routes ===
  {
    id: 'team-admin',
    paths: pathVariants.teamAdmin(':teamSlug'),
    component: pages.TeamAdminPage,
    auth: 'authenticated',
    parentId: 'team-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.admin.title') },
    prefetch: teamScopedPrefetch(),
  },
  {
    id: 'team-admin-places',
    paths: pathVariants.teamAdminPlaces(':teamSlug'),
    component: pages.TeamPlacesPage,
    auth: 'authenticated',
    parentId: 'team-admin',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.admin.tabs.places') },
    prefetch: teamScopedPrefetch((qc, p, url) => prefetchTeamPlaces(qc, p.teamSlug!, url)),
  },
  {
    // The tag vocabulary (docs/LEDGER_*.md WEB-40) — team admins only, the page redirects others.
    id: 'team-admin-tags',
    paths: pathVariants.teamAdminTags(':teamSlug'),
    component: pages.TeamTagsPage,
    auth: 'authenticated',
    parentId: 'team-admin',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.admin.tabs.tags') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchTeamTagsAdmin(qc, p.teamSlug!)),
  },
  {
    id: 'team-admin-pages',
    paths: pathVariants.teamAdminPages(':teamSlug'),
    component: pages.TeamPagesAdminPage,
    auth: 'authenticated',
    parentId: 'team-admin',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.admin.tabs.pages') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchTeamPagesAdmin(qc, p.teamSlug!)),
  },
  {
    id: 'team-admin-page-new',
    paths: pathVariants.teamAdminPageNew(':teamSlug'),
    component: pages.CreateTeamPagePage,
    auth: 'authenticated',
    parentId: 'team-admin-pages',
    breadcrumb: { type: 'static', i18nKey: tRegister('actions.new') },
    prefetch: teamScopedPrefetch(),
    showBackLink: true,
  },
  {
    id: 'team-admin-page-edit',
    paths: pathVariants.teamAdminPageEdit(':teamSlug', ':pageSlug'),
    component: pages.EditTeamPagePage,
    auth: 'authenticated',
    parentId: 'team-admin-pages',
    breadcrumb: { type: 'dynamic', entity: 'teamPage' },
    prefetch: teamScopedPrefetch((qc, p) => prefetchEditTeamPageForm(qc, p.teamSlug!, p.pageSlug!)),
    showBackLink: true,
  },
  {
    id: 'team-members',
    paths: pathVariants.teamAdminMembers(':teamSlug'),
    component: pages.TeamMembersPage,
    auth: 'authenticated',
    parentId: 'team-admin',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.admin.tabs.members') },
    prefetch: teamScopedPrefetch((qc, p, url) => prefetchTeamMembers(qc, p.teamSlug!, url)),
  },
  {
    id: 'team-admin-reports',
    paths: pathVariants.teamAdminReports(':teamSlug'),
    component: pages.TeamReportsPage,
    auth: 'authenticated',
    parentId: 'team-admin',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.admin.tabs.reports') },
    prefetch: teamScopedPrefetch((qc, p, url) => prefetchTeamReports(qc, p.teamSlug!, url)),
  },
  {
    id: 'team-settings',
    paths: pathVariants.teamSettings(':teamSlug'),
    component: pages.TeamSettingsPage,
    auth: 'authenticated',
    parentId: 'team-admin',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.admin.tabs.settings') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchTeamSettings(qc, p.teamSlug!)),
  },

  // === Ride Routes ===
  // A ride's page hangs under the agenda (WEB-68), its creation under the team.
  {
    id: 'ride-new',
    paths: pathVariants.rideNew(':teamSlug'),
    component: pages.CreateRidePage,
    auth: 'authenticated',
    parentId: 'team-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('rides.create.title') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchCreateRideForm(qc, p.teamSlug!)),
    showBackLink: true,
  },
  {
    id: 'ride-detail',
    paths: pathVariants.ride(':teamSlug', ':rideSlug'),
    component: pages.RideDetailPage,
    auth: 'public',
    parentId: 'team-agenda',
    breadcrumb: { type: 'dynamic', entity: 'ride' },
    prefetch: (queryClient, params, url) =>
      prefetchRideDetail(queryClient, params.teamSlug!, params.rideSlug!, url),
    meta: rideMeta,
  },
  {
    // One group of a ride (ledger WEB-77): the ride page's reads, plus the group's participants.
    id: 'ride-group',
    paths: pathVariants.rideGroup(':teamSlug', ':rideSlug', ':groupId'),
    component: pages.RideGroupPage,
    auth: 'public',
    parentId: 'ride-detail',
    breadcrumb: { type: 'dynamic', entity: 'rideGroup' },
    prefetch: (queryClient, params, url) =>
      prefetchRideGroup(queryClient, params.teamSlug!, params.rideSlug!, params.groupId!, url),
    // A ride with at most one group has no group page: its own page is the group's (WEB-79).
    dataRedirect: rideGroupDataRedirect,
    meta: rideGroupMeta,
  },
  {
    // The group's map in full screen (ledger WEB-117), its colour mode in `?color=`: the group
    // page's reads, minus what only that page's children read.
    id: 'ride-group-map',
    paths: pathVariants.rideGroupMap(':teamSlug', ':rideSlug', ':groupId'),
    component: pages.RideGroupFullscreenMapPage,
    auth: 'public',
    layout: 'bare',
    parentId: 'ride-group',
    breadcrumb: { type: 'static', i18nKey: tRegister('map.fullscreen.title') },
    prefetch: (queryClient, params) =>
      prefetchRideGroupMap(queryClient, params.teamSlug!, params.rideSlug!),
    // No group page for a ride with at most one group (WEB-79), so no group map either: a solo
    // ride's is the ride's own map (WEB-118), `?color=` kept; a ride without groups, its page.
    dataRedirect: rideGroupMapDataRedirect,
    meta: rideGroupMeta,
  },
  {
    // A solo ride's map in full screen (ledger WEB-118): its one group's route, its colour mode in
    // `?color=` — the ride page's reads, minus what only that page's children read.
    id: 'ride-map',
    paths: pathVariants.rideMap(':teamSlug', ':rideSlug'),
    component: pages.RideFullscreenMapPage,
    auth: 'public',
    layout: 'bare',
    parentId: 'ride-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('map.fullscreen.title') },
    prefetch: (queryClient, params) =>
      prefetchRideMap(queryClient, params.teamSlug!, params.rideSlug!),
    // Only a solo ride has this map: any other goes to its page.
    dataRedirect: rideMapDataRedirect,
    meta: rideMeta,
  },
  {
    id: 'ride-edit',
    paths: pathVariants.rideEdit(':teamSlug', ':rideSlug'),
    component: pages.EditRidePage,
    auth: 'authenticated',
    parentId: 'ride-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('actions.edit') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchEditRideForm(qc, p.teamSlug!, p.rideSlug!)),
    showBackLink: true,
  },

  // === Ride Template Routes ===
  {
    id: 'ride-templates',
    paths: pathVariants.rideTemplates(':teamSlug'),
    component: pages.RideTemplateListPage,
    auth: 'authenticated',
    parentId: 'team-admin',
    breadcrumb: { type: 'static', i18nKey: tRegister('teams.admin.tabs.rideTemplates') },
    prefetch: teamScopedPrefetch((qc, p, url) => prefetchRideTemplateList(qc, p.teamSlug!, url)),
  },
  {
    id: 'ride-template-new',
    paths: pathVariants.rideTemplateNew(':teamSlug'),
    component: pages.CreateRideTemplatePage,
    auth: 'authenticated',
    parentId: 'ride-templates',
    breadcrumb: { type: 'static', i18nKey: tRegister('actions.new') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchCreateRideTemplateForm(qc, p.teamSlug!)),
    showBackLink: true,
  },
  {
    id: 'ride-template-edit',
    paths: pathVariants.rideTemplateEdit(':teamSlug', ':templateSlug'),
    component: pages.EditRideTemplatePage,
    auth: 'authenticated',
    parentId: 'ride-templates',
    breadcrumb: { type: 'dynamic', entity: 'rideTemplate' },
    prefetch: teamScopedPrefetch((qc, p) =>
      prefetchEditRideTemplateForm(qc, p.teamSlug!, p.templateSlug!)
    ),
    showBackLink: true,
  },

  // === Trip Routes ===
  // A trip's page hangs under the agenda (WEB-68), its creation under the team.
  {
    id: 'trip-new',
    paths: pathVariants.tripNew(':teamSlug'),
    component: pages.CreateTripPage,
    auth: 'authenticated',
    parentId: 'team-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('trips.create.title') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchCreateTripForm(qc, p.teamSlug!)),
    showBackLink: true,
  },
  {
    id: 'trip-detail',
    paths: pathVariants.trip(':teamSlug', ':tripSlug'),
    component: pages.TripDetailPage,
    auth: 'public',
    parentId: 'team-agenda',
    breadcrumb: { type: 'dynamic', entity: 'trip' },
    prefetch: (queryClient, params) =>
      prefetchTripDetail(queryClient, params.teamSlug!, params.tripSlug!),
    meta: tripMeta,
  },
  {
    id: 'trip-edit',
    paths: pathVariants.tripEdit(':teamSlug', ':tripSlug'),
    component: pages.EditTripPage,
    auth: 'authenticated',
    parentId: 'trip-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('actions.edit') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchEditTripForm(qc, p.teamSlug!, p.tripSlug!)),
    showBackLink: true,
  },
  {
    id: 'stage-detail',
    paths: pathVariants.stage(':teamSlug', ':tripSlug', ':stageSlug'),
    component: pages.StageDetailPage,
    auth: 'public',
    parentId: 'trip-detail',
    breadcrumb: { type: 'dynamic', entity: 'stage' },
    // StageDetailPage reads the team and the parent trip, then looks up the stage by
    // `stageSlug` within the trip's own stages to find its route — same lookup here, once the
    // trip is in cache. GPS export options are authenticated-only, resolved the same way as
    // route-detail's own prefetch above.
    prefetch: (queryClient, params) =>
      prefetchStageDetail(queryClient, params.teamSlug!, params.tripSlug!, params.stageSlug!),
    meta: stageMeta,
  },
  {
    id: 'stage-map',
    paths: pathVariants.stageMap(':teamSlug', ':tripSlug', ':stageSlug'),
    component: pages.StageFullscreenMapPage,
    auth: 'public',
    layout: 'bare',
    parentId: 'stage-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('map.fullscreen.title') },
    prefetch: (queryClient, params) =>
      prefetchStageMap(queryClient, params.teamSlug!, params.tripSlug!, params.stageSlug!),
  },

  // === Post Routes ===
  // A post's page hangs under the team's « Publications » (WEB-68), its creation under the team.
  {
    id: 'post-new',
    paths: pathVariants.postNew(':teamSlug'),
    component: pages.CreatePostPage,
    auth: 'authenticated',
    parentId: 'team-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('posts.create.title') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchCreatePostForm(qc, p.teamSlug!)),
    showBackLink: true,
  },
  {
    id: 'post-detail',
    paths: pathVariants.post(':teamSlug', ':postSlug'),
    component: pages.PostDetailPage,
    auth: 'public',
    parentId: 'team-posts',
    breadcrumb: { type: 'dynamic', entity: 'post' },
    prefetch: (queryClient, params) =>
      prefetchPostDetail(queryClient, params.teamSlug!, params.postSlug!),
    meta: postMeta,
  },
  {
    id: 'post-edit',
    paths: pathVariants.postEdit(':teamSlug', ':postSlug'),
    component: pages.EditPostPage,
    auth: 'authenticated',
    parentId: 'post-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('actions.edit') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchEditPostForm(qc, p.teamSlug!, p.postSlug!)),
    showBackLink: true,
  },

  // === Route Routes ===
  // Note: routes have a list page, so route-detail has parent 'routes'
  {
    id: 'routes',
    paths: pathVariants.routes(':teamSlug'),
    component: pages.RouteListPage,
    auth: 'public',
    // Not indexed, like `all-routes`: a list of maps under as many URLs as filter combinations.
    // Each route's own page stays indexable (docs/LEDGER_*.md WEB-85).
    noindex: true,
    parentId: 'team-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('nav.routes') },
    prefetch: (queryClient, params, url) =>
      withTeamSwitcher(queryClient, prefetchRouteList(queryClient, params.teamSlug!, url)),
  },
  {
    id: 'routes-map',
    paths: pathVariants.routesMap(':teamSlug'),
    component: pages.RoutesMapPage,
    auth: 'public',
    noindex: true,
    parentId: 'routes',
    breadcrumb: { type: 'static', i18nKey: tRegister('routes.view.map') },
    prefetch: (queryClient, params, url) =>
      withTeamSwitcher(queryClient, prefetchRoutesMap(queryClient, params.teamSlug!, url)),
  },
  {
    id: 'route-new',
    paths: pathVariants.routeNew(':teamSlug'),
    component: pages.CreateRoutePage,
    auth: 'authenticated',
    parentId: 'routes',
    breadcrumb: { type: 'static', i18nKey: tRegister('actions.new') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchCreateRouteForm(qc, p.teamSlug!)),
    showBackLink: true,
  },
  {
    id: 'route-detail',
    paths: pathVariants.route(':teamSlug', ':routeSlug'),
    component: pages.RouteDetailPage,
    auth: 'public',
    parentId: 'routes',
    breadcrumb: { type: 'dynamic', entity: 'route' },
    // Comments are member-only (RouteDetailPage's `isMember`, from the team's `role`) and GPS
    // export options are authenticated-only — both resolved from data already being prefetched
    // here, so this replicates the page's own gating instead of guessing.
    prefetch: (queryClient, params) =>
      prefetchRouteDetail(queryClient, params.teamSlug!, params.routeSlug!),
    meta: routeMeta,
  },
  {
    id: 'route-map',
    paths: pathVariants.routeMap(':teamSlug', ':routeSlug'),
    component: pages.RouteFullscreenMapPage,
    auth: 'public',
    layout: 'bare',
    parentId: 'route-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('map.fullscreen.title') },
    prefetch: (queryClient, params) =>
      prefetchRouteMap(queryClient, params.teamSlug!, params.routeSlug!),
    meta: routeMeta,
  },
  {
    id: 'route-edit',
    paths: pathVariants.routeEdit(':teamSlug', ':routeSlug'),
    component: pages.EditRoutePage,
    auth: 'authenticated',
    parentId: 'route-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('actions.edit') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchEditRouteForm(qc, p.teamSlug!, p.routeSlug!)),
    showBackLink: true,
  },

  // === Ad Routes ===
  {
    id: 'ads',
    paths: pathVariants.ads(':teamSlug'),
    component: pages.AdListPage,
    // The whole ad API is `@RolesAllowed("user")` and the tab only shows to members — a public
    // route here just rendered a shell that 401s.
    auth: 'authenticated',
    parentId: 'team-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('ads.title') },
    // AdListPage reads the team plus its first two, unfiltered ad pages — matches its query key
    // exactly (including `view`), same pattern as the publications and routes lists above.
    prefetch: (queryClient, params, url) =>
      withTeamSwitcher(queryClient, prefetchAdList(queryClient, params.teamSlug!, url)),
  },
  {
    id: 'ad-new',
    paths: pathVariants.adNew(':teamSlug'),
    component: pages.CreateAdPage,
    auth: 'authenticated',
    parentId: 'ads',
    breadcrumb: { type: 'static', i18nKey: tRegister('ads.create.title') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchCreateAdForm(qc, p.teamSlug!)),
    showBackLink: true,
  },
  {
    id: 'ad-detail',
    paths: pathVariants.ad(':teamSlug', ':adSlug'),
    component: pages.AdDetailPage,
    auth: 'authenticated',
    parentId: 'ads',
    breadcrumb: { type: 'dynamic', entity: 'ad' },
    prefetch: (queryClient, params) =>
      prefetchAdDetail(queryClient, params.teamSlug!, params.adSlug!),
    // No `meta`: a member-only page has no link preview to build — every unfurl crawler is
    // anonymous, so the prefetch it would read from answers 401. See docs/LINK_PREVIEW.md.
  },
  {
    id: 'ad-edit',
    paths: pathVariants.adEdit(':teamSlug', ':adSlug'),
    component: pages.EditAdPage,
    auth: 'authenticated',
    parentId: 'ad-detail',
    breadcrumb: { type: 'static', i18nKey: tRegister('actions.edit') },
    prefetch: teamScopedPrefetch((qc, p) => prefetchEditAdForm(qc, p.teamSlug!, p.adSlug!)),
    showBackLink: true,
  },

  // === Platform Admin Routes ===
  {
    id: 'admin',
    paths: pathVariants.admin(),
    component: pages.AdminDashboardPage,
    auth: 'authenticated',
    parentId: null,
    breadcrumb: { type: 'static', i18nKey: tRegister('admin.title') },
    prefetch: (queryClient) => prefetchAdminDashboard(queryClient),
  },
  {
    id: 'admin-domains',
    paths: pathVariants.adminDomains(),
    component: pages.AdminDomainsPage,
    auth: 'authenticated',
    parentId: 'admin',
    breadcrumb: { type: 'static', i18nKey: tRegister('admin.tabs.domains') },
    prefetch: (queryClient) => prefetchAdminDomains(queryClient),
  },
  {
    id: 'admin-teams',
    paths: pathVariants.adminTeams(),
    component: pages.AdminTeamsPage,
    auth: 'authenticated',
    parentId: 'admin',
    breadcrumb: { type: 'static', i18nKey: tRegister('admin.tabs.teams') },
    prefetch: (queryClient) => prefetchAdminTeams(queryClient),
  },
  {
    id: 'admin-users',
    paths: pathVariants.adminUsers(),
    component: pages.AdminUsersPage,
    auth: 'authenticated',
    parentId: 'admin',
    breadcrumb: { type: 'static', i18nKey: tRegister('admin.tabs.users') },
    prefetch: (queryClient) => prefetchAdminUsers(queryClient),
  },
  {
    id: 'admin-reports',
    paths: pathVariants.adminReports(),
    component: pages.AdminReportsPage,
    auth: 'authenticated',
    parentId: 'admin',
    breadcrumb: { type: 'static', i18nKey: tRegister('admin.tabs.reports') },
    prefetch: (queryClient, _params, url) => prefetchAdminReports(queryClient, url),
  },
  {
    id: 'admin-beta-signups',
    paths: pathVariants.adminBetaSignups(),
    component: pages.AdminBetaSignupsPage,
    auth: 'authenticated',
    parentId: 'admin',
    breadcrumb: { type: 'static', i18nKey: tRegister('admin.tabs.betaSignups') },
    prefetch: (queryClient) => prefetchAdminBetaSignups(queryClient),
  },
  {
    id: 'admin-maintenance',
    paths: pathVariants.adminMaintenance(),
    component: pages.AdminMaintenancePage,
    auth: 'authenticated',
    parentId: 'admin',
    breadcrumb: { type: 'static', i18nKey: tRegister('admin.tabs.maintenance') },
    prefetch: (queryClient) => prefetchAdminMaintenance(queryClient),
  },
]
