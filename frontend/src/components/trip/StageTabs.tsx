import { useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { ScrollArea, Tabs, Stack, Text } from '@mantine/core'
import { useMediaQuery } from '@mantine/hooks'
import { IconHome } from '@tabler/icons-react'
import type { TripDto } from '@/api/dto'
import { Rendezvous } from '../common/Rendezvous'
import { paths } from '@/config/paths'
import { EntityLogo } from '../common/EntityLogo'

interface StageTabsProps {
  trip: TripDto
  teamSlug: string
  currentTab: 'overview' | string // 'overview' or stageSlug
}

export function StageTabs({ trip, teamSlug, currentTab }: StageTabsProps) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  // Below the two-column breakpoint the vertical rail pushed the stage content off screen —
  // a ten-day trip stacked ten tabs before any content. `getInitialValueInEffect` keeps the
  // first client render identical to the SSR one, so hydration stays in parity.
  const isWide = useMediaQuery('(min-width: 64em)', true, { getInitialValueInEffect: true })
  const orientation = isWide ? 'vertical' : 'horizontal'

  const handleTabChange = (value: string | null) => {
    if (!value) return

    if (value === 'overview') {
      navigate(paths.trip(teamSlug, trip.slug))
    } else {
      navigate(paths.stage(teamSlug, trip.slug, value))
    }
  }

  return (
    <Tabs orientation={orientation} value={currentTab} onChange={handleTabChange} variant="pills">
      <ScrollArea type={isWide ? 'never' : 'auto'} offsetScrollbars={!isWide}>
        <Tabs.List style={{ flexWrap: isWide ? undefined : 'nowrap' }}>
          <Tabs.Tab value="overview" leftSection={<IconHome size={16} />}>
            {t('trips.tabs.overview')}
          </Tabs.Tab>

          {trip.stages?.map((stage, index) => (
            <Tabs.Tab
              key={stage.id}
              value={stage.slug}
              leftSection={
                stage.media.assets.logo ? (
                  <EntityLogo logo={stage.media.assets.logo} alt={stage.name} size="sm" />
                ) : (
                  <Text size="sm" fw={700} w={20} ta="center">
                    {index + 1}
                  </Text>
                )
              }
            >
              <Stack gap={0}>
                <Text size="sm" fw={500} lineClamp={1}>
                  {stage.name}
                </Text>
                <Text size="xs" opacity={0.7}>
                  <Rendezvous date={stage.dateTime} zone={stage.timezone} format="day" />
                </Text>
              </Stack>
            </Tabs.Tab>
          ))}
        </Tabs.List>
      </ScrollArea>
    </Tabs>
  )
}
