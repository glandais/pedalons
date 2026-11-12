import { Badge, Text } from '@mantine/core'
import type { RideTemplateGroupDto } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'

/**
 * A template's group and its pace, « A 28 km/h »: the name in the badge's capitals, the unit in its
 * own case — never « 28 KM/H » (docs/LEDGER_*.md WEB-167 N27). The template list and the picker.
 */
export function TemplateGroupBadge({
  group,
  color,
}: {
  group: Pick<RideTemplateGroupDto, 'name' | 'averageSpeed'>
  color: 'primary' | 'gray'
}) {
  const { speed } = useUnits()
  return (
    <Badge variant="light" color={color} size="sm">
      {group.name}
      {group.averageSpeed ? (
        <Text span ml={4} c="dimmed" tt="none" inherit data-testid="template-group-speed">
          {speed(group.averageSpeed)}
        </Text>
      ) : null}
    </Badge>
  )
}
