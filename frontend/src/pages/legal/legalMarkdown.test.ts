import { describe, expect, it } from 'vitest'
import { stripLeadingTitle } from './legalMarkdown'

describe('stripLeadingTitle', () => {
  it('drops the first-line h1 and the blank lines after it', () => {
    expect(stripLeadingTitle('# Politique de confidentialité\n\n**Mise à jour**\n')).toBe(
      '**Mise à jour**\n'
    )
  })

  it('handles CRLF and leading blank lines', () => {
    expect(stripLeadingTitle('\r\n# Terms\r\n\r\nBody')).toBe('Body')
  })

  it('drops a document made of its title only', () => {
    expect(stripLeadingTitle('# Title')).toBe('')
  })

  it('keeps a text that does not open on an h1', () => {
    const support = 'Une question ? Écrivez-nous.\n\n# Plus loin\n'
    expect(stripLeadingTitle(support)).toBe(support)
    expect(stripLeadingTitle('## Section\n\nBody')).toBe('## Section\n\nBody')
    expect(stripLeadingTitle('#hashtag\n')).toBe('#hashtag\n')
  })

  it('drops only the first h1', () => {
    expect(stripLeadingTitle('# One\n# Two\n')).toBe('# Two\n')
  })
})
