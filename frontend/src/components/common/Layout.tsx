import { useEffect } from 'react'
import { Outlet, useLocation, useNavigationType } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import {
  AppShell,
  Group,
  Burger,
  Text,
  Button,
  Avatar,
  Menu,
  Container,
  Anchor,
  Stack,
  Divider,
  Box,
  UnstyledButton,
  Indicator,
  Badge,
} from '@mantine/core'
import { useDisclosure, useHeadroom } from '@mantine/hooks'
import {
  IconUser,
  IconChevronRight,
  IconLogout,
  IconShield,
  IconBell,
  IconMessageReport,
  IconDownload,
} from '@tabler/icons-react'
import { InstallBanner } from '@/components/install/InstallBanner'
import { InstallInstructionsModal } from '@/components/install/InstallInstructionsModal'
import { useInstallOffer } from '@/lib/install/useInstallOffer'
import { openFeedback } from '@/lib/feedback/feedbackStore'
import { logEntry } from '@/lib/feedback/clientLog'
import { useGetVersion } from '@/api/endpoints/server-version/server-version'
import { useAuth } from '../../hooks/useAuth'
import { useAppName } from '../../hooks/useAppName'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { useBreadcrumb } from '../../hooks/useBreadcrumb'
import { useScrollRestoration } from '../../hooks/useScrollRestoration'
import { Breadcrumb } from './Breadcrumb'
import { ColorSchemeSwitcher } from './ColorSchemeSwitcher'
import { NotificationBell } from '@/components/notification/NotificationBell'
import { useUnreadNotificationCount } from '@/hooks/useNotifications'
import { LanguageSwitcher } from './LanguageSwitcher'
import { DrawerMainNav, HeaderMainNav } from './MainNav'
import { paths } from '@/config/paths'
import classes from './Layout.module.css'

/** Target of the skip link; the page's `<main>`. */
const MAIN_ID = 'main-content'

