import { useTranslation } from 'react-i18next'
import type { CalendarEventDto, TeamDetailDto } from '@/api/dto'
import { paths } from '@/config/paths'

/** Helpers of the member home's blocks, apart from the components (fast refresh). */

/**
 * The activity line of a team row, from the per-page counters of `GET /api/teams` — zeros left
 * out; the member count when nothing is going on.
 */
export function useTeamActivity() {
  const { t } = useTranslation()
  return (team: TeamDetailDto): string => {
    const parts = [
      team.upcomingRideCount > 0
        ? t('home.teams.activity.rides', { count: team.upcomingRideCount })
        : null,
      team.upcomingTripCount > 0
        ? t('home.teams.activity.trips', { count: team.upcomingTripCount })
        : null,
      team.recentPostCount > 0
        ? t('home.teams.activity.posts', { count: team.recentPostCount })
        : null,
    ].filter((part): part is string => part !== null)
    return parts.length > 0 ? parts.join(' · ') : t('memberCount', { count: team.memberCount })
  }
}

/** The last team picked on the member home, per browser: the next visit starts there. */
export const CREATE_TEAM_STORAGE_KEY = 'pedalons.home.createTeam'

export const canOrganize = (team: TeamDetailDto) =>
  team.role === 'ORGANIZER' || team.role === 'ADMIN'

export function eventPath(event: CalendarEventDto): string {
  return event.type === 'TRIP_STAGE' && event.tripSlug
    ? paths.stage(event.teamSlug, event.tripSlug, event.entitySlug)
    : paths.ride(event.teamSlug, event.entitySlug)
}

/**
 * The sentence under the greeting, from the same « Cette semaine » response: the week's published
 * rides in the member's teams (stages left out), and how many of them they are registered to.
 */
export function useWeekSummary(events: CalendarEventDto[] | undefined): string | null {
  const { t } = useTranslation()
  if (!events) return null
  const rides = events.filter((e) => e.type === 'RIDE' && e.status === 'PUBLISHED' && !e.finished)
  if (rides.length === 0) return t('home.member.summary.none')
  const registered = rides.filter((e) => e.registered).length
  const head = t('home.member.summary.rides', { count: rides.length })
  if (registered === 0) return head
  const tail =
    registered === rides.length
      ? t('home.member.summary.registeredAll', { count: registered })
      : t('home.member.summary.registered', { count: registered })
  return `${head} ${tail}`
}
