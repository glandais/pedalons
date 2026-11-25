import { useEffect, useState } from 'react'
import { useLocation, useNavigate } from 'react-router-dom'
import { readGeneratedHandoff, type GeneratedHandoff } from '@/lib/routeGenerator'
import { readDrawHandoff, readGpxFileHandoff } from '@/lib/routeHandoff'

export interface RouteEditorHandoffs {
  generated?: GeneratedHandoff
  gpxFile?: File
  draw: boolean
}

/**
 * What a route's create or edit page was handed through the location state (a generated or
 * retouched route, a GPX file, « Tracer sur la carte »), **taken once** (docs/LEDGER_*.md WEB-214).
 *
 * The page keeps what it read on its first render, and the history entry is then rewritten without
 * it: the browser's back button after a save no longer reopens the form with the same proposal (a
 * second route), nor replays a track replacement on the edit page.
 */
export function useRouteEditorHandoff(): RouteEditorHandoffs {
  const location = useLocation()
  const navigate = useNavigate()
  const [handoffs] = useState<RouteEditorHandoffs>(() => ({
    generated: readGeneratedHandoff(location.state),
    gpxFile: readGpxFileHandoff(location.state),
    draw: readDrawHandoff(location.state),
  }))

  const carried = location.state != null
  useEffect(() => {
    if (!carried) return
    navigate(
      { pathname: location.pathname, search: location.search, hash: location.hash },
      { replace: true, state: null, preventScrollReset: true }
    )
  }, [carried, navigate, location.pathname, location.search, location.hash])

  return handoffs
}
