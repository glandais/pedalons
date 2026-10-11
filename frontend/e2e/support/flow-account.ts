import { inflateRawSync } from 'node:zlib'
import { expect, type BrowserContext, type Locator, type Page } from '@playwright/test'
import type { CalendarTokenDto, PasskeyDto, UserDto } from '../../src/api/dto'
import { apiGet, refresh, refreshHeld, withApi, type AuthResponse } from './api'
import type { WallClock } from './dates'
import { escapeRegExp, hydrated } from './ui'

/**
 * Helpers for the account journeys (flow-account.e2e.ts): the header's account controls on both
 * layouts, the links of the auth mails, the session cookie and the account as the API sees it, and
 * the personal ICS feed read the way a calendar application reads it.
 */

/**
 * The link to `path` (`/verify-email`, `/reset-password`) in a mail, as the backend wrote it — the
 * whole URL, so the test follows exactly what a reader would click.
 */
export function mailLinkTo(text: string, path: string): string {
  const match = text.match(
    new RegExp(`https?://[^\\s"<>]+${escapeRegExp(path)}\\?token=[^\\s"<>&]+`)
  )
  if (!match) throw new Error(`no ${path}?token= link in mail:\n${text}`)
  return match[0]
}

/**
 * Where the header's global controls (theme, language, account) are on screen: the header itself on
 * desktop, the burger's drawer on mobile — which this opens. On desktop the collapsed drawer still
 * holds a second copy of every control, hence the scoping.
 */
export async function headerControls(page: Page, isMobile: boolean): Promise<Locator> {
  if (!isMobile) return page.getByRole('banner')
  const drawer = page.getByRole('navigation').filter({ has: page.getByRole('combobox') })
  // The burger has no accessible name (Layout.tsx) — it is the header's only visible button on
  // this layout, the desktop group being display:none.
  const burger = page.getByRole('banner').getByRole('button')
  await hydrated(burger)
  await burger.click()
  await expect(drawer.getByRole('combobox')).toBeInViewport()
  return drawer
}

/** Signs out through the header: the account menu on desktop, the drawer's button on mobile. */
export async function signOutFromHeader(page: Page, isMobile: boolean, displayName: string) {
  if (isMobile) {
    const drawer = await headerControls(page, true)
    await drawer.getByRole('button', { name: 'Se déconnecter' }).click()
    return
  }
  const account = page.getByRole('banner').getByRole('button', { name: displayName })
  await hydrated(account)
  await account.click()
  await page.getByRole('menuitem', { name: 'Se déconnecter' }).click()
}

/** The refresh_token cookie the browser holds, if any. */
export async function sessionCookie(context: BrowserContext): Promise<string | undefined> {
  return (await context.cookies()).find((c) => c.name === 'refresh_token')?.value
}

/**
 * A session as a test reaches it: the browser context holding its cookie, the AuthResponse the test
 * holds, or a bare token.
 */
export type Session = BrowserContext | { refreshToken: string } | string

/**
 * Refreshes `session` and keeps the rotated token where it came from (docs/LEDGER_*.md SEC-27): in
 * the browser's cookie, or in the AuthResponse. Left behind, the old token would be presented again
 * later, after the grace: rotated again from itself, it kills the successor whoever held it
 * (docs/LEDGER_*.md API-94). A bare token cannot be kept: pass it once.
 */
async function refreshSession(session: Session): Promise<AuthResponse | null> {
  if (typeof session === 'string') return refresh(session)
  if (!('cookies' in session)) return refreshHeld(session)
  const cookies = await session.cookies()
  const cookie = cookies.find((c) => c.name === 'refresh_token')
  if (!cookie) return null
  const auth = await refresh(cookie.value)
  if (auth && auth.refreshToken !== cookie.value)
    await session.addCookies([{ ...cookie, value: auth.refreshToken }])
  return auth
}

/** Whether a session still opens on the backend. */
export async function sessionIsAlive(session: Session): Promise<boolean> {
  return (await refreshSession(session)) !== null
}

/** The account behind a session, as GET /api/users/me returns it. */
export async function meFromSession(session: Session): Promise<UserDto> {
  const auth = await refreshSession(session)
  if (!auth) throw new Error('the session no longer refreshes')
  return apiGet<UserDto>(auth, '/api/users/me')
}

/** The account's passkeys, as GET /api/auth/passkeys returns them. */
export const passkeysOf = (accessToken: string) =>
  apiGet<PasskeyDto[]>({ accessToken }, '/api/auth/passkeys')

