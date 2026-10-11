import { describe, expect, it } from 'vitest'
import fr from '@/locales/fr/common.json'
import en from '@/locales/en/common.json'

// The typecheck holds every t() call to the French catalogue only (i18next.d.ts): this holds the
// English one to the same keys. docs/LEDGER_*.md WEB-73.
const catalogues: Record<string, Record<string, unknown>> = { fr, en }

const PLURAL_SUFFIX = /_(zero|one|two|few|many|other)$/

/** Keys with their plural forms folded into the base key (`x_one`, `x_other` → `x`). */
function baseKeys(catalogue: Record<string, unknown>): string[] {
  const keys = new Set<string>()
  for (const key of Object.keys(catalogue)) {
    const base = key.replace(PLURAL_SUFFIX, '')
    keys.add(base !== key && `${base}_other` in catalogue ? base : key)
  }
  return [...keys].sort()
}

describe('translation catalogues', () => {
  it('give English the same keys as French', () => {
    // Plural forms differ by language (French has `_many`): only the base keys must match.
    expect(baseKeys(en)).toEqual(baseKeys(fr))
  })

  it.each(Object.keys(catalogues))('give each plural exactly the forms %s has', (language) => {
    const categories = new Intl.PluralRules(language).resolvedOptions().pluralCategories as string[]
    const catalogue = catalogues[language]
    const bases = Object.keys(catalogue)
      .filter((key) => key.endsWith('_other'))
      .map((key) => key.slice(0, -'_other'.length))
    // A missing form shows the raw key: French reads `_many` for a million (« 1 000 000 »).
    const missing = bases.flatMap((base) =>
      categories
        .filter((form) => !(`${base}_${form}` in catalogue))
        .map((form) => `${base}_${form}`)
    )
    // A form the language lacks is never read — `_zero` aside, i18next's own, read for a count of 0.
    const extra = Object.keys(catalogue).filter((key) => {
      const form = key.match(PLURAL_SUFFIX)?.[1]
      const base = key.replace(PLURAL_SUFFIX, '')
      return form && form !== 'zero' && bases.includes(base) && !categories.includes(form)
    })
    expect({ missing, extra }).toEqual({ missing: [], extra: [] })
  })

  it('hold no untranslated scaffold', () => {
    // What `pnpm format` (i18next-cli extract) writes for a key used in code but absent here: it
    // satisfies the typecheck, so only this catches it.
    for (const catalogue of Object.values(catalogues)) {
      const scaffolds = Object.keys(catalogue).filter(
        (key) => catalogue[key] === '___MISSING_TRANSLATION___'
      )
      expect(scaffolds).toEqual([])
    }
  })

  it('hold only strings, flat', () => {
    for (const catalogue of Object.values(catalogues)) {
      expect(Object.values(catalogue).filter((value) => typeof value !== 'string')).toEqual([])
    }
  })
})
