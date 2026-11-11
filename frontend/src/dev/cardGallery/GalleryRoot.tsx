/**
 * The contexts every card reads, as the site provides them: the app's own provider tree
 * (`AppProviders`: i18n, Mantine theme, React Query, dates), a signed-in session for Camille Durand,
 * metric units, the app config, and the fake API. Each case brings its own router
 * (`galleryLayout.tsx`).
 */
import { useState, type ReactNode } from 'react'
import type { i18n as I18nInstance } from 'i18next'
import { AppProviders } from '@/AppProviders'
import { makeQueryClient } from '@/lib/queryClient'
import { seedAppConfig } from '@/config/appConfig'
import { useAuthStore } from '@/store/authStore'
import { usePreferencesStore } from '@/store/preferencesStore'
import { installFakeApi } from './fakeApi'
import { APP_CONFIG, READER } from './fixtures'

/** Sets the session, the units and the config the cards read. Idempotent. */
export function seedGalleryContext(): void {
  installFakeApi()
  seedAppConfig(APP_CONFIG)
  useAuthStore.setState({
    user: READER,
    accessToken: 'galerie',
    hasPasskeys: false,
    isAuthenticated: true,
    isInitialized: true,
    isInitializing: false,
    isLoading: false,
    error: null,
  })
  usePreferencesStore.setState({ unitSystem: 'METRIC' })
}

function makeGalleryQueryClient() {
  const queryClient = makeQueryClient()
  // Fixtures never go stale and a refused request is not retried.
  queryClient.setDefaultOptions({
    ...queryClient.getDefaultOptions(),
    queries: { ...queryClient.getDefaultOptions().queries, retry: false, staleTime: Infinity },
  })
  return queryClient
}

export function GalleryRoot({ i18n, children }: { i18n: I18nInstance; children: ReactNode }) {
  const [queryClient] = useState(makeGalleryQueryClient)
  return (
    <AppProviders i18n={i18n} queryClient={queryClient} defaultColorScheme="light">
      {children}
    </AppProviders>
  )
}
