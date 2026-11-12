#!/usr/bin/env node
/**
 * Captures the list gallery (src/dev/listGallery): one picture per case, the browser window and not
 * the whole page (1280 × 900 and 390 × 900), light mode.
 *
 *   pnpm dev --port 5183 --strictPort           # in another terminal: the gallery is dev-only
 *   node scripts/capture-list-gallery.mjs <dir> [--base http://localhost:5183] [--only <case>,…]
 *
 * The page's clock is pinned at today 12:00, Paris time (Playwright `clock.setFixedTime`), as for
 * the card gallery (`capture-card-gallery.mjs`): the gallery's data is relative to that « now ».
 *
 * Files: <dir>/<section>/<case>-1280.png and <dir>/<section>/<case>-390.png, at a device pixel
 * ratio of 2. The cases are read from the gallery's own table of contents, so this script never
 * lists them twice; what a case needs before its shot comes from its own attributes: the list to
 * bring to the top of the window (`data-gallery-scroll`) and the clicks that open a panel or a
 * drop-down (`data-gallery-clicks`), made here as real clicks.
 */
import fs from 'node:fs'
import path from 'node:path'
import { chromium } from 'playwright'

const WIDTHS = [1280, 390]
const HEIGHT = 900
const GALLERY_PATH = '/dev/lists.html'
const ZONE = 'Europe/Paris'

/** The wall clock of `date` in Paris, field by field. */
function wallClock(date) {
  return Object.fromEntries(
    new Intl.DateTimeFormat('en-CA', {
      timeZone: ZONE,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    })
      .formatToParts(date)
      .map((p) => [p.type, Number(p.value)])
  )
}

/** Paris's offset from UTC at `date`, in milliseconds. */
function offsetAt(date) {
  const w = wallClock(date)
  return Date.UTC(w.year, w.month - 1, w.day, w.hour, w.minute) - Math.floor(date / 60_000) * 60_000
}

/** Today at 12:00 in Paris, as an instant (the offset read at noon itself, DST included). */
function noonToday() {
  const { year, month, day } = wallClock(new Date())
  const noonAsUtc = Date.UTC(year, month - 1, day, 12)
  return new Date(noonAsUtc - offsetAt(new Date(noonAsUtc - offsetAt(new Date()))))
}

function parseArgs(argv) {
  const args = { out: undefined, base: undefined, only: undefined }
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--base') args.base = argv[++i]
    else if (argv[i] === '--only') args.only = argv[++i].split(',')
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
  const { out, base: requestedBase, only } = parseArgs(process.argv.slice(2))
  if (!out) {
    console.error('Usage: node scripts/capture-list-gallery.mjs <output-dir> [--base <url>]')
    process.exit(2)
  }
  fs.mkdirSync(out, { recursive: true })

  const browser = await chromium.launch()
  const context = await browser.newContext({
    ignoreHTTPSErrors: true,
    colorScheme: 'light',
    locale: 'fr-FR',
    timezoneId: ZONE,
    deviceScaleFactor: 2,
    viewport: { width: WIDTHS[0], height: HEIGHT },
  })
  const noon = noonToday()
  await context.clock.setFixedTime(noon)
  console.log(`Clock pinned at ${noon.toISOString()}`)
  const page = await context.newPage()
  page.on('console', (message) => {
    if (message.text().includes('[galerie]') || message.type() === 'error') {
      console.warn(`  console.${message.type()}: ${message.text().slice(0, 300)}`)
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

  await page.waitForSelector('nav[aria-label="Sommaire"] a[data-case]')
  const cases = (
    await page.$$eval('nav[aria-label="Sommaire"] a[data-case]', (links) =>
      links.map((a) => ({ section: a.dataset.section, id: a.dataset.case }))
    )
  ).filter((c) => !only || only.includes(c.id))
  console.log(`Gallery at ${base}${GALLERY_PATH}: ${cases.length} cases`)

  let failures = 0
  for (const width of WIDTHS) {
    await page.setViewportSize({ width, height: HEIGHT })
    for (const { section, id } of cases) {
      // A slow dev server (a cold chunk) is worth a second try before counting a failure.
      for (let attempt = 1; attempt <= 2; attempt++) {
      try {
        await page.goto(`${base}${GALLERY_PATH}?section=${section}&case=${id}`, {
          waitUntil: 'networkidle',
        })
        const root = page.locator(`[data-gallery-case="${id}"]`)
        await root.locator('main').waitFor({ timeout: 20_000 })
        await page.evaluate(() => document.fonts.ready)
        // The fake API answers at once; the page's own transitions (Collapse, skeletons) settle.
        await page.waitForTimeout(900)

        const scrollTo = await root.getAttribute('data-gallery-scroll')
        if (scrollTo) {
          await page.evaluate((selector) => {
            const target = document.querySelector(selector)
            if (target) window.scrollTo(0, target.getBoundingClientRect().top + window.scrollY - 16)
          }, scrollTo)
          await page.waitForTimeout(200)
        }

        const clicks = JSON.parse((await root.getAttribute('data-gallery-clicks')) ?? '[]')
        for (const step of clicks) {
          const target =
            'placeholder' in step
              ? root.getByPlaceholder(step.placeholder, { exact: true })
              : root.getByRole(step.role, { name: step.name, exact: true })
          await target.first().click()
          await page.waitForTimeout(500)
        }

        const dir = path.join(out, section)
        fs.mkdirSync(dir, { recursive: true })
        const file = path.join(dir, `${id}-${width}.png`)
        await page.screenshot({ path: file })
        console.log(`  ${file}`)
        break
      } catch (error) {
        if (attempt === 2) failures++
        console.error(`  ${section}/${id} at ${width}px (attempt ${attempt}): ${error.message.split('\n')[0]}`)
      }
      }
    }
  }

  await browser.close()
  if (failures > 0) {
    console.error(`${failures} capture(s) failed`)
    process.exit(1)
  }
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
