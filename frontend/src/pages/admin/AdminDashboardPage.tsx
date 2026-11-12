import { useTranslation } from 'react-i18next'
import { formatNumber } from '@/utils/unitFormat'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { Stack, SimpleGrid, Paper, Text, Group, ThemeIcon, Skeleton, Anchor } from '@mantine/core'
import { IconWorld, IconBuildingCommunity, IconUsers, IconArrowRight } from '@tabler/icons-react'
import { AdminLayout } from '@/components/admin/AdminLayout'
import { paths } from '@/config/paths'
import { useGetStats } from '@/api/endpoints/admin-domains/admin-domains'

interface StatCardProps {
  title: string
  value: number | undefined
  icon: React.ReactNode
  link: string
  linkLabel: string
  isLoading: boolean
}

function StatCard({ title, value, icon, link, linkLabel, isLoading }: StatCardProps) {
  // The page's language, not the runtime's default locale: Node renders « 2,786 », a French
  // browser « 2 786 », and the difference broke hydration past 999.
  const { i18n } = useTranslation()
  return (
    <Paper withBorder p="lg" radius="md">
      <Group justify="space-between" align="flex-start">
        <div>
          <Text c="dimmed" size="sm" fw={500}>
            {title}
          </Text>
          {isLoading ? (
            <Skeleton height={32} width={60} mt="xs" />
          ) : (
            <Text size="xl" fw={700} mt="xs">
              {formatNumber(value ?? 0, i18n.language)}
            </Text>
          )}
        </div>
        <ThemeIcon size="lg" variant="light" radius="md">
          {icon}
        </ThemeIcon>
      </Group>
      <Anchor component={PrefetchLink} to={link} mt="md">
        <Group gap={4}>
          <Text size="sm">{linkLabel}</Text>
          <IconArrowRight size={14} />
        </Group>
      </Anchor>
    </Paper>
  )
}

export function AdminDashboardPage() {
  const { t } = useTranslation()
  const { data: stats, isLoading } = useGetStats()

  return (
    <AdminLayout currentTab="dashboard">
      <Stack mt="lg">
        <Text c="dimmed">{t('admin.dashboard.subtitle')}</Text>

        <SimpleGrid cols={{ base: 1, sm: 3 }} spacing="lg">
          <StatCard
            title={t('admin.stats.domains')}
            value={stats?.totalDomains}
            icon={<IconWorld size={20} />}
            link={paths.adminDomains()}
            linkLabel={t('admin.dashboard.viewAll')}
            isLoading={isLoading}
          />
          <StatCard
            title={t('admin.stats.teams')}
            value={stats?.totalTeams}
            icon={<IconBuildingCommunity size={20} />}
            link={paths.adminTeams()}
            linkLabel={t('admin.dashboard.viewAll')}
            isLoading={isLoading}
          />
          <StatCard
            title={t('admin.stats.users')}
            value={stats?.totalUsers}
            icon={<IconUsers size={20} />}
            link={paths.adminUsers()}
            linkLabel={t('admin.dashboard.viewAll')}
            isLoading={isLoading}
          />
        </SimpleGrid>
      </Stack>
    </AdminLayout>
  )
}
