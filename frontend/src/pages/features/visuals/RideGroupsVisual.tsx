import { useTranslation } from 'react-i18next'
import { Group, Paper, Stack, Text, Title } from '@mantine/core'
import { IconCloud } from '@tabler/icons-react'
import { PUBLICATION_TYPE_COLORS } from '@/lib/badgeColors.generated'
import { Badge, TypeBadge } from '@/components/card/common'
import { VisualFrame } from './VisualFrame'
import { DemoDayBox } from './DemoDayBox'

interface DemoGroup {
  time: string
  name: string
  pace: string
  count: number
  max: number
  state: 'open' | 'joined' | 'full'
}

/**
 * A ride and its groups, as on the ride page: the group you joined detached on top, then the
 * others, each with its own start time, its places or the « Complet » badge, and the weather.
 */
export function RideGroupsVisual() {
  const { t } = useTranslation()
  const joined: DemoGroup = {
    time: '08:15',
    name: t('features.demo.ride.groupB'),
    pace: t('features.demo.ride.paceB'),
    count: 12,
    max: 15,
    state: 'joined',
  }
  const others: DemoGroup[] = [
    {
      time: '08:00',
      name: t('features.demo.ride.groupA'),
      pace: t('features.demo.ride.paceA'),
      count: 12,
      max: 15,
      state: 'open',
    },
    {
      time: '08:30',
      name: t('features.demo.ride.groupC'),
      pace: t('features.demo.ride.paceC'),
      count: 15,
      max: 15,
      state: 'full',
    },
  ]

  const renderGroup = (group: DemoGroup) => (
    <Paper
      key={group.name}
      withBorder
      radius="md"
      p="sm"
      bg={group.state === 'joined' ? 'var(--mantine-primary-color-light)' : undefined}
      style={
        group.state === 'joined'
          ? { borderColor: 'var(--mantine-primary-color-filled)' }
          : undefined
      }
    >
      <Group wrap="wrap" gap="sm" align="center">
        <Text fz={20} fw={700} style={{ flex: 'none' }}>
          {group.time}
        </Text>
        <Stack gap={0} style={{ flex: '1 1 140px', minWidth: 0 }}>
          <Text fw={700}>{group.name}</Text>
          <Text size="sm" c="dimmed">
            {group.pace}
          </Text>
        </Stack>
        {group.state === 'joined' && (
          <Badge variant="primary">{t('rides.detail.groups.joined')}</Badge>
        )}
        {group.state === 'open' && (
          <Text size="sm" fw={600}>
            {t('features.demo.ride.participants', { registered: group.count, max: group.max })}
          </Text>
        )}
        {group.state === 'full' && <Badge>{t('rides.detail.groups.full')}</Badge>}
      </Group>
    </Paper>
  )

  return (
    <VisualFrame color={PUBLICATION_TYPE_COLORS.RIDE}>
      <Paper withBorder radius="md" p="md" bg="var(--mantine-color-body)">
        <Stack gap="sm">
          <Group gap="sm" wrap="nowrap" align="center">
            <DemoDayBox
              weekday={t('features.demo.ride.weekday')}
              day={22}
              month={t('features.demo.ride.month')}
            />
            <Stack gap={4} style={{ minWidth: 0 }} align="flex-start">
              <TypeBadge type="RIDE">{t('publicationType.ride')}</TypeBadge>
              <Title order={3} size="h4">
                {t('features.demo.ride.title')}
              </Title>
              <Text size="sm" c="dimmed">
                {t('features.demo.ride.place')}
              </Text>
            </Stack>
          </Group>
          {renderGroup(joined)}
          {others.map(renderGroup)}
          <Group gap={8} wrap="nowrap" c="dimmed">
            <IconCloud size={18} style={{ flex: 'none' }} />
            <Text size="sm">{t('features.demo.ride.weather')}</Text>
          </Group>
        </Stack>
      </Paper>
    </VisualFrame>
  )
}
