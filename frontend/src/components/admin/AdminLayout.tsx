import { Navigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Container, Title, Text, Box, Stack } from '@mantine/core'
import {
  IconDashboard,
  IconChartBar,
  IconWorld,
  IconUsers,
  IconBuildingCommunity,
  IconFlag,
  IconTool,
} from '@tabler/icons-react'
import { paths } from '@/config/paths'
import { NavButtons, type NavButtonItem } from '../common/NavButtons'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'

export type AdminTab =
  'dashboard' | 'stats' | 'domains' | 'teams' | 'users' | 'reports' | 'maintenance'

interface AdminLayoutProps {
  currentTab: AdminTab
  /** Under the title, dimmed: the dashboard's one line (docs/LEDGER_*.md WEB-208). */
  subtitle?: string
  children: React.ReactNode
}

export function AdminLayout({ currentTab, subtitle, children }: AdminLayoutProps) {
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
      id: 'stats',
      path: paths.adminStats(),
      label: t('admin.tabs.stats'),
      icon: IconChartBar,
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
        {/* The page's h1. No back link: the admin breadcrumb stops at /admin (parentId null), the site header (site name, main nav) is the way back to the application (docs/LEDGER_*.md WEB-208). */}
        <Box>
          <Title order={1} size="h2">
            {t('admin.title')}
          </Title>
          {subtitle && (
            <Text c="dimmed" mt={4}>
              {subtitle}
            </Text>
          )}
        </Box>

        {/* Admin Navigation */}
        <NavButtons items={tabs} currentId={currentTab} label={t('nav.landmark.admin')} />

        {/* Page Content */}
        <Box>{children}</Box>
      </Stack>
    </Container>
  )
}
