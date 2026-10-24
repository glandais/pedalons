import type { AdContactRequest, UserPreferencesRequest } from '../../src/api/dto'
import { apiContext, expectOk, type AuthResponse } from './api'

/**
 * Journey helpers for the classified-ad contact relay: the author's opt-out switch, a direct call to
 * the relay, and the ad as the API returns it. Ads themselves come from support/ads.ts, the relayed
 * mails from `mailsTo` in support/mailpit.ts.
 */

/** The profile switch « Accepter les messages des membres » (« Confidentialité »). */
export async function setContactable(user: AuthResponse, contactableByMembers: boolean) {
  const api = await apiContext(user.accessToken)
  try {
    const request: UserPreferencesRequest = { contactableByMembers }
    await expectOk(await api.patch('/api/users/me/preferences', { data: request }))
  } finally {
    await api.dispose()
  }
}

/** One message through the relay, straight to the API — used to consume the sender's quota. */
export async function contactAuthor(
  sender: AuthResponse,
  teamSlug: string,
  adSlug: string,
  message: string
) {
  const api = await apiContext(sender.accessToken)
  try {
    const request: AdContactRequest = { message }
    await expectOk(
      await api.post(`/api/teams/${teamSlug}/classifieds/${adSlug}/contact`, { data: request })
    )
  } finally {
    await api.dispose()
  }
}

/** The ad as a given member reads it, raw — to check what the API discloses. */
export async function rawAd(reader: AuthResponse, teamSlug: string, adSlug: string) {
  const api = await apiContext(reader.accessToken)
  try {
    const response = await api.get(`/api/teams/${teamSlug}/classifieds/${adSlug}`)
    if (!response.ok()) throw new Error(`GET ad → ${response.status()}`)
    return await response.text()
  } finally {
    await api.dispose()
  }
}
