import { useTranslation } from 'react-i18next'
import { Group, Paper, Progress, Stack, Text } from '@mantine/core'
import { PUBLICATION_TYPE_COLORS } from '@/lib/badgeColors.generated'
import { Badge, StatusBadge, TypeBadge } from '@/components/card/common'
import { VisualFrame } from './VisualFrame'
import { DemoButton } from './DemoButton'

interface DemoGroup {
  name: string
  pace: string
  count: number
  max: number
  state: 'open' | 'joined' | 'full'
}

/** A ride's groups, as on the ride page: pace, places, and the three registration states. */
export function RideGroupsVisual() {
  const { t } = useTranslation()
  const groups: DemoGroup[] = [
    {
      name: t('features.demo.ride.groupA'),
      pace: t('features.demo.ride.paceA'),
      count: 8,
      max: 12,
      state: 'open',
    },
    {
      name: t('features.demo.ride.groupB'),
      pace: t('features.demo.ride.paceB'),
      count: 12,
      max: 15,
      state: 'joined',
    },
    {
      name: t('features.demo.ride.groupC'),
      pace: t('features.demo.ride.paceC'),
      count: 15,
      max: 15,
      state: 'full',
    },
  ]

  return (
    <VisualFrame color={PUBLICATION_TYPE_COLORS.RIDE}>
      <Stack gap="sm">
        <Group justify="space-between">
          <Text fw={700}>{t('features.demo.ride.groupsTitle')}</Text>
          <Group gap={4}>
            <TypeBadge type="RIDE">{t('publicationType.ride')}</TypeBadge>
            <StatusBadge status="PUBLISHED">{t('status.PUBLISHED')}</StatusBadge>
          </Group>
        </Group>
        {groups.map((group) => (
          <Paper
            key={group.name}
            withBorder
            radius="lg"
            p="sm"
            style={
              group.state === 'joined'
                ? { borderColor: 'var(--mantine-primary-color-filled)' }
                : undefined
            }
          >
            <Group wrap="wrap" gap="sm" align="center">
              <Stack gap={0} style={{ flex: '1 1 140px', minWidth: 0 }}>
                <Text fw={700}>{group.name}</Text>
                <Text size="sm" c="dimmed">
                  {group.pace}
                </Text>
              </Stack>
              <Stack gap={4} style={{ flex: '1 1 110px' }}>
                <Text size="xs" c="dimmed">
                  {t('features.demo.ride.participants', {
                    registered: group.count,
                    max: group.max,
                  })}
                </Text>
                <Progress
                  value={(group.count / group.max) * 100}
                  size="sm"
                  color={group.state === 'full' ? 'gray' : 'primary'}
                />
              </Stack>
              {group.state === 'open' && <DemoButton>{t('rides.detail.groups.join')}</DemoButton>}
              {group.state === 'joined' && (
                <Group gap="xs">
                  <Badge variant="primary">{t('rides.detail.groups.joined')}</Badge>
                  <DemoButton variant="outline">{t('rides.detail.groups.leave')}</DemoButton>
                </Group>
              )}
              {group.state === 'full' && <Badge>{t('rides.detail.groups.full')}</Badge>}
            </Group>
          </Paper>
        ))}
      </Stack>
    </VisualFrame>
  )
}
