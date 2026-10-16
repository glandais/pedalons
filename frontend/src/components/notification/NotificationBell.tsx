import { useTranslation } from 'react-i18next'
import { ActionIcon, Anchor, Divider, Group, Indicator, Menu, Stack, Text } from '@mantine/core'
import { useDisclosure } from '@mantine/hooks'
import { IconBell, IconChecks } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useListMyNotifications } from '@/api/endpoints/notifications/notifications'
import { useNotificationActions, useUnreadNotificationCount } from '@/hooks/useNotifications'
import { paths } from '@/config/paths'
import { NotificationItem } from './NotificationItem'

/** How many entries the dropdown shows. Anything longer belongs on the notifications page. */
const PREVIEW_SIZE = 6

/**
 * The header bell: an unread badge, and the last few notifications on click.
 *
 * The list is only fetched once the menu opens — a badge costs one cheap `unread-count` per
 * minute, a list would cost a page of notifications on every poll for a dropdown nobody opened.
 */
export function NotificationBell() {
  const { t } = useTranslation()
  const [opened, { open, close }] = useDisclosure(false)
  const unreadCount = useUnreadNotificationCount()
  const { markRead, markAllRead, isMarkingAllRead } = useNotificationActions()

  const { data, isLoading } = useListMyNotifications(
    { page: 0, size: PREVIEW_SIZE },
    { query: { enabled: opened } }
  )
  const items = data?.items ?? []

  return (
    <Menu
      shadow="md"
      width={360}
      position="bottom-end"
      opened={opened}
      onChange={(next) => (next ? open() : close())}
    >
      <Indicator
        disabled={unreadCount === 0}
        label={unreadCount > 99 ? '99+' : unreadCount}
        size={16}
        color="danger"
        offset={4}
      >
        {/* The target is the button, not the Indicator: Menu.Target puts aria-haspopup/expanded/controls
            on its child, which a role-less <div> may not carry (Lighthouse aria-allowed-attr). */}
        <Menu.Target>
          <ActionIcon
            variant="subtle"
            color="gray"
            aria-label={
              unreadCount > 0
                ? t('notifications.bell.ariaLabelUnread', { count: unreadCount })
                : t('notifications.bell.ariaLabel')
            }
          >
            <IconBell size={20} />
          </ActionIcon>
        </Menu.Target>
      </Indicator>

      <Menu.Dropdown>
        <Group justify="space-between" px="xs" py={4} wrap="nowrap">
          <Text size="sm" fw={600}>
            {t('notifications.title')}
          </Text>
          {unreadCount > 0 && (
            <Anchor
              component="button"
              type="button"
              size="xs"
              onClick={markAllRead}
              disabled={isMarkingAllRead}
            >
              <Group gap={4} wrap="nowrap">
                <IconChecks size={14} />
                {t('notifications.actions.markAllRead')}
              </Group>
            </Anchor>
          )}
        </Group>
        <Divider />

        {isLoading ? (
          <Text size="sm" c="dimmed" ta="center" py="md">
            {t('loading')}
          </Text>
        ) : items.length === 0 ? (
          <Text size="sm" c="dimmed" ta="center" py="md">
            {t('notifications.empty.title')}
          </Text>
        ) : (
          <Stack gap={0} py={4}>
            {items.map((notification) => (
              <NotificationItem
                key={notification.id}
                notification={notification}
                compact
                onOpen={(entry) => {
                  markRead(entry.id, entry.read)
                  close()
                }}
              />
            ))}
          </Stack>
        )}

        <Divider />
        <Anchor
          component={PrefetchLink}
          to={paths.notifications()}
          size="sm"
          display="block"
          ta="center"
          py="xs"
          onClick={close}
        >
          {t('notifications.actions.seeAll')}
        </Anchor>
      </Menu.Dropdown>
    </Menu>
  )
}
