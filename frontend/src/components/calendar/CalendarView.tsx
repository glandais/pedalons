import { useCallback, useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Schedule } from '@mantine/schedule'
import type {
  RenderEventBody,
  ScheduleEventData,
  ScheduleLabelsOverride,
  ScheduleViewLevel,
} from '@mantine/schedule'
import { Box, Group, Image, LoadingOverlay, Stack, Text, Tooltip } from '@mantine/core'
import { useMounted } from '@mantine/hooks'
import dayjs from 'dayjs'
import utc from 'dayjs/plugin/utc'
import timezone from 'dayjs/plugin/timezone'
import { paths } from '@/config/paths'
import { useUnits } from '@/hooks/useUnits'
import { formatTime, useEffectiveTimezone } from '@/utils/dateFormat'
import { supportedZone } from '@/utils/zoneLabel'
import { rendezvousMention } from '@/utils/rendezvous'
import { ZoneMentionIcon } from '@/components/common/Rendezvous'
import { hourAlignedNow } from '@/utils/nowIso'
import { getVisibleRange } from '@/components/calendar/calendarRange'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'
import type { CalendarEventDto, CalendarEventType } from '@/api/dto'

dayjs.extend(utc)
dayjs.extend(timezone)

interface CalendarViewProps {
  events: CalendarEventDto[]
  isLoading: boolean
  onDateRangeChange: (start: Date, end: Date) => void
}

/**
 * `@mantine/schedule` types `renderEvent` internally but does not re-export the type from its
 * entry point (only `RenderEventBody` is public), so we restate the same signature here.
 */
type RenderEvent = (
  event: ScheduleEventData,
  props: React.ComponentPropsWithoutRef<'button'> & { children: React.ReactNode }
) => React.ReactElement

interface CalendarEventPayload {
  dto: CalendarEventDto
  [key: PropertyKey]: unknown
}

/**
 * Mantine palette *names*, not hex values — same hues as before (`blue`/`green` are the shades the
 * literals `#228be6`/`#40c057` came from), but they survive dark mode.
 *
 * `@mantine/schedule` runs this through `theme.variantColorResolver` with the `light` variant. Given
 * a name it resolves to `--mantine-color-blue-light` / `-light-color`, which are defined per colour
 * scheme. Given a raw hex it can only blend `rgba(hex, 0.1)` for the background and keep the hex as
 * the text colour — a pair computed for a white surface, which in dark mode painted mid-blue text on
 * a near-transparent tint and made every event unreadable.
 */
const EVENT_COLORS: Record<CalendarEventType, string> = {
  RIDE: 'blue',
  TRIP_STAGE: 'green',
}

const SEPARATOR = ' · '

function getPayloadDto(event: ScheduleEventData): CalendarEventDto | undefined {
  return (event.payload as CalendarEventPayload | undefined)?.dto
}

