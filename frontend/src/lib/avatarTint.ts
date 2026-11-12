/**
 * The colour of a person's avatar, the one rule of the site (docs/LEDGER_*.md WEB-167, R5 of
 * `docs/plans/2026-11-10-etat-des-lieux-affichage/audit-cartes/tri.md`): a stable hash of the
 * displayed name picks one of eleven accents, the reader is always the primary colour. The app does
 * exactly the same (`PdlAvatar.tintFor`, `PdlColors.avatarAccents` in
 * `mobile/lib/core/theme/pdl_colors.dart`) — same hash, same accents in the same order — so a person
 * wears the same colour on both. Change one, change the other.
 */

/**
 * The app's `avatarAccents`, value for value and in its order: dark tints, the same in both colour
 * schemes, so that white initials stay readable (KIT §8 and §9 — the four of KIT §8 are orange
 * `#e8590c`, blue `#1971c2`, green `#2f9e44`, grape `#ae3ec9`). The families keep the app's former
 * order: blue, teal, grape, lime, orange, violet, cyan, pink, green, yellow, red. Indigo, close to
 * the primary colour, is the reader's alone (decision of 2026-11-12, KIT §9): eleven for the others.
 */
export const AVATAR_ACCENTS = [
  '#087f5b', // teal 9
  '#6741d9', // violet 8
  '#0b7285', // cyan 9
  '#1971c2', // blue 8
  '#5c940d', // lime 9
  '#ae3ec9', // grape 7
  '#c2255c', // pink 8
  '#a16207', // ochre (darker than Mantine's yellow 9, which misses 3:1 on white)
  '#c92a2a', // red 9
  '#2f9e44', // green 8
  '#e8590c', // orange 8
] as const

/**
 * The app's `PdlAvatar.stableHash`: `hash * 31 + unit`, kept to 31 bits, over the UTF-16 code
 * units — what Dart's `String.codeUnits` and JavaScript's `charCodeAt` both read.
 */
export function stableHash(value: string): number {
  let hash = 0
  for (let i = 0; i < value.length; i++) {
    hash = (hash * 31 + value.charCodeAt(i)) & 0x7fffffff
  }
  return hash
}

/** The colour a name is drawn in. */
export function avatarAccent(name: string): (typeof AVATAR_ACCENTS)[number] {
  return AVATAR_ACCENTS[stableHash(name) % AVATAR_ACCENTS.length]
}

/** The background of an avatar without a photo: its colour, the primary for the reader. */
export function avatarBackground(name: string, isCurrentUser = false): string {
  return isCurrentUser ? 'var(--mantine-primary-color-filled)' : avatarAccent(name)
}

/** Two initials at most, from the name's first two words — the app's `PdlAvatar.initialsOf`. */
export function avatarInitials(name: string): string {
  const words = name.trim().split(/\s+/).filter(Boolean)
  if (words.length === 0) return '?'
  const first = (word: string) => (Array.from(word)[0] ?? '').toUpperCase()
  return words.length === 1 ? first(words[0]) : `${first(words[0])}${first(words[1])}`
}
