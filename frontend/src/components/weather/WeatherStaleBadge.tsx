import { useTranslation } from 'react-i18next'
import { Badge } from '@mantine/core'
import { IconHistory } from '@tabler/icons-react'

/** « Prévision ancienne »: the server serves its last forecast rather than nothing. */
export function WeatherStaleBadge() {
  const { t } = useTranslation()
  return (
    <Badge color="yellow" variant="light" leftSection={<IconHistory size={12} aria-hidden />}>
      {t('rides.weather.stale')}
    </Badge>
  )
}
