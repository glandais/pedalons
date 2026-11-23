import { useTranslation } from 'react-i18next'
import { Box, Button, Card, Group, Stack, Text, Tooltip, UnstyledButton } from '@mantine/core'
import type { GeneratedRouteDto, RouteGeneratorType } from '@/api/dto'
import { useUnits } from '@/hooks/useUnits'
import { SHARED_MIN_METERS } from '@/lib/routeGenerator'
import { routeColor } from '@/lib/routeColors'

interface GeneratedRouteCardProps {
  candidate: GeneratedRouteDto
  index: number
  type: RouteGeneratorType
  selected: boolean
  /** Hover highlights the line on the map, it does not select. */
  onHover: (index: number | null) => void
  onSelect: (index: number) => void
  onOpen: (candidate: GeneratedRouteDto) => void
  /** « Ouvrir dans l'éditeur », or « Utiliser ce parcours » in the editor's modal. */
  openLabel: string
  openDisabled?: boolean
  openDisabledReason?: string
  /** The previous seed's cards, dimmed while the new ones come. */
  dimmed?: boolean
}

/** One proposal: what the person decides on, in words rather than in figures that mean nothing. */
export function GeneratedRouteCard({
  candidate,
  index,
  type,
  selected,
  onHover,
  onSelect,
  onOpen,
  openLabel,
  openDisabled = false,
  openDisabledReason,
  dimmed = false,
}: GeneratedRouteCardProps) {
  const { t } = useTranslation()
  const { distance, elevation, percent } = useUnits()
  const color = routeColor(index)
  // Unpaved is worth saying where it is a choice (gravel, MTB), and from 1 % on a road ride
  const showUnpaved = candidate.unpavedShare >= 0.01 || type !== 'ROAD'
  return (
    <Card
      withBorder
      padding="sm"
      aria-current={selected ? 'true' : undefined}
      data-testid="generated-route-card"
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
              <Text fw={600}>{t('routeGenerator.card.title', { index: index + 1 })}</Text>
            </Group>
            <Text fw={600}>{distance(candidate.distanceM)}</Text>
          </Group>
        </UnstyledButton>
        {candidate.ascentM !== undefined && (
          <Text size="sm">
            {t('routeGenerator.card.ascent', { ascent: elevation(candidate.ascentM) })}
          </Text>
        )}
        <Text size="sm" c="dimmed">
          {t('routeGenerator.card.teamShare', { share: percent(candidate.teamShare * 100) })}
        </Text>
        {candidate.sharedM >= SHARED_MIN_METERS && (
          <Text size="sm" c="dimmed">
            {t('routeGenerator.card.shared', { distance: distance(candidate.sharedM) })}
          </Text>
        )}
        {showUnpaved && (
          <Text size="sm" c="dimmed">
            {t('routeGenerator.card.unpaved', { share: percent(candidate.unpavedShare * 100) })}
          </Text>
        )}
        {candidate.unpavedTargetReached === false && candidate.unpavedTarget !== undefined && (
          <Text size="xs" c="dimmed">
            {candidate.unpavedShare < candidate.unpavedTarget
              ? t('routeGenerator.card.unpavedBelow')
              : t('routeGenerator.card.unpavedAbove')}
          </Text>
        )}
        <Group justify="flex-end" mt={4}>
          {openDisabled && openDisabledReason ? (
            <Tooltip
              label={openDisabledReason}
              withArrow
              events={{ hover: true, focus: true, touch: true }}
            >
              {/* A disabled button swallows the pointer and cannot take focus: the span carries the tooltip */}
              <span tabIndex={0} aria-label={`${openLabel}. ${openDisabledReason}`}>
                <Button variant="light" size="compact-md" disabled>
                  {openLabel}
                </Button>
              </span>
            </Tooltip>
          ) : (
            <Button
              variant="light"
              size="compact-md"
              disabled={openDisabled}
              onClick={(event) => {
                event.stopPropagation()
                onOpen(candidate)
              }}
            >
              {openLabel}
            </Button>
          )}
        </Group>
      </Stack>
    </Card>
  )
}
