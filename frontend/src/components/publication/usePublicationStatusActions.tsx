import { useState, type ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import { Status, type RideDto, type TripDto } from '@/api/dto'
import {
  getGetRideQueryKey,
  useDeleteRide,
  useUndeleteRide,
  useUpdateRide,
} from '@/api/endpoints/rides/rides'
import {
  getGetTripQueryKey,
  useDeleteTrip,
  useUndeleteTrip,
  useUpdateTrip,
} from '@/api/endpoints/trips/trips'
import { getListPublicationsQueryKey } from '@/api/endpoints/publications/publications'
import { getGetTeamDashboardQueryKey } from '@/api/endpoints/teams/teams'
import { ConfirmDialog } from '@/components/common/ConfirmDialog'
import { paths } from '@/config/paths'
import { invalidateRideWeather } from '@/pages/ride/rideDetailData'
import { rideStatusRequest } from '@/pages/ride/rideFormData'
import { invalidateTripWeather } from '@/pages/trip/tripDetailData'
import { tripStatusRequest } from '@/pages/trip/tripFormData'
import { KIND_LABELS, type PublicationKind } from './publicationKind'
import {
  useRestoreRefusal,
  useVisibilityAlignment,
} from '@/components/visibility/useVisibilityAlignment'
import { invalidateRouteQueries } from '@/lib/routeCacheInvalidation'
import type { IncompatibleRouteDto } from '@/api/dto'

/** The publication whose status the organiser manages, with its kind. */
export type ManagedPublication = { kind: 'ride'; dto: RideDto } | { kind: 'trip'; dto: TripDto }

type Confirmation = 'unpublish' | 'cancel' | 'uncancel' | 'delete'

export interface PublicationStatusActions {
  kind: PublicationKind
  status: Status
  deleted: boolean
  publish: () => void
  restore: () => void
  confirm: (what: Confirmation) => void
  isUpdating: boolean
  isRestoring: boolean
  /** The four confirmation dialogs, to render once in the page. */
  dialogs: ReactNode
}

/**
 * Publishing, unpublishing, cancelling, restoring and deleting a ride or a trip, with their
 * confirmations (`publication` null while it loads: the page calls the hook before its early
 * returns) — one implementation for both detail pages (docs/LEDGER_*.md WEB-155). Every
 * mutation of both kinds is declared (hooks run unconditionally); only the publication's own are
 * called.
 *
 * Invalidated after a change: the publication, its weather (its own query key, not a prefix of the
 * publication's) and the team's feed. After a delete, the feed and the dashboard, then back to the
 * agenda: the reader was managing publications.
 */
export function usePublicationStatusActions(
  teamSlug: string,
  kind: PublicationKind,
  publication: ManagedPublication | null
): PublicationStatusActions {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [open, setOpen] = useState<Confirmation | null>(null)
  const labels = KIND_LABELS[kind]
  const slug = publication?.dto.slug ?? ''

  const updateRide = useUpdateRide()
  const deleteRide = useDeleteRide()
  const undeleteRide = useUndeleteRide()
  const updateTrip = useUpdateTrip()
  const deleteTrip = useDeleteTrip()
  const undeleteTrip = useUndeleteTrip()
  const isRide = kind === 'ride'
  const update = isRide ? updateRide : updateTrip
  const remove = isRide ? deleteRide : deleteTrip
  const undelete = isRide ? undeleteRide : undeleteTrip
  // Publishing goes through the full update, which checks the routes again: a route that went
  // « Équipe » under an older version (plan A1) is raised after confirmation (decision D5). A
  // restore carries no body to align with: its routes are listed, to be opened first.
  const alignedKind = isRide ? 'ride' : 'trip'
  const alignment = useVisibilityAlignment(alignedKind, update.isPending)
  const restoreRefusal = useRestoreRefusal(teamSlug, alignedKind)

  const invalidate = () => {
    if (isRide) {
      void queryClient.invalidateQueries({ queryKey: getGetRideQueryKey(teamSlug, slug) })
      void invalidateRideWeather(queryClient, teamSlug, slug)
    } else {
      void queryClient.invalidateQueries({ queryKey: getGetTripQueryKey(teamSlug, slug) })
      void invalidateTripWeather(queryClient, teamSlug, slug)
    }
    void queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug) })
  }

  const done = (message: string) => () => {
    invalidate()
    notifications.show({ message, color: 'green' })
  }

  const changeStatus = (status: Status, message: string, aligned?: IncompatibleRouteDto[]) => {
    const onSuccess = () => {
      aligned?.forEach((route) => invalidateRouteQueries(queryClient, teamSlug, route.slug))
      done(message)()
    }
    const onError = (error: unknown) =>
      alignment.offer(error, (routes) => changeStatus(status, message, routes))
    const alignVisibility = aligned ? true : undefined
    if (!publication) return
    if (publication.kind === 'ride') {
      updateRide.mutate(
        {
          teamSlug,
          rideSlug: slug,
          data: { ...rideStatusRequest(publication.dto, status), alignVisibility },
        },
        { onSuccess, onError }
      )
    } else {
      updateTrip.mutate(
        {
          teamSlug,
          tripSlug: slug,
          data: { ...tripStatusRequest(publication.dto, status), alignVisibility },
        },
        { onSuccess, onError }
      )
    }
    setOpen(null)
  }

  const deletePublication = () => {
    const onSuccess = () => {
      void queryClient.invalidateQueries({ queryKey: getListPublicationsQueryKey(teamSlug) })
      void queryClient.invalidateQueries({ queryKey: getGetTeamDashboardQueryKey(teamSlug) })
      notifications.show({ message: t(labels.deleted), color: 'green' })
      navigate(paths.teamAgenda(teamSlug))
    }
    if (isRide) deleteRide.mutate({ teamSlug, rideSlug: slug }, { onSuccess })
    else deleteTrip.mutate({ teamSlug, tripSlug: slug }, { onSuccess })
    setOpen(null)
  }

  const restore = () => {
    const onSuccess = done(t(labels.restored))
    const onError = (error: unknown) => restoreRefusal.offer(error, () => {})
    if (isRide) undeleteRide.mutate({ teamSlug, rideSlug: slug }, { onSuccess, onError })
    else undeleteTrip.mutate({ teamSlug, tripSlug: slug }, { onSuccess, onError })
  }

  const close = () => setOpen(null)
  const dialogs = (
    <>
      <ConfirmDialog
        isOpen={open === 'unpublish'}
        onClose={close}
        onConfirm={() => changeStatus(Status.DRAFT, t(labels.unpublished))}
        title={t('actions.unpublish')}
        message={t(labels.confirmUnpublish)}
        confirmText={t('actions.unpublish')}
        variant="warning"
        isLoading={update.isPending}
      />
      <ConfirmDialog
        isOpen={open === 'cancel'}
        onClose={close}
        onConfirm={() => changeStatus(Status.CANCELLED, t(labels.cancelled))}
        title={t(labels.cancelAction)}
        message={t(labels.confirmCancel)}
        confirmText={t(labels.cancelAction)}
        variant="warning"
        isLoading={update.isPending}
      />
      <ConfirmDialog
        isOpen={open === 'uncancel'}
        onClose={close}
        onConfirm={() => changeStatus(Status.DRAFT, t(labels.uncancelled))}
        title={t(labels.uncancelAction)}
        message={t(labels.confirmUncancel)}
        confirmText={t(labels.uncancelAction)}
        variant="info"
        isLoading={update.isPending}
      />
      <ConfirmDialog
        isOpen={open === 'delete'}
        onClose={close}
        onConfirm={deletePublication}
        title={t('actions.delete')}
        message={t(labels.confirmDelete)}
        confirmText={t('actions.delete')}
        variant="danger"
        isLoading={remove.isPending}
      />
      {alignment.dialog}
      {restoreRefusal.dialog}
    </>
  )

  return {
    kind,
    status: publication?.dto.status ?? Status.DRAFT,
    deleted: publication?.dto.deleted ?? false,
    publish: () => changeStatus(Status.PUBLISHED, t(labels.published)),
    restore,
    confirm: setOpen,
    isUpdating: update.isPending,
    isRestoring: undelete.isPending,
    dialogs,
  }
}
