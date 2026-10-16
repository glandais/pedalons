import { describe, expect, it } from 'vitest'
import { catalogueChunks, cataloguePreloadLinks } from './cataloguePreload.js'

const manifest = {
  'index.html': { file: 'assets/index-abc.js', isEntry: true },
  '_locale-fr-fr1.js': { file: 'assets/locale-fr-fr1.js', name: 'locale-fr' },
  '_locale-en-en1.js': { file: 'assets/locale-en-en1.js', name: 'locale-en' },
  // An app chunk that happens to be called `common` (components/common) is not a catalogue.
  '_common-xyz.js': { file: 'assets/common-xyz.js', name: 'common' },
}

describe('catalogueChunks', () => {
  it('maps each language to its catalogue chunk', () => {
    expect(catalogueChunks(manifest)).toEqual({
      fr: '/assets/locale-fr-fr1.js',
      en: '/assets/locale-en-en1.js',
    })
  })

  it('is empty without a manifest', () => {
    expect(catalogueChunks(undefined)).toEqual({})
  })
})

describe('cataloguePreloadLinks', () => {
  const chunks = catalogueChunks(manifest)

  it('preloads only the French catalogue for a French page', () => {
    expect(cataloguePreloadLinks(chunks, 'fr')).toBe(
      '<link rel="modulepreload" crossorigin href="/assets/locale-fr-fr1.js">'
    )
  })

  it('preloads the fallback after the page language', () => {
    expect(cataloguePreloadLinks(chunks, 'en')).toBe(
      '<link rel="modulepreload" crossorigin href="/assets/locale-en-en1.js">' +
        '<link rel="modulepreload" crossorigin href="/assets/locale-fr-fr1.js">'
    )
  })

  it('drops a language without a chunk', () => {
    expect(cataloguePreloadLinks({}, 'fr')).toBe('')
  })
})
