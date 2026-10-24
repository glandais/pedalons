import { useTranslation } from 'react-i18next'
import { Box, Flex, Stack } from '@mantine/core'
import type { TeamDashboardDto, TeamDetailDto } from '@/api/dto'
import { paths } from '@/config/paths'
import { DashboardSection } from './DashboardSection'
import { TodoBand } from './TodoBand'
import { MyUpcomingList } from './MyUpcomingList'
import { UpcomingRideCard } from './UpcomingRideCard'
import { LatestAdsList, LatestPostsList, NewRoutesList } from './ContentLists'
import { AdminPanel } from './AdminPanel'
import { TemplatesPanel } from './TemplatesPanel'
import { postsOf, ridesOf } from './dashboardHelpers'

interface TeamDashboardProps {
  dashboard: TeamDashboardDto
  /** The team as `GET /api/teams/{slug}` gives it — the same object as `dashboard.team`. */
  team?: TeamDetailDto
}

/**
 * The body of the team dashboard, for everyone (API-86): a visitor's response carries the public
 * sections only — upcoming rides, latest posts, new routes — and a null `role`. Each « Voir tout »
 * leads to the list behind it: the agenda (« Je participe » for « Mes prochaines »), the posts, the
 * routes (ledger WEB-68). What it shows follows the API, never a guess from the client:
 * a section is drawn when the response carries it — `null` means the team disabled that module —
 * and the organizer and admin blocks only exist in the response for those who hold the rights: a
 * team ORGANIZER or ADMIN, or a platform admin whose `role` is null when not a member
 * (docs/LEDGER_*.md API-137). Their presence, not `role`, is what draws them.
 */
export function TeamDashboard({ dashboard, team: teamOverride }: TeamDashboardProps) {
  const { t } = useTranslation()
  const team = teamOverride ?? dashboard.team
  const slug = team.slug
  const organizer = dashboard.organizer ?? undefined
  const admin = dashboard.admin ?? undefined
  const isOrganizer = !!organizer

  const { myUpcoming, upcomingRides, latestPosts, newRoutes, latestAds } = dashboard
  const upcoming = ridesOf(upcomingRides?.publications)
  const posts = postsOf(latestPosts?.publications)

  const hasAside = !!admin || !!organizer?.rideTemplates || !!newRoutes || !!latestAds

  return (
    <Stack gap="xl">
      {organizer && <TodoBand teamSlug={slug} organizer={organizer} />}

      <Flex gap="xl" wrap="wrap" align="flex-start">
        <Stack gap="xl" style={{ flex: '999 1 560px', minWidth: 0 }}>
          {myUpcoming && (
            <DashboardSection
              id="dashboard-my-upcoming"
              title={t('teams.dashboard.myUpcoming.title')}
              seeAllTo={`${paths.teamAgenda(slug)}?w=me`}
              isEmpty={myUpcoming.publications.length === 0}
              empty={t('teams.dashboard.myUpcoming.empty')}
            >
              <MyUpcomingList publications={myUpcoming.publications} />
            </DashboardSection>
          )}

          {upcomingRides && (
            <DashboardSection
              id="dashboard-upcoming-rides"
              title={t('teams.dashboard.upcomingRides.title')}
              seeAllTo={paths.teamAgenda(slug)}
              isEmpty={upcoming.length === 0}
              empty={t('teams.dashboard.upcomingRides.empty')}
            >
              <Box
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))',
                  gap: 'var(--mantine-spacing-md)',
                }}
              >
                {upcoming.map((ride) => (
                  <UpcomingRideCard key={ride.id} ride={ride} canManage={isOrganizer} />
                ))}
              </Box>
            </DashboardSection>
          )}

          {latestPosts && (
            <DashboardSection
              id="dashboard-posts"
              title={t('teams.dashboard.posts.title')}
              seeAllTo={paths.teamPosts(slug)}
              isEmpty={posts.length === 0}
              empty={t('teams.dashboard.posts.empty')}
            >
              <LatestPostsList posts={posts} />
            </DashboardSection>
          )}
        </Stack>

        {hasAside && (
          <Stack gap="xl" style={{ flex: '1 1 300px', minWidth: 0 }}>
            {admin && <AdminPanel team={team} admin={admin} />}

            {organizer?.rideTemplates && (
              <TemplatesPanel teamSlug={slug} templates={organizer.rideTemplates} />
            )}

            {newRoutes && (
              <DashboardSection
                id="dashboard-routes"
                title={t('teams.dashboard.routes.title')}
                framed
                seeAllTo={paths.routes(slug)}
                isEmpty={newRoutes.routes.length === 0}
                empty={t('teams.dashboard.routes.empty')}
              >
                <NewRoutesList routes={newRoutes.routes} />
              </DashboardSection>
            )}

            {latestAds && (
              <DashboardSection
                id="dashboard-ads"
                title={t('teams.dashboard.ads.title')}
                framed
                seeAllTo={paths.ads(slug)}
                isEmpty={latestAds.ads.length === 0}
                empty={t('teams.dashboard.ads.empty')}
              >
                <LatestAdsList ads={latestAds.ads} />
              </DashboardSection>
            )}
          </Stack>
        )}
      </Flex>
    </Stack>
  )
}
