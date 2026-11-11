#!/usr/bin/env node
/**
 * Captures the card gallery (src/dev/cardGallery, ledger WEB-167): one full-page screenshot per
 * section, at 1280 px and at 390 px wide, light mode.
 *
 *   pnpm dev                                    # in another terminal: the gallery is dev-only
 *   node scripts/capture-card-gallery.mjs <dir> [--base https://localhost:5173]
 *
 * Files: <dir>/<section>-1280.png and <dir>/<section>-390.png. The sections are read from the
 * gallery's own table of contents, so this script never lists them twice. The base URL defaults to
 * https://localhost:5173 (the dev server with the mkcert certificates), falling back to http.
 */
import fs from 'node:fs'
import path from 'node:path'
import { chromium } from 'playwright'

const WIDTHS = [1280, 390]
const GALLERY_PATH = '/dev/cards.html'

function parseArgs(argv) {
  const args = { out: undefined, base: undefined }
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--base') args.base = argv[++i]
    else if (!args.out) args.out = argv[i]
  }
  return args
}

async function reachable(page, base) {
  try {
    const response = await page.goto(`${base}${GALLERY_PATH}`, {
      waitUntil: 'load',
      timeout: 15_000,
    })
    return !!response && response.ok()
  } catch {
    return false
  }
}

async function main() {
  const { out, base: requestedBase } = parseArgs(process.argv.slice(2))
  if (!out) {
    console.error('Usage: node scripts/capture-card-gallery.mjs <output-dir> [--base <url>]')
    process.exit(2)
  }
  fs.mkdirSync(out, { recursive: true })

  const browser = await chromium.launch()
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    colorScheme: 'light',
    locale: 'fr-FR',
    timezoneId: 'Europe/Paris',
    deviceScaleFactor: 2,
    viewport: { width: WIDTHS[0], height: 900 },
  })
  const page = await context.newPage()
  page.on('console', (message) => {
    if (message.text().includes('[galerie]') || message.type() === 'error') {
      console.warn(`  console.${message.type()}: ${message.text()}`)
    }
  })

  const candidates = requestedBase
    ? [requestedBase]
    : ['https://localhost:5173', 'http://localhost:5173']
  let base
  for (const candidate of candidates) {
    if (await reachable(page, candidate)) {
      base = candidate
      break
    }
  }
  if (!base) {
    console.error(
      `Gallery unreachable at ${candidates.join(' or ')}${GALLERY_PATH} — is \`pnpm dev\` running?`
    )
    await browser.close()
    process.exit(1)
  }

  await page.waitForSelector('nav[aria-label="Sommaire"] a')
  const sections = await page.$$eval('nav[aria-label="Sommaire"] a', (links) =>
    links
      .map((a) => new URLSearchParams(a.getAttribute('href') ?? '').get('section'))
      .filter(Boolean)
  )
  console.log(`Gallery at ${base}${GALLERY_PATH}: ${sections.length} sections`)

  for (const width of WIDTHS) {
    await page.setViewportSize({ width, height: 900 })
    for (const section of sections) {
      await page.goto(`${base}${GALLERY_PATH}?section=${section}`, { waitUntil: 'networkidle' })
      await page.waitForSelector(`[data-gallery-section="${section}"]`)
      await page.evaluate(() => document.fonts.ready)
      // Scroll through once so the cards' lazy images load, then let the fake API's answers settle.
      await page.evaluate(async () => {
        for (let y = 0; y < document.body.scrollHeight; y += window.innerHeight) {
          window.scrollTo(0, y)
          await new Promise((resolve) => setTimeout(resolve, 50))
        }
        window.scrollTo(0, 0)
      })
      await page.waitForTimeout(500)
      const errors = await page.$$eval('[data-gallery-error]', (nodes) =>
        nodes.map((n) => n.getAttribute('data-gallery-error'))
      )
      if (errors.length > 0) console.warn(`  ${section}: render error in ${errors.join(', ')}`)
      const file = path.join(out, `${section}-${width}.png`)
      await page.screenshot({ path: file, fullPage: true })
      console.log(`  ${file}`)
    }
  }

  await browser.close()
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
