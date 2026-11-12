import type { TFunction } from 'i18next'

/**
 * « Groupe B » for a group named « B », but « Groupe 1 » — not « Groupe Groupe 1 » — for one
 * already named so (the editor's default name, `rides.create.form.groups.defaultName`). The app's
 * `groupTitle` (group_title.dart) is the same rule.
 */
export function groupTitle(name: string, t: TFunction): string {
  const trimmed = name.trim()
  const prefix = t('rides.group.title', { name: '' }).trim().toLowerCase()
  if (prefix) {
    const head = trimmed.toLowerCase()
    if (head === prefix || head.startsWith(`${prefix} `)) return trimmed
  }
  return t('rides.group.title', { name: trimmed })
}
