import fr from '@/locales/fr/common.json'

/**
 * A `t` reading the French catalogue — interpolation and the `_one`/`_other` plural forms — for
 * tests that mock `react-i18next` (`vi.mock('react-i18next', async () => …frenchT…)`).
 */
const messages = fr as Record<string, string>

export function frenchT(key: string, options?: Record<string, unknown>): string {
  let message = messages[key]
  if (message === undefined && typeof options?.count === 'number') {
    const form = options.count === 0 ? '_zero' : options.count === 1 ? '_one' : '_other'
    message = messages[`${key}${form}`] ?? messages[`${key}_other`]
  }
  if (message === undefined && typeof options?.defaultValue === 'string') {
    message = options.defaultValue
  }
  return (message ?? key).replace(/\{\{(\w+)\}\}/g, (_, name: string) =>
    String(options?.[name] ?? '')
  )
}
