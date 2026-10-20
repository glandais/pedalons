import { lazy, type ComponentType, type LazyExoticComponent } from 'react'

/**
 * A lazily-loaded page, plus the raw import function it was built from.
 *
 * `React.lazy` hides its loader, so anything else that wants to warm a page's chunk (
 * `lib/prefetch.ts`, on hover/focus) would have to re-declare the same `import()` — a second
 * list of 64 imports silently drifting from this one. Keeping the loader on the component means
 * the import is written exactly once, here.
 */
export type LazyPage = LazyExoticComponent<ComponentType> & {
  /** Load the page's chunk without rendering it. Idempotent: the module registry dedupes. */
  preload: () => Promise<unknown>
}

/**
 * `lazyPage('HomePage', () => import('../pages/home/HomePage'))` — pages are named exports, so the
 * export name is passed rather than relying on a default export.
 */
function lazyPage<N extends string>(
  name: N,
  load: () => Promise<{ [K in N]: ComponentType }>
): LazyPage {
  const component = lazy(() => load().then((m) => ({ default: m[name] }))) as LazyPage
  component.preload = load
  return component
}

/**
 * Every route-level page component, keyed by its export name. `routes.config.ts` renders them;
 * `lib/prefetch.ts` prefetches their chunks.
 */
export const pages = {
  HomePage: lazyPage('HomePage', () => import('../pages/home/HomePage')),
  NotificationListPage: lazyPage(
    'NotificationListPage',
    () => import('../pages/notification/NotificationListPage')
  ),
  LoginPage: lazyPage('LoginPage', () => import('../pages/auth/LoginPage')),
  DeviceVerifyPage: lazyPage('DeviceVerifyPage', () => import('../pages/device/DeviceVerifyPage')),
  VerifyEmailPage: lazyPage('VerifyEmailPage', () => import('../pages/auth/VerifyEmailPage')),
  AcceptInvitationPage: lazyPage(
    'AcceptInvitationPage',
    () => import('../pages/invitation/AcceptInvitationPage')
  ),
  BiketeamMigrationPage: lazyPage(
    'BiketeamMigrationPage',
    () => import('../pages/biketeamMigration/BiketeamMigrationPage')
  ),
  ForgotPasswordPage: lazyPage(
    'ForgotPasswordPage',
    () => import('../pages/auth/ForgotPasswordPage')
  ),
  ResetPasswordPage: lazyPage('ResetPasswordPage', () => import('../pages/auth/ResetPasswordPage')),
  ProfileOverviewPage: lazyPage(
    'ProfileOverviewPage',
    () => import('../pages/profile/ProfileOverviewPage')
  ),
  MyRidesPage: lazyPage('MyRidesPage', () => import('../pages/profile/MyRidesPage')),
  ProfilePreferencesPage: lazyPage(
    'ProfilePreferencesPage',
    () => import('../pages/profile/ProfilePreferencesPage')
  ),
  ProfileNotificationsPage: lazyPage(
    'ProfileNotificationsPage',
    () => import('../pages/profile/ProfileNotificationsPage')
  ),
  ProfileDevicesPage: lazyPage(
    'ProfileDevicesPage',
    () => import('../pages/profile/ProfileDevicesPage')
  ),
  ProfileSecurityPage: lazyPage(
    'ProfileSecurityPage',
    () => import('../pages/profile/ProfileSecurityPage')
  ),
  ProfilePrivacyPage: lazyPage(
    'ProfilePrivacyPage',
    () => import('../pages/profile/ProfilePrivacyPage')
  ),
  BlockedUsersPage: lazyPage('BlockedUsersPage', () => import('../pages/profile/BlockedUsersPage')),
  ProfileAccountPage: lazyPage(
    'ProfileAccountPage',
    () => import('../pages/profile/ProfileAccountPage')
  ),
  ProfileHelpPage: lazyPage('ProfileHelpPage', () => import('../pages/profile/ProfileHelpPage')),
  TeamListPage: lazyPage('TeamListPage', () => import('../pages/team/TeamListPage')),
  CreateTeamPage: lazyPage('CreateTeamPage', () => import('../pages/team/CreateTeamPage')),
  TeamHomePage: lazyPage('TeamHomePage', () => import('../pages/team/TeamHomePage')),
  TeamAgendaPage: lazyPage('TeamAgendaPage', () => import('../pages/team/TeamAgendaPage')),
  TeamPostsPage: lazyPage('TeamPostsPage', () => import('../pages/team/TeamPostsPage')),
  TeamMembersPage: lazyPage('TeamMembersPage', () => import('../pages/team/TeamMembersPage')),
  TeamDirectoryPage: lazyPage('TeamDirectoryPage', () => import('../pages/team/TeamDirectoryPage')),
  TeamReportsPage: lazyPage('TeamReportsPage', () => import('../pages/team/TeamReportsPage')),
  TeamSettingsPage: lazyPage('TeamSettingsPage', () => import('../pages/team/TeamSettingsPage')),
  TeamAdminPage: lazyPage('TeamAdminPage', () => import('../pages/team/TeamAdminPage')),
  TeamPlacesPage: lazyPage('TeamPlacesPage', () => import('../pages/team/TeamPlacesPage')),
  TeamTagsPage: lazyPage('TeamTagsPage', () => import('../pages/team/TeamTagsPage')),
  TeamAboutPage: lazyPage('TeamAboutPage', () => import('../pages/team/TeamAboutPage')),
  TeamPageDetailPage: lazyPage(
    'TeamPageDetailPage',
    () => import('../pages/team/TeamPageDetailPage')
  ),
  TeamPagesAdminPage: lazyPage(
    'TeamPagesAdminPage',
    () => import('../pages/team/TeamPagesAdminPage')
  ),
  CreateTeamPagePage: lazyPage(
    'CreateTeamPagePage',
    () => import('../pages/team/CreateTeamPagePage')
  ),
  EditTeamPagePage: lazyPage('EditTeamPagePage', () => import('../pages/team/EditTeamPagePage')),
  RideDetailPage: lazyPage('RideDetailPage', () => import('../pages/ride/RideDetailPage')),
  RideGroupPage: lazyPage('RideGroupPage', () => import('../pages/ride/RideGroupPage')),
  CreateRidePage: lazyPage('CreateRidePage', () => import('../pages/ride/CreateRidePage')),
  EditRidePage: lazyPage('EditRidePage', () => import('../pages/ride/EditRidePage')),
  RideTemplateListPage: lazyPage(
    'RideTemplateListPage',
    () => import('../pages/ridetemplate/RideTemplateListPage')
  ),
  CreateRideTemplatePage: lazyPage(
    'CreateRideTemplatePage',
    () => import('../pages/ridetemplate/CreateRideTemplatePage')
  ),
  EditRideTemplatePage: lazyPage(
    'EditRideTemplatePage',
    () => import('../pages/ridetemplate/EditRideTemplatePage')
  ),
  TripDetailPage: lazyPage('TripDetailPage', () => import('../pages/trip/TripDetailPage')),
  CreateTripPage: lazyPage('CreateTripPage', () => import('../pages/trip/CreateTripPage')),
  EditTripPage: lazyPage('EditTripPage', () => import('../pages/trip/EditTripPage')),
  StageDetailPage: lazyPage('StageDetailPage', () => import('../pages/trip/StageDetailPage')),
  StageFullscreenMapPage: lazyPage(
    'StageFullscreenMapPage',
    () => import('../pages/trip/StageFullscreenMapPage')
  ),
  PostDetailPage: lazyPage('PostDetailPage', () => import('../pages/post/PostDetailPage')),
  CreatePostPage: lazyPage('CreatePostPage', () => import('../pages/post/CreatePostPage')),
  EditPostPage: lazyPage('EditPostPage', () => import('../pages/post/EditPostPage')),
  RouteListPage: lazyPage('RouteListPage', () => import('../pages/route/RouteListPage')),
  RouteDetailPage: lazyPage('RouteDetailPage', () => import('../pages/route/RouteDetailPage')),
  RouteFullscreenMapPage: lazyPage(
    'RouteFullscreenMapPage',
    () => import('../pages/route/RouteFullscreenMapPage')
  ),
  CreateRoutePage: lazyPage('CreateRoutePage', () => import('../pages/route/CreateRoutePage')),
  EditRoutePage: lazyPage('EditRoutePage', () => import('../pages/route/EditRoutePage')),
  AllRoutesMapPage: lazyPage('AllRoutesMapPage', () => import('../pages/route/AllRoutesMapPage')),
  GpxToolsPage: lazyPage('GpxToolsPage', () => import('../pages/gpxtool/GpxToolsPage')),
  CreateGpxPreviewPage: lazyPage(
    'CreateGpxPreviewPage',
    () => import('../pages/gpxtool/CreateGpxPreviewPage')
  ),
  MyGpxPreviewsPage: lazyPage(
    'MyGpxPreviewsPage',
    () => import('../pages/gpxtool/MyGpxPreviewsPage')
  ),
  GpxBlankMapPage: lazyPage('GpxBlankMapPage', () => import('../pages/gpxtool/GpxBlankMapPage')),
  GpxPreviewPage: lazyPage('GpxPreviewPage', () => import('../pages/gpxtool/GpxPreviewPage')),
  GpxPreviewFullscreenMapPage: lazyPage(
    'GpxPreviewFullscreenMapPage',
    () => import('../pages/gpxtool/GpxPreviewFullscreenMapPage')
  ),
  EditGpxPreviewPage: lazyPage(
    'EditGpxPreviewPage',
    () => import('../pages/gpxtool/EditGpxPreviewPage')
  ),
  RoutesMapPage: lazyPage('RoutesMapPage', () => import('../pages/route/RoutesMapPage')),
  AllRoutesPage: lazyPage('AllRoutesPage', () => import('../pages/route/AllRoutesPage')),
  CalendarPage: lazyPage('CalendarPage', () => import('../pages/calendar/CalendarPage')),
  TeamCalendarPage: lazyPage(
    'TeamCalendarPage',
    () => import('../pages/calendar/TeamCalendarPage')
  ),
  AdListPage: lazyPage('AdListPage', () => import('../pages/ad/AdListPage')),
  AdDetailPage: lazyPage('AdDetailPage', () => import('../pages/ad/AdDetailPage')),
  CreateAdPage: lazyPage('CreateAdPage', () => import('../pages/ad/CreateAdPage')),
  EditAdPage: lazyPage('EditAdPage', () => import('../pages/ad/EditAdPage')),
  AdminDashboardPage: lazyPage(
    'AdminDashboardPage',
    () => import('../pages/admin/AdminDashboardPage')
  ),
  AdminDomainsPage: lazyPage('AdminDomainsPage', () => import('../pages/admin/AdminDomainsPage')),
  AdminTeamsPage: lazyPage('AdminTeamsPage', () => import('../pages/admin/AdminTeamsPage')),
  AdminUsersPage: lazyPage('AdminUsersPage', () => import('../pages/admin/AdminUsersPage')),
  AdminReportsPage: lazyPage('AdminReportsPage', () => import('../pages/admin/AdminReportsPage')),
  AdminBetaSignupsPage: lazyPage(
    'AdminBetaSignupsPage',
    () => import('../pages/admin/AdminBetaSignupsPage')
  ),
  AdminMaintenancePage: lazyPage(
    'AdminMaintenancePage',
    () => import('../pages/admin/AdminMaintenancePage')
  ),
  PrivacyPolicyPage: lazyPage(
    'PrivacyPolicyPage',
    () => import('../pages/legal/PrivacyPolicyPage')
  ),
  TermsOfServicePage: lazyPage(
    'TermsOfServicePage',
    () => import('../pages/legal/TermsOfServicePage')
  ),
  SupportPage: lazyPage('SupportPage', () => import('../pages/legal/SupportPage')),
  AppsPage: lazyPage('AppsPage', () => import('../pages/apps/AppsPage')),
  FeaturesPage: lazyPage('FeaturesPage', () => import('../pages/features/FeaturesPage')),
} as const

export type PageKey = keyof typeof pages
