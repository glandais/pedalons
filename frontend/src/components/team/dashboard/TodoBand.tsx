import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Anchor,
  Button,
  Group,
  Paper,
  SimpleGrid,
  Stack,
  Text,
  ThemeIcon,
  Title,
} from '@mantine/core'
import {
  IconFileText,
  IconFlag,
  IconRouteOff,
  IconUsersGroup,
  type TablerIcon,
} from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import type { ReportReason, ReportTargetType, TeamDashboardOrganizerDto, RideDto } from '@/api/dto'
import { paths } from '@/config/paths'
import { formatPattern, useFormattedDate } from '@/utils/dateFormat'
import { isSupportedZone } from '@/utils/zoneLabel'
import { publicationEditPath, publicationPath, ridesOf } from './dashboardHelpers'

interface TodoBandProps {
  teamSlug: string
  organizer: TeamDashboardOrganizerDto
}

/**
 * « À traiter »: what an organizer or an administrator should look at — drafts, upcoming rides
 * without a route, rides with a full group, open reports. Same audience as the team's moderation
 * queue (`requireTeamModerator`), which is why the reports tile is shown to organizers too.
 *
 * A tile shows only when something waits in its category, and the whole section is gone when
 * nothing waits anywhere.
 */
export function TodoBand({ teamSlug, organizer }: TodoBandProps) {
  const { t, i18n } = useTranslation()
  const reader = useFormattedDate()
  const { drafts, ridesWithoutRoute, ridesWithFullGroup, reports } = organizer

  const firstDraft = drafts.publications[0]
  const withoutRoute = ridesOf(ridesWithoutRoute?.publications)
  const withFullGroup = ridesOf(ridesWithFullGroup?.publications)
  const firstFull = withFullGroup[0]
  const fullGroup = firstFull?.groupSummaries.find((g) => g.full)

  // The ride's day, a rendezvous in its zone (docs/LEDGER_*.md API-60).
  const rideLabel = (ride: RideDto) =>
    `${ride.name}, ${
      isSupportedZone(ride.timezone)
        ? formatPattern(ride.dateTime, 'EEE d MMM', i18n.language, ride.timezone)
        : reader.formatPattern(ride.dateTime, 'EEE d MMM')
    }`

  const hasRidesWithoutRoute = !!ridesWithoutRoute && ridesWithoutRoute.total > 0
  const hasRidesWithFullGroup = !!ridesWithFullGroup && ridesWithFullGroup.total > 0
  if (
    drafts.total === 0 &&
    !hasRidesWithoutRoute &&
    !hasRidesWithFullGroup &&
    reports.openCount === 0
  )
    return null

  return (
    <section aria-labelledby="dashboard-todo">
      <Stack gap="sm">
        <Title order={2} id="dashboard-todo" size="h3">
          {t('teams.dashboard.todo.title')}
        </Title>
        <SimpleGrid cols={{ base: 1, xs: 2, md: 4 }} spacing="md">
          {drafts.total > 0 && (
            <TodoTile
              icon={IconFileText}
              color="gray"
              count={drafts.total}
              label={t('teams.dashboard.todo.drafts', { count: drafts.total })}
              detail={
                drafts.publications.length > 0 ? (
                  <>
                    {drafts.publications.map((draft, index) => (
                      <span key={draft.id}>
                        {index > 0 && ', '}
                        <Anchor
                          component={PrefetchLink}
                          to={publicationEditPath(draft)}
                          inherit
                          c="inherit"
                        >
                          {draft.name}
                        </Anchor>
                      </span>
                    ))}
                  </>
                ) : undefined
              }
              action={
                firstDraft
                  ? { label: t('teams.dashboard.todo.resume'), to: publicationEditPath(firstDraft) }
                  : undefined
              }
            />
          )}

          {ridesWithoutRoute && hasRidesWithoutRoute && (
            <TodoTile
              icon={IconRouteOff}
              color="warning"
              count={ridesWithoutRoute.total}
              label={t('teams.dashboard.todo.withoutRoute', { count: ridesWithoutRoute.total })}
              detail={
                withoutRoute.length > 0 ? (
                  <span suppressHydrationWarning>{withoutRoute.map(rideLabel).join(' · ')}</span>
                ) : undefined
              }
              action={
                withoutRoute[0]
                  ? {
                      label: t('teams.dashboard.todo.addRoute'),
                      to: publicationEditPath(withoutRoute[0]),
                    }
                  : undefined
              }
            />
          )}

          {ridesWithFullGroup && hasRidesWithFullGroup && (
            <TodoTile
              icon={IconUsersGroup}
              color="primary"
              count={ridesWithFullGroup.total}
              label={t('teams.dashboard.todo.fullGroup', { count: ridesWithFullGroup.total })}
              detail={
                firstFull && fullGroup
                  ? t('teams.dashboard.todo.fullGroupDetail', {
                      group: fullGroup.name,
                      ride: firstFull.name,
                      count: fullGroup.countParticipants,
                      max: fullGroup.maxParticipants ?? fullGroup.countParticipants,
                    })
                  : undefined
              }
              action={
                firstFull
                  ? { label: t('teams.dashboard.todo.seeGroups'), to: publicationPath(firstFull) }
                  : undefined
              }
            />
          )}

          {reports.openCount > 0 && (
            <TodoTile
              icon={IconFlag}
              color="danger"
              count={reports.openCount}
              label={t('teams.dashboard.todo.reports', { count: reports.openCount })}
              detail={
                reports.openCount > 0 && reports.latestTargetType ? (
                  <ReportSummary
                    targetType={reports.latestTargetType}
                    reason={reports.latestReason}
                    excerpt={reports.latestExcerpt}
                  />
                ) : undefined
              }
              action={
                reports.openCount > 0
                  ? {
                      label: t('teams.dashboard.todo.review'),
                      to: paths.teamAdminReports(teamSlug),
                    }
                  : undefined
              }
            />
          )}
        </SimpleGrid>
      </Stack>
    </section>
  )
}

