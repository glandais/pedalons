import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import type { RouteDto, TeamDetailDto, SurfaceType, RouteRequest } from '@/api/dto'
import { RouteEditor } from './RouteEditor'
import { useCreateRoute } from '@/api/endpoints/routes/routes'
import { SurfaceType as SurfaceTypeEnum } from '@/api/dto'
import { defaultMedia } from '@/lib/apiUtils'
import { invalidateRouteQueries } from '@/lib/routeCacheInvalidation'
import { invalidatePlannerQuota } from '@/lib/plannerQuota'
import { Modal } from '@mantine/core'
import { ConfirmDialog } from '../common/ConfirmDialog'

interface CreateRouteModalProps {
  isOpen: boolean
  onClose: () => void
  onRouteCreated: (route: RouteDto) => void
  team: TeamDetailDto
}

export function CreateRouteModal({ isOpen, onClose, onRouteCreated, team }: CreateRouteModalProps) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const createRouteMutation = useCreateRoute()
  // Escape closes every Mantine modal at once: while the planner's fullscreen editor is open, it
  // must not take this form (and the unsaved route) down with it.
  const [plannerFullscreen, setPlannerFullscreen] = useState(false)
  // Closing (Annuler, the cross, Escape) asks first when a drawing or a file would be lost: the
  // ride's or trip's form stays, but this one goes (docs/LEDGER_*.md WEB-213).
  const dirtyRef = useRef<(() => boolean) | null>(null)
  const [confirmingClose, setConfirmingClose] = useState(false)
  const requestClose = () => {
    if (dirtyRef.current?.()) setConfirmingClose(true)
    else onClose()
  }

  const initialValues = {
    name: '',
    media: defaultMedia(),
    surfaceType: SurfaceTypeEnum.ROAD as SurfaceType,
    visibility: team.defaultContentVisibility,
    excludedFromGenerator: false,
  }

  const handleSubmit = async (data: RouteRequest, gpxFile?: File) => {
    if (!gpxFile && !data.plannerState && (!data.points || data.points.length < 2)) return

    const route = await createRouteMutation.mutateAsync(
      {
        teamSlug: team.slug,
        data: {
          route: data,
          gpxFile,
        },
      },
      {
        onSuccess: () => {
          invalidateRouteQueries(queryClient, team.slug)
          // A drawn track counted against the team's quota
          invalidatePlannerQuota(queryClient, team.slug)
          notifications.show({ message: i18next.t('routes.notifications.created'), color: 'green' })
        },
      }
    )

    onRouteCreated(route)
    onClose()
  }

  return (
    <Modal
      opened={isOpen}
      onClose={requestClose}
      title={t('routes.create.title')}
      fullScreen
      closeOnEscape={!plannerFullscreen && !confirmingClose}
    >
      <RouteEditor
        team={team}
        teamSlug={team.slug}
        initialValues={initialValues}
        isCreateMode={true}
        onSubmit={handleSubmit}
        onCancel={requestClose}
        isPending={createRouteMutation.isPending}
        error={createRouteMutation.error}
        submitButtonText={t('routes.create.submit')}
        onPlannerFullscreenChange={setPlannerFullscreen}
        dirtyRef={dirtyRef}
      />
      <ConfirmDialog
        isOpen={confirmingClose}
        onClose={() => setConfirmingClose(false)}
        onConfirm={() => {
          setConfirmingClose(false)
          onClose()
        }}
        title={t('leaveGuard.title')}
        message={t('leaveGuard.message')}
        confirmText={t('leaveGuard.leave')}
        cancelText={t('leaveGuard.stay')}
      />
    </Modal>
  )
}
