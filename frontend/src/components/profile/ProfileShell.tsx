import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Box, Button, Divider, Group, NavLink, Paper, Stack, Text, Title } from '@mantine/core'
import { IconLogout } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useAuth } from '@/hooks/useAuth'
import {
  PROFILE_NAV_GROUPS,
  PROFILE_OVERVIEW,
  type ProfileNavItem,
  type ProfileSection,
} from './profileNav'

/** From this breakpoint up, the profile has its sidebar; below it, the overview's list. */
export const PROFILE_SIDEBAR_FROM = 'md'

/**
 * « Se déconnecter », the profile's one occurrence of it (the avatar menu and the drawer keep
 * theirs): at the foot of the sidebar on a desktop, of the overview's list on a phone.
 */
export function ProfileSignOutButton() {
  const { t } = useTranslation()
  const { logout } = useAuth()
  return (
    <Button
      variant="subtle"
      color="gray"
      justify="flex-start"
      fullWidth
      leftSection={<IconLogout size={18} />}
      onClick={logout}
    >
      {t('nav.signOut')}
    </Button>
  )
}

function SidebarLink({ item, active }: { item: ProfileNavItem; active: boolean }) {
  const { t } = useTranslation()
  const Icon = item.icon
  return (
    <NavLink
      component={PrefetchLink}
      to={item.to()}
      label={t(item.labelKey)}
      leftSection={<Icon size={18} stroke={1.5} />}
      active={active}
      aria-current={active ? 'page' : undefined}
      variant="light"
      style={{ borderRadius: 'var(--mantine-radius-md)' }}
    />
  )
}

/** The grouped sidebar of the profile, on a desktop. Not sticky: the page is short enough. */
function ProfileSidebar({ section }: { section: ProfileSection }) {
  const { t } = useTranslation()
  return (
    <Stack component="nav" aria-label={t('nav.profile')} gap="md">
      <SidebarLink item={PROFILE_OVERVIEW} active={section === 'overview'} />
      {PROFILE_NAV_GROUPS.map((group) => (
        <Stack key={group.labelKey} gap={2}>
          <Text size="xs" fw={600} tt="uppercase" c="dimmed" px="sm" pb={4}>
            {t(group.labelKey)}
          </Text>
          {group.items.map((item) => (
            <SidebarLink key={item.section} item={item} active={item.section === section} />
          ))}
        </Stack>
      ))}
      <Divider />
      <ProfileSignOutButton />
    </Stack>
  )
}

interface ProfileShellProps {
  /** The subject of the page, marked current in the sidebar. */
  section: ProfileSection
  title: string
  /** One line under the title, saying what the page is for. */
  description?: ReactNode
  /** Beside the title (e.g. the link from the notification settings to the inbox). */
  actions?: ReactNode
  children: ReactNode
}

/**
 * The frame of every profile page: the grouped sidebar on a desktop, the page alone on a phone —
 * where the overview's list stands in for the sidebar, and the breadcrumb leads back to « Profil ».
 *
 * Both layouts are in the markup and the breakpoint is pure CSS (`visibleFrom`), never a media
 * query read in JavaScript: the server cannot know the viewport, and a JS switch would hydrate the
 * wrong layout first.
 */
export function ProfileShell({
  section,
  title,
  description,
  actions,
  children,
}: ProfileShellProps) {
  return (
    <Group align="flex-start" gap="xl" wrap="nowrap">
      <Box visibleFrom={PROFILE_SIDEBAR_FROM} w={250} style={{ flexShrink: 0 }}>
        <ProfileSidebar section={section} />
      </Box>
      <Stack gap="lg" style={{ flex: 1, minWidth: 0 }} maw={760}>
        <Stack gap={4}>
          <Group justify="space-between" align="center" wrap="wrap" gap="sm">
            <Title order={2}>{title}</Title>
            {actions}
          </Group>
          {description && (
            <Text size="sm" c="dimmed">
              {description}
            </Text>
          )}
        </Stack>
        {children}
      </Stack>
    </Group>
  )
}

/**
 * A block of a profile page: one subject, in its own bordered card. `tone="danger"` draws the
 * border in the charter's danger token (docs/BRANDING.md §3.1), for the account's danger zone.
 */
export function ProfileCard({ children, tone }: { children: ReactNode; tone?: 'danger' }) {
  return (
    <Paper
      withBorder
      radius="md"
      p="lg"
      style={tone === 'danger' ? { borderColor: 'var(--mantine-color-danger-outline)' } : undefined}
    >
      {children}
    </Paper>
  )
}
