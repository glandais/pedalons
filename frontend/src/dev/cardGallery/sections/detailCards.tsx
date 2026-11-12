import { Fragment, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { Divider, Stack } from '@mantine/core'
import type { RideDto, RideGroupDto, TripStageDto } from '@/api/dto'
import { RideGroupCard } from '@/components/ride/RideGroupCard'
import { TripStageCard } from '@/components/trip/TripStageCard'
import { canSwitchTo, groupAction, groupsRegisteredFirst } from '@/pages/ride/rideGroupData'
import { rideMapRoutes } from '@/pages/ride/rideMapRoutes'
import { someGroupLeavesAtOwnTime } from '@/utils/groupStart'
import { routeColor } from '@/lib/routeColors'
import type { GallerySection } from '../galleryLayout'
import {
  TRIP_SLUG,
  VCM_SLUG,
  ride,
  routeDetails,
  stages,
  weatherLeg,
  weatherSummary,
} from '../fixtures'

/**
 * A ride's group cards with the props `RideDetailPage` gives them — same helpers, same order (the
 * reader's group first, then « Autres groupes »). `only` keeps one group, for a single-card case.
 */
function GroupCards({
  ride: theRide,
  only,
  withWeather = true,
  fullOn,
}: {
  ride: RideDto
  /** A single card: the group of that name, as `only` reshapes it. */
  only?: { name: string; reshape?: (group: RideGroupDto) => RideGroupDto }
  withWeather?: boolean
  /** « Rejoindre » just failed on the group of that name: it filled up meanwhile (R6). */
  fullOn?: string
}) {
  const { t } = useTranslation()
  const routesBySlug = useMemo(routeDetails, [])
  const { colorByGroupId } = useMemo(
    () => rideMapRoutes(theRide, t('rides.detail.mainRoute')),
    [theRide, t]
  )
  const groups = only
    ? theRide.groups.filter((g) => g.name === only.name).map(only.reshape ?? ((g) => g))
    : groupsRegisteredFirst(theRide.groups, theRide.registeredGroupId)
  const isRegisteredInGroup = theRide.groups.some((g) => g.id === theRide.registeredGroupId)

  return (
    <Stack gap="sm">
      {groups.map((group, index) => (
        <Fragment key={group.id}>
          {index === 1 && isRegisteredInGroup && (
            <Divider label={t('rides.detail.groups.others')} labelPosition="left" mt="xs" />
          )}
          <RideGroupCard
            group={group}
            rideTimezone={theRide.timezone}
            rideDateTime={theRide.dateTime}
            showStartTime={someGroupLeavesAtOwnTime(theRide.groups, theRide.dateTime)}
            teamSlug={VCM_SLUG}
            rideSlug={theRide.slug}
            rideRouteSlug={only ? group.routeSlug : theRide.routeSlug}
            routesBySlug={routesBySlug}
            trackColor={colorByGroupId.get(group.id)}
            weatherLeg={withWeather ? weatherLeg(group) : undefined}
            action={groupAction(theRide, group)}
            canSwitch={canSwitchTo(theRide, group)}
            canSeeParticipants={!!theRide.permissions.canSeeParticipants}
            onJoin={() => undefined}
            onLeave={() => undefined}
            onSwitch={() => undefined}
            error={fullOn === group.name ? t('rides.detail.groups.failure.full') : undefined}
          />
        </Fragment>
      ))}
    </Stack>
  )
}

export const groupsSection: GallerySection = {
  id: 'groupes',
  title: 'Groupes d’une sortie — RideGroupCard',
  entries: [
    {
      id: 'groupes-inscrite-b',
      label: 'les trois groupes, heures différentes, Camille dans le B',
      layout: 'side',
      render: () => <GroupCards ride={ride({ registered: true })} />,
    },
    {
      id: 'groupes-non-inscrite',
      label: 'les trois groupes à la même heure, Camille dans aucun',
      layout: 'side',
      render: () => <GroupCards ride={ride({ sameTime: true })} />,
    },
    {
      id: 'groupe-erreur',
      label: '« Rejoindre » sur B, la dernière place vient d’être prise : l’erreur dans sa carte',
      layout: 'side',
      render: () => {
        const base = ride({ sameTime: true })
        const failed = {
          ...base,
          groups: base.groups.map((g) =>
            g.name === 'B' ? { ...g, countParticipants: 12, full: true } : g
          ),
        }
        return <GroupCards ride={failed} fullOn="B" />
      },
    },
    {
      id: 'groupe-non-membre',
      label: 'groupe A vu par une personne non membre : le compte, jamais de visage',
      layout: 'side',
      render: () => (
        <GroupCards
          ride={ride(
            { sameTime: true },
            {
              permissions: {
                ...ride().permissions,
                canRegister: false,
                canComment: false,
                canSeeParticipants: false,
              },
            }
          )}
          only={{
            name: 'A',
            reshape: (group) => ({ ...group, participants: [], leader: undefined }),
          }}
        />
      ),
    },
    {
      id: 'groupe-sans-parcours',
      label: 'groupe B sans parcours, même heure, Camille dans aucun',
      layout: 'side',
      render: () => (
        <GroupCards
          ride={ride({ sameTime: true }, { routeSlug: undefined })}
          withWeather={false}
          only={{
            name: 'B',
            reshape: (group) => ({
              ...group,
              routeSlug: undefined,
              distance: undefined,
              elevationGain: undefined,
              thumbnailLightUrl: undefined,
              thumbnailDarkUrl: undefined,
            }),
          }}
        />
      ),
    },
    {
      id: 'groupe-sans-meteo',
      label: 'groupe A sans météo (aucune prévision pour lui), même heure',
      layout: 'side',
      render: () => (
        <GroupCards ride={ride({ sameTime: true })} withWeather={false} only={{ name: 'A' }} />
      ),
    },
  ],
}

function StageCards({
  list,
  weather,
  riding = false,
}: {
  list: TripStageDto[]
  weather?: boolean
  riding?: boolean
}) {
  return (
    <Stack gap="sm">
      {list.map((stage, index) => (
        <TripStageCard
          key={stage.id}
          stage={stage}
          index={index}
          teamSlug={VCM_SLUG}
          tripSlug={TRIP_SLUG}
          weather={weather ? weatherSummary(false, 10 + index) : undefined}
          riding={riding}
          trackColor={stage.route ? routeColor(index) : undefined}
        />
      ))}
    </Stack>
  )
}

export const stagesSection: GallerySection = {
  id: 'etapes',
  title: 'Étapes d’un voyage — TripStageCard',
  entries: [
    {
      id: 'etapes',
      label: 'les trois étapes',
      layout: 'side',
      render: () => <StageCards list={stages()} weather />,
    },
    {
      id: 'etape-inscrite',
      label: 'étape 1, Camille participe au voyage : « GPS »',
      layout: 'side',
      render: () => {
        const [first] = stages()
        return (
          <TripStageCard
            stage={first}
            index={0}
            teamSlug={VCM_SLUG}
            tripSlug={TRIP_SLUG}
            weather={weatherSummary(false, 10)}
            riding
            trackColor={routeColor(0)}
          />
        )
      },
    },
    {
      id: 'etape-sans-parcours',
      label: 'étape 2 sans parcours ni allure',
      layout: 'side',
      render: () => (
        <TripStageCard
          stage={stages(10, { withRoute: false })[1]}
          index={1}
          teamSlug={VCM_SLUG}
          tripSlug={TRIP_SLUG}
        />
      ),
    },
    {
      id: 'etape-alerte-pluie',
      label: 'étape 1, pluie 60 % vers 11:00',
      layout: 'side',
      render: () => {
        const [first] = stages()
        return (
          <TripStageCard
            stage={first}
            index={0}
            teamSlug={VCM_SLUG}
            tripSlug={TRIP_SLUG}
            weather={weatherSummary(true, 10)}
            trackColor={routeColor(0)}
          />
        )
      },
    },
  ],
}