function ReportSummary({
  targetType,
  reason,
  excerpt,
}: {
  targetType: ReportTargetType
  reason?: ReportReason
  excerpt?: string
}) {
  const { t } = useTranslation()
  const target = t(
    `moderation.targetType.${targetType satisfies 'COMMENT' | 'POST' | 'AD' | 'RIDE' | 'TRIP' | 'ROUTE' | 'MEMBER'}`
  )
  const why = reason
    ? t(
        `moderation.reason.${reason satisfies 'SPAM' | 'HARASSMENT' | 'HATE' | 'SEXUAL' | 'VIOLENCE' | 'ILLEGAL' | 'INAPPROPRIATE_IMAGE' | 'OTHER'}`
      )
    : undefined
  return (
    <>
      {why ? t('teams.dashboard.todo.reportDetail', { target, reason: why }) : target}
      {excerpt && ` ${t('teams.dashboard.todo.reportExcerpt', { excerpt })}`}
    </>
  )
}

interface TodoTileProps {
  icon: TablerIcon
  /** A theme colour name (`primary`, `warning`, `danger`…), never a hex. */
  color: string
  count: number
  label: string
  detail?: ReactNode
  action?: { label: string; to: string }
}

function TodoTile({ icon: Icon, color, count, label, detail, action }: TodoTileProps) {
  return (
    <Paper withBorder radius="md" p="md">
      <Stack gap="xs" h="100%">
        <Group gap="sm" wrap="nowrap">
          <ThemeIcon variant="light" color={color} size="lg" radius="md">
            <Icon size={20} />
          </ThemeIcon>
          <Text fz={28} fw={700} lh={1}>
            {count}
          </Text>
        </Group>
        <Text fw={600}>{label}</Text>
        <Text size="sm" c="dimmed" lineClamp={3}>
          {detail}
        </Text>
        {action && (
          <Button
            component={PrefetchLink}
            to={action.to}
            variant="light"
            size="xs"
            mt="auto"
            style={{ alignSelf: 'flex-start' }}
          >
            {action.label}
          </Button>
        )}
      </Stack>
    </Paper>
  )
}
