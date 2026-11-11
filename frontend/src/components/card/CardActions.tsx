import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import { CardActionsMenu } from './common'
import { paths } from '@/config/paths'
import { invalidateRouteQueries } from '@/lib/routeCacheInvalidation'
import { getListPublicationsQueryKey } from '@/api/endpoints/publications/publications'
import {
  changeRideStatus,
  deleteRide,
  getDownloadRideIcsQueryKey,
  getGetRideQueryKey,
  getGetRideWeatherQueryKey,
} from '@/api/endpoints/rides/rides'
import {
  changeTripStatus,
  deleteTrip,
  getDownloadTripIcsQueryKey,
  getGetTripQueryKey,
} from '@/api/endpoints/trips/trips'
import { changePostStatus, deletePost, getGetPostQueryKey } from '@/api/endpoints/posts/posts'
import {
  changeAdStatus,
  deleteAd,
  getGetAdQueryKey,
  getListAdsQueryKey,
} from '@/api/endpoints/ads/ads'
import { deleteRoute } from '@/api/endpoints/routes/routes'
import { getGetTeamDashboardQueryKey } from '@/api/endpoints/teams/teams'
import type { AdDto, PublicationDto, RideDto, RouteDto, TripDto } from '@/api/dto'

/*
 * The per-type actions of a list card (docs/LEDGER_DONE.md WEB-33). Each wrapper decides which
 * actions apply and wires them to the API; `CardActionsMenu` only renders them.
 *
 * Publishing goes through `PATCH …/status`, never through the full update: a list row is a
 * compact projection without a ride's groups or a trip's stages, and sending it back as the whole
 * entity would delete them.
 */

interface PublicationCardActionsProps {
  /** Its `permissions` decide what is offered: edit and publish, delete (docs/LEDGER_*.md WEB-166). */
  publication: PublicationDto
}

export function PublicationCardActions({ publication }: PublicationCardActionsProps) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const teamSlug = publication.team.slug
  const slug = publication.slug

  // A soft-deleted row (shown to admins only) is restored from its page, not from the list.
  if (publication.deleted) {
    return null
  }

  const refresh = (detailKey: readonly unknown[]) => {
    queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug) })
    queryClient.invalidateQueries({ queryKey: getGetTeamDashboardQueryKey(teamSlug) })
    queryClient.invalidateQueries({ queryKey: detailKey })
    // A ride's forecast is its own key, not a prefix match of the ride's: a draft's cached
    // OUT_OF_RANGE would otherwise outlive its publication by the weather's staleTime.
    if (publication.type === 'RIDE') {
      queryClient.invalidateQueries({ queryKey: getGetRideWeatherQueryKey(teamSlug, slug) })
    }
  }

  const published = () => {
    refresh(detailKeyOf())
    notifications.show({ message: t(publishedMessageOf()), color: 'green' })
  }
  const deleted = () => {
    refresh(detailKeyOf())
    notifications.show({ message: t(deletedMessageOf()), color: 'green' })
  }

  function detailKeyOf() {
    switch (publication.type) {
      case 'RIDE':
        return getGetRideQueryKey(teamSlug, slug)
      case 'TRIP':
        return getGetTripQueryKey(teamSlug, slug)
      case 'POST':
        return getGetPostQueryKey(teamSlug, slug)
    }
  }
  function publishedMessageOf() {
    switch (publication.type) {
      case 'RIDE':
        return 'rides.notifications.published' as const
      case 'TRIP':
        return 'trips.notifications.published' as const
      case 'POST':
        return 'posts.notifications.published' as const
    }
  }
  function deletedMessageOf() {
    switch (publication.type) {
      case 'RIDE':
        return 'rides.notifications.deleted' as const
      case 'TRIP':
        return 'trips.notifications.deleted' as const
      case 'POST':
        return 'posts.notifications.deleted' as const
    }
  }

  const publish = { status: 'PUBLISHED' as const }
  let editPath: string
  let onPublish: () => Promise<unknown>
  let onDelete: () => Promise<unknown>
  let deleteMessage: string
  let icsUrl: string | undefined
  switch (publication.type) {
    case 'RIDE':
      editPath = paths.rideEdit(teamSlug, slug)
      onPublish = () => changeRideStatus(teamSlug, slug, publish).then(published)
      onDelete = () => deleteRide(teamSlug, slug).then(deleted)
      deleteMessage = t('rides.detail.confirmations.delete')
      icsUrl = upcoming(publication as RideDto)
        ? getDownloadRideIcsQueryKey(teamSlug, slug)[0]
        : undefined
      break
    case 'TRIP':
      editPath = paths.tripEdit(teamSlug, slug)
      onPublish = () => changeTripStatus(teamSlug, slug, publish).then(published)
      onDelete = () => deleteTrip(teamSlug, slug).then(deleted)
      deleteMessage = t('trips.detail.confirmations.delete')
      icsUrl = upcoming(publication as TripDto)
        ? getDownloadTripIcsQueryKey(teamSlug, slug)[0]
        : undefined
      break
    case 'POST':
      editPath = paths.postEdit(teamSlug, slug)
      onPublish = () => changePostStatus(teamSlug, slug, publish).then(published)
      onDelete = () => deletePost(teamSlug, slug).then(deleted)
      deleteMessage = t('posts.detail.confirmations.delete')
      break
  }

  // The backend's answers for this row (docs/LEDGER_*.md WEB-166, decision D7).
  const { canEdit, canDelete } = publication.permissions
  return (
    <CardActionsMenu
      title={publication.name}
      editPath={canEdit ? editPath : undefined}
      onPublish={canEdit && publication.status === 'DRAFT' ? onPublish : undefined}
      onDelete={canDelete ? onDelete : undefined}
      deleteMessage={deleteMessage}
      icsUrl={icsUrl}
    />
  )
}

