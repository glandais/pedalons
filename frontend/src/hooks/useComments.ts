import { useQuery, useInfiniteQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import {
  listRideComments,
  createRideComment,
  deleteRideComment,
  getListRideCommentsQueryKey,
} from '../api/endpoints/ride-comments/ride-comments'
import {
  listPostComments,
  createPostComment,
  deletePostComment,
  getListPostCommentsQueryKey,
} from '../api/endpoints/post-comments/post-comments'
import {
  listTripComments,
  createTripComment,
  deleteTripComment,
  getListTripCommentsQueryKey,
} from '../api/endpoints/trip-comments/trip-comments'
import {
  listRouteComments,
  createRouteComment,
  deleteRouteComment,
  getListRouteCommentsQueryKey,
} from '../api/endpoints/route-comments/route-comments'
import {
  listTripStageComments,
  createTripStageComment,
  deleteTripStageComment,
  getListTripStageCommentsQueryKey,
} from '../api/endpoints/trip-stage-comments/trip-stage-comments'
import { SortDirection } from '@/api/dto'
import type { CommentDto, CommentListResponse, CommentRequest } from '@/api/dto'

// Re-export types for convenience
export type { CommentDto, CommentListResponse, CommentRequest }

/** `stages` is a trip stage, addressed by its slug alone: it is unique within the team. */
export type EntityType = 'rides' | 'posts' | 'trips' | 'routes' | 'stages'

/** Top-level comments per request. The contract caps `size` at 100. */
export const COMMENT_PAGE_SIZE = 20

/**
 * The options `CommentSection` mounts with. Oldest first (docs/LEDGER_*.md WEB-175, RL5): a
 * conversation reads in order, replies already follow that order, it is the API's default and the
 * app's — « Afficher plus de commentaires » brings the later ones, under the earlier. The route
 * `prefetch`es in `routes.config.ts` must reproduce them, since both end up in the query key
 * (`{ size, sort }`).
 *
 * Exported so neither side can hold its own copy: the prefetch used to spell out
 * `{ size: COMMENT_PAGE_SIZE, sort: SortDirection.DESC }` in four places, and flipping the
 * section to ASC (as RL5 did) would have quietly turned all four into dead cache entries — the page refetching
 * on hydration, with nothing failing.
 */
export const COMMENT_LIST_OPTIONS = {
  size: COMMENT_PAGE_SIZE,
  sort: SortDirection.ASC,
} as const

interface CommentPageParams {
  page?: number
  size?: number
  sort?: SortDirection
  parentId?: string
}

function listComments(
  teamSlug: string,
  entityType: EntityType,
  entitySlug: string,
  params: CommentPageParams
) {
  switch (entityType) {
    case 'rides':
      return listRideComments(teamSlug, entitySlug, params)
    case 'posts':
      return listPostComments(teamSlug, entitySlug, params)
    case 'trips':
      return listTripComments(teamSlug, entitySlug, params)
    case 'routes':
      return listRouteComments(teamSlug, entitySlug, params)
    case 'stages':
      return listTripStageComments(teamSlug, entitySlug, params)
  }
}

function getQueryKey(teamSlug: string, entityType: EntityType, entitySlug: string) {
  switch (entityType) {
    case 'rides':
      return getListRideCommentsQueryKey(teamSlug, entitySlug)
    case 'posts':
      return getListPostCommentsQueryKey(teamSlug, entitySlug)
    case 'trips':
      return getListTripCommentsQueryKey(teamSlug, entitySlug)
    case 'routes':
      return getListRouteCommentsQueryKey(teamSlug, entitySlug)
    case 'stages':
      return getListTripStageCommentsQueryKey(teamSlug, entitySlug)
  }
}

/**
 * Top-level comments, one page at a time, in the order `options.sort` asks (oldest first on the
 * pages, {@link COMMENT_LIST_OPTIONS}).
 *
 * This used to load the entire tree in one request whatever its size. The query key keeps the
 * generated key as its prefix, so the mutations below still invalidate it by prefix.
 */
export function useComments(
  teamSlug: string | undefined,
  entityType: EntityType,
  entitySlug: string | undefined,
  options?: { size?: number; sort?: SortDirection }
) {
  const size = options?.size ?? COMMENT_PAGE_SIZE
  const sort = options?.sort

  return useInfiniteQuery({
    queryKey: [...getQueryKey(teamSlug!, entityType, entitySlug!), { size, sort }],
    queryFn: ({ pageParam }) =>
      listComments(teamSlug!, entityType, entitySlug!, { page: pageParam, size, sort }),
    initialPageParam: 0,
    getNextPageParam: (last) =>
      (last.page + 1) * last.size < last.itemTotal ? last.page + 1 : undefined,
    enabled: !!teamSlug && !!entitySlug,
    staleTime: 30 * 1000, // 30 seconds - comments need fresher data
  })
}

/**
 * The replies of one comment, fetched on demand.
 *
 * A paginated page of top-level comments does not necessarily embed every reply, so a thread
 * whose `replyCount` exceeds the replies it carries is expanded through this.
 */
export function useCommentReplies(
  teamSlug: string | undefined,
  entityType: EntityType,
  entitySlug: string | undefined,
  parentId: string,
  enabled: boolean
) {
  return useQuery({
    queryKey: [...getQueryKey(teamSlug!, entityType, entitySlug!), { parentId }],
    queryFn: () => listComments(teamSlug!, entityType, entitySlug!, { parentId, size: 100 }),
    enabled: enabled && !!teamSlug && !!entitySlug,
    staleTime: 30 * 1000,
  })
}

export function useCreateComment(
  teamSlug: string | undefined,
  entityType: EntityType,
  entitySlug: string | undefined
) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (data: CommentRequest) => {
      if (!teamSlug || !entitySlug) throw new Error('Team and entity slugs are required')
      switch (entityType) {
        case 'rides':
          return await createRideComment(teamSlug, entitySlug, data)
        case 'posts':
          return await createPostComment(teamSlug, entitySlug, data)
        case 'trips':
          return await createTripComment(teamSlug, entitySlug, data)
        case 'routes':
          return await createRouteComment(teamSlug, entitySlug, data)
        case 'stages':
          return await createTripStageComment(teamSlug, entitySlug, data)
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: getQueryKey(teamSlug!, entityType, entitySlug!) })
      notifications.show({ message: i18next.t('comments.notifications.created'), color: 'green' })
    },
  })
}

export function useDeleteComment(
  teamSlug: string | undefined,
  entityType: EntityType,
  entitySlug: string | undefined
) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: async (commentId: string) => {
      if (!teamSlug || !entitySlug) throw new Error('Team and entity slugs are required')
      switch (entityType) {
        case 'rides':
          return await deleteRideComment(teamSlug, entitySlug, commentId)
        case 'posts':
          return await deletePostComment(teamSlug, entitySlug, commentId)
        case 'trips':
          return await deleteTripComment(teamSlug, entitySlug, commentId)
        case 'routes':
          return await deleteRouteComment(teamSlug, entitySlug, commentId)
        case 'stages':
          return await deleteTripStageComment(teamSlug, entitySlug, commentId)
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: getQueryKey(teamSlug!, entityType, entitySlug!) })
      notifications.show({ message: i18next.t('comments.notifications.deleted'), color: 'green' })
    },
  })
}
