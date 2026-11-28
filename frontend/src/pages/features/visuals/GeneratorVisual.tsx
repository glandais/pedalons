import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Box, Center, Divider, Group, Paper, SimpleGrid, Stack, Text, Title } from '@mantine/core'
import { IconCircleDot, IconMap, IconMinus, IconPlus, IconSelector } from '@tabler/icons-react'
import { useUnits } from '@/hooks/useUnits'
import { routeColor } from '@/lib/routeColors'
import { DemoButton } from './DemoButton'
import { FakeSegments, FakeSlider } from './FakeControls'
import { MAP_CASING, MAP_CLASS, MAP_ROAD, MAP_WATER, MapBackdrop, Pin } from './MapBackdrop'

/** Fictional proposals; the first is the selected one. */
const PROPOSALS = [
  { distanceM: 82_400, ascentM: 1_240, teamShare: 74, unpaved: 28 },
  { distanceM: 79_100, ascentM: 980, teamShare: 88, unpaved: 22 },
]

/** The compass cells in the real picker's order, the centre one being the « any direction » dot. */
const COMPASS = ['NW', 'N', 'NE', 'W', null, 'E', 'SW', 'S', 'SE'] as const

const LOOP_1 = 'M250 280 C200 340 120 400 110 500 C100 600 190 660 250 600 C300 550 270 400 250 280'
const LOOP_2 = 'M250 280 C330 270 450 320 460 420 C470 520 380 560 320 500 C280 460 270 360 250 280'

/** A labelled setting, as on the real panel. */
function Setting({ label, children }: { label: string; children: ReactNode }) {
  return (
    <Stack gap={4}>
      <Text size="sm" fw={500}>
        {label}
      </Text>
      {children}
    </Stack>
  )
}

/** The real `GeneratedRouteCard`, drawn: the trace's colour, the figures, the way into the editor. */
function ProposalCard({
  proposal,
  index,
  selected,
}: {
  proposal: (typeof PROPOSALS)[number]
  index: number
  selected: boolean
}) {
  const { t } = useTranslation()
  const { distance, elevation, percent } = useUnits()

  return (
    <Paper
      withBorder
      radius="md"
      p="sm"
      style={selected ? { borderColor: routeColor(index), borderWidth: 2 } : undefined}
    >
      <Stack gap={4}>
        <Group justify="space-between" wrap="nowrap" gap="xs">
          <Group gap="xs" wrap="nowrap">
            <Box w={4} h={20} bg={routeColor(index)} style={{ borderRadius: 2 }} />
            <Text fw={600}>{t('routeGenerator.card.title', { index: index + 1 })}</Text>
          </Group>
          <Text fw={600}>{distance(proposal.distanceM)}</Text>
        </Group>
        <Text size="sm">
          {t('routeGenerator.card.ascent', { ascent: elevation(proposal.ascentM) })}
        </Text>
        <Text size="sm" c="dimmed">
          {t('routeGenerator.card.teamShare', { share: percent(proposal.teamShare) })}
        </Text>
        <Text size="sm" c="dimmed">
          {t('routeGenerator.card.unpaved', { share: percent(proposal.unpaved) })}
        </Text>
        <Group justify="flex-end" mt={4}>
          <DemoButton variant="light" size="compact-md">
            {t('routeGenerator.card.open')}
          </DemoButton>
        </Group>
      </Stack>
    </Paper>
  )
}

/**
 * The route generator in miniature, drawn inertly after the real panel: the settings (boxes, never
 * inputs), the two proposal cards and the map with both loops. Fictional demo content; the figures
 * go through `useUnits` like the real cards.
 */
