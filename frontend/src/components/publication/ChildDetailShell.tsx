import type { ReactNode } from 'react'
import { Anchor, Box, Container, Group, Stack } from '@mantine/core'
import { IconArrowLeft } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { DetailHeader } from './DetailHeader'
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
  /** Beside the title: « Vous participez »… */
  badges?: ReactNode
  /** The header's actions, by name: their order is `DetailHeader`'s (docs/LEDGER_*.md WEB-206). */
  primary?: ReactNode
  gps?: ReactNode
  edit?: ReactNode
  /** Renders the share button with this title. */
  shareTitle?: string
  /** The `⋯` menu. */
  more?: ReactNode
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
  primary,
  gps,
  edit,
  shareTitle,
  more,
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

      <DetailHeader
        top={<SiblingNav siblings={siblings} currentId={currentId} label={siblingLabel} />}
        context={parentName}
        title={title}
        badges={badges}
        primary={primary}
        gps={gps}
        edit={edit}
        shareTitle={shareTitle}
        more={more}
        error={error}
      >
        {departure}

        {notices}
      </DetailHeader>

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
