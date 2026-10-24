import { useTranslation } from 'react-i18next'
import { Group, Progress, Stack, Text } from '@mantine/core'
import type { RideGroupDto } from '@/api/dto'

/** The places bar: « 11/12 personnes », « 1 place restante ». No max, no bar. */
export function GroupPlaces({ group }: { group: RideGroupDto }) {
  const { t } = useTranslation()
  if (!group.maxParticipants) {
    return (
      <Text size="sm" c="dimmed">
        {t('rides.detail.groups.participantsNoMax', { count: group.countParticipants })}
      </Text>
    )
  }
  const max = group.maxParticipants
  const left = Math.max(0, max - group.countParticipants)
  return (
    <Stack gap={4} data-testid="group-places">
      <Group justify="space-between" gap="xs">
        <Text size="sm" fw={500}>
          {t('rides.detail.groups.participants', { current: group.countParticipants, count: max })}
        </Text>
        <Text size="sm" c="dimmed">
          {t('rides.group.placesLeft', { count: left })}
        </Text>
      </Group>
      <Progress
        value={Math.min(100, (group.countParticipants / max) * 100)}
        color={left === 0 ? 'gray' : 'primary'}
        aria-label={t('rides.detail.groups.participants', {
          current: group.countParticipants,
          count: max,
        })}
      />
    </Stack>
  )
}
