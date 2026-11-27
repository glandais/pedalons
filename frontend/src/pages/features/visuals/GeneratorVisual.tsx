import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Box, Group, Paper, Stack, Text, Title } from '@mantine/core'
import { IconSparkles } from '@tabler/icons-react'
import { DemoButton } from './DemoButton'
import { ElevationSketch } from './RouteSketch'
import { MapBackdrop, Pin } from './MapBackdrop'
import { TRACK_SURFACE_COLORS } from '@/lib/badgeColors.generated'

const FIELD_STYLE = {
  borderRadius: 'var(--mantine-radius-md)',
  border: '1px solid var(--mantine-color-default-border)',
} as const

/** A labelled setting; the optional `value` sits on the label's right, as on the real panel. */
function Setting({
  label,
  value,
  children,
}: {
  label: string
  value?: string
  children: ReactNode
}) {
  return (
    <Stack gap={6}>
      <Group justify="space-between" wrap="nowrap" gap="xs">
        <Text size="sm" fw={500}>
          {label}
        </Text>
        {value && (
          <Text size="sm" fw={600}>
            {value}
          </Text>
        )}
      </Group>
      {children}
    </Stack>
  )
}

/** A slider drawn with boxes: not an input, so nothing in the illustration takes focus. */
function FakeSlider({ percent }: { percent: number }) {
  return (
    <Box pos="relative" h={18}>
      <Box
        pos="absolute"
        top={7}
        left={0}
        right={0}
        h={4}
        bg="var(--mantine-color-default-border)"
        style={{ borderRadius: 2 }}
      />
      <Box
        pos="absolute"
        top={7}
        left={0}
        h={4}
        w={`${percent}%`}
        bg="var(--mantine-primary-color-filled)"
        style={{ borderRadius: 2 }}
      />
      <Box
        pos="absolute"
        top={1}
        w={16}
        h={16}
        bg="var(--mantine-primary-color-filled)"
        style={{
          left: `calc(${percent}% - ${(percent / 100) * 16}px)`,
          borderRadius: '50%',
          border: '2px solid var(--mantine-color-body)',
        }}
      />
    </Box>
  )
}

