import { useMemo } from 'react'
import { useListTeamTags } from '@/api/endpoints/tags/tags'
import type { TagTarget } from '@/api/dto'

/**
 * The labels of the tags `ids` names, in the vocabulary's order, as a filtered empty state names
 * them (RL10). Reads the same query as `TagFilter`, so it costs nothing more; an unknown id
 * has no label and is left out, as the filter leaves it out.
 */
export function useTagLabels(
  teamSlug: string,
  type: TagTarget | undefined,
  ids: string[] | undefined
) {
  const { data: tags } = useListTeamTags(
    teamSlug,
    { type: type! },
    { query: { enabled: !!type }, request: { skipErrorToast: true } }
  )
  return useMemo(() => {
    const wanted = new Set(ids ?? [])
    return (tags ?? []).filter((tag) => wanted.has(tag.id)).map((tag) => tag.label)
  }, [tags, ids])
}
