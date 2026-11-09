import { useParams, Navigate } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import {
  Container,
  Paper,
  Group,
  Stack,
  Title,
  Text,
  Badge,
  Button,
  Box,
  Anchor,
} from '@mantine/core'
import { IconBolt, IconMapPin, IconPencil } from '@tabler/icons-react'
import { useStageDetailData } from './stageDetailData'
import { RouteDetailView } from '../../components/route/RouteDetailView'
import { paths } from '../../config/paths'
import { useAuth } from '../../hooks/useAuth'
import { useUnits } from '../../hooks/useUnits'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { DetailPageSkeleton } from '../../components/common/DetailPageSkeleton'
import { TripLayout } from '../../components/trip/TripLayout'
import { MediaDisplay } from '../../components/common/MediaDisplay'
import { EntityLogo } from '../../components/common/EntityLogo'
import { DepartureBlock } from '../../components/common/DepartureBlock'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { ShareButton } from '../../components/common/ShareButton'
import { CommentSection } from '../../components/comment'
import { STATUS_COLORS } from '@/lib/badgeColors.generated'
import { ErrorBoundary } from '@/components/common/ErrorBoundary'
import { StageWeatherSection } from '@/components/weather'
import { withMapColor } from '@/hooks/filters/mapColorFilters'
import { stageWindLeg } from '@/lib/tripWeatherOnMap'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function StageDetailPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { speed } = useUnits()
  const { teamSlug, tripSlug, stageSlug } = useParams<{
    teamSlug: string
    tripSlug: string
    stageSlug: string
  }>()
  useAuth() // For authentication context

  const {
    team: { data: team, isLoading: isLoadingTeam },
    trip: { data: trip, isLoading: isLoadingTrip, error, refetch },
    route: { data: route, isLoading: isLoadingRoute },
    routeSlug,
    weather,
  } = useStageDetailData(teamSlug, tripSlug, stageSlug)

  // Find stage (derived from the trip already in cache)
  const stage = trip?.stages?.find((s) => s.slug === stageSlug)

  useCanonicalPath(
    team && trip && stageSlug ? paths.stage(team.slug, trip.slug, stageSlug) : undefined
  )

  const isLoading = isLoadingTeam || isLoadingTrip || !!(routeSlug && isLoadingRoute)

  if (!isLoading && !team) {
    return <Navigate to={paths.teams()} replace />
  }

  if (team && (!team.enableTrips || !team.enableRoutes)) {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  if (isLoading || error || !trip) {
    return (
      <Container size="xl" py="xl">
        <QueryStateBoundary
          isLoading={isLoading}
          isError={!!error}
          error={error}
          isNotFound={!trip}
          onRetry={() => void refetch()}
          skeleton={<DetailPageSkeleton />}
          notFound={{
            title: t('trips.detail.notFound.title'),
            message: t('trips.detail.notFound.message'),
            backTo: paths.team(teamSlug!),
            backLabel: t('trips.detail.notFound.backToTrips'),
          }}
        >
          {null}
        </QueryStateBoundary>
      </Container>
    )
  }

  if (!stage) {
    return (
      <Container size="xl" py="xl">
        <QueryStateBoundary
          isLoading={false}
          isNotFound
          notFound={{
            title: t('trips.stage.notFound.title'),
            message: t('trips.stage.notFound.message'),
            backTo: paths.trip(teamSlug!, tripSlug!),
            backLabel: t('trips.stage.notFound.backToTrip'),
          }}
        >
          {null}
        </QueryStateBoundary>
      </Container>
    )
  }

  const stageIndex = trip.stages?.findIndex((s) => s.slug === stageSlug) ?? 0
  // Registering and the join banner follow the real membership; editing and the comment thread
  // (moderation), the rights a platform admin holds in every team (docs/LEDGER_*.md API-137).
  const { isMember, isOrganizer: canEdit } = teamAccess(team, isPlatformAdmin)
  const canReadComments = isMember || isPlatformAdmin
  // The stage's Météo mode on its map, and on its fullscreen map (WEB-118)
  const windLeg = stageWindLeg(trip, weather.data, stage.id)

  // Weather along the stage's route, its own state (docs/LEDGER_*.md API-76), under the map (WEB-143)
  const weatherSection = (
    <ErrorBoundary variant="inline">
      <StageWeatherSection
        weather={weather.data}
        stageId={stage.id}
        isLoading={weather.isLoading}
        isFetching={weather.isFetching}
        onRetry={() => void weather.refetch()}
        canEdit={canEdit}
        timezone={stage.timezone}
      />
    </ErrorBoundary>
  )

  return (
    <Container size="xl" py="xl">
      {/* Trip Header */}
      <Paper withBorder p="lg" mb="lg">
        <Group justify="space-between" align="flex-start" wrap="wrap">
          <Group style={{ minWidth: 0 }}>
            <EntityLogo
              logo={stage.media.assets.logo ?? trip.media.assets.logo}
              alt={stage.name || trip.name}
              size="lg"
            />
            <Box>
              <Anchor
                component={PrefetchLink}
                to={paths.trip(teamSlug!, tripSlug!)}
                c="dimmed"
                size="sm"
                underline="hover"
              >
                {trip.name}
              </Anchor>
              <Title order={2} lineClamp={1}>
                {stage.name}
              </Title>
            </Box>
            <Badge color={STATUS_COLORS[trip.status]}>
              {t(`status.${trip.status satisfies 'DRAFT' | 'PUBLISHED' | 'CANCELLED'}`)}
            </Badge>
          </Group>

          <Group gap="xs" wrap="nowrap">
            {canEdit && (
              <Button
                component={PrefetchLink}
                to={paths.tripEdit(teamSlug!, tripSlug!)}
                variant="outline"
                leftSection={<IconPencil size={16} />}
              >
                {t('actions.edit')}
              </Button>
            )}
            <ShareButton title={stage.name || trip.name} />
          </Group>
        </Group>
      </Paper>

      {/* Stage tabs + Stage content */}
      <TripLayout trip={trip} teamSlug={teamSlug!} currentTab={stageSlug!}>
        <Stack>
          {/* Stage header */}
          <Paper withBorder p="lg">
            <Group mb="md">
              <Badge size="xl" variant="light" color="primary" circle>
                {stageIndex + 1}
              </Badge>
              <Box>
                <Title order={2}>{stage.name}</Title>
                {stage.averageSpeed && (
                  <Group gap="xs" mt="xs">
                    <IconBolt size={16} />
                    <Text size="sm" c="dimmed">
                      {speed(stage.averageSpeed)}
                    </Text>
                  </Group>
                )}
              </Box>
            </Group>

            {/* The departure, under the title, before the description (docs/BRANDING.md §7.8,
                docs/LEDGER_*.md WEB-137). A stage carries no end of its own: no return. */}
            <Box mb="md">
              <DepartureBlock
                date={stage.dateTime}
                zone={stage.timezone}
                place={stage.startPlace}
              />
            </Box>

            {/* Description */}
            {stage.media.markdown && (
              <Box mb="md">
                <MediaDisplay media={stage.media} />
              </Box>
            )}

            {/* The start place is in the departure block; the end place, when there is one, here. */}
            {stage.endPlace && (
              <Group gap="sm">
                <IconMapPin size={20} color="var(--mantine-color-red-text)" />
                <Box>
                  <Text size="xs" c="dimmed">
                    {t('endPlace')}
                  </Text>
                  <Text fw={500}>{stage.endPlace.name}</Text>
                </Box>
              </Group>
            )}
          </Paper>

          {/* Route details */}
          {route && (
            <Box>
              <Group justify="space-between" mb="md">
                <Title order={3}>{route.name}</Title>
                <Button
                  component={PrefetchLink}
                  to={paths.route(teamSlug!, route.slug)}
                  variant="subtle"
                  size="sm"
                >
                  {t('trips.stage.viewRouteDetails')}
                </Button>
              </Group>
              <RouteDetailView
                route={route}
                teamSlug={teamSlug}
                showInfo={false}
                fullscreenPath={(colorBy) =>
                  withMapColor(paths.stageMap(teamSlug!, tripSlug!, stageSlug!), colorBy)
                }
                windLeg={windLeg}
                windAttribution={windLeg ? weather.data?.attribution : undefined}
                timezone={stage.timezone}
                beforeClimbs={weatherSection}
              />
            </Box>
          )}

          {/* Without a route, no map to stand under: the section still says why (NO_LOCATION…) */}
          {!route && weatherSection}

          {/* The stage's own thread, apart from the trip's — members only, like every thread */}
          {canReadComments && team && (
            <Box>
              <CommentSection
                teamSlug={teamSlug!}
                teamName={team.name}
                entityType="stages"
                entitySlug={stageSlug!}
                isOrganizer={canEdit}
              />
            </Box>
          )}
        </Stack>
      </TripLayout>
    </Container>
  )
}