/** A segmented switch drawn with boxes; `active` is the selected segment. */
function FakeSegments({ items, active }: { items: string[]; active: number }) {
  return (
    <Box
      p={3}
      bg="var(--mantine-color-default-hover)"
      style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${items.length}, minmax(0, 1fr))`,
        borderRadius: 'var(--mantine-radius-md)',
      }}
    >
      {items.map((item, index) => (
        <Text
          key={item}
          size="sm"
          fw={500}
          ta="center"
          py={5}
          c={index === active ? undefined : 'dimmed'}
          bg={index === active ? 'var(--mantine-color-body)' : undefined}
          style={{ borderRadius: 'var(--mantine-radius-sm)' }}
        >
          {item}
        </Text>
      ))}
    </Box>
  )
}

/**
 * The route generator in miniature, drawn inertly: the settings panel (boxes, never inputs), the
 * map with a proposed loop (paved and unpaved in the planner's surface colours), the floating proposal card,
 * and the profile coloured by slope. Fictional demo content.
 */
export function GeneratorVisual() {
  const { t } = useTranslation()
  const road = `var(--mantine-color-${TRACK_SURFACE_COLORS.PAVED}-filled)`
  const path = `var(--mantine-color-${TRACK_SURFACE_COLORS.GRAVEL}-filled)`

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
          {t('features.demo.generator.title')}
        </Title>
        <Setting label={t('features.demo.generator.start')}>
          <Text size="sm" px="sm" py={7} style={FIELD_STYLE}>
            {t('features.demo.generator.startValue')}
          </Text>
        </Setting>
        <Setting label={t('features.demo.generator.finish')}>
          <FakeSegments
            items={[
              t('features.demo.generator.finishHere'),
              t('features.demo.generator.finishElsewhere'),
            ]}
            active={0}
          />
        </Setting>
        <Setting
          label={t('features.demo.generator.distance')}
          value={t('features.demo.generator.distanceValue')}
        >
          <FakeSlider percent={33} />
        </Setting>
        <Setting label={t('features.demo.generator.discovery')}>
          <FakeSlider percent={25} />
          <Text size="xs" c="dimmed">
            {t('features.demo.generator.discoveryHint')}
          </Text>
        </Setting>
        <Setting label={t('features.demo.generator.practice')}>
          <FakeSegments
            items={[
              t('features.demo.generator.road'),
              t('features.demo.generator.gravel'),
              t('features.demo.generator.mtb'),
            ]}
            active={1}
          />
        </Setting>
        <Setting
          label={t('features.demo.generator.unpaved')}
          value={t('features.demo.generator.unpavedValue')}
        >
          <FakeSlider percent={30} />
        </Setting>
        <DemoButton size="md" leftSection={<IconSparkles size={18} />}>
          {t('features.demo.generator.submit')}
        </DemoButton>
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
            viewBox="0 0 700 400"
            preserveAspectRatio="xMidYMid slice"
            style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}
          >
            <MapBackdrop width={700} height={400} />
            <g stroke="var(--mantine-color-body)" fill="none">
              <path d="M80 0 L140 400" strokeWidth={5} />
              <path d="M0 120 C200 140 400 90 700 130" strokeWidth={5} />
              <path d="M420 0 C430 120 470 260 520 400" strokeWidth={4} />
              <path d="M0 220 L700 200" strokeWidth={3} />
              <path d="M260 0 C250 90 300 180 280 400" strokeWidth={3} />
              <path
                d="M170 250 C150 190 190 120 260 105 C330 90 400 70 470 110 C540 150 600 170 590 230 C580 290 500 320 430 300 C370 284 320 320 260 310 C210 302 185 290 170 250 Z"
                strokeWidth={9}
                strokeLinejoin="round"
              />
            </g>
            <g fill="none" strokeWidth={5} strokeLinecap="round">
              <path d="M170 250 C150 190 190 120 260 105 C330 90 400 70 470 110" stroke={road} />
              <path d="M470 110 C540 150 600 170 590 230" stroke={path} />
              <path
                d="M590 230 C580 290 500 320 430 300 C370 284 320 320 260 310 C210 302 185 290 170 250"
                stroke={road}
              />
            </g>
            <Pin x={170} y={250} />
            <circle
              cx={470}
              cy={110}
              r={11}
              fill="var(--mantine-color-grape-filled)"
              stroke="var(--mantine-color-body)"
              strokeWidth={2}
            />
          </svg>
          <Paper
            shadow="lg"
            radius="md"
            p="sm"
            pos="absolute"
            left={16}
            top={16}
            w="min(300px, calc(100% - 32px))"
          >
            <Stack gap={8}>
              <Group justify="space-between">
                <Text fw={700}>{t('features.demo.generator.proposal')}</Text>
                <Text size="xs" c="dimmed">
                  {t('features.demo.generator.proposalCount')}
                </Text>
              </Group>
              <Group gap="md">
                <Text size="sm" fw={600}>
                  {t('features.demo.generator.proposalDistance')}
                </Text>
                <Text size="sm" fw={600}>
                  {t('features.demo.generator.proposalElevation')}
                </Text>
                <Text size="sm" fw={600}>
                  {t('features.demo.generator.proposalClimbs')}
                </Text>
              </Group>
              <Text size="xs" c="dimmed">
                {t('features.demo.generator.proposalShare')}
              </Text>
              <Group gap={8}>
                <DemoButton>{t('features.demo.generator.use')}</DemoButton>
                <DemoButton variant="default">{t('features.demo.generator.openEditor')}</DemoButton>
              </Group>
            </Stack>
          </Paper>
          <Group
            gap="sm"
            px="xs"
            py={6}
            pos="absolute"
            right={16}
            bottom={12}
            bg="var(--mantine-color-body)"
            style={{ borderRadius: 'var(--mantine-radius-md)' }}
          >
            {[
              { color: road, label: t('features.demo.generator.legendRoad') },
              { color: path, label: t('features.demo.generator.legendPath') },
            ].map((item) => (
              <Group key={item.label} gap={6} wrap="nowrap">
                <Box w={14} h={4} style={{ borderRadius: 2, backgroundColor: item.color }} />
                <Text size="xs">{item.label}</Text>
              </Group>
            ))}
          </Group>
        </Box>
        <Box
          bg="var(--mantine-color-body)"
          px="md"
          pt="xs"
          pb={6}
          style={{ borderTop: '1px solid var(--mantine-color-default-border)' }}
        >
          <ElevationSketch height={80} />
          <Group justify="space-between" wrap="nowrap" gap="xs" mt={4}>
            <Text size="xs" c="dimmed">
              {t('features.demo.generator.profileStart')}
            </Text>
            <Text size="xs" c="dimmed" ta="center">
              {t('features.demo.generator.profileClimb')}
            </Text>
            <Text size="xs" c="dimmed">
              {t('features.demo.generator.proposalDistance')}
            </Text>
          </Group>
        </Box>
      </Stack>
    </Paper>
  )
}
