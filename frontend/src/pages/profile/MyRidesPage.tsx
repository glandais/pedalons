import { useTranslation } from 'react-i18next'
import { Badge, SimpleGrid, Stack, Tabs } from '@mantine/core'
import { IconCalendarEvent, IconHistory } from '@tabler/icons-react'
import { PublicationCard, PublicationCardSkeleton } from '@/components/card'
import { EmptyState } from '@/components/common/EmptyState'
import { Pagination } from '@/components/common/Pagination'
import { ProfileShell } from '@/components/profile/ProfileShell'
import { MY_RIDES_TABS, useMyRidesData, type MyRidesTab } from './myRidesData'

/**
 * « Mes sorties »: the rides and trips the member is registered to, in two tabs, each labelled with
 * its exact total. It used to be an accordion of the profile page; it is a page of its own now, so
 * its tab and page are in the URL like any list's.
 */
export function MyRidesPage() {
  const { t } = useTranslation()
  const { filters, setFilters, upcomingCount, historyCount, list, totalPages } = useMyRidesData()

  const publications = list.data?.publications ?? []
  const upcoming = filters.tab === 'upcoming'

  return (
    <ProfileShell section="rides" title={t('profile.nav.rides')}>
      <Tabs
        value={filters.tab}
        onChange={(value) =>
          value && (MY_RIDES_TABS as readonly string[]).includes(value)
            ? setFilters({ tab: value as MyRidesTab })
            : undefined
        }
      >
        <Tabs.List>
          <Tabs.Tab
            value="upcoming"
            leftSection={<IconCalendarEvent size={16} />}
            rightSection={
              <Badge color="primary" variant="light" size="sm">
                {upcomingCount.data?.total ?? 0}
              </Badge>
            }
          >
            {t('profile.participations.upcoming')}
          </Tabs.Tab>
          <Tabs.Tab
            value="history"
            leftSection={<IconHistory size={16} />}
            rightSection={
              <Badge variant="default" size="sm">
                {historyCount.data?.total ?? 0}
              </Badge>
            }
          >
            {t('profile.participations.history')}
          </Tabs.Tab>
        </Tabs.List>
      </Tabs>

      {list.isLoading || !list.data ? (
        <SimpleGrid cols={{ base: 1, sm: 2 }} spacing="md">
          {[...Array(2)].map((_, i) => (
            <PublicationCardSkeleton key={i} />
          ))}
        </SimpleGrid>
      ) : publications.length === 0 ? (
        <EmptyState
          icon={upcoming ? <IconCalendarEvent size={48} /> : <IconHistory size={48} />}
          title={
            upcoming
              ? t('profile.participations.empty.upcoming.title')
              : t('profile.participations.empty.history.title')
          }
          description={
            upcoming
              ? t('profile.participations.empty.upcoming.description')
              : t('profile.participations.empty.history.description')
          }
        />
      ) : (
        <Stack gap="md">
          <SimpleGrid cols={{ base: 1, sm: 2 }} spacing="md">
            {publications.map((publication, index) => (
              <PublicationCard
                key={publication.id}
                publication={publication}
                showTeam
                priority={index === 0}
              />
            ))}
          </SimpleGrid>
          <Pagination
            currentPage={filters.page}
            totalPages={totalPages}
            onPageChange={(page) => setFilters({ page })}
          />
        </Stack>
      )}
    </ProfileShell>
  )
}
