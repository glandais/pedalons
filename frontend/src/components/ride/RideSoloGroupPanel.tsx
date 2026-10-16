import { useTranslation } from 'react-i18next'
import { IconAlertTriangle } from '@tabler/icons-react'
import { Alert, Badge, Box, Group, Paper, Stack, Text, Title } from '@mantine/core'
import type { RideDto, RideGroupDto, RouteDetailDto } from '@/api/dto'
import { GroupJoinActions } from '@/components/ride/group/GroupJoinActions'
import { GroupLeader } from '@/components/ride/group/GroupLeader'
import { GroupPlaces } from '@/components/ride/group/GroupPlaces'
import { RideGroupRouteActions } from '@/components/ride/RideGroupRouteActions'
import type { GroupAction } from '@/pages/ride/rideGroupData'

interface RideSoloGroupPanelProps {
  teamSlug: string
  ride: RideDto
  /** The ride's one group (`soloGroup`). */
  group: RideGroupDto
  /** `groupAction(ride, group, isMember)`: « Rejoindre », « Quitter » or nothing. */
  action: GroupAction
  membership: {
    join: (groupId: string) => void
    leave: (groupId: string) => void
    isPending: boolean
  }
  /** Every route of the ride, from its one `/routes/bulk` read. */
  routesBySlug: Map<string, RouteDetailDto>
  /** The colour of the group's trace on the ride's map (`routeColorsById`). */
  trackColor?: string
  /** Why the last join/leave failed. */
  error?: string
}

/**
 * The group of a solo ride, on the ride's page (ledger WEB-79): a ride with one group has no group
 * page, so its page carries what the group page would — the group's name and trace colour (a
 * block, not a link), its places, « Rejoindre » / « Quitter » / « Complet », its leader when one is
 * designated, and its route's actions. Its figures and participants follow it on the page.
 *
 * A Paper but not a `<section>`, like a group card: the e2e `groupCard()` finds it the same way.
 */
export function RideSoloGroupPanel({
  teamSlug,
  ride,
  group,
  action,
  membership,
  routesBySlug,
  trackColor,
  error,
}: RideSoloGroupPanelProps) {
  const { t } = useTranslation()
  const routeSlug = group.routeSlug ?? ride.routeSlug
  const route = routeSlug ? routesBySlug.get(routeSlug) : undefined

  return (
    <Paper
      withBorder
      p="md"
      data-testid="solo-group"
      style={
        group.registered
          ? {
              borderColor: 'var(--mantine-primary-color-filled)',
              boxShadow: '0 0 0 1px var(--mantine-primary-color-filled)',
            }
          : undefined
      }
    >
      <Stack gap="sm">
        <Group justify="space-between" wrap="nowrap" align="flex-start">
          <Stack gap={0} style={{ minWidth: 0 }}>
            <Text size="xs" tt="uppercase" fw={600} c="dimmed">
              {t('rides.detail.groups.soloLabel')}
            </Text>
            <Group gap="sm" wrap="nowrap" style={{ minWidth: 0 }}>
              {trackColor && (
                <Box
                  data-testid="group-track-color"
                  aria-hidden
                  w={4}
                  h={20}
                  style={{ flexShrink: 0, borderRadius: 2, backgroundColor: trackColor }}
                />
              )}
              <Title order={3} size="h4" style={{ minWidth: 0 }} lineClamp={1}>
                {group.name}
              </Title>
              {group.registered && (
                <Badge size="sm" color="primary" variant="light" style={{ flexShrink: 0 }}>
                  {t('rides.detail.groups.joined')}
                </Badge>
              )}
            </Group>
          </Stack>
          <GroupJoinActions action={action} group={group} membership={membership} showFull />
        </Group>

        <GroupPlaces group={group} />

        <GroupLeader group={group} framed={false} />

        {routeSlug && (
          <RideGroupRouteActions teamSlug={teamSlug} routeSlug={routeSlug} route={route} />
        )}

        {error && (
          <Alert color="red" variant="light" icon={<IconAlertTriangle size={16} />}>
            {error}
          </Alert>
        )}
      </Stack>
    </Paper>
  )
}
