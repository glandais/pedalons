import { useTranslation } from 'react-i18next'
import { Group, Stack, Text, ThemeIcon } from '@mantine/core'
import type { WaypointDto } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { WAYPOINT_TYPE_COLORS } from '@/lib/badgeColors.generated'
import { waypointTypeOf } from '@/lib/waypoints'
import { WAYPOINT_ICONS } from '../map/waypointIcons'

/** What a waypoint says about itself: its type, name, description and where it sits on the route. */
export function WaypointDetails({ waypoint }: { waypoint: WaypointDto }) {
  const { t } = useTranslation()
  const { distance } = useUnits()
  const type = waypointTypeOf(waypoint.type)
  const { Icon } = WAYPOINT_ICONS[type]

  return (
    <Stack gap={4}>
      <Group gap="xs" wrap="nowrap">
        <ThemeIcon
          variant="filled"
          color={WAYPOINT_TYPE_COLORS[type]}
          radius="xl"
          size={24}
          aria-hidden
        >
          <Icon size={14} />
        </ThemeIcon>
        <Text size="xs" c="dimmed">
          {t(`routes.waypoints.type.${type}`)}
        </Text>
      </Group>
      {waypoint.name && (
        <Text fw={600} size="sm" style={{ overflowWrap: 'anywhere' }}>
          {waypoint.name}
        </Text>
      )}
      {waypoint.description && (
        <Text size="sm" style={{ whiteSpace: 'pre-line', overflowWrap: 'anywhere' }}>
          {waypoint.description}
        </Text>
      )}
      <Text size="xs" c="dimmed">
        {waypoint.distance != null
          ? t('routes.waypoints.fromStart', { distance: distance(waypoint.distance) })
          : t('routes.waypoints.offTrack')}
      </Text>
    </Stack>
  )
}
