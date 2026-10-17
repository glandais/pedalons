import { useState } from 'react'
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
import { Modal } from '@mantine/core'

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

  const initialValues = {
    name: '',
    media: defaultMedia(),
    surfaceType: SurfaceTypeEnum.ROAD as SurfaceType,
    visibility: team.visibility,
  }

  const handleSubmit = async (data: RouteRequest, gpxFile?: File) => {
    if (!gpxFile && (!data.points || data.points.length < 2)) return

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
      onClose={onClose}
      title={t('routes.create.title')}
      fullScreen
      closeOnEscape={!plannerFullscreen}
    >
      <RouteEditor
        team={team}
        teamSlug={team.slug}
        initialValues={initialValues}
        isCreateMode={true}
        onSubmit={handleSubmit}
        onCancel={onClose}
        isPending={createRouteMutation.isPending}
        error={createRouteMutation.error}
        submitButtonText={t('routes.create.submit')}
        showCancelButton={false}
        onPlannerFullscreenChange={setPlannerFullscreen}
      />
    </Modal>
  )
}
