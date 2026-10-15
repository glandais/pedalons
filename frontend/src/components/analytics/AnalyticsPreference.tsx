import { useTranslation } from 'react-i18next'
import { Stack, Switch, Text } from '@mantine/core'
import { setAnalyticsOptedOut } from '@/lib/analytics/optOut'
import { useAnalyticsOptedOut, useBrowserSignalsOptOut } from '@/lib/analytics/useAnalyticsOptOut'

/**
 * Oppose the site's audience measurement (docs/plans/2026-10-15-web-analytics.md §4.4,
 * docs/LEDGER_*.md WEB-90). Shown on « Profil → Confidentialité » and on the privacy policy page,
 * for a visitor without an account. Stored in this browser, for this site only — never on the
 * account — which the label says, pointing at Do Not Track / GPC as the only global way.
 */
export function AnalyticsPreference() {
  const { t } = useTranslation()
  const optedOut = useAnalyticsOptedOut()
  const browserSignal = useBrowserSignalsOptOut()

  return (
    <Stack gap={4}>
      <Switch
        checked={!optedOut && !browserSignal}
        disabled={browserSignal}
        onChange={(event) => setAnalyticsOptedOut(!event.currentTarget.checked)}
        label={t('analytics.optOut.label')}
      />
      <Text size="xs" c="dimmed">
        {t('analytics.optOut.description')}
      </Text>
      {browserSignal && (
        <Text size="xs" c="dimmed">
          {t('analytics.optOut.browserSignal')}
        </Text>
      )}
    </Stack>
  )
}
