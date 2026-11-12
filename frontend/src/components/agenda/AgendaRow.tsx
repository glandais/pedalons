import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Anchor, Group, Paper, Stack } from '@mantine/core'
import { IconMapPin, IconStack2, IconUsers } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { DayBox } from '@/components/common/DayBox'
import { PublicationDepartureLine } from '@/components/common/DepartureLine'
import {
  RegisteredBadge,
  Stat,
  StateBadge,
  TypeBadge,
  VisibilityBadge,
} from '@/components/card/common'
import { publicationPath } from '@/components/team/dashboard/dashboardHelpers'
import { spanStart, type DatedPublication } from '@/utils/publicationTiming'
import { cardState } from '@/utils/cardState'
import { visibilityIsException } from '@/utils/visibilityException'

interface AgendaRowProps {
  publication: DatedPublication
  /** The `⋯` menu, for a reader who manages the team's content. */
  actions?: ReactNode
}

/**
 * A line of the agenda's « Lignes » view (plan 2026-10-06, ledger `WEB-69`): the day box, the
 * title and its badges, the departure line « Départ 08:30 » (a trip: its span),
 * then the groups or the stages and who is registered. Denser than a card: no picture, no excerpt.
 * The departure is the reader's group's (`spanStart`, WEB-136) and never one of the statistics
 * (docs/LEDGER_*.md WEB-138).
 */
export function AgendaRow({ publication, actions }: AgendaRowProps) {
  const { t } = useTranslation()
  const isTrip = publication.type === 'TRIP'
  const path = publicationPath(publication)

  return (
    <Paper withBorder radius="md" p="sm" data-testid="agenda-row">
      <Group wrap="nowrap" gap="md" align="center">
        <DayBox
          date={spanStart(publication)}
          zone={publication.timezone}
          tone={isTrip ? 'teal' : 'primary'}
        />
        <Stack gap={4} style={{ flex: 1, minWidth: 0 }}>
          <Group gap="xs" wrap="wrap">
            <Anchor component={PrefetchLink} to={path} fw={600} c="inherit" lineClamp={1}>
              {publication.name}
            </Anchor>
            {/* The cards' order (docs/LEDGER_*.md WEB-167, R1): type, one state, « J'y vais », the
                visibility only when it differs from the team's. */}
            {isTrip && <TypeBadge type="TRIP">{t('publicationType.trip')}</TypeBadge>}
            <StateBadge
              state={cardState({
                status: publication.status,
                start: publication.dateTime,
                end: publication.endDateTime,
              })}
              subject={isTrip ? 'trip' : 'ride'}
            />
            {publication.registered && <RegisteredBadge />}
            {visibilityIsException(publication.visibility, publication.team) && (
              <VisibilityBadge visibility={publication.visibility} />
            )}
          </Group>
          <PublicationDepartureLine publication={publication} size="sm" />
          <Group gap="md" wrap="wrap">
            {!isTrip && publication.startPlace && (
              <Stat icon={<IconMapPin size={16} />}>{publication.startPlace.name}</Stat>
            )}
            {/* No counter at zero (R4). A trip registers on itself; a ride through its groups. */}
            {(publication.type === 'TRIP' ? publication.stageCount : publication.groupCount) >
              0 && (
              <Stat icon={<IconStack2 size={16} />}>
                {publication.type === 'TRIP'
                  ? t('trips.card.stageCount', { count: publication.stageCount })
                  : t('groups.groupCount', { count: publication.groupCount })}
              </Stat>
            )}
            {(publication.type === 'TRIP' || publication.groupCount > 0) &&
              publication.participantCount > 0 && (
                <Stat icon={<IconUsers size={16} />}>
                  {t('participantCount', { count: publication.participantCount })}
                </Stat>
              )}
          </Group>
        </Stack>
        {actions}
      </Group>
    </Paper>
  )
}
