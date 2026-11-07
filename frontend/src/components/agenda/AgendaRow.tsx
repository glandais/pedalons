import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Anchor, Badge, Group, Paper, Stack } from '@mantine/core'
import { IconCheck, IconClock, IconMapPin, IconStack2, IconUsers } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { DayBox } from '@/components/common/DayBox'
import { Stat, StatusBadge, TypeBadge, VisibilityBadge } from '@/components/card/common'
import { publicationPath } from '@/components/team/dashboard/dashboardHelpers'
import { isUnderWay, spanStart, type DatedPublication } from '@/utils/publicationTiming'
import { InProgressBadge } from './InProgressBadge'
import { PublicationTimeSpan } from './PublicationTimeSpan'

interface AgendaRowProps {
  publication: DatedPublication
  /** The `⋯` menu, for a reader who manages the team's content. */
  actions?: ReactNode
}

/**
 * A line of the agenda's « Lignes » view (plan 2026-10-06, ledger `WEB-69`): the day box, the
 * title and its badges, « départ → retour vers … », then the groups or the stages and who is
 * registered. Denser than a card: no picture, no excerpt.
 */
export function AgendaRow({ publication, actions }: AgendaRowProps) {
  const { t } = useTranslation()
  const isTrip = publication.type === 'TRIP'
  const path = publicationPath(publication)

  return (
    <Paper withBorder radius="md" p="sm" data-testid="agenda-row">
      <Group wrap="nowrap" gap="md" align="center">
        <DayBox date={spanStart(publication)} zone={publication.timezone} />
        <Stack gap={4} style={{ flex: 1, minWidth: 0 }}>
          <Group gap="xs" wrap="wrap">
            <Anchor component={PrefetchLink} to={path} fw={600} c="inherit" lineClamp={1}>
              {publication.name}
            </Anchor>
            {isUnderWay(publication) && <InProgressBadge />}
            {publication.registered && (
              <Badge
                size="sm"
                color="primary"
                variant="light"
                leftSection={<IconCheck size={12} />}
              >
                {t('publications.registered')}
              </Badge>
            )}
            {isTrip && <TypeBadge type="TRIP">{t('publicationType.trip')}</TypeBadge>}
            {publication.status !== 'PUBLISHED' && (
              <StatusBadge status={publication.status}>
                {t(`status.${publication.status satisfies 'DRAFT' | 'PUBLISHED' | 'CANCELLED'}`)}
              </StatusBadge>
            )}
            {publication.visibility !== 'PUBLIC' && (
              <VisibilityBadge visibility={publication.visibility} />
            )}
          </Group>
          <Group gap="md" wrap="wrap">
            <Stat icon={<IconClock size={16} />}>
              <PublicationTimeSpan publication={publication} mode="time" />
            </Stat>
            {!isTrip && publication.startPlace && (
              <Stat icon={<IconMapPin size={16} />}>{publication.startPlace.name}</Stat>
            )}
            <Stat icon={<IconStack2 size={16} />}>
              {publication.type === 'TRIP'
                ? t('trips.card.stageCount', { count: publication.stageCount })
                : t('groups.groupCount', { count: publication.groupCount })}
            </Stat>
            <Stat icon={<IconUsers size={16} />}>
              {t('participantCount', { count: publication.participantCount })}
            </Stat>
          </Group>
        </Stack>
        {actions}
      </Group>
    </Paper>
  )
}
