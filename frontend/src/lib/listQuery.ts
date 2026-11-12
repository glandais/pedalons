import { keepPreviousData } from '@tanstack/react-query'
import type { AxiosRequestConfig } from 'axios'

/**
 * How every list page of the site reads its list (docs/LEDGER_*.md WEB-175, RL11) — in its hook,
 * in its neighbour-page prefetch and in its route's `prefetch`, so the three agree.
 *
 * `LIST_REQUEST`: the list says its own failure (`QueryStateBoundary`: « Chargement impossible »,
 * « Pas de connexion », a refusal), so the mutator's toast would only say it a second time, over
 * the block. Pass it as the generated hooks' `request` option, or as the fetcher's `options`.
 */
export const LIST_REQUEST = { skipErrorToast: true } as const satisfies AxiosRequestConfig

/**
 * `LIST_QUERY`: after a filter or a page change, the previous answer stays on screen — dimmed by
 * `QueryStateBoundary`'s `isRefreshing`, read from `isPlaceholderData` — until the next one
 * replaces it, the same on every list. Spread it into the hooks' `query` option.
 */
export const LIST_QUERY = { placeholderData: keepPreviousData } as const