export function Layout() {
  const { t } = useTranslation()
  const { user, isAuthenticated, logout } = useAuth()
  const appName = useAppName()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { items: breadcrumbItems, showBackLink } = useBreadcrumb()
  const [opened, { toggle, close }] = useDisclosure(false)
  // The bell is desktop-only: below `sm` the burger and the drawer carry the unread count.
  const unreadCount = useUnreadNotificationCount()
  const location = useLocation()
  const { pathname } = location
  const navigationType = useNavigationType()
  // Fixed for the lifetime of the running server, so fetch it once and never revalidate.
  const { data: version } = useGetVersion({ query: { staleTime: Infinity } })
  // Null until hydrated, and whenever there is nothing to install (already installed, or a
  // browser with neither a prompt nor home-screen instructions). The entry leads to the apps page,
  // which lays out every app (the site installed, the mobile app…) rather than picking one.
  const { offer: installOffer } = useInstallOffer({ withStore: true })

  // Mounted before the effect below so its cleanup records the scroll position
  // while the outgoing route is still on screen.
  useScrollRestoration()

  // Navigations, in the bug-report log: the path only.
  useEffect(() => {
    logEntry('INFO', 'navigation', pathname)
  }, [pathname])

  const pinned = useHeadroom({ fixedAt: 120 })
  // Scroll to top when entering a new route. POP is left to useScrollRestoration,
  // and REPLACE (a filter edit) must not move the page at all.
  useEffect(() => {
    if (navigationType === 'PUSH') {
      window.scrollTo(0, 0)
    }
  }, [pathname, navigationType])

  // Update document title on route change
  useEffect(() => {
    const label = breadcrumbItems.at(-1)?.label
    document.title = label ? `${label} — ${appName}` : appName
  }, [breadcrumbItems, appName])

  // Close mobile menu on Escape key
  useEffect(() => {
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape' && opened) {
        close()
      }
    }

    document.addEventListener('keydown', handleEscape)
    return () => document.removeEventListener('keydown', handleEscape)
  }, [opened, close])

  return (
    <AppShell
      header={{ height: { base: 56, sm: 60 }, collapsed: !pinned }}
      navbar={{ width: 300, breakpoint: 'sm', collapsed: { desktop: true, mobile: !opened } }}
      padding={{ base: 'xs', sm: 'md' }}
    >
      {/* The href alone would work, but through a hash change React Router reads as a POP
          navigation (and useScrollRestoration with it); focusing the target directly doesn't. */}
      <a
        href={`#${MAIN_ID}`}
        className={classes.skipLink}
        onClick={(event) => {
          event.preventDefault()
          document.getElementById(MAIN_ID)?.focus()
        }}
      >
        {t('nav.skipToContent')}
      </a>
      <AppShell.Header>
        <Container size="lg" h="100%">
          <Group h="100%" justify="space-between" wrap="nowrap">
            <Anchor component={PrefetchLink} to="/" underline="never">
              <Text size="xl" fw={700} c="primary">
                {appName}
              </Text>
            </Anchor>

            <HeaderMainNav />

            {/* Desktop controls */}
            <Group gap="sm" visibleFrom="sm" wrap="nowrap">
              <ColorSchemeSwitcher />
              <LanguageSwitcher />
              {isAuthenticated && <NotificationBell />}
              {isAuthenticated ? (
                <Menu shadow="md" width={200}>
                  <Menu.Target>
                    <UnstyledButton>
                      <Group gap="xs">
                        <Avatar
                          src={user?.avatarUrl}
                          alt={user?.displayName}
                          radius="xl"
                          size="sm"
                          color="primary"
                        >
                          {user?.displayName?.charAt(0).toUpperCase()}
                        </Avatar>
                        {/* Capped so a long name cannot push the main navigation out. */}
                        <Text size="sm" visibleFrom="md" maw={160} truncate>
                          {user?.displayName}
                        </Text>
                      </Group>
                    </UnstyledButton>
                  </Menu.Target>
                  <Menu.Dropdown>
                    <Menu.Item
                      leftSection={<IconUser size={14} />}
                      component={PrefetchLink}
                      to={paths.profile()}
                    >
                      {t('nav.profile')}
                    </Menu.Item>
                    <Menu.Item
                      leftSection={<IconBell size={14} />}
                      component={PrefetchLink}
                      to={paths.notifications()}
                    >
                      {t('notifications.title')}
                    </Menu.Item>
                    <Menu.Item
                      leftSection={<IconMessageReport size={14} />}
                      onClick={() => openFeedback()}
                    >
                      {t('feedback.menu')}
                    </Menu.Item>
                    {installOffer && (
                      <Menu.Item
                        leftSection={<IconDownload size={14} />}
                        component={PrefetchLink}
                        to={paths.apps()}
                      >
                        {t('install.menu')}
                      </Menu.Item>
                    )}
                    {isPlatformAdmin && (
                      <Menu.Item
                        leftSection={<IconShield size={14} />}
                        component={PrefetchLink}
                        to={paths.admin()}
                      >
                        {t('nav.admin')}
                      </Menu.Item>
                    )}
                    <Menu.Divider />
                    <Menu.Item
                      leftSection={<IconLogout size={14} />}
                      onClick={logout}
                      color="danger"
                    >
                      {t('nav.signOut')}
                    </Menu.Item>
                  </Menu.Dropdown>
                </Menu>
              ) : (
                <Button component={PrefetchLink} to={paths.login()} state={{ from: location }}>
                  {t('nav.signIn')}
                </Button>
              )}
            </Group>

            {/* Mobile burger */}
            <Indicator
              hiddenFrom="sm"
              disabled={opened || unreadCount === 0}
              size={10}
              color="danger"
              offset={4}
            >
              <Burger
                opened={opened}
                onClick={toggle}
                size="sm"
                aria-label={opened ? t('nav.closeMenu') : t('nav.openMenu')}
              />
            </Indicator>
          </Group>
        </Container>
      </AppShell.Header>

      {/* Mobile Navigation */}
      <AppShell.Navbar p="md">
        <Stack>
          <DrawerMainNav onNavigate={close} />
          <Divider />
          <Group gap="sm" wrap="nowrap">
            <ColorSchemeSwitcher />
            <LanguageSwitcher />
          </Group>
          {installOffer && (
            <Button
              variant="light"
              leftSection={<IconDownload size={16} />}
              component={PrefetchLink}
              to={paths.apps()}
              onClick={close}
            >
              {t('install.menu')}
            </Button>
          )}
          <Divider />
          {isAuthenticated ? (
            <>
              {/* Says it is a link: an avatar and a name alone read as a label, not as the way
                  to the profile (the drawer has no other). */}
              <UnstyledButton component={PrefetchLink} to={paths.profile()} onClick={close}>
                <Group wrap="nowrap">
                  <Avatar
                    src={user?.avatarUrl}
                    alt={user?.displayName}
                    radius="xl"
                    size="md"
                    color="primary"
                  >
                    {user?.displayName?.charAt(0).toUpperCase()}
                  </Avatar>
                  <Box style={{ flex: 1, minWidth: 0 }}>
                    <Text size="sm" fw={500} truncate>
                      {user?.displayName}
                    </Text>
                    <Text size="xs" c="dimmed">
                      {t('nav.viewProfile')}
                    </Text>
                  </Box>
                  <IconChevronRight size={16} color="var(--mantine-color-dimmed)" />
                </Group>
              </UnstyledButton>
              <Button
                variant="subtle"
                leftSection={<IconBell size={16} />}
                component={PrefetchLink}
                to={paths.notifications()}
                onClick={close}
                rightSection={
                  unreadCount > 0 && (
                    <Badge
                      size="sm"
                      color="danger"
                      circle={unreadCount < 10}
                      aria-label={t('notifications.bell.ariaLabelUnread', { count: unreadCount })}
                    >
                      {unreadCount > 99 ? '99+' : unreadCount}
                    </Badge>
                  )
                }
              >
                {t('notifications.title')}
              </Button>
              {isPlatformAdmin && (
                <Button
                  variant="subtle"
                  leftSection={<IconShield size={16} />}
                  component={PrefetchLink}
                  to={paths.admin()}
                  onClick={close}
                >
                  {t('nav.admin')}
                </Button>
              )}
              <Button
                variant="subtle"
                color="danger"
                leftSection={<IconLogout size={16} />}
                onClick={() => {
                  logout()
                  close()
                }}
              >
                {t('nav.signOut')}
              </Button>
            </>
          ) : (
            <Button
              component={PrefetchLink}
              to={paths.login()}
              state={{ from: location }}
              onClick={close}
            >
              {t('nav.signIn')}
            </Button>
          )}
        </Stack>
      </AppShell.Navbar>

      <AppShell.Main id={MAIN_ID} tabIndex={-1} className={classes.main}>
        <Container size="lg" px={0}>
          <InstallBanner />
          <Breadcrumb items={breadcrumbItems} showBackLink={showBackLink} />
          <Outlet />
        </Container>
      </AppShell.Main>

      <Box
        component="footer"
        py="xl"
        style={{ borderTop: '1px solid var(--mantine-color-default-border)' }}
      >
        <Container size="lg">
          <Group justify="center" gap="xs" wrap="wrap">
            <Text c="dimmed" size="sm">
              {t('footer.copyright', { year: new Date().getFullYear(), appName })}
            </Text>
            <Text c="dimmed" size="sm">
              ·
            </Text>
            <Anchor component={PrefetchLink} to={paths.features()} c="dimmed" size="sm">
              {t('footer.features')}
            </Anchor>
            <Text c="dimmed" size="sm">
              ·
            </Text>
            <Anchor component={PrefetchLink} to={paths.apps()} c="dimmed" size="sm">
              {t('footer.apps')}
            </Anchor>
            <Text c="dimmed" size="sm">
              ·
            </Text>
            <Anchor component={PrefetchLink} to={paths.privacy()} c="dimmed" size="sm">
              {t('footer.privacy')}
            </Anchor>
            <Text c="dimmed" size="sm">
              ·
            </Text>
            <Anchor component={PrefetchLink} to={paths.terms()} c="dimmed" size="sm">
              {t('footer.terms')}
            </Anchor>
            <Text c="dimmed" size="sm">
              ·
            </Text>
            <Anchor component={PrefetchLink} to={paths.support()} c="dimmed" size="sm">
              {t('footer.support')}
            </Anchor>
            <Text c="dimmed" size="sm">
              ·
            </Text>
            {isAuthenticated ? (
              <Anchor
                component="button"
                type="button"
                c="dimmed"
                size="sm"
                onClick={() => openFeedback()}
              >
                {t('feedback.menu')}
              </Anchor>
            ) : (
              <Anchor
                component={PrefetchLink}
                to={paths.login()}
                state={{ from: location }}
                c="dimmed"
                size="sm"
              >
                {t('feedback.menu')}
              </Anchor>
            )}
            {version && (
              <>
                <Text c="dimmed" size="sm">
                  ·
                </Text>
                <Text c="dimmed" size="sm">
                  {version.commit
                    ? t('footer.version', {
                        version: version.apiVersion,
                        commit: version.commit,
                      })
                    : t('footer.versionShort', { version: version.apiVersion })}
                </Text>
              </>
            )}
          </Group>
        </Container>
      </Box>
      <InstallInstructionsModal />
    </AppShell>
  )
}
