import type { ReactNode } from 'react'
import { Box, Group, Text } from '@mantine/core'
import { DayBox, type DayBoxTone } from '@/components/common/DayBox'
import { useRendezvousFormat } from '@/hooks/useRendezvousFormat'

interface CardDayOverlayProps {
  /** The departure the card gives: the reader's group's for a registered ride. */
  date: string
  /** The entity's zone: the box and the pill judge the day in it (docs/LEDGER_*.md API-60). */
  zone: string | null | undefined
  tone?: DayBoxTone
  /**
   * Whether the « Aujourd'hui » / « Demain » pill may show: not on a ride or trip already started or
   * cancelled (docs/LEDGER_*.md MOB-115, as the app). The day box stays. Defaults to true.
   */
  showRelative?: boolean
  /** More on the top right, after the pill (« J'y vais » on « Ma prochaine sortie »). */
  extra?: ReactNode
  /** The card's `⋯` menu sits in the top right corner (`Card.actions`): the pill moves left of it. */
  clearActions?: boolean
}

/**
 * What a card lays on its picture (docs/BRANDING.md §7.1, ledger `BRAND-8`, docs/LEDGER_*.md
 * WEB-138): the posed day box on the top left, 16 px in; on the top right, only today or tomorrow,
 * a white pill « Aujourd'hui » / « Demain ». Both are white, whatever the colour scheme, so they
 * read the same on a photo and on the fallback gradient. The parent is `position: relative`.
 */
export function CardDayOverlay({
  date,
  zone,
  tone = 'primary',
  showRelative = true,
  extra,
  clearActions = false,
}: CardDayOverlayProps) {
  const rendezvous = useRendezvousFormat(zone)
  const relative = showRelative ? rendezvous.formatRelativeDay(date) : null
  return (
    <>
      <Box pos="absolute" top={16} left={16}>
        <DayBox date={date} zone={rendezvous.zone} tone={tone} variant="posed" />
      </Box>
      {(relative || extra) && (
        // The `⋯` button is 28 px wide, 10 px in from the corner.
        <Group pos="absolute" top={16} right={clearActions ? 46 : 16} gap={6} justify="flex-end">
          {relative && (
            <Text
              span
              fz={12}
              fw={700}
              lh={1}
              px={10}
              py={6}
              data-testid="day-pill"
              suppressHydrationWarning
              style={{
                borderRadius: 'var(--mantine-radius-xl)',
                // Not `primary-light-color`: in the dark scheme that is a pale shade, unreadable on
                // white. primary-8 is 5.6:1 on it.
                color: 'var(--mantine-color-primary-8)',
                background: 'rgba(255, 255, 255, 0.95)',
                boxShadow: 'var(--mantine-shadow-xs)',
              }}
            >
              {relative}
            </Text>
          )}
          {extra}
        </Group>
      )}
    </>
  )
}