export function GeneratorVisual() {
  const { t } = useTranslation()
  const { distance } = useUnits()

  return (
    <Paper
      aria-hidden
      withBorder
      radius="xl"
      shadow="md"
      style={{ overflow: 'hidden', display: 'flex', flexWrap: 'wrap' }}
    >
      <Stack gap="md" p="md" style={{ flex: '1 1 300px', minWidth: 0 }}>
        <Title order={3} size="h4">
          {t('routeGenerator.title')}
        </Title>
        <Setting label={t('routeGenerator.start.label')}>
          <Group
            justify="space-between"
            wrap="nowrap"
            px="sm"
            h={34}
            bg="var(--mantine-color-default)"
            style={{
              border: '1px solid var(--mantine-color-default-border)',
              borderRadius: 'var(--mantine-radius-md)',
            }}
          >
            <Text size="sm" truncate>
              {t('features.demo.generator.startValue')}
            </Text>
            <IconSelector size={16} color="var(--mantine-color-dimmed)" />
          </Group>
          <Group gap="xs">
            <DemoButton variant="subtle" size="compact-sm">
              {t('routeGenerator.start.pick')}
            </DemoButton>
          </Group>
        </Setting>
        <Setting label={t('routeGenerator.end.label')}>
          <FakeSegments
            items={[t('routeGenerator.end.loop'), t('routeGenerator.end.elsewhere')]}
            active={0}
          />
        </Setting>
        <Setting label={t('routeGenerator.bearing.label')}>
          <SimpleGrid cols={3} spacing={4} maw={180}>
            {COMPASS.map((point, i) =>
              point ? (
                <DemoButton key={point} variant="default" size="compact-sm">
                  {t(`rides.weather.compass.${point}`)}
                </DemoButton>
              ) : (
                <DemoButton key={i} variant="filled" size="compact-sm">
                  <IconCircleDot size={14} />
                </DemoButton>
              )
            )}
          </SimpleGrid>
        </Setting>
        <Stack gap={4}>
          <Group justify="space-between" wrap="nowrap" gap="xs">
            <Text size="sm" fw={500}>
              {t('routeGenerator.distance.label')}
            </Text>
            <Text size="sm">{distance(80_000)}</Text>
          </Group>
          <FakeSlider percent={33} />
        </Stack>
        <Setting label={t('routeGenerator.discovery.label')}>
          <FakeSlider percent={25} marks={5} />
          <Group justify="space-between" mt={8} wrap="nowrap" gap="xs">
            <Text size="xs" c="dimmed">
              {t('routeGenerator.discovery.low')}
            </Text>
            <Text size="xs" c="dimmed">
              {t('routeGenerator.discovery.high')}
            </Text>
          </Group>
        </Setting>
        <Setting label={t('routeGenerator.type.label')}>
          <FakeSegments
            items={[
              t('routes.surfaceType.ROAD'),
              t('routes.surfaceType.GRAVEL'),
              t('routes.surfaceType.MTB'),
            ]}
            active={1}
          />
        </Setting>
        <Setting label={t('routeGenerator.unpaved.label')}>
          <FakeSegments
            items={[
              t('routeGenerator.unpaved.low'),
              t('routeGenerator.unpaved.usual'),
              t('routeGenerator.unpaved.high'),
            ]}
            active={1}
            columns="1fr 1.6fr 1.1fr"
          />
        </Setting>
        <DemoButton size="md" fullWidth>
          {t('routeGenerator.generate')}
        </DemoButton>
        <Stack gap="sm" mt={4}>
          {PROPOSALS.map((proposal, index) => (
            <ProposalCard key={index} proposal={proposal} index={index} selected={index === 0} />
          ))}
        </Stack>
      </Stack>
      <Stack
        gap={0}
        bg="var(--mantine-color-default-hover)"
        style={{
          flex: '999 1 480px',
          minWidth: 0,
          borderLeft: '1px solid var(--mantine-color-default-border)',
        }}
      >
        <Box pos="relative" mih={380} style={{ flex: '1 1 auto' }}>
          <svg
            className={MAP_CLASS}
            viewBox="0 0 540 760"
            preserveAspectRatio="xMidYMid slice"
            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}
          >
            <MapBackdrop width={540} height={760} />
            <path
              d="M-20 220 C120 180 220 270 330 230 C430 195 480 240 560 210"
              stroke={MAP_WATER}
              strokeWidth={22}
              fill="none"
            />
            <g stroke={MAP_ROAD} fill="none" strokeLinecap="round">
              <path d="M60 0 L140 760" strokeWidth={4} />
              <path d="M0 60 C180 80 340 30 540 70" strokeWidth={4} />
              <path d="M380 0 C370 200 420 420 470 760" strokeWidth={3} />
              <path d="M0 400 L540 360" strokeWidth={3} />
              <path d="M240 0 C230 300 280 600 250 760" strokeWidth={2} />
              <path d="M0 640 C200 620 360 670 540 630" strokeWidth={2} />
            </g>
            <g fill="none" strokeLinecap="round" strokeLinejoin="round">
              <path d={LOOP_2} stroke={MAP_CASING} strokeWidth={9} />
              <path d={LOOP_2} stroke={routeColor(1)} strokeWidth={4} />
              <path d={LOOP_1} stroke={MAP_CASING} strokeWidth={11} />
              <path d={LOOP_1} stroke={routeColor(0)} strokeWidth={6} />
            </g>
            <Pin x={250} y={280} />
          </svg>
          <Group
            px="sm"
            w={210}
            h={32}
            pos="absolute"
            left={12}
            top={12}
            bg="var(--mantine-color-body)"
            style={{
              border: '1px solid var(--mantine-color-default-border)',
              borderRadius: 'var(--mantine-radius-md)',
            }}
          >
            <Text size="xs" c="dimmed">
              {t('map.search.placeholder')}
            </Text>
          </Group>
          <Paper withBorder radius="md" pos="absolute" left={12} top={56} w={28}>
            <Center h={28}>
              <IconPlus size={14} />
            </Center>
            <Divider />
            <Center h={28}>
              <IconMinus size={14} />
            </Center>
          </Paper>
          <Paper withBorder radius="md" pos="absolute" right={12} top={12} w={32} h={32}>
            <Center h="100%">
              <IconMap size={16} />
            </Center>
          </Paper>
          <Text
            fz={11}
            c="dimmed"
            px={6}
            py={2}
            pos="absolute"
            right={8}
            bottom={8}
            bg="color-mix(in srgb, var(--mantine-color-body) 90%, transparent)"
            style={{ borderRadius: 'var(--mantine-radius-xs)' }}
          >
            {t('routes.surface.attribution')}
          </Text>
        </Box>
      </Stack>
    </Paper>
  )
}
