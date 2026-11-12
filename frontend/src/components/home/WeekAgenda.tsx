import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Anchor,
  Badge,
  Box,
  Group,
  Paper,
  SimpleGrid,
  Skeleton,
  Stack,
  Text,
  Title,
  UnstyledButton,
} from '@mantine/core'
import { IconChevronRight } from '@tabler/icons-react'
import type { CalendarEventDto } from '@/api/dto'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { StateBadge } from '@/components/card/common'
import { eventState } from '@/utils/cardState'
import { paths } from '@/config/paths'
import classes from './Home.module.css'
import { eventPath } from './memberHomeHelpers'
import { formatPattern, formatTime, useEffectiveTimezone } from '@/utils/dateFormat'
import { DayBox } from '@/components/common/DayBox'
import { supportedZone } from '@/utils/zoneLabel'
import { rendezvousMention } from '@/utils/rendezvous'
import { ZoneMentionIcon } from '@/components/common/Rendezvous'
import { PUBLICATION_TYPE_COLORS } from '@/lib/badgeColors.generated'

const DAY_MS = 24 * 60 * 60 * 1000
/** Rows listed under the strip; the calendar holds the rest. */
const MAX_ROWS = 5

interface WeekAgendaProps {
  /** The hour-aligned `now` the events were fetched from — the strip's first day. */
  nowIso: string
  events: CalendarEventDto[] | undefined
  isLoading: boolean
  isError?: boolean
  /**
   * The ride « Ma prochaine sortie » already shows beside the agenda: left out of the rows (as
   * the app does), still counted in the strip's dots.
   */
  nextRide?: { teamSlug: string; slug: string }
}

/**
 * « Les 7 prochains jours » (formerly « Cette semaine ») on the member home: a seven-day strip from today, a dot on each day with an
 * event, then the next events of all the member's teams — from one `GET /api/calendar/events`
 * call. Days are read in the effective timezone (the member's preference, else the browser's).
 */
