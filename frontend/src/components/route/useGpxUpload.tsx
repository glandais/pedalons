import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import { createRoute } from '@/api/endpoints/routes/routes'
import { SurfaceType, type TeamDetailDto } from '@/api/dto'
import { defaultMedia } from '@/lib/apiUtils'
import { invalidateRouteQueries } from '@/lib/routeCacheInvalidation'
import { defaultGpxName, readGpxNames } from '@/lib/gpxNames'
import { paths } from '@/config/paths'
import type { RouteEditorHandoff } from '@/lib/routeHandoff'

export interface GpxUpload {
  /** Opens the browser's file picker, several files allowed. */
  open: () => void
  /** While several files are sent: how many are done. */
  progress: { current: number; total: number } | null
}

/**
 * « Importer des GPX », as in the app: one file opens the route form with it (nothing is saved
 * before « Enregistrer »); several are imported at once, one route per file, named after the file's
 * own name (metadata, else first track, else the file name), with the team's default visibility and
 * a road surface, then the team's routes open. Progress and outcome are notifications, so the entry needs no place on the page:
 * the routes list, the team's dashboard and the member home offer it from their « Créer ▾ » menus.
 */
export function useGpxUpload(team: TeamDetailDto): GpxUpload {
  const teamSlug = team.slug
  const { t } = useTranslation()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [progress, setProgress] = useState<{ current: number; total: number } | null>(null)

  const importAll = async (files: File[]) => {
    const id = `gpx-import-${teamSlug}`
    const total = files.length
    setProgress({ current: 0, total })
    notifications.show({
      id,
      loading: true,
      autoClose: false,
      withCloseButton: false,
      message: t('routes.upload.progress', { current: 0, total }),
    })
    const failed: string[] = []
    for (let i = 0; i < total; i++) {
      const file = files[i]
      try {
        const name = defaultGpxName(await readGpxNames(file))
        await createRoute(teamSlug, {
          route: {
            name,
            visibility: team.defaultContentVisibility,
            surfaceType: SurfaceType.ROAD,
            media: defaultMedia(),
          },
          gpxFile: file,
        })
      } catch {
        failed.push(file.name)
      }
      setProgress({ current: i + 1, total })
      notifications.update({
        id,
        message: t('routes.upload.progress', { current: i + 1, total }),
      })
    }
    setProgress(null)
    const imported = total - failed.length
    if (imported > 0) {
      // Refresh every cached view of this team's routes (list, detail, bulk), and show them: the
      // new routes are there, as in the app.
      invalidateRouteQueries(queryClient, teamSlug)
      navigate(paths.routes(teamSlug))
    }
    notifications.update({
      id,
      loading: false,
      autoClose: failed.length ? false : 4000,
      withCloseButton: true,
      color: failed.length ? 'red' : 'green',
      message: failed.length
        ? t('routes.upload.partialFailure', { count: imported, names: failed.join(', ') })
        : t('routes.upload.done', { count: imported }),
    })
  }

  const open = () => {
    const input = document.createElement('input')
    input.type = 'file'
    input.accept = '.gpx'
    input.multiple = true
    input.onchange = () => {
      const files = Array.from(input.files ?? [])
      if (files.length === 1) {
        const state: RouteEditorHandoff = { gpxFile: files[0] }
        navigate(paths.routeNew(teamSlug), { state })
      } else if (files.length > 1) {
        void importAll(files)
      }
    }
    input.click()
  }

  return { open, progress }
}
