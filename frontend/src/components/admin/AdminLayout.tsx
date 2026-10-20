import { Navigate } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { Container, Group, Title, Anchor, Box, Stack } from '@mantine/core'
import {
  IconArrowLeft,
  IconDashboard,
  IconWorld,
  IconUsers,
  IconBuildingCommunity,
  IconMailFast,
  IconFlag,
  IconTool,
} from '@tabler/icons-react'
import { paths } from '@/config/paths'
import { NavButtons, type NavButtonItem } from '../common/NavButtons'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'

export type AdminTab =
  'dashboard' | 'domains' | 'teams' | 'users' | 'reports' | 'beta-signups' | 'maintenance'

interface AdminLayoutProps {
  currentTab: AdminTab
  children: React.ReactNode
}

export function AdminLayout({ currentTab, children }: AdminLayoutProps) {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)

  // Only platform admins can access admin section
  if (!isPlatformAdmin) {
    return <Navigate to={paths.home()} replace />
  }

  const tabs: NavButtonItem[] = [
    {
      id: 'dashboard',
      path: paths.admin(),
      label: t('admin.tabs.dashboard'),
      icon: IconDashboard,
    },
    {
      id: 'domains',
      path: paths.adminDomains(),
      label: t('admin.tabs.domains'),
      icon: IconWorld,
    },
    {
      id: 'teams',
      path: paths.adminTeams(),
      label: t('admin.tabs.teams'),
      icon: IconBuildingCommunity,
    },
    {
      id: 'users',
      path: paths.adminUsers(),
      label: t('admin.tabs.users'),
      icon: IconUsers,
    },
    {
      id: 'reports',
      path: paths.adminReports(),
      label: t('admin.tabs.reports'),
      icon: IconFlag,
    },
    {
      id: 'beta-signups',
      path: paths.adminBetaSignups(),
      label: t('admin.tabs.betaSignups'),
      icon: IconMailFast,
    },
    {
      id: 'maintenance',
      path: paths.adminMaintenance(),
      label: t('admin.tabs.maintenance'),
      icon: IconTool,
    },
  ]

  return (
    <Container size="xl" py="xl">
      {/* Same vertical rhythm as TeamLayout, which wraps its nav row in a Stack */}
      <Stack>
        {/* Header with back link */}
        <Box>
          <Anchor component={PrefetchLink} to={paths.home()} c="dimmed" size="sm">
            <Group gap={4}>
              <IconArrowLeft size={16} />
              {t('admin.backToApp')}
            </Group>
          </Anchor>
          <Title order={2} mt="xs">
            {t('admin.title')}
          </Title>
        </Box>

        {/* Admin Navigation */}
        <NavButtons items={tabs} currentId={currentTab} label={t('nav.landmark.admin')} />

        {/* Page Content */}
        <Box>{children}</Box>
      </Stack>
    </Container>
  )
}
