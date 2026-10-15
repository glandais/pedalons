import { useTranslation } from 'react-i18next'
import { Paper, Stack, Title } from '@mantine/core'
import { AnalyticsPreference } from '@/components/analytics/AnalyticsPreference'
import { LegalPage } from './LegalPage'

/** Anchor of the box, for links to the opposition (« /confidentialite#mesure-audience »). */
const ANALYTICS_ANCHOR = 'mesure-audience'

/**
 * The privacy policy, with the opposition to the audience measurement above its text: the visitor
 * without an account — most of the public pages' audience — has no profile page to find it on
 * (docs/LEDGER_*.md WEB-90). Rendered here, outside the Markdown: that text is also shown by the
 * mobile app, which measures nothing and would display a marker as is.
 */
export function PrivacyPolicyPage() {
  const { t } = useTranslation()
  return (
    <LegalPage
      type="privacy"
      beforeContent={
        <Paper withBorder radius="md" p="md" id={ANALYTICS_ANCHOR}>
          <Stack gap="sm">
            <Title order={2} size="h4">
              {t('analytics.optOut.title')}
            </Title>
            <AnalyticsPreference />
          </Stack>
        </Paper>
      }
    />
  )
}
