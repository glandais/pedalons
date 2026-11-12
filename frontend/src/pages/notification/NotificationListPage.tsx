import { useTranslation } from 'react-i18next'
import { Box, Button, Group, Paper, SegmentedControl, Skeleton, Stack, Title } from '@mantine/core'
import { IconBellOff, IconChecks, IconSettings } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { paths } from '@/config/paths'
import { EmptyState } from '@/components/common/EmptyState'
import { FilteredEmptyState } from '@/components/common/FilteredEmptyState'
import { Pagination } from '@/components/common/Pagination'
import { QueryStateBoundary } from '@/components/common/QueryStateBoundary'
import { OutOfRangeState } from '@/components/common/OutOfRangeState'
import { ResultCount } from '@/components/common/ResultCount'
import { NotificationItem } from '@/components/notification/NotificationItem'
import { useNotificationActions } from '@/hooks/useNotifications'
import { useScrollToListTop } from '@/hooks/useScrollToListTop'
import { isNotificationFiltered } from '@/hooks/filters/notificationFilters'
import { useNotificationListData } from './notificationListData'

/** The inbox in full: every notification, paginated, with an "unread only" filter. */
export function NotificationListPage() {
  const { t } = useTranslation()
  const { filters, setFilters, notifications, totalPages } = useNotificationListData()
  const { markRead, markAllRead, isMarkingAllRead } = useNotificationActions()
  const { listTopRef, scrollToListTop } = useScrollToListTop()

  const { data, isLoading, isError, error, refetch, isPlaceholderData } = notifications
  const items = data?.items ?? []
  const unreadCount = data?.unreadCount ?? 0

  return (
    <Box maw={672} mx="auto">
      <Group justify="space-between" align="center" wrap="wrap" mb="md">
        <Title order={2}>{t('notifications.title')}</Title>
        <Group gap="xs">
          {unreadCount > 0 && (
            <Button
              variant="default"
              leftSection={<IconChecks size={16} />}
              onClick={markAllRead}
              loading={isMarkingAllRead}
            >
              {t('notifications.actions.markAllRead')}
            </Button>
          )}
          {/* What reaches the member by e-mail and push is set in the profile, which links back. */}
          <Button
            component={PrefetchLink}
            to={paths.profileNotifications()}
            variant="subtle"
            leftSection={<IconSettings size={16} />}
          >
            {t('notifications.actions.settings')}
          </Button>
        </Group>
      </Group>

      <Stack gap="sm" mb="sm">
        {/* One form for a criterion on the site, one word with the app: « Toutes / Non lues » (RL6). */}
        <SegmentedControl
          value={filters.unreadOnly ? 'unread' : 'all'}
          onChange={(value) => setFilters({ unreadOnly: value === 'unread' })}
          data={[
            { value: 'all', label: t('notifications.filter.all') },
            { value: 'unread', label: t('notifications.filter.unread') },
          ]}
          aria-label={t('notifications.filter.label')}
          style={{ alignSelf: 'flex-start' }}
        />
        {/* Under the bar, as on every list (RL8). */}
        <ResultCount total={data?.total} resource="notifications" />
      </Stack>

      <div ref={listTopRef} />

      <QueryStateBoundary
        isLoading={isLoading}
        isError={isError}
        error={error}
        onRetry={() => void refetch()}
        isRefreshing={isPlaceholderData}
        isEmpty={items.length === 0}
        skeleton={
          <Stack gap="xs">
            {Array.from({ length: 5 }, (_, index) => (
              <Skeleton key={index} height={64} radius="md" />
            ))}
          </Stack>
        }
        empty={
          filters.page > 0 ? (
            <OutOfRangeState onFirstPage={() => setFilters({ page: 0 })} />
          ) : isNotificationFiltered(filters) ? (
            <FilteredEmptyState
              resource="notifications"
              filters={[t('notifications.filter.unread')]}
              onClear={() => setFilters({ unreadOnly: false })}
            />
          ) : (
            <EmptyState
              icon={<IconBellOff size={48} />}
              title={t('notifications.empty.title')}
              description={t('notifications.empty.description')}
            />
          )
        }
      >
        <Paper withBorder radius="md" p={4}>
          <Stack gap={0}>
            {items.map((notification) => (
              <NotificationItem
                key={notification.id}
                notification={notification}
                onOpen={(entry) => markRead(entry.id, entry.read)}
              />
            ))}
          </Stack>
        </Paper>
      </QueryStateBoundary>

      <Box mt="md">
        <Pagination
          currentPage={filters.page}
          totalPages={totalPages}
          onPageChange={(page) => {
            setFilters({ page })
            scrollToListTop()
          }}
        />
      </Box>
    </Box>
  )
}
