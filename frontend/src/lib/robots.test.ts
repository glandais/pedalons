// public/robots.txt keeps crawlers out of the API, yet every image a page can name as og:image /
// twitter:image (lib/seo.ts imgFromAsset / imgFromTemplate) must stay fetchable: link-preview bots
// that obey robots.txt (Twitterbot, LinkedInBot…) would otherwise show a card with no picture.
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, it, expect } from 'vitest'

interface Rule {
  allow: boolean
  pattern: string
}

const rules: Rule[] = readFileSync(resolve(process.cwd(), 'public/robots.txt'), 'utf8')
  .split('\n')
  .map((line) => line.replace(/#.*/, '').trim())
  .flatMap((line): Rule[] => {
    const match = /^(Allow|Disallow):\s*(\S+)$/i.exec(line)
    return match ? [{ allow: match[1].toLowerCase() === 'allow', pattern: match[2] }] : []
  })

/** RFC 9309 matching: `*` any run of characters, `$` end of path; longest pattern wins, Allow on a tie. */
function allowed(path: string): boolean {
  let best: Rule | undefined
  for (const rule of rules) {
    const source = rule.pattern
      .split('')
      .map((c) => (c === '*' ? '.*' : c === '$' ? '$' : c.replace(/[.+?^{}()|[\]\\/]/g, '\\$&')))
      .join('')
    if (!new RegExp(`^${source}`).test(path)) continue
    if (
      !best ||
      rule.pattern.length > best.pattern.length ||
      (rule.pattern.length === best.pattern.length && rule.allow)
    )
      best = rule
  }
  return best?.allow ?? true
}

describe('robots.txt', () => {
  // The template prefixes the backend hands out, with seo.ts's 1200 width filled in.
  const previewImages = [
    '/api/download/public/images/n-peloton/0abc/1200', // AssetService.buildImageUrl, PUBLIC
    '/api/download/public_unlisted/images/n-peloton/0abc/1200', // PUBLIC_UNLISTED, shared by link
    '/api/gpx-previews/0abc/thumbnail/1200', // GpxPreviewDto.thumbnailUrl
  ]

  it.each(previewImages)('lets link previews fetch %s', (path) => {
    expect(allowed(path)).toBe(true)
  })

  it.each([
    '/api/download/public/images/n-peloton/0abc/{size}',
    '/api/download/public/images/n-peloton/0abc/%7Bsize%7D',
    '/api/download/public_unlisted/images/n-peloton/0abc/{size}',
    '/api/download/public_unlisted/images/n-peloton/0abc/%7Bsize%7D',
    '/api/gpx-previews/0abc/thumbnail/{size}',
    '/api/gpx-previews/0abc/thumbnail/%7Bsize%7D',
  ])('keeps the unresolved template %s out', (path) => {
    expect(allowed(path)).toBe(false)
  })

  it.each([
    '/api/teams',
    '/api/version',
    '/api/teams/np/rides/x',
    '/api/download/public/assets/n-peloton/0abc/route.gpx',
    '/api/download/team/images/n-peloton/0abc/1200',
    '/api/gpx-previews/0abc/gpx',
  ])('keeps the API response %s out', (path) => {
    expect(allowed(path)).toBe(false)
  })

  it('leaves the pages crawlable', () => {
    expect(allowed('/')).toBe(true)
    expect(allowed('/equipes/np/sorties/x')).toBe(true)
    expect(allowed('/profil')).toBe(false)
  })
})
