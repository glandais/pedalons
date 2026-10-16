import i18n, { type BackendModule } from 'i18next'
import { initReactI18next } from 'react-i18next'
import LanguageDetector from 'i18next-browser-languagedetector'
import dayjs from 'dayjs'
import 'dayjs/locale/fr'
import 'dayjs/locale/en'

// Both catalogues, bundled for the server only (see bundledResources below).
import frCommon from '../locales/fr/common.json'
import enCommon from '../locales/en/common.json'

export const supportedLanguages = ['fr', 'en'] as const
export type SupportedLanguage = (typeof supportedLanguages)[number]

export const languageNames: Record<SupportedLanguage, string> = {
  fr: 'Français',
  en: 'English',
}

// Every language ready synchronously, where a render may need any of them: the per-request server
// instances and the server's global instance. Referenced nowhere the browser bundle reaches (the
// global init below reads it behind `import.meta.env.SSR`), so the client build drops it and loads
// only the language it renders, through catalogueBackend.
const bundledResources = {
  fr: {
    common: frCommon,
  },
  en: {
    common: enCommon,
  },
}

// The browser's catalogues, one `locale-<lang>` chunk per language (vite.config.ts). server.js
// preloads the rendered language's chunk (and French, the fallback) from the Vite manifest, so it
// downloads alongside the entry instead of after it.
const catalogueLoaders: Record<
  SupportedLanguage,
  () => Promise<{ default: Record<string, string> }>
> = {
  fr: () => import('../locales/fr/common.json'),
  en: () => import('../locales/en/common.json'),
}

const catalogueBackend: BackendModule = {
  type: 'backend',
  init() {},
  read(language, _namespace, callback) {
    const load = catalogueLoaders[language as SupportedLanguage]
    if (!load) {
      callback(null, {})
      return
    }
    load().then(
      (module) => callback(null, module.default),
      (error: unknown) => callback(error instanceof Error ? error : new Error(String(error)), null)
    )
  },
}

const isServer = typeof window === 'undefined'

// Shared config used by both the client singleton and per-request server instances.
const i18nBaseConfig = {
  fallbackLng: 'fr' as const, // French is the default
  supportedLngs: supportedLanguages,
  defaultNS: 'common',
  ns: ['common'],
  interpolation: {
    escapeValue: false, // React already escapes values
  },
}

/**
 * Create a per-request i18n instance for SSR.
 * Avoids mutating the global singleton, which would race under concurrent requests.
 * No browser language detector is used; the language is resolved by the server.
 * dayjs locale is NOT set here — dayjs.locale() is global and would race under
 * concurrent requests. Use dayjs(date).locale(lng) at call sites if needed.
 */
export async function createServerI18n(language: string) {
  const instance = i18n.createInstance()
  await instance.use(initReactI18next).init({
    ...i18nBaseConfig,
    resources: bundledResources,
    lng: language || 'fr',
  })
  return instance
}

/**
 * Cookie carrying an explicit language choice (LanguageSwitcher), so the SSR server can render in
 * that language — the only way an anonymous visitor's choice survives a reload without a hydration
 * mismatch. The server reads it after a signed-in visitor's stored preference and before
 * Accept-Language (entry-server.tsx).
 */
export const LANGUAGE_COOKIE = 'lang'
const LANGUAGE_COOKIE_MAX_AGE = 60 * 60 * 24 * 365 // one year, in seconds

/** The supported language held by the {@link LANGUAGE_COOKIE} in a `Cookie` header, if any. */
export function languageFromCookieHeader(
  cookieHeader: string | undefined
): SupportedLanguage | undefined {
  const match = cookieHeader?.match(new RegExp(`(?:^|;\\s*)${LANGUAGE_COOKIE}=([^;]*)`))
  const value = match?.[1]
  return value && (supportedLanguages as readonly string[]).includes(value)
    ? (value as SupportedLanguage)
    : undefined
}

/**
 * Remember an explicit language choice for the next document request. Only explicit choices are
 * written: persisting the detected language would pin the Accept-Language of the first visit.
 */
export function persistLanguageChoice(language: string) {
  if (!(supportedLanguages as readonly string[]).includes(language)) return
  const secure = window.location.protocol === 'https:' ? '; Secure' : ''
  document.cookie = `${LANGUAGE_COOKIE}=${language}; Path=/; Max-Age=${LANGUAGE_COOKIE_MAX_AGE}; SameSite=Lax${secure}`
}

// Client-only initialization: browser language detection, dayjs locale, and the HTML lang
// attribute. Guarded so none of it runs during SSR (no document / no global dayjs mutation).
async function initClientI18n() {
  try {
    await i18n
      .use(LanguageDetector)
      .use(catalogueBackend)
      .use(initReactI18next)
      .init({
        ...i18nBaseConfig,
        detection: {
          // The server-emitted <html lang> is authoritative: it already applies, in order, the
          // signed-in visitor's stored preference, the LANGUAGE_COOKIE choice and Accept-Language,
          // so following it keeps the hydration render identical to the markup. navigator is only
          // a fallback for a page served without SSR.
          order: ['htmlTag', 'navigator'],
          // Nothing is cached from detection: the choice is persisted explicitly by
          // persistLanguageChoice. The former localStorage cache stored whatever <html lang> said
          // and, read back after init, overrode an anonymous visitor's choice on every reload.
          caches: [],
        },
      })
  } catch (err) {
    console.error('[i18n] Client initialization failed:', err)
  }

  // Drop the value the former localStorage cache left behind; it no longer drives anything.
  try {
    localStorage.removeItem('i18nextLng')
  } catch {
    // Storage unavailable (private mode, blocked site data): nothing to clean up.
  }

  // Update HTML lang attribute and dayjs locale when language changes
  const applyLanguage = (lng: string) => {
    document.documentElement.lang = lng
    dayjs.locale(lng)
  }

  applyLanguage(i18n.language)
  i18n.on('languageChanged', applyLanguage)
}

// Server-side, the global instance is initialized once with the bundled resources so that
// module-level t() call sites (date patterns, validation messages…) work during SSR. Its
// language is pinned to the fallback and NEVER mutated — per-request language lives in the
// createServerI18n instances; call sites that need the request language must pass { lng }
// explicitly (as useFormattedDate does). initAsync: false makes init synchronous, so the
// instance is ready before the first render.
if (isServer) {
  void i18n.use(initReactI18next).init({
    ...i18nBaseConfig,
    resources: import.meta.env.SSR ? bundledResources : {},
    lng: 'fr',
    initAsync: false,
  })
}

// Resolves once client i18n init completes. entry-client awaits this before hydrating so the
// initial client render matches the server markup. On the server it resolves immediately
// (the synchronous init above has already run by module-load end).
export const i18nReady: Promise<void> = isServer
  ? Promise.resolve()
  : initClientI18n().catch((err) => {
      console.error('[i18n] Unexpected error:', err)
    })

export default i18n
