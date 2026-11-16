// A look at one screen, for a recette: open a URL as a device, take a screenshot, print the boxes
// of some elements. `scripts/recette.sh look` runs it; see frontend/e2e/README.md « Manual recette ».
//
//   node look.mjs <desktop|iphone|pixel|cdp> <url|path> <shot.png> [--boxes <css>]… [--full]
//                 [--click <text>] [--wait <css>] [--settle <ms>] [--width <px>]
//
// - iphone / pixel: Chromium's device emulation (iPhone 15, Pixel 7: touch, coarse pointer) — no
//   WebKit here, and no Chrome on iOS to drive. --width overrides the viewport width (e.g. 390).
// - cdp: the real Chrome of the phone `scripts/recette.sh web-android` opened (localhost:9222).
//   Its one context is the phone's own profile, with all its tabs: the page is found by URL
//   (a tab already on it, else a new tab), never `pages()[0]`.
// - a path is resolved against RECETTE_BASE_URL (default the e2e stack, http://localhost:8190).
// - --boxes prints [text, left, top, width, height] of every visible match (repeatable); --click
//   clicks the first element with that text (a tab, a radio…); --wait waits for a selector first.
//
// Prints one JSON line: { url, viewport, coarse, boxes: { <css>: [...] } }.
import { createRequire } from 'node:module'

const require = createRequire(new URL('../../package.json', import.meta.url))
const { chromium, devices } = require('@playwright/test')

const [mode, target, shot, ...rest] = process.argv.slice(2)
if (!mode || !target || !shot) {
  console.error('usage: look.mjs <desktop|iphone|pixel|cdp> <url|path> <shot.png> [options]')
  process.exit(2)
}
const options = { boxes: [], full: false, settle: 1500 }
for (let i = 0; i < rest.length; i++) {
  const flag = rest[i]
  if (flag === '--full') options.full = true
  else if (flag === '--boxes') options.boxes.push(rest[++i])
  else if (flag === '--click') options.click = rest[++i]
  else if (flag === '--wait') options.wait = rest[++i]
  else if (flag === '--settle') options.settle = Number(rest[++i])
  else if (flag === '--width') options.width = Number(rest[++i])
  else throw new Error(`look.mjs: unknown option ${flag}`)
}

const base = process.env.RECETTE_BASE_URL ?? 'http://localhost:8190'
const url = /^https?:/.test(target) ? target : new URL(target, base).href
const cdpPort = process.env.RECETTE_CDP_PORT ?? '9222'

const DEVICES = { desktop: 'Desktop Chrome', iphone: 'iPhone 15', pixel: 'Pixel 7' }

let browser
let page
if (mode === 'cdp') {
  browser = await chromium.connectOverCDP(`http://localhost:${cdpPort}`)
  const context = browser.contexts()[0]
  const origin = new URL(url).origin
  page =
    context.pages().find((p) => p.url() === url) ??
    context.pages().find((p) => p.url().startsWith(origin)) ??
    (await context.newPage())
  await page.bringToFront()
} else if (DEVICES[mode]) {
  browser = await chromium.launch()
  const device = devices[DEVICES[mode]]
  const viewport = options.width
    ? { width: options.width, height: Math.round((options.width * device.viewport.height) / device.viewport.width) }
    : device.viewport
  // Emulation drives Chromium whatever the device: WebKit's user agent would not match.
  const { defaultBrowserType: _ignored, ...settings } = device
  const context = await browser.newContext({
    ...settings,
    viewport,
    locale: 'fr-FR',
    timezoneId: 'Europe/Paris',
  })
  page = await context.newPage()
} else {
  console.error(`look.mjs: mode ${mode} — desktop, iphone, pixel or cdp`)
  process.exit(2)
}

try {
  await page.goto(url, { waitUntil: 'networkidle' })
  if (options.wait) await page.waitForSelector(options.wait)
  if (options.click) await page.getByText(options.click, { exact: false }).first().click()
  await page.waitForTimeout(options.settle)
  const info = await page.evaluate((selectors) => {
    const visible = (e) => {
      const r = e.getBoundingClientRect()
      return r.width > 0 && r.height > 0
    }
    const box = (e) => {
      const r = e.getBoundingClientRect()
      const text = (e.innerText || e.getAttribute('aria-label') || '').replace(/\s+/g, ' ').trim()
      return [text.slice(0, 60), ...[r.left, r.top, r.width, r.height].map(Math.round)]
    }
    return {
      url: location.href,
      viewport: [innerWidth, innerHeight],
      coarse: matchMedia('(pointer: coarse)').matches,
      boxes: Object.fromEntries(
        selectors.map((s) => [s, [...document.querySelectorAll(s)].filter(visible).map(box)])
      ),
    }
  }, options.boxes)
  await page.screenshot({ path: shot, fullPage: options.full })
  console.log(JSON.stringify(info))
} finally {
  // Over CDP, close only the connection: the phone's Chrome and its tabs stay.
  await browser.close().catch(() => {})
}
