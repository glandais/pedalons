// The browser loads one translation catalogue, the language it renders, with a dynamic import
// (src/i18n/index.ts, catalogueLoaders). Left to that import, the catalogue would only be requested
// once the entry chunk has run — one more round trip before hydration. The page names it up front
// instead: a <link rel="modulepreload"> per catalogue the client will read, found in the Vite
// manifest by its chunk name, `locale-<lang>` (vite.config.ts).

/** French is i18next's fallback language: the client loads it alongside any other language. */
const FALLBACK_LANGUAGE = 'fr'

/**
 * The catalogue chunk of each language, as `{ fr: '/assets/locale-fr-….js', … }`, read from a Vite
 * client manifest. A language whose chunk is missing is simply absent: the page then loses the
 * preload, never its translations.
 */
export function catalogueChunks(manifest) {
  const chunks = {}
  for (const chunk of Object.values(manifest ?? {})) {
    const match = chunk?.name?.match(/^locale-(.+)$/)
    if (match && chunk.file?.endsWith('.js')) chunks[match[1]] = `/${chunk.file}`
  }
  return chunks
}

/** The modulepreload links for a page rendered in `lang`: its catalogue, then the fallback's. */
export function cataloguePreloadLinks(chunks, lang) {
  const languages = [...new Set([lang, FALLBACK_LANGUAGE])]
  return languages
    .map((language) => chunks[language])
    .filter(Boolean)
    .map((href) => `<link rel="modulepreload" crossorigin href="${href}">`)
    .join('')
}
