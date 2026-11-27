import { useTranslation } from 'react-i18next'
import { Box, Group, Paper, Stack, Text } from '@mantine/core'
import { IconCheck } from '@tabler/icons-react'
import { VisualFrame } from './VisualFrame'
import { DemoDayBox } from './DemoDayBox'
import { RouteTrace } from './RouteSketch'

/** The automatic-send switch, drawn with boxes: nothing in an illustration takes focus. */
function FakeSwitch() {
  return (
    <Box
      pos="relative"
      w={34}
      h={20}
      bg="var(--mantine-primary-color-filled)"
      style={{ flex: 'none', borderRadius: 1000 }}
    >
      <Box
        pos="absolute"
        top={2}
        left={16}
        w={16}
        h={16}
        bg="white"
        style={{ borderRadius: '50%' }}
      />
    </Box>
  )
}

/**
 * A generic bike computer showing the route, the linked account with its automatic-send switch
 * (Garmin Connect is only the example), and an upcoming ride marked « sur votre GPS ».
 */
export function DevicesVisual() {
  const { t } = useTranslation()

  return (
    <VisualFrame color="gray">
      <Stack gap="sm">
        <Group gap="lg" justify="center" align="center">
          {/* The device stays dark in both colour schemes: it is a screen, not a surface. */}
          <Stack
            w={150}
            h={220}
            p={12}
            gap={8}
            style={{
              flex: 'none',
              borderRadius: 22,
              backgroundColor: 'var(--mantine-color-dark-7)',
              border: '2px solid var(--mantine-color-dark-4)',
            }}
          >
            <Box
              style={{
                flex: 1,
                borderRadius: 10,
                overflow: 'hidden',
                display: 'flex',
                alignItems: 'center',
                backgroundColor: 'var(--mantine-color-dark-5)',
              }}
            >
              <RouteTrace height={120} stroke="var(--mantine-color-blue-4)" />
            </Box>
            <Group justify="space-between" c="white">
              <Stack gap={0}>
                <Text size="10px" c="gray.5">
                  {t('features.demo.device.distanceLabel')}
                </Text>
                <Text size="xs">{t('features.demo.device.distance')}</Text>
              </Stack>
              <Stack gap={0} align="flex-end">
                <Text size="10px" c="gray.5">
                  {t('features.demo.device.elevationLabel')}
                </Text>
                <Text size="xs">{t('features.demo.device.elevation')}</Text>
              </Stack>
            </Group>
          </Stack>
          <Stack gap="sm" style={{ flex: '1 1 220px', minWidth: 0 }}>
            <Paper withBorder radius="md" p="sm">
              <Stack gap="xs">
                <Box>
                  <Text fw={700}>{t('features.demo.device.account')}</Text>
                  <Text size="sm" c="var(--mantine-color-green-light-color)">
                    {t('features.demo.device.linked')}
                  </Text>
                </Box>
                <Group gap="xs" wrap="nowrap" align="flex-start">
                  <FakeSwitch />
                  <Text size="sm">{t('features.demo.device.autoSend')}</Text>
                </Group>
              </Stack>
            </Paper>
            <Text size="xs" c="dimmed">
              {t('features.demo.device.note')}
            </Text>
          </Stack>
        </Group>
        <Paper
          withBorder
          radius="md"
          p="sm"
          style={{ borderColor: 'var(--mantine-color-green-light-hover)' }}
        >
          <Group gap="sm" wrap="nowrap">
            <DemoDayBox
              weekday={t('features.demo.ride.weekday')}
              day={22}
              month={t('features.demo.ride.month')}
              small
            />
            <Stack gap={2} style={{ minWidth: 0 }}>
              <Text size="sm" fw={600}>
                {t('features.demo.device.ride')}
              </Text>
              <Group gap={6} wrap="nowrap" c="var(--mantine-color-green-light-color)">
                <IconCheck size={14} />
                <Text size="xs">{t('features.demo.device.onDevice')}</Text>
              </Group>
            </Stack>
          </Group>
        </Paper>
      </Stack>
    </VisualFrame>
  )
}
