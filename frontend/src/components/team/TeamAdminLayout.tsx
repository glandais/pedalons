import { Navigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Container, Title, Box, Stack } from '@mantine/core'
import {
  IconCalendarRepeat,
  IconMapPin,
  IconFileText,
  IconUsers,
  IconSettings,
  IconFlag,
  IconTags,
} from '@tabler/icons-react'
import type { TeamDetailDto } from '@/api/dto'
import { paths } from '@/config/paths'
import { NavButtons, type NavButtonItem } from '../common/NavButtons'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'

export type AdminTab =
  'ride-templates' | 'places' | 'tags' | 'pages' | 'members' | 'reports' | 'settings'

interface TeamAdminLayoutProps {
  team: TeamDetailDto
  currentTab: AdminTab
  children: React.ReactNode
}

export function TeamAdminLayout({ team, currentTab, children }: TeamAdminLayoutProps) {
  const { t } = useTranslation()

  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)

  const isAdmin = team.role === 'ADMIN'
  const isOrganizer = team.role === 'ADMIN' || team.role === 'ORGANIZER'

  // Only ADMIN or ORGANIZER can access admin section — except its moderation queue, which a
  // platform admin opens from a report notification without being a member of the team.
  const canModerateOnly = !isOrganizer && isPlatformAdmin && currentTab === 'reports'
  if (!isOrganizer && !canModerateOnly) {
    return <Navigate to={paths.team(team.slug)} replace />
  }

  const tabs: (NavButtonItem & { adminOnly?: boolean; moderation?: boolean })[] = [
    {
      id: 'ride-templates',
      path: paths.rideTemplates(team.slug),
      label: t('teams.admin.tabs.rideTemplates'),
      icon: IconCalendarRepeat,
    },
    {
      id: 'places',
      path: paths.teamAdminPlaces(team.slug),
      label: t('places.title'),
      icon: IconMapPin,
    },
    {
      // The vocabulary is the admins' alone (plan D4); organizers only pick from it.
      id: 'tags',
      path: paths.teamAdminTags(team.slug),
      label: t('teams.admin.tabs.tags'),
      icon: IconTags,
      adminOnly: true,
    },
    {
      id: 'pages',
      path: paths.teamAdminPages(team.slug),
      label: t('teams.admin.tabs.pages'),
      icon: IconFileText,
      adminOnly: true,
    },
    {
      id: 'members',
      path: paths.teamAdminMembers(team.slug),
      label: t('teams.admin.tabs.members'),
      icon: IconUsers,
      adminOnly: true,
    },
    {
      id: 'reports',
      path: paths.teamAdminReports(team.slug),
      label: t('teams.admin.tabs.reports'),
      icon: IconFlag,
      moderation: true,
    },
    {
      id: 'settings',
      path: paths.teamSettings(team.slug),
      label: t('teams.admin.tabs.settings'),
      icon: IconSettings,
      adminOnly: true,
    },
  ]

  // Filter tabs based on role. A platform admin who is not an organizer here only gets the queue.
  const visibleTabs: NavButtonItem[] = tabs
    .filter((tab) => !tab.adminOnly || isAdmin)
    .filter((tab) => !canModerateOnly || tab.moderation)

  return (
    <Container size="xl" py="xl">
      {/* Same vertical rhythm as TeamLayout, which wraps its nav row in a Stack */}
      <Stack>
        {/* Header — the way back to the team is the breadcrumb */}
        <Title order={2}>{t('teams.admin.title')}</Title>

        {/* Admin Navigation */}
        <NavButtons
          items={visibleTabs}
          currentId={currentTab}
          label={t('nav.landmark.teamAdmin')}
        />

        {/* Page Content */}
        <Box>{children}</Box>
      </Stack>
    </Container>
  )
}