/** Worth adding to a calendar: published, and not over yet (`finished`, computed by the server). */
function upcoming(publication: RideDto | TripDto): boolean {
  return publication.status === 'PUBLISHED' && !publication.finished
}

interface RouteCardActionsProps {
  /** Its `permissions` decide what is offered (docs/LEDGER_*.md WEB-166). */
  route: RouteDto
}

/** A route has no status: edit and delete only. */
export function RouteCardActions({ route }: RouteCardActionsProps) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const { canEdit, canDelete } = route.permissions
  if ((!canEdit && !canDelete) || route.deleted) {
    return null
  }
  const teamSlug = route.team.slug
  return (
    <CardActionsMenu
      title={route.name}
      editPath={canEdit ? paths.routeEdit(teamSlug, route.slug) : undefined}
      onDelete={
        canDelete
          ? () =>
              deleteRoute(teamSlug, route.slug).then(() => {
                invalidateRouteQueries(queryClient, teamSlug, route.slug)
                notifications.show({ message: t('routes.notifications.deleted'), color: 'green' })
              })
          : undefined
      }
      deleteMessage={t('routes.detail.deleteConfirm.message')}
    />
  )
}

interface AdCardActionsProps {
  /** Its `permissions` decide what is offered (docs/LEDGER_*.md WEB-166). */
  ad: AdDto
}

/**
 * An ad is managed by the team admin or its author — an organizer alone is not enough: the
 * backend's `permissions` say it, as `AdAccessChecker` decides.
 */
export function AdCardActions({ ad }: AdCardActionsProps) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const { canEdit, canDelete } = ad.permissions
  if ((!canEdit && !canDelete) || ad.deleted) {
    return null
  }
  const teamSlug = ad.team.slug
  const refresh = () => {
    queryClient.invalidateQueries({ queryKey: getListAdsQueryKey(teamSlug) })
    queryClient.invalidateQueries({ queryKey: getGetAdQueryKey(teamSlug, ad.slug) })
  }
  return (
    <CardActionsMenu
      title={ad.name}
      editPath={canEdit ? paths.adEdit(teamSlug, ad.slug) : undefined}
      onPublish={
        canEdit && ad.status === 'DRAFT'
          ? () =>
              changeAdStatus(teamSlug, ad.slug, { status: 'PUBLISHED' }).then(() => {
                refresh()
                notifications.show({ message: t('ads.notifications.published'), color: 'green' })
              })
          : undefined
      }
      onDelete={
        canDelete
          ? () =>
              deleteAd(teamSlug, ad.slug).then(() => {
                refresh()
                notifications.show({ message: t('ads.notifications.deleted'), color: 'green' })
              })
          : undefined
      }
      deleteMessage={t('ads.detail.confirmations.delete')}
    />
  )
}
