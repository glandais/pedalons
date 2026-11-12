import { useTranslation } from 'react-i18next'
import { Box, Button, Group, Paper, Skeleton, Stack, Switch, Title } from '@mantine/core'
import { IconBellOff, IconChecks, IconSearchOff, IconSettings } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { paths } from '@/config/paths'
import { EmptyState } from '@/components/common/EmptyState'
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

  const { data, isLoading, isError, error, refetch } = notifications
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

      <Group justify="space-between" align="center" wrap="wrap" mb="sm">
        <Switch
          checked={filters.unreadOnly}
          onChange={(event) => setFilters({ unreadOnly: event.currentTarget.checked })}
          label={t('notifications.filter.unreadOnly')}
        />
        <ResultCount total={data?.total} resource="notifications" />
      </Group>

      <div ref={listTopRef} />

      <QueryStateBoundary
        isLoading={isLoading}
        isError={isError}
        error={error}
        onRetry={() => void refetch()}
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
            <EmptyState
              variant="filtered"
              icon={<IconSearchOff size={48} />}
              title={t('notifications.empty.filtered.title')}
              description={t('notifications.empty.filtered.description')}
              actions={
                <Button variant="default" onClick={() => setFilters({ unreadOnly: false })}>
                  {t('notifications.empty.filtered.action')}
                </Button>
              }
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
