import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import { Button, Group, Skeleton, Stack, Text } from '@mantine/core'
import {
  useListMyBlockedUsers,
  useUnblockUser,
  getListMyBlockedUsersQueryKey,
} from '@/api/endpoints/moderation/moderation'
import type { PublicUserDto } from '@/api/dto'
import { UserAvatar } from '../common/UserAvatar'
import { invalidateModeratedContent } from '@/lib/moderationCacheInvalidation'

/**
 * « Personnes bloquées », its own page under « Confidentialité » — the one place a block can be undone. Unblocking needs no
 * confirmation: it is as silent as the block was, and can be redone from any comment or ad.
 */
export function BlockedUsers() {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const { data, isLoading } = useListMyBlockedUsers()
  const unblockMutation = useUnblockUser()
  const [pendingId, setPendingId] = useState<string | null>(null)

  const handleUnblock = (user: PublicUserDto) => {
    setPendingId(user.id)
    unblockMutation.mutate(
      { userId: user.id },
      {
        onSuccess: () => {
          void queryClient.invalidateQueries({ queryKey: getListMyBlockedUsersQueryKey() })
          // What they wrote shows again in the reader's lists.
          void invalidateModeratedContent(queryClient)
          notifications.show({
            message: t('profile.blockedUsers.unblocked', { name: user.displayName }),
            color: 'green',
          })
        },
        onSettled: () => setPendingId(null),
      }
    )
  }

  const users = data?.users ?? []

  return (
    <Stack>
      <Text size="sm" c="dimmed">
        {t('profile.blockedUsers.description')}
      </Text>

      {isLoading ? (
        <Skeleton height={40} />
      ) : users.length === 0 ? (
        <Text size="sm" c="dimmed" fs="italic">
          {t('profile.blockedUsers.empty')}
        </Text>
      ) : (
        <Stack gap="xs">
          {users.map((user) => (
            <Group key={user.id} justify="space-between" wrap="nowrap">
              <Group gap="sm" wrap="nowrap" style={{ minWidth: 0 }}>
                <UserAvatar user={user} size="sm" />
                <Text size="sm" truncate>
                  {user.displayName}
                </Text>
              </Group>
              <Button
                variant="default"
                size="xs"
                onClick={() => handleUnblock(user)}
                loading={pendingId === user.id}
              >
                {t('profile.blockedUsers.unblock')}
              </Button>
            </Group>
          ))}
        </Stack>
      )}
    </Stack>
  )
}
