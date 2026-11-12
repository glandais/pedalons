import { describe, expect, it } from 'vitest'
import fr from '@/locales/fr/common.json'
import en from '@/locales/en/common.json'

/**
 * The search invites of the lists (docs/LEDGER_*.md WEB-175, RL7): « Rechercher {un objet}… »,
 * with the one-character ellipsis (U+2026), the app's own words — and « Rechercher par nom ou
 * e-mail… » for whoever administers the members, the only list that searches the address too.
 */
const INVITES: Record<string, string> = {
  'home.feed.search.placeholder': 'Rechercher une publication…',
  'teams.posts.search.placeholder': 'Rechercher une publication…',
  'agenda.search.placeholder': "Rechercher dans l'agenda…",
  'routes.list.search.placeholder': 'Rechercher un parcours…',
  'ads.list.search.placeholder': 'Rechercher une annonce…',
  'teams.list.search.placeholder': 'Rechercher une équipe…',
  'teams.detail.members.searchPlaceholder': 'Rechercher un membre…',
  'teams.detail.members.search.placeholder': 'Rechercher par nom ou e-mail…',
  'participants.searchPlaceholder': 'Rechercher une personne…',
  'rideTemplates.list.search.placeholder': 'Rechercher un modèle…',
  'rideTemplates.picker.search': 'Rechercher un modèle…',
  'routes.picker.search': 'Rechercher un parcours…',
  'places.search.placeholder': 'Rechercher un lieu…',
  'admin.users.searchPlaceholder': 'Rechercher par nom ou e-mail…',
}

describe('list search invites (RL7)', () => {
  it.each(Object.entries(INVITES))('%s reads « %s »', (key, text) => {
    expect((fr as Record<string, string>)[key]).toBe(text)
  })

  it('end on the one-character ellipsis, in English too', () => {
    for (const key of Object.keys(INVITES)) {
      expect((en as Record<string, string>)[key], key).toMatch(/\S…$/)
    }
  })
})
