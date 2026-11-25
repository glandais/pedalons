import { useTranslation } from 'react-i18next'
import { useNavigate } from 'react-router-dom'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { TFunction } from 'i18next'
import { apiErrorCode, isNetworkError } from '@/lib/apiError'
import { CLIENT_ONLY_QUERY } from '@/lib/prefetchAudit'
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
type Progress = { current: number; total: number }

/**
 * The import under way for a team, shared by every instance of the hook (the list, the dashboard
 * and the home each have one): a second import does not start beside the first. Held in the
 * request's query cache, never fetched — so nothing module-level, and nothing on the server.
 */
const progressKey = (teamSlug: string) => ['gpx-import', teamSlug] as const

/** Why a file was refused, in a few words: the API's code when it has one. */
export function refusalReason(error: unknown, t: TFunction): string {
  if (isNetworkError(error)) return t('routes.upload.reason.network')
  const code = apiErrorCode(error)
  return code
    ? t(`errors.api.${code}`, { defaultValue: t('routes.upload.reason.unknown') })
    : t('routes.upload.reason.unknown')
}

export function useGpxUpload(team: TeamDetailDto): GpxUpload {
  const teamSlug = team.slug
  const { t } = useTranslation()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { data: progress = null } = useQuery<Progress | null>({
    queryKey: progressKey(teamSlug),
    queryFn: () => null,
    enabled: false,
    staleTime: Infinity,
    meta: { [CLIENT_ONLY_QUERY]: true },
  })
  const setProgress = (next: Progress | null) =>
    queryClient.setQueryData(progressKey(teamSlug), next)

  const importAll = async (files: File[]) => {
    // One import at a time per team (docs/LEDGER_*.md WEB-216)
    if (queryClient.getQueryData(progressKey(teamSlug))) return
    const id = `gpx-import-${teamSlug}`
    // Where the import started: the routes open at the end only if the person is still there
    const startedOn = window.location.pathname
    const total = files.length
    setProgress({ current: 0, total })
    notifications.show({
      id,
      loading: true,
      autoClose: false,
      withCloseButton: false,
      message: t('routes.upload.progress', { current: 0, total }),
    })
    const failed: { name: string; reason: string }[] = []
    for (let i = 0; i < total; i++) {
      const file = files[i]
      try {
        const name = defaultGpxName(await readGpxNames(file))
        await createRoute(
          teamSlug,
          {
            route: {
              name,
              visibility: team.defaultContentVisibility,
              surfaceType: SurfaceType.ROAD,
              media: defaultMedia(),
            },
            gpxFile: file,
          },
          // The outcome is the summary below, not one toast per file
          { skipErrorToast: true }
        )
      } catch (error) {
        failed.push({ name: file.name, reason: refusalReason(error, t) })
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
      // Only from the page the import started on: someone who went on elsewhere (a ride's form)
      // is not pulled away from it (docs/LEDGER_*.md WEB-216).
      if (window.location.pathname === startedOn) navigate(paths.routes(teamSlug))
    }
    const outcome = imported
      ? t('routes.upload.done', { count: imported })
      : t('routes.upload.noneImported')
    notifications.update({
      id,
      loading: false,
      autoClose: failed.length ? false : 4000,
      withCloseButton: true,
      color: failed.length ? (imported ? 'yellow' : 'red') : 'green',
      message: failed.length
        ? `${outcome}. ${t('routes.upload.refused', {
            count: failed.length,
            list: failed.map((f) => `${f.name} (${f.reason})`).join(' ; '),
          })}`
        : outcome,
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
