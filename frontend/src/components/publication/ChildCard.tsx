import type { ReactNode } from 'react'
import { Alert, Anchor, Box, Group, Paper, Text } from '@mantine/core'
import {
  IconAlertTriangle,
  IconArrowsMaximize,
  IconArrowUp,
  IconBolt,
  IconChevronRight,
} from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useUnits } from '@/hooks/useUnits'
import classes from './ChildCard.module.css'

interface ChildCardProps {
  /** The child's own page: the name's link, stretched over the whole card. */
  href: string
  name: string
  /** Before the name: a ride group's trace colour, a stage's number or logo. */
  marker?: ReactNode
  /** After the name: « Vous participez »… */
  badges?: ReactNode
  /** On the right of the name: a group's join actions, a stage's departure. Lifted above the link. */
  corner?: ReactNode
  /** Under the name: a group's own time and leader, a stage's places. */
  children?: ReactNode
  /** The facts row: distance, climb, speed, then whatever the card adds (a group's people). */
  meta?: ReactNode
  /** The weather line. */
  weather?: ReactNode
  /** The route's files and devices, lifted above the link. */
  routeActions?: ReactNode
  /**
   * The card's last row, full width and lifted above the link: a group's « Changer pour {groupe} »,
   * at the foot so that the group's name is never cut short beside the card's own.
   */
  footer?: ReactNode
  /** Why the last action on this card failed. */
  error?: string
  /** Lit by a hover, here or on the map. */
  highlighted?: boolean
  /** Set apart: the reader's own group. */
  emphasized?: boolean
  onHover?: (hovering: boolean) => void
}

/**
 * One card for a ride's group and a trip's stage (docs/LEDGER_*.md WEB-155, design « ChildCard »):
 * the marker, the name linking to the child's page over the whole card, the corner, the specific
 * rows, the facts, the weather line, the route's actions and the footer, in that order on both. Nothing of the
 * child's description: that is its page's.
 */
export function ChildCard({
  href,
  name,
  marker,
  badges,
  corner,
  children,
  meta,
  weather,
  routeActions,
  footer,
  error,
  highlighted = false,
  emphasized = false,
  onHover,
}: ChildCardProps) {
  return (
    <Paper
      shadow={highlighted ? 'md' : 'xs'}
      p="md"
      withBorder
      className={classes.card}
      style={{
        borderColor: highlighted || emphasized ? 'var(--mantine-primary-color-filled)' : undefined,
        backgroundColor: highlighted ? 'var(--mantine-primary-color-light)' : undefined,
        boxShadow: emphasized ? '0 0 0 1px var(--mantine-primary-color-filled)' : undefined,
      }}
      onMouseEnter={() => onHover?.(true)}
      onMouseLeave={() => onHover?.(false)}
    >
      <Group justify="space-between" wrap="nowrap" gap="sm">
        <Group gap="sm" wrap="nowrap" style={{ minWidth: 0 }}>
          {marker}
          <Anchor
            component={PrefetchLink}
            to={href}
            fw={500}
            c="inherit"
            underline="hover"
            className={classes.stretchedLink}
            style={{ minWidth: 0 }}
          >
            <Group gap={2} wrap="nowrap">
              <Text fw={600} truncate inherit>
                {name}
              </Text>
              <IconChevronRight size={16} aria-hidden style={{ flexShrink: 0 }} />
            </Group>
          </Anchor>
          {badges}
        </Group>
        {corner && (
          <Box className={classes.aboveLink} style={{ flexShrink: 0 }}>
            {corner}
          </Box>
        )}
      </Group>

      {children}

      {meta && (
        <Group mt="xs" gap="md" wrap="wrap">
          {meta}
        </Group>
      )}

      {weather && <Box mt="xs">{weather}</Box>}

      {routeActions && (
        <Box mt="sm" className={classes.aboveLink} w="fit-content">
          {routeActions}
        </Box>
      )}

      {footer && (
        <Box mt="sm" className={classes.aboveLink}>
          {footer}
        </Box>
      )}

      {error && (
        <Alert color="red" variant="light" mt="sm" icon={<IconAlertTriangle size={16} />}>
          {error}
        </Alert>
      )}
    </Paper>
  )
}

/** Lifts a control of the card's body above the stretched link, so it gets its own clicks. */
export function AboveLink({ children }: { children: ReactNode }) {
  return <Box className={classes.aboveLink}>{children}</Box>
}

/**
 * The facts every child card shows first, in the same order as the app's: distance, climb, speed
 * (docs/plans/2026-11-10-etat-des-lieux-affichage/maquettes/KIT.md §8, ledger WEB-165).
 */
export function ChildFacts({
  averageSpeed,
  distance,
  elevationGain,
}: {
  averageSpeed?: number
  distance?: number
  elevationGain?: number
}) {
  const { speed, distance: formatDistance, elevation } = useUnits()
  return (
    <>
      {distance !== undefined && (
        <Group gap={4} wrap="nowrap">
          <IconArrowsMaximize size={16} aria-hidden />
          <Text size="sm" c="dimmed">
            {formatDistance(distance)}
          </Text>
        </Group>
      )}
      {elevationGain !== undefined && (
        <Group gap={4} wrap="nowrap">
          <IconArrowUp size={16} aria-hidden />
          <Text size="sm" c="dimmed">
            {elevation(elevationGain)}
          </Text>
        </Group>
      )}
      {averageSpeed !== undefined && averageSpeed > 0 && (
        <Group gap={4} wrap="nowrap">
          <IconBolt size={16} aria-hidden />
          <Text size="sm" c="dimmed">
            {speed(averageSpeed)}
          </Text>
        </Group>
      )}
    </>
  )
}
