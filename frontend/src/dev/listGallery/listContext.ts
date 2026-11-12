/**
 * The session and settings every list page reads, as the card gallery sets them
 * (`../cardGallery/GalleryRoot.tsx`), over the list gallery's own fake API.
 */
import { seedAppConfig } from '@/config/appConfig'
import { useAuthStore } from '@/store/authStore'
import { usePreferencesStore } from '@/store/preferencesStore'
import { APP_CONFIG, READER } from '../cardGallery/fixtures'
import { installListFakeApi, setScenario } from './listFakeApi'
import type { ListCase } from './cases'

/** Camille Durand signed in, metric units, the domain's config, the case's answers. */
export function seedListGallery(entry?: ListCase): void {
  installListFakeApi()
  setScenario(entry?.api ?? {})
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
