import type { QueryClient } from '@tanstack/react-query'
import { useGetPost, prefetchGetPostQuery, getGetPostQueryKey } from '@/api/endpoints/posts/posts'
import { prefetchEntityTeam, useEntityTeam } from '@/lib/entityTeam'
import type { PostDto } from '@/api/dto'
import {
  listPostComments,
  getListPostCommentsQueryKey,
} from '@/api/endpoints/post-comments/post-comments'
import { prefetchMemberComments } from '@/config/prefetchHelpers'

/**
 * The one description of what the post detail screen reads, consumed two ways: `PostDetailPage`
 * calls {@link usePostDetailData} for the query results, the `post-detail` route in
 * `routes.config.ts` calls {@link prefetchPostDetail} for the same data server-side. Describing it
 * twice is what this file exists to prevent: a divergence doesn't break anything visibly, it just
 * yields a different query key, so the client refetches after hydration and only
 * the prefetch audit of
 * `e2e/routes-render.e2e.ts` notices.
 *
 * Its own module rather than exports of `PostDetailPage.tsx`: `routes.config.ts` is imported
 * eagerly and must not pull the page out of its lazy chunk (same contract as
 * `pages/ride/rideDetailData.ts`).
 */

/**
 * Every query `PostDetailPage` itself owns, returned as the raw query results so the page keeps
 * using `.data` / `.isLoading` / `.error` / `.refetch` directly.
 *
 * Comments deliberately stay out: they're fetched by `CommentSection`, a child the page mounts
 * only when `permissions.canComment`, not by the page itself. That's covered by {@link prefetchPostDetail}
 * instead, so the asymmetry is on purpose rather than a gap.
 */
export function usePostDetailData(teamSlug?: string, postSlug?: string) {
  const post = useGetPost(teamSlug!, postSlug!, {
    query: { enabled: !!teamSlug && !!postSlug },
  })
  // Behind the post, only when it says the team answers the reader (docs/LEDGER_*.md WEB-166).
  const team = useEntityTeam(teamSlug, post.data?.team)

  return { team, post }
}

/**
 * Server-side counterpart of {@link usePostDetailData}. Also prefetches the post's member
 * comments — fetched by `CommentSection`, a child the page mounts, not by the page itself.
 */
export async function prefetchPostDetail(
  queryClient: QueryClient,
  teamSlug: string,
  postSlug: string
): Promise<void> {
  await prefetchGetPostQuery(queryClient, teamSlug, postSlug)
  const post = queryClient.getQueryData<PostDto>(getGetPostQueryKey(teamSlug, postSlug))
  await Promise.all([
    prefetchEntityTeam(queryClient, teamSlug, post?.team),
    prefetchMemberComments(
      queryClient,
      teamSlug,
      postSlug,
      listPostComments,
      getListPostCommentsQueryKey,
      post?.permissions.canComment
    ),
  ])
}