export function WeekAgenda({ nowIso, events, isLoading, isError, nextRide }: WeekAgendaProps) {
  const { t, i18n } = useTranslation()
  const { timezone, isPlaceholder } = useEffectiveTimezone()
  const inZone = (date: Date | string, pattern: string, zone: string) =>
    formatPattern(date, pattern, i18n.language, zone)
  const dayKey = (date: Date | string) => inZone(date, 'yyyy-MM-dd', timezone)

  // Calendar days, not 24-hour steps: the day the clocks change is 23 or 25 hours long, and
  // `now + i × 24 h` from late evening skipped or repeated one (docs/LEDGER_*.md WEB-71). Each day
  // is held as noon UTC of its date in the effective zone, where adding 24 hours is always the
  // next date; it is read back in UTC.
  const days = useMemo(() => {
    const today = new Date(`${formatPattern(nowIso, 'yyyy-MM-dd', 'en', timezone)}T12:00:00Z`)
    return Array.from({ length: 7 }, (_, i) => new Date(today.getTime() + i * DAY_MS))
  }, [nowIso, timezone])
  const calendarDayKey = (day: Date) => inZone(day, 'yyyy-MM-dd', 'UTC')

  const dayKeys = new Set(days.map(calendarDayKey))
  const inWeek = (events ?? [])
    .filter((e) => !e.finished && dayKeys.has(dayKey(e.start)))
    .sort((a, b) => a.start.localeCompare(b.start))
  const busyDays = new Set(inWeek.map((e) => dayKey(e.start)))
  const todayKey = calendarDayKey(days[0])
  const rows = inWeek.filter(
    (e) =>
      !(
        nextRide &&
        e.type === 'RIDE' &&
        e.teamSlug === nextRide.teamSlug &&
        e.entitySlug === nextRide.slug
      )
  )
  // Rows past the limit are named, never dropped silently: the calendar holds them (as the app).
  const hidden = rows.length - MAX_ROWS

  return (
    <Paper withBorder radius="md" p="md" component="section" aria-labelledby="home-week-title">
      <Group justify="space-between" mb="sm">
        <Title id="home-week-title" order={2} size="h4">
          {t('home.week.title')}
        </Title>
        {/* Not « Calendrier »: the main navigation already holds a link of that name. */}
        <Anchor component={PrefetchLink} to={paths.calendar()} size="sm">
          {t('home.week.calendarLink')}
        </Anchor>
      </Group>

      <SimpleGrid cols={7} spacing={4} mb="sm" aria-hidden>
        {days.map((day) => {
          const key = calendarDayKey(day)
          const isToday = key === todayKey
          return (
            <Stack
              key={key}
              gap={2}
              align="center"
              py={6}
              style={{
                borderRadius: 'var(--mantine-radius-md)',
                backgroundColor: isToday ? 'var(--mantine-primary-color-light)' : undefined,
              }}
            >
              <Text size="xs" c="dimmed" tt="uppercase">
                {inZone(day, 'EEEEE', 'UTC')}
              </Text>
              <Text size="sm" fw={isToday ? 700 : 500} c={isToday ? 'primary' : undefined}>
                {inZone(day, 'd', 'UTC')}
              </Text>
              <Box
                w={6}
                h={6}
                style={{
                  borderRadius: '50%',
                  backgroundColor: busyDays.has(key)
                    ? `var(--mantine-color-${PUBLICATION_TYPE_COLORS.RIDE}-filled)`
                    : 'transparent',
                }}
              />
            </Stack>
          )
        })}
      </SimpleGrid>

      {isLoading ? (
        <Stack gap="xs">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} h={48} radius="md" />
          ))}
        </Stack>
      ) : isError ? (
        <Text size="sm" c="dimmed">
          {t('error.loading')}
        </Text>
      ) : rows.length === 0 ? (
        <Text size="sm" c="dimmed">
          {inWeek.length > 0 ? t('home.week.nothingElse') : t('home.week.empty')}
        </Text>
      ) : (
        <Stack gap={4}>
          {rows.slice(0, MAX_ROWS).map((event) => (
            <UnstyledButton
              key={`${event.type}-${event.id}`}
              component={PrefetchLink}
              to={eventPath(event)}
              p={6}
              className={classes.row}
            >
              <Group gap="sm" wrap="nowrap">
                {/* The row's day and time are a rendezvous, in the event's zone (docs/LEDGER_*.md
                    API-60); the strip, the dots and the grouping stay the reader's. The day box
                    is the one of every list (docs/BRANDING.md §7.8, WEB-138). */}
                <DayBox date={event.start} zone={supportedZone(event.timezone) || timezone} />
                <Box style={{ flex: 1, minWidth: 0 }}>
                  <Group gap={6} wrap="nowrap">
                    <Text size="sm" fw={600} truncate>
                      {event.title}
                    </Text>
                    {/* One state, then « J'y vais » (docs/LEDGER_*.md WEB-167, R1). */}
                    <StateBadge state={eventState(event)} />
                    {event.registered && (
                      <Badge size="xs" color="primary" variant="light" style={{ flexShrink: 0 }}>
                        {t('publications.registered')}
                      </Badge>
                    )}
                  </Group>
                  <Text size="sm" c="dimmed" truncate>
                    {!event.allDay && (
                      <>
                        {/* The departure in 700, not a dimmed aside (BRAND-8). */}
                        <Text span inherit fw={700} c="var(--mantine-color-text)">
                          {formatTime(
                            event.start,
                            i18n.language,
                            supportedZone(event.timezone) || timezone
                          )}
                        </Text>
                        <ZoneMentionIcon
                          mention={rendezvousMention(
                            event.start,
                            event.timezone,
                            isPlaceholder ? null : timezone,
                            i18n.language,
                            t
                          )}
                        />
                        {' · '}
                      </>
                    )}
                    {[event.teamName, event.groupName].filter(Boolean).join(' · ')}
                  </Text>
                </Box>
                <IconChevronRight size={16} color="var(--mantine-color-dimmed)" />
              </Group>
            </UnstyledButton>
          ))}
          {hidden > 0 && (
            <Anchor
              component={PrefetchLink}
              to={paths.calendar()}
              size="sm"
              p={6}
              data-testid="week-more"
            >
              {t('home.week.more', { count: hidden })}
            </Anchor>
          )}
        </Stack>
      )}
    </Paper>
  )
}
