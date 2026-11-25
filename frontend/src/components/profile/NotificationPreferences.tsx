import { Fragment } from 'react'
import { useTranslation } from 'react-i18next'
import { Checkbox, Skeleton, Stack, Switch, Table, Text, Title } from '@mantine/core'
import {
  useGetMyNotificationPreferences,
  useUpdateMyNotificationPreferences,
  getGetMyNotificationPreferencesQueryKey,
} from '@/api/endpoints/notifications/notifications'
import { useQueryClient } from '@tanstack/react-query'
import { NotificationChannel } from '@/api/dto'
import type { NotificationType } from '@/api/dto'
import { cellOf, familiesWithRows } from './notificationFamilies'
import { ProfileCard } from './ProfileShell'
import { WebPushSettings } from './WebPushSettings'
import classes from './NotificationPreferences.module.css'

/**
 * The notification settings of `GET /api/notifications/preferences`, on their profile page: this
 * device (web push), the type × channel matrix grouped by family, the daily e-mail digest, and one
 * mute switch per team.
 *
 * Only the **channels the server says are configurable** get a column: `IN_APP` never appears (the
 * inbox is always on, and `PUT` refuses it), `PUSH` only with an FCM account, `EMAIL` only when the
 * server sends e-mail. With no channel, the matrix and the digest are hidden rather than rendered
 * empty — see `docs/plans/archive/2026-09-18-notifications.md` §5. The team mutes don't depend on
 * it: muting a team also keeps its announcements out of the inbox (§12), so they show whenever the
 * user has a team. A type the server lists no cell for has no row, and a family left without rows
 * has no heading.
 */
export function NotificationPreferences() {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const { data, isLoading } = useGetMyNotificationPreferences()
  const mutation = useUpdateMyNotificationPreferences({
    mutation: {
      onSuccess: () =>
        queryClient.invalidateQueries({ queryKey: getGetMyNotificationPreferencesQueryKey() }),
    },
  })

  if (isLoading || !data) {
    return <Skeleton height={240} radius="md" />
  }

  const hasChannels = data.channels.length > 0
  const hasTeams = data.teams.length > 0

  if (!hasChannels && !hasTeams) {
    return (
      <ProfileCard>
        <Text size="sm" c="dimmed">
          {t('notifications.preferences.nothingToSet')}
        </Text>
      </ProfileCard>
    )
  }

  const toggle = (type: NotificationType, channel: NotificationChannel, enabled: boolean) => {
    // One cell per call: the endpoint takes a list of overrides, and sending the whole matrix
    // would turn every default into an explicit override the user never chose.
    mutation.mutate({ data: { preferences: [{ type, channel, enabled }] } })
  }

  // The request is a partial update: `preferences` is required, so it goes empty when only a team
  // or the digest changes.
  const toggleTeam = (teamSlug: string, muted: boolean) => {
    mutation.mutate({ data: { preferences: [], teams: [{ teamSlug, muted }] } })
  }

  const toggleDigest = (emailDigest: boolean) => {
    mutation.mutate({ data: { preferences: [], emailDigest } })
  }

  const families = familiesWithRows(data)

  const typeLabel = (type: NotificationType) =>
    t(`notifications.typeLabel.${type satisfies NotificationType}`)
  const channelLabel = (channel: NotificationChannel) =>
    t(`notifications.channel.${channel satisfies NotificationChannel}`)

  return (
    <>
      {/* The PUSH column reaches the member's devices; this is where a browser becomes one. */}
      {data.channels.includes(NotificationChannel.PUSH) && <WebPushSettings />}

      {hasChannels && (
        <ProfileCard>
          <Stack gap="sm">
            <Title order={2} size="h5">
              {t('notifications.preferences.matrix.title')}
            </Title>
            <Text size="sm" c="dimmed">
              {t('notifications.preferences.description')}
            </Text>
            <Table.ScrollContainer minWidth={360}>
              <Table verticalSpacing="xs">
                <Table.Thead>
                  <Table.Tr>
                    <Table.Th>{t('notifications.preferences.columnType')}</Table.Th>
                    {data.channels.map((channel) => (
                      <Table.Th key={channel} w={90} ta="center">
                        {channelLabel(channel)}
                      </Table.Th>
                    ))}
                  </Table.Tr>
                </Table.Thead>
                <Table.Tbody>
                  {families.map((family) => (
                    <Fragment key={family.labelKey}>
                      <Table.Tr bg="var(--mantine-color-default-hover)">
                        <Table.Th
                          colSpan={data.channels.length + 1}
                          scope="colgroup"
                          fz="xs"
                          tt="uppercase"
                          c="dimmed"
                        >
                          {t(family.labelKey)}
                        </Table.Th>
                      </Table.Tr>
                      {family.types.map((type) => (
                        <Table.Tr key={type}>
                          <Table.Td>
                            <Text size="sm">{typeLabel(type)}</Text>
                          </Table.Td>
                          {data.channels.map((channel) => {
                            const cell = cellOf(data, type, channel)
                            return (
                              <Table.Td key={channel} className={classes.cell}>
                                {cell && (
                                  // The label is the 44 px touch target, not the 20 px box.
                                  <label className={classes.hit}>
                                    <Checkbox
                                      checked={cell.enabled}
                                      disabled={mutation.isPending}
                                      onChange={(event) =>
                                        toggle(type, channel, event.currentTarget.checked)
                                      }
                                      aria-label={t('notifications.preferences.toggleAriaLabel', {
                                        type: typeLabel(type),
                                        channel: channelLabel(channel),
                                      })}
                                    />
                                  </label>
                                )}
                              </Table.Td>
                            )
                          })}
                        </Table.Tr>
                      ))}
                    </Fragment>
                  ))}
                </Table.Tbody>
              </Table>
            </Table.ScrollContainer>
          </Stack>
        </ProfileCard>
      )}

      {/* The digest only holds e-mails back: without an e-mail channel, there is nothing to hold. */}
      {data.channels.includes(NotificationChannel.EMAIL) && (
        <ProfileCard>
          <Switch
            checked={data.emailDigest}
            disabled={mutation.isPending}
            onChange={(event) => toggleDigest(event.currentTarget.checked)}
            label={t('notifications.preferences.digest.label')}
            description={t('notifications.preferences.digest.description')}
          />
        </ProfileCard>
      )}

      {hasTeams && (
        <ProfileCard>
          <Stack gap="xs">
            <Title order={2} size="h5">
              {t('notifications.preferences.teams.title')}
            </Title>
            <Text size="sm" c="dimmed">
              {t('notifications.preferences.teams.description')}
            </Text>
            {/* On = the team's announcements reach you; the API speaks of `muted`, the reverse. */}
            {data.teams.map((team) => (
              <Switch
                key={team.teamSlug}
                checked={!team.muted}
                disabled={mutation.isPending}
                onChange={(event) => toggleTeam(team.teamSlug, !event.currentTarget.checked)}
                label={team.teamName}
                aria-label={t('notifications.preferences.teams.toggleAriaLabel', {
                  team: team.teamName,
                })}
              />
            ))}
          </Stack>
        </ProfileCard>
      )}
    </>
  )
}
