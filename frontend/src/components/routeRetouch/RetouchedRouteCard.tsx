import { useTranslation } from 'react-i18next'
import { Box, Card, Group, Stack, Text, UnstyledButton } from '@mantine/core'
import { RetouchVariant, type RetouchedRouteDto } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { routeColor } from '@/lib/routeColors'
import { isTruncation } from '@/lib/routeRetouch'

/** From this many metres kept without a map check, a discreet note is shown. */
export const UNMATCHED_NOTE_METERS = 500

interface RetouchedRouteCardProps {
  candidate: RetouchedRouteDto
  index: number
  /** The original route's distance and ascent, as the engine measured them. */
  originalDistanceM: number
  originalAscentM?: number
  selected: boolean
  /** Hover highlights the line on the map, it does not select. */
  onHover: (index: number | null) => void
  onSelect: (index: number) => void
  /** The previous seed's cards, dimmed while the new ones come. */
  dimmed?: boolean
}

/** One proposal: before → after, what was replaced, how much of the route is kept. */
export function RetouchedRouteCard({
  candidate,
  index,
  originalDistanceM,
  originalAscentM,
  selected,
  onHover,
  onSelect,
  dimmed = false,
}: RetouchedRouteCardProps) {
  const { t } = useTranslation()
  const { distance, elevation, percent } = useUnits()
  const color = routeColor(index)
  const truncated = isTruncation(candidate)
  const { changed } = candidate
  const variant =
    candidate.variant === RetouchVariant.BEST
      ? t('routeRetouch.variant.best')
      : candidate.variant === RetouchVariant.KEEP_ALL
        ? t('routeRetouch.variant.keepAll')
        : candidate.variant === RetouchVariant.NEAREST
          ? t('routeRetouch.variant.nearest')
          : undefined
  return (
    <Card
      withBorder
      padding="sm"
      aria-current={selected ? 'true' : undefined}
      data-testid="retouched-route-card"
      onMouseEnter={() => onHover(index)}
      onMouseLeave={() => onHover(null)}
      onClick={() => onSelect(index)}
      style={{
        borderColor: selected ? color : undefined,
        borderWidth: selected ? 2 : undefined,
        opacity: dimmed ? 0.5 : 1,
        cursor: 'pointer',
        flexShrink: 0,
      }}
    >
      <Stack gap={4}>
        {/* The keyboard's way to select: the card itself is only a mouse target */}
        <UnstyledButton
          aria-pressed={selected}
          onClick={(event) => {
            event.stopPropagation()
            onSelect(index)
          }}
          style={{ width: '100%' }}
        >
          <Group justify="space-between" wrap="nowrap" gap="xs">
            <Group gap="xs" wrap="nowrap">
              <Box w={4} h={20} style={{ backgroundColor: color, borderRadius: 2 }} />
              <Text fw={600}>{t('routeRetouch.card.title', { index: index + 1 })}</Text>
            </Group>
            <Text fw={600}>
              {t('routeRetouch.card.distance', {
                before: distance(originalDistanceM),
                after: distance(candidate.distanceM),
              })}
            </Text>
          </Group>
        </UnstyledButton>
        <Text size="sm">
          {t('routeRetouch.card.ascent', {
            before: originalAscentM !== undefined ? elevation(originalAscentM) : '–',
            after: candidate.ascentM !== undefined ? elevation(candidate.ascentM) : '–',
          })}
        </Text>
        <Text size="sm" c="dimmed">
          {truncated
            ? t('routeRetouch.card.truncated')
            : t('routeRetouch.card.changed', {
                old: distance(Math.max(0, changed.toM - changed.fromM)),
                new: distance(changed.newM),
              })}
        </Text>
        <Text size="sm" c="dimmed">
          {t('routeRetouch.card.kept', { percent: percent(candidate.keptShare * 100) })}
        </Text>
        {variant && (
          <Text size="sm" c="dimmed">
            {variant}
          </Text>
        )}
        {candidate.unmatchedM > UNMATCHED_NOTE_METERS && (
          <Text size="xs" c="dimmed">
            {t('routeRetouch.card.unmatched')}
          </Text>
        )}
      </Stack>
    </Card>
  )
}