/**
 * A CTAP2 virtual authenticator on `page`, through the Chrome DevTools Protocol (both projects run
 * Chromium): resident keys, user verification always granted, presence simulated — so the
 * browser's WebAuthn prompts resolve without a human. http://localhost is a secure context, so
 * WebAuthn is available there.
 */
export async function virtualAuthenticator(page: Page) {
  const cdp = await page.context().newCDPSession(page)
  await cdp.send('WebAuthn.enable')
  const { authenticatorId } = await cdp.send('WebAuthn.addVirtualAuthenticator', {
    options: {
      protocol: 'ctap2',
      transport: 'internal',
      hasResidentKey: true,
      hasUserVerification: true,
      isUserVerified: true,
      automaticPresenceSimulation: true,
    },
  })
  return {
    credentials: async () =>
      (await cdp.send('WebAuthn.getCredentials', { authenticatorId })).credentials,
  }
}

/** The account's calendar token and feed URLs, as GET /api/calendar/token returns them. */
export const calendarTokenOf = (who: AuthResponse) =>
  apiGet<CalendarTokenDto>(who, '/api/calendar/token')

/** What a calendar application gets from a feed URL: no session, no cookie, just the URL. */
export async function fetchFeed(url: string) {
  return withApi(undefined, async (api) => {
    const response = await api.get(url)
    return {
      status: response.status(),
      contentType: response.headers()['content-type'] ?? '',
      body: await response.text(),
    }
  })
}

/** One VEVENT of a feed: its properties by name (parameters dropped: `DTSTART;VALUE=DATE` → `DTSTART`). */
export type IcsEvent = Record<string, string>

/**
 * Parses an iCalendar body strictly enough to call it valid (RFC 5545): CRLF line endings, one
 * VCALENDAR wrapping everything, VERSION 2.0 and a PRODID, every VEVENT closed and carrying the
 * UID, DTSTAMP and DTSTART the RFC requires. Throws on the first violation.
 */
export function parseIcs(body: string): { name: string | undefined; events: IcsEvent[] } {
  if (!body.endsWith('\r\n')) throw new Error('an iCalendar body ends with CRLF')
  if (/[^\r]\n/.test(body)) throw new Error('an iCalendar line ends with a bare LF')
  // Unfold continuation lines (CRLF followed by a space or a tab).
  const lines = body
    .replace(/\r\n[ \t]/g, '')
    .split('\r\n')
    .slice(0, -1)
  if (lines[0] !== 'BEGIN:VCALENDAR' || lines.at(-1) !== 'END:VCALENDAR')
    throw new Error(`not one VCALENDAR: ${lines[0]} … ${lines.at(-1)}`)
  const calendar: Record<string, string> = {}
  const events: IcsEvent[] = []
  let event: IcsEvent | undefined
  for (const line of lines.slice(1, -1)) {
    const colon = line.indexOf(':')
    if (colon < 1) throw new Error(`not a content line: ${line}`)
    const name = line.slice(0, colon).split(';')[0]
    const value = line.slice(colon + 1)
    if (name === 'BEGIN' && value === 'VEVENT') {
      if (event) throw new Error('a VEVENT opened inside another')
      event = {}
    } else if (name === 'END' && value === 'VEVENT') {
      if (!event) throw new Error('END:VEVENT without BEGIN')
      for (const required of ['UID', 'DTSTAMP', 'DTSTART'])
        if (!event[required]) throw new Error(`a VEVENT has no ${required}`)
      events.push(event)
      event = undefined
    } else if (event) {
      event[name] = value
    } else {
      calendar[name] = value
    }
  }
  if (event) throw new Error('a VEVENT is never closed')
  if (calendar.VERSION !== '2.0') throw new Error(`VERSION is ${calendar.VERSION}`)
  if (!calendar.PRODID) throw new Error('no PRODID')
  return { name: calendar['X-WR-CALNAME'], events }
}

/** An instant as an iCalendar UTC date-time: 2026-09-27T07:29:20.218Z → 20260927T072920Z. */
export const icsDateTime = (instant: string) =>
  new Date(instant)
    .toISOString()
    .replace(/\.\d{3}Z$/, 'Z')
    .replace(/[-:]/g, '')

/**
 * Registers a passkey from « Connexion et sécurité », as a user does it: « Ajouter une clé d'accès »,
 * a device name,
 * « Enregistrer » — the virtual authenticator of {@link virtualAuthenticator} answers the browser's
 * prompt. Returns once the new passkey is listed.
 */
