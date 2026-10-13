import type { Locator, Page } from '@playwright/test'
import type {
  CommentDto,
  CommentListResponse,
  CommentRequest,
  GroupRequest,
  RideDto,
  RideParticipationDto,
  RideRequest,
  RideTemplateListResponse,
} from '../../src/api/dto'
import { apiGet, apiGetOrNull, apiPost, type AuthResponse } from './api'
import { markdownMedia } from './data'
import { wallTimeOf } from './dates'

/**
 * Rides seeded through the REST API as the ride editor creates them, participations, comments, and
 * the locators of the ride detail page.
 */

/**
 * A published, members-only ride two days ahead — comfortably inside "upcoming" whatever the
 * hour-aligned `from` boundary of the feeds — with one group, « Groupe A », unless `overrides` say
 * otherwise.
 */
export function rideRequest(name: string, overrides: Partial<RideRequest> = {}): RideRequest {
  const group: GroupRequest = { name: 'Groupe A' }
  return {
    name,
    media: markdownMedia(),
    dateTime: wallTimeOf(Date.now() + 2 * 24 * 3600 * 1000),
    status: 'PUBLISHED',
    visibility: 'TEAM',
    groups: [group],
    ...overrides,
  }
}

export const newRide = (
  by: AuthResponse,
  teamSlug: string,
  name: string,
  overrides: Partial<RideRequest> = {}
) => apiPost<RideDto>(by, `/api/teams/${teamSlug}/rides`, rideRequest(name, overrides))

const rideApiPath = (teamSlug: string, rideSlug: string) =>
  `/api/teams/${teamSlug}/rides/${rideSlug}`

/** The ride as `by` reads it through the API. */
export const readRide = (by: AuthResponse, teamSlug: string, rideSlug: string) =>
  apiGet<RideDto>(by, rideApiPath(teamSlug, rideSlug))

/** The ride as `by` reads it, or null when the API answers 404 (deleted, or never there). */
export const findRide = (by: AuthResponse, teamSlug: string, rideSlug: string) =>
  apiGetOrNull<RideDto>(by, rideApiPath(teamSlug, rideSlug))

export const readComments = (by: AuthResponse, teamSlug: string, rideSlug: string) =>
  apiGet<CommentListResponse>(by, `${rideApiPath(teamSlug, rideSlug)}/comments`)

export const readTemplates = (by: AuthResponse, teamSlug: string) =>
  apiGet<RideTemplateListResponse>(by, `/api/teams/${teamSlug}/ride-templates`)

export function groupId(ride: RideDto, name: string): string {
  const group = ride.groups.find((g) => g.name === name)
  if (!group) throw new Error(`ride ${ride.slug} has no group named ${name}`)
  return group.id
}

export const joinGroup = (who: AuthResponse, teamSlug: string, ride: RideDto, groupName: string) =>
  apiPost<RideParticipationDto>(
    who,
    `${rideApiPath(teamSlug, ride.slug)}/groups/${groupId(ride, groupName)}/join`
  )

/** Top-level comments, posted one after the other so their creation order is their text order. */
export async function postComments(
  who: AuthResponse,
  teamSlug: string,
  rideSlug: string,
  contents: string[]
) {
  for (const content of contents) {
    const request: CommentRequest = { content }
    await apiPost<CommentDto>(who, `${rideApiPath(teamSlug, rideSlug)}/comments`, request)
  }
}

export const ridePath = (teamSlug: string, rideSlug: string) =>
  `/equipes/${teamSlug}/sorties/${rideSlug}`

/**
 * Opens the ride page and waits for its title and its groups — the « Groupes » list, or a solo
 * ride's one group (ledger WEB-79), both under `ride-groups`: every later absence check needs a
 * loaded page.
 */
export async function openRide(page: Page, teamSlug: string, ride: RideDto) {
  await page.goto(ridePath(teamSlug, ride.slug))
  await page.getByRole('heading', { level: 2, name: ride.name }).waitFor()
  await page.getByTestId('ride-groups').waitFor()
}

/**
 * The card of one ride group (`RideGroupCard`, a Mantine Paper holding the group's name as its own
 * text) — or, on a solo ride's page (ledger WEB-79), its group panel (`RideSoloGroupPanel`, same
 * shape: name, places, join, leader). A solo ride's figures and participants follow the panel,
 * outside it. Group names are unique per test, so a second match is a strict-mode error, not a guess.
 * The « Météo » section is a Paper too, and names each group in its picker: it is a `<section>`,
 * a group card is not.
 */
export function groupCard(page: Page, groupName: string): Locator {
  return page
    .locator('.mantine-Paper-root:not(section)')
    .filter({ has: page.getByText(groupName, { exact: true }) })
}
