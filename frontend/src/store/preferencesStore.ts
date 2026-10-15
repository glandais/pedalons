import { create, type StoreApi } from 'zustand'
import { UnitSystem } from '@/api/dto'
import { getSSRAuth } from '@/lib/ssrContext'
import { ssrAuthState } from '@/lib/ssrState'

const STORAGE_KEY = 'pedalons-unit-system'
const isServer = typeof window === 'undefined'

interface PreferencesState {
  unitSystem: UnitSystem
  setUnitSystem: (unitSystem: UnitSystem) => void
  syncFromServer: (unitSystem: string | null | undefined) => void
}

function parseUnitSystem(value: string | null | undefined): UnitSystem {
  return value === 'IMPERIAL' ? 'IMPERIAL' : 'METRIC'
}

function getStoredUnitSystem(): UnitSystem {
  if (isServer) return 'METRIC'
  return parseUnitSystem(localStorage.getItem(STORAGE_KEY))
}

/**
 * Mirrors authStore.ts's handling of the SSR session (`ssrAuthState()`, the `#ssr-auth-state` data
 * block, parsed before any module script runs), so an authenticated session's unitSystem is already
 * known here, synchronously, at module load — the first client render can match the server
 * markup exactly. An anonymous localStorage preference is deliberately NOT read here (see
 * hydrateAnonymousPreferences below): the server has no way to know it, so reading it at module
 * scope would make the first client render diverge from the anonymous server markup (always
 * 'METRIC'), the exact hydration mismatch documented in docs/SSR.md "Finding 4".
 */
const ssrUser = isServer ? undefined : ssrAuthState()?.user
const initialUnitSystem: UnitSystem = ssrUser ? parseUnitSystem(ssrUser.unitSystem) : 'METRIC'

const preferencesStore = create<PreferencesState>()((set) => ({
  unitSystem: initialUnitSystem,

  setUnitSystem: (unitSystem) => {
    localStorage.setItem(STORAGE_KEY, unitSystem)
    set({ unitSystem })
  },

  syncFromServer: (serverUnitSystem) => {
    if (!serverUnitSystem) return
    const unitSystem = parseUnitSystem(serverUnitSystem)
    localStorage.setItem(STORAGE_KEY, unitSystem)
    set({ unitSystem })
  },
}))

/**
 * The unitSystem for the request being rendered, derived from the per-request session
 * (getSSRAuth()) rather than from the store's own (process-wide) state. Same constraint as
 * authStore's ssrAuthState(): the Zustand store above is a module singleton shared by every
 * concurrent render in the Node process, so it must never hold one visitor's preference.
 * Anonymous requests render 'METRIC' — the same default an anonymous client's first render uses.
 */
function ssrPreferencesState(): PreferencesState {
  const actions = preferencesStore.getState()
  const unitSystem = parseUnitSystem(getSSRAuth()?.user?.unitSystem)
  return { ...actions, unitSystem }
}

function usePreferencesStoreOnServer(): PreferencesState
function usePreferencesStoreOnServer<T>(selector: (state: PreferencesState) => T): T
function usePreferencesStoreOnServer<T>(
  selector?: (state: PreferencesState) => T
): T | PreferencesState {
  const state = ssrPreferencesState()
  return selector ? selector(state) : state
}

function usePreferencesStoreOnClient(): PreferencesState
function usePreferencesStoreOnClient<T>(selector: (state: PreferencesState) => T): T
function usePreferencesStoreOnClient<T>(
  selector?: (state: PreferencesState) => T
): T | PreferencesState {
  return selector ? preferencesStore(selector) : preferencesStore()
}

type UsePreferencesStore = typeof usePreferencesStoreOnServer &
  Pick<StoreApi<PreferencesState>, 'getState' | 'setState' | 'subscribe'>

// Assign onto a fresh function, never onto `preferencesStore` itself: see authStore.ts for why
// (overwriting the Zustand store's own setState with the wrapper below would make it call itself).
export const usePreferencesStore: UsePreferencesStore = Object.assign(
  isServer ? usePreferencesStoreOnServer : usePreferencesStoreOnClient,
  {
    getState: () => (isServer ? ssrPreferencesState() : preferencesStore.getState()),
    setState: ((...args: Parameters<StoreApi<PreferencesState>['setState']>) => {
      if (isServer) {
        throw new Error(
          '[SSR] usePreferencesStore.setState() must not be called on the server: the store is ' +
            'shared by all concurrent renders. Preferences render from the per-request session ' +
            '(see ssrPreferencesState).'
        )
      }
      return preferencesStore.setState(...args)
    }) as StoreApi<PreferencesState>['setState'],
    subscribe: preferencesStore.subscribe,
  }
)

/**
 * Applies a locally-stored preference for a visitor the server rendered anonymously — the only
 * case where the module-load `initialUnitSystem` above couldn't already be correct. Skipped when
 * the SSR session carried a user, since the store was already seeded from it. Called once,
 * post-hydration (see useAuth.ts), so it never affects the first client render compared against
 * the server markup — only a harmless one-off re-render after, same tradeoff as
 * ColorSchemeSwitcher's `hydrated` guard.
 */
export function hydrateAnonymousPreferences(): void {
  if (isServer || ssrAuthState()?.user) return
  const stored = getStoredUnitSystem()
  if (stored !== preferencesStore.getState().unitSystem) {
    preferencesStore.setState({ unitSystem: stored })
  }
}
