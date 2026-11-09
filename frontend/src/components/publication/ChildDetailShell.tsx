import type { ReactNode } from 'react'
import { Alert, Anchor, Box, Container, Group, Paper, Stack, Text, Title } from '@mantine/core'
import { IconArrowLeft } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { SiblingNav, type Sibling } from './SiblingNav'
import { CHILD_WEATHER_ANCHOR } from './useWeatherFocus'

interface ChildDetailShellProps {
  /** The parent's page, the way back to it (« Retour à la sortie »), and its name over the title. */
  backTo: string
  backLabel: string
  parentName: string
  siblings: Sibling[]
  currentId: string
  /** Names the sibling picker: « Choisir un groupe », « Choisir une étape ». */
  siblingLabel: string
  title: string
  /** Beside the title: « Vous participez », « Complet »… and the share button. */
  badges?: ReactNode
  /** On the right of the title: join or leave, edit. */
  actions?: ReactNode
  /** Under the title: the departure block, the places. */
  departure: ReactNode
  /** Under the departure: a word on another group, why one cannot join. */
  notices?: ReactNode
  error?: string | null
  /** The side column: figures, leader, people, instructions, the route's actions. */
  side: ReactNode
  /** The map, sticky beside the column on md+; null without a route. */
  map: ReactNode | null
  /** Full width under the column and the map: the route's weather, its timeline needs the room. */
  weather: ReactNode
  /** After everything: a stage's comments. */
  children?: ReactNode
}

/**
 * The page of one child of a publication — a ride's group, a trip's stage — in one layout
 * (docs/LEDGER_*.md WEB-155, design « Page groupe / Page étape »): the way back to the parent, the
 * siblings either side, one header (the parent's name, the child's title, its badges and actions,
 * its departure), then the side column beside the sticky map that fills the visible height
 * (`.detail-layout`, WEB-134) and the weather full width under them (`#meteo`).
 */
export function ChildDetailShell({
  backTo,
  backLabel,
  parentName,
  siblings,
  currentId,
  siblingLabel,
  title,
  badges,
  actions,
  departure,
  notices,
  error,
  side,
  map,
  weather,
  children,
}: ChildDetailShellProps) {
  return (
    <Container size="xl" py="xl">
      <Box mb="md">
        <Anchor component={PrefetchLink} to={backTo} size="sm" c="dimmed" underline="hover">
          <Group gap={4} wrap="nowrap">
            <IconArrowLeft size={16} aria-hidden />
            {backLabel}
          </Group>
        </Anchor>
      </Box>

      <Paper shadow="xs" p="lg" mb="lg" withBorder component="header">
        <Stack gap="md">
          <SiblingNav siblings={siblings} currentId={currentId} label={siblingLabel} />

          <Group justify="space-between" wrap="wrap" align="flex-start">
            <Stack gap={4} style={{ minWidth: 0 }}>
              <Text size="sm" c="dimmed">
                {parentName}
              </Text>
              <Group gap="sm" wrap="wrap">
                <Title order={1} size="h2">
                  {title}
                </Title>
                {badges}
              </Group>
            </Stack>
            {actions && (
              <Group gap="xs" wrap="wrap">
                {actions}
              </Group>
            )}
          </Group>

          {departure}

          {notices}

          {error && (
            <Alert color="red" variant="light">
              {error}
            </Alert>
          )}
        </Stack>
      </Paper>

      <Box className={map ? 'detail-layout' : 'detail-layout detail-layout--no-map'}>
        <Stack className="detail-side" gap="lg">
          {side}
        </Stack>
        {map && <Box className="detail-map detail-map--fill detail-map--solo">{map}</Box>}
      </Box>

      <Box
        id={CHILD_WEATHER_ANCHOR}
        mt={{ base: 'md', sm: 'lg' }}
        style={{ scrollMarginTop: 'var(--app-shell-header-height)' }}
      >
        {weather}
      </Box>

      {children && <Box mt="lg">{children}</Box>}
    </Container>
  )
}
