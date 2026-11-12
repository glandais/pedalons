import type { TFunction } from 'i18next'

/**
 * How a ride group is named on every card and line, compact ones included (decision of
 * 2026-11-12, KIT §9): « Groupe B » for a name of one or two characters — a bare letter or number
 * reads as nothing on its own —, any other name as it is (« Les Rapides », « Groupe 1 »,
 * « Gr. A »). The app's `groupTitle` (group_title.dart) is the same rule.
 */
export function groupTitle(name: string, t: TFunction): string {
  const trimmed = name.trim()
  // Code points, not UTF-16 units: « É » and an emoji count as one character.
  const length = Array.from(trimmed).length
  if (length >= 1 && length <= 2) return t('rides.group.title', { name: trimmed })
  return trimmed
}