export async function addPasskeyFromProfile(page: Page, deviceName: string) {
  const main = page.getByRole('main')
  const add = main.getByRole('button', { name: "Ajouter une clé d'accès", exact: true })
  await hydrated(add)
  await add.click()
  const dialog = page.getByRole('dialog', { name: "Ajouter une clé d'accès" })
  await dialog.getByRole('textbox', { name: "Nom de l'appareil (optionnel)" }).fill(deviceName)
  const registered = page.waitForResponse(
    (r) => r.request().method() === 'POST' && r.url().includes('/api/auth/passkeys/register')
  )
  // The list is read again once the passkey is stored; under load that read can outlast an expect.
  const relisted = page.waitForResponse(
    (r) => r.request().method() === 'GET' && r.url().endsWith('/api/auth/passkeys')
  )
  await dialog.getByRole('button', { name: 'Enregistrer' }).click()
  expect((await registered).ok()).toBe(true)
  expect((await relisted).ok(), 'the passkey list was read again').toBe(true)
  await expect(dialog).toBeHidden()
  await expect(main.getByText(deviceName, { exact: true })).toBeVisible()
}

/**
 * How `instant` reads on the wall clock of `timeZone` — the same shape as dates.ts's
 * `parisWallClock`, for any zone, so `frenchDateTime` can spell it the way the app does.
 */
export function wallClockIn(instant: string, timeZone: string): WallClock {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-GB', {
      timeZone,
      year: 'numeric',
      month: 'numeric',
      day: 'numeric',
      hour: 'numeric',
      minute: 'numeric',
      hourCycle: 'h23',
    })
      .formatToParts(new Date(instant))
      .map((part) => [part.type, part.value])
  )
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
  }
}

/**
 * The content of one file of a ZIP archive, read through its central directory (so an archive
 * written as a stream, sizes in data descriptors, reads the same). Stored and deflated entries only
 * — all java.util.zip writes. Throws when the archive has no such entry.
 */
export function zipEntry(archive: Buffer, name: string): Buffer {
  // End of central directory: signature 0x06054b50, within the last 64 KiB + 22 bytes.
  let eocd = archive.length - 22
  while (eocd >= 0 && archive.readUInt32LE(eocd) !== 0x06054b50) eocd--
  if (eocd < 0) throw new Error('not a ZIP archive: no end of central directory')
  const entries = archive.readUInt16LE(eocd + 10)
  let offset = archive.readUInt32LE(eocd + 16)
  const names: string[] = []
  for (let i = 0; i < entries; i++) {
    if (archive.readUInt32LE(offset) !== 0x02014b50) throw new Error('corrupt central directory')
    const method = archive.readUInt16LE(offset + 10)
    const compressedSize = archive.readUInt32LE(offset + 20)
    const nameLength = archive.readUInt16LE(offset + 28)
    const extraLength = archive.readUInt16LE(offset + 30)
    const commentLength = archive.readUInt16LE(offset + 32)
    const localHeader = archive.readUInt32LE(offset + 42)
    const entryName = archive.toString('utf8', offset + 46, offset + 46 + nameLength)
    names.push(entryName)
    if (entryName === name) {
      const dataStart =
        localHeader +
        30 +
        archive.readUInt16LE(localHeader + 26) +
        archive.readUInt16LE(localHeader + 28)
      const data = archive.subarray(dataStart, dataStart + compressedSize)
      if (method === 0) return data
      if (method === 8) return inflateRawSync(data)
      throw new Error(`${name}: unsupported compression method ${method}`)
    }
    offset += 46 + nameLength + extraLength + commentLength
  }
  throw new Error(`no ${name} in the archive; it holds: ${names.join(', ')}`)
}

/**
 * The picture of `displayName`'s avatar inside `scope`. Mantine's Avatar renders an `<img>` named by
 * its `alt` (the display name) only when it has a source; without one it shows the initials in a
 * placeholder that is no image at all — so a count of 0 means « no avatar yet ».
 */
export const avatarImage = (scope: Locator, displayName: string) =>
  scope.getByRole('img', { name: displayName, exact: true })

/**
 * Waits until `image` shows `src` and the browser actually decoded it — an `<img>` whose URL
 * answers 404 or a non-image is still on screen, with a naturalWidth of 0 (and Mantine would swap
 * it for the initials).
 */
export async function expectAvatarShown(image: Locator, src: string) {
  await expect(image).toBeVisible()
  await expect(image).toHaveAttribute('src', src)
  await expect
    .poll(() =>
      image.evaluate((element: HTMLImageElement) => element.complete && element.naturalWidth)
    )
    .toBeGreaterThan(0)
}
