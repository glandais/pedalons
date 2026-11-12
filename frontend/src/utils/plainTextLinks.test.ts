import { describe, expect, it } from 'vitest'
import { splitPlainTextLinks } from './plainTextLinks'

// KIT §9 (2026-11-12): a comment stays raw text; only a full address becomes a link.
describe('splitPlainTextLinks', () => {
  it('cuts out a full http or https address, whole', () => {
    expect(
      splitPlainTextLinks('Trace : https://www.example.org/a/b?x=1&y=2#c et http://x.fr')
    ).toEqual([
      { kind: 'text', text: 'Trace : ' },
      { kind: 'link', href: 'https://www.example.org/a/b?x=1&y=2#c' },
      { kind: 'text', text: ' et ' },
      { kind: 'link', href: 'http://x.fr' },
    ])
  })

  it('leaves the punctuation that ends the sentence, and an unopened bracket, outside', () => {
    expect(splitPlainTextLinks('Voir https://x.fr/a. (ou https://x.fr/b)')).toEqual([
      { kind: 'text', text: 'Voir ' },
      { kind: 'link', href: 'https://x.fr/a' },
      { kind: 'text', text: '. (ou ' },
      { kind: 'link', href: 'https://x.fr/b' },
      { kind: 'text', text: ')' },
    ])
    expect(splitPlainTextLinks('https://fr.wikipedia.org/wiki/Col_(géographie)')).toEqual([
      { kind: 'link', href: 'https://fr.wikipedia.org/wiki/Col_(géographie)' },
    ])
  })

  it('interprets nothing else: no www., e-mail, markdown, HTML or other scheme', () => {
    for (const text of [
      'www.example.org',
      'lea@example.org',
      '[lien](javascript:alert(1))',
      '<a href="https://x.fr">x</a> **gras**'.replace('https://x.fr', 'ftp://x.fr'),
      'javascript:alert(1)',
      'https://',
    ]) {
      expect(splitPlainTextLinks(text)).toEqual([{ kind: 'text', text }])
    }
  })

  it('keeps the text as it is without an address, and returns nothing for an empty one', () => {
    expect(splitPlainTextLinks('À demain\n09:00')).toEqual([
      { kind: 'text', text: 'À demain\n09:00' },
    ])
    expect(splitPlainTextLinks('')).toEqual([])
  })
})