export function CalendarView({
  events,
  isLoading,
  onDateRangeChange,
}: CalendarViewProps): React.ReactElement {
  const navigate = useNavigate()
  const { t, i18n } = useTranslation()
  const { distance: formatDistance, elevation: formatElevation } = useUnits()
  const { timezone: tz, isPlaceholder } = useEffectiveTimezone()
  const colorScheme = useResolvedColorScheme()

  const labels = useMemo<ScheduleLabelsOverride>(
    () => ({
      today: t('calendar.schedule.today'),
      next: t('calendar.schedule.next'),
      previous: t('calendar.schedule.previous'),
      day: t('calendar.schedule.day'),
      week: t('calendar.schedule.week'),
      month: t('calendar.schedule.month'),
      year: t('calendar.schedule.year'),
      allDay: t('calendar.schedule.allDay'),
      weekday: t('calendar.schedule.weekday'),
      timeSlot: t('calendar.schedule.timeSlot'),
      selectMonth: t('calendar.schedule.selectMonth'),
      selectYear: t('calendar.schedule.selectYear'),
      switchToDayView: t('calendar.schedule.switchToDayView'),
      switchToWeekView: t('calendar.schedule.switchToWeekView'),
      switchToMonthView: t('calendar.schedule.switchToMonthView'),
      switchToYearView: t('calendar.schedule.switchToYearView'),
      viewSelectLabel: t('calendar.schedule.viewSelectLabel'),
      noEvents: t('calendar.schedule.noEvents'),
      moreLabel: (count) => t('calendar.schedule.moreLabel', { count }),
    }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [t, i18n.language]
  )

  const [view, setView] = useState<ScheduleViewLevel>('month')
  // "Today" in the *visitor's* zone, from the same hour-aligned instant the query keys use, not
  // from a raw `dayjs()`. A raw call reads the server process's zone during SSR (UTC in the
  // container) and the browser's on the client: between midnight and the local offset on the 1st
  // of a month the server renders July's grid while the client renders August's — a whole-subtree
  // hydration mismatch, plus a `highlightToday` cell in the wrong place. `tz` is `UTC` on the
  // server and again on the hydration render (`useEffectiveTimezone`'s server snapshot), or the
  // user's own preference on both sides when they have one, so the two agree either way.
  const [initialDate] = useState(() => dayjs(hourAlignedNow()).tz(tz).format('YYYY-MM-DD'))
  const [date, setDate] = useState(initialDate)
  // `Schedule` itself still reads a raw `dayjs()` in two places that reach the server render. The
  // mobile month view selects "today" by default and prints it as the heading of its agenda
  // ("dimanche 28 septembre") — a text mismatch between midnight and the offset, so it gets the
  // same day as `date` instead. And both month views mark "today" with `data-today`: an attribute
  // React does not patch on hydration, so it would stay on the server's day. Highlighting only
  // once mounted lets the client alone decide which cell that is.
  const mounted = useMounted()

  useEffect(() => {
    const { start, end } = getVisibleRange(date, view, tz)
    onDateRangeChange(start, end)
  }, [date, view, tz]) // eslint-disable-line react-hooks/exhaustive-deps

  const scheduleEvents = useMemo<ScheduleEventData[]>(
    () =>
      events.map((event) => ({
        id: event.id,
        title: event.title,
        start: dayjs(event.start).tz(tz).format('YYYY-MM-DD HH:mm:ss'),
        end: dayjs(event.end ?? event.start)
          .tz(tz)
          .format('YYYY-MM-DD HH:mm:ss'),
        color: EVENT_COLORS[event.type],
        payload: { dto: event } satisfies CalendarEventPayload,
      })),
    [events, tz]
  )

  const eventMap = useMemo(() => new Map(events.map((e) => [String(e.id), e])), [events])

  /** Metric line ("42 km · 850 m"), empty when the entity carries no route. */
  const buildMetrics = useCallback(
    (dto: CalendarEventDto): string =>
      [
        dto.distance != null ? formatDistance(dto.distance) : null,
        dto.elevationGain != null ? formatElevation(dto.elevationGain) : null,
      ]
        .filter(Boolean)
        .join(SEPARATOR),
    [formatDistance, formatElevation]
  )

  /**
   * "team · time · start place" — the summary line required on every event. The time is a
   * rendezvous, in the event's zone with the language's 12/24 h rule (docs/LEDGER_*.md API-60); the
   * grid itself stays in the reader's zone `tz`.
   */
  const buildSummary = useCallback(
    (dto: CalendarEventDto): string =>
      [
        dto.teamName,
        dto.allDay
          ? t('calendar.schedule.allDay')
          : formatTime(dto.start, i18n.language, supportedZone(dto.timezone) || tz),
        dto.startPlaceName ?? null,
      ]
        .filter(Boolean)
        .join(SEPARATOR),
    [t, tz, i18n.language]
  )

  /** « heure de Tokyo (ven. 01:00 chez vous) » when the event's offset is not the reader's. */
  const buildMention = useCallback(
    (dto: CalendarEventDto) =>
      dto.allDay
        ? null
        : rendezvousMention(dto.start, dto.timezone, isPlaceholder ? null : tz, i18n.language, t),
    [t, tz, isPlaceholder, i18n.language]
  )

  /** "J'y vais" / "J'y vais · Groupe A", empty when the user is not registered. */
  const buildRegistration = useCallback(
    (dto: CalendarEventDto): string => {
      if (!dto.registered) {
        return ''
      }
      return dto.groupName
        ? t('calendar.event.registeredInGroup', { group: dto.groupName })
        : t('calendar.event.registered')
    },
    [t]
  )

  /**
   * Month-view event rows have a fixed height (one text line), so the body stays on a single
   * truncated line and the tooltip carries the structured detail.
   */
  const renderEventBody = useCallback<RenderEventBody>(
    (event) => {
      const dto = getPayloadDto(event)
      if (!dto) {
        return event.title
      }
      const details = [buildSummary(dto), buildMetrics(dto), buildRegistration(dto)]
        .filter(Boolean)
        .join(SEPARATOR)
      return (
        <Text size="xs" lh={1.3} truncate>
          <Text span inherit fw={600}>
            {dto.title}
          </Text>
          <ZoneMentionIcon mention={buildMention(dto)} withTooltip={false} />
          <Text span inherit c="dimmed">
            {details ? SEPARATOR + details : ''}
          </Text>
        </Text>
      )
    },
    [buildMention, buildMetrics, buildRegistration, buildSummary]
  )

  const renderEvent = useCallback<RenderEvent>(
    (event, props) => {
      const dto = getPayloadDto(event)
      // The server says it (docs/LEDGER_*.md API-16): the same answer in the server render and at
      // hydration. Without a DTO, from `event`'s wall-clock strings, read in `tz` — a bare `dayjs()`
      // would read them in the process's zone.
      const isPast = dto
        ? dto.finished
        : dayjs.tz(String(event.end ?? event.start), tz).isBefore(dayjs())
      // Themed variants are separate assets (contract 3.3.0) — the map tile is rendered per
      // scheme server-side, so it cannot be derived from the other one. `thumbnailUrl` stays the
      // fallback for an event whose picture only ever existed in the opposite variant.
      const themedThumbnail =
        colorScheme === 'dark' ? dto?.thumbnailDarkUrl : dto?.thumbnailLightUrl
      const thumbnail = (themedThumbnail ?? dto?.thumbnailUrl)?.replace('{size}', '128')
      const metrics = dto ? buildMetrics(dto) : ''
      const registration = dto ? buildRegistration(dto) : ''
      const mention = dto ? buildMention(dto) : null

      const button = (
        <button
          {...props}
          style={{
            ...props.style,
            opacity: isPast ? 0.55 : undefined,
            borderInlineStart: dto?.registered
              ? '3px solid var(--mantine-primary-color-filled)'
              : undefined,
          }}
        />
      )

      if (!dto) {
        return button
      }

      // This tooltip is a card (thumbnail + several lines), not a one-line label, so it is
      // restyled as a surface that *follows* the scheme instead of inverting it — Mantine's
      // default would paint a light box in dark mode. `c="inherit"` keeps every line on the
      // tooltip's own colour rather than each `Text` re-resolving `--mantine-color-text`.
      const tooltip = (
        <Stack gap={4}>
          {thumbnail ? (
            <Image src={thumbnail} alt={dto.title} w={200} h={80} fit="cover" radius="sm" />
          ) : null}
          <Text size="sm" fw={600} c="inherit">
            {dto.title}
          </Text>
          <Text size="xs" c="inherit">
            {buildSummary(dto)}
          </Text>
          {mention ? (
            <Text size="xs" c="inherit">
              {mention.full}
            </Text>
          ) : null}
          {metrics ? (
            <Text size="xs" c="inherit">
              {metrics}
            </Text>
          ) : null}
          {registration ? (
            <Text size="xs" fw={500} c="inherit">
              {registration}
            </Text>
          ) : null}
          {dto.status !== 'PUBLISHED' ? (
            <Text size="xs" c="inherit">
              {t(`status.${dto.status satisfies 'DRAFT' | 'PUBLISHED' | 'CANCELLED'}`)}
            </Text>
          ) : null}
        </Stack>
      )

      return (
        <Tooltip
          label={tooltip}
          withArrow
          multiline
          w={220}
          openDelay={250}
          position="top"
          styles={{
            tooltip: {
              backgroundColor: 'var(--mantine-color-body)',
              color: 'var(--mantine-color-text)',
              border: '1px solid var(--mantine-color-default-border)',
              boxShadow: 'var(--mantine-shadow-md)',
            },
            arrow: {
              backgroundColor: 'var(--mantine-color-body)',
              border: '1px solid var(--mantine-color-default-border)',
            },
          }}
        >
          {button}
        </Tooltip>
      )
    },
    [buildMention, buildMetrics, buildRegistration, buildSummary, colorScheme, t, tz]
  )

  /**
   * The phone's month view lists the selected day's events, and ignores `renderEventBody`: its
   * own body is the title and "HH:mm – HH:mm" (or a hard-coded English "All day"), with neither the
   * team nor the registration — and no hover to show the tooltip. Its body is replaced here.
   */
  const renderMobileEvent = useCallback<RenderEvent>(
    (event, props) => {
      const dto = getPayloadDto(event)
      if (!dto) {
        return renderEvent(event, props)
      }
      const registration = buildRegistration(dto)
      const mention = buildMention(dto)
      const body = (
        <Group gap="xs" wrap="nowrap" align="stretch">
          <Box
            w={4}
            style={{
              borderRadius: 2,
              flexShrink: 0,
              backgroundColor: `var(--mantine-color-${EVENT_COLORS[dto.type]}-filled)`,
            }}
          />
          <Stack gap={2}>
            <Text size="sm" fw={600}>
              {dto.title}
            </Text>
            <Text size="xs" c="dimmed">
              {buildSummary(dto)}
            </Text>
            {mention ? (
              <Text size="xs" c="dimmed">
                {mention.full}
              </Text>
            ) : null}
            {registration ? (
              <Text size="xs" fw={500}>
                {registration}
              </Text>
            ) : null}
          </Stack>
        </Group>
      )
      return renderEvent(event, { ...props, children: body })
    },
    [buildMention, buildRegistration, buildSummary, renderEvent]
  )

  const handleEventClick = useCallback(
    (event: ScheduleEventData) => {
      const original = eventMap.get(String(event.id))
      if (!original) return
      switch (original.type) {
        case 'RIDE':
          navigate(paths.ride(original.teamSlug, original.entitySlug))
          break
        case 'TRIP_STAGE':
          if (original.tripSlug) {
            navigate(paths.stage(original.teamSlug, original.tripSlug, original.entitySlug))
          }
          break
      }
    },
    [eventMap, navigate]
  )

  return (
    <Box pos="relative">
      <LoadingOverlay visible={isLoading} />
      <Schedule
        events={scheduleEvents}
        view={view}
        onViewChange={setView}
        date={date}
        onDateChange={setDate}
        onEventClick={handleEventClick}
        locale={i18n.language}
        labels={labels}
        renderEventBody={renderEventBody}
        // Without this, `Schedule` renders `desktopContent` only and `mobileMonthViewProps` below
        // is dead: a phone got the desktop month grid. The switch is pure CSS (both trees render,
        // one is hidden), so it costs no media query and no hydration hazard.
        layout="responsive"
        monthViewProps={{ firstDayOfWeek: 1, renderEvent, highlightToday: mounted }}
        weekViewProps={{ renderEvent }}
        dayViewProps={{ renderEvent }}
        mobileMonthViewProps={{
          renderEvent: renderMobileEvent,
          defaultSelectedDate: initialDate,
          highlightToday: mounted,
        }}
      />
    </Box>
  )
}
