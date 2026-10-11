import { useTranslation } from 'react-i18next'
import { Stack, Text } from '@mantine/core'
import type { TeamTimezoneChangePreviewDto } from '@/api/dto'
import { formatPattern, formatTime } from '@/utils/dateFormat'
import { zoneCityOf } from '@/utils/zoneLabel'

interface TimezoneChangePreviewProps {
  preview: TeamTimezoneChangePreviewDto
}

/**
 * What a change of the team's zone does (docs/LEDGER_*.md API-60, plan §9), in the backend's own
 * words: « 3 rendez-vous à venir sans lieu de départ : la sortie « Boucle » du samedi 11 octobre
 * restera à 09:30, désormais heure de Montréal ». The example's date and time are read in the OLD
 * zone — the wall time it keeps in the new one. The front computes no zone here: the list of what
 * moves comes from the backend, the zone only names it.
 */
export function TimezoneChangePreview({ preview }: TimezoneChangePreviewProps) {
  const { t, i18n } = useTranslation()
  const language = i18n.language
  const ofCity = zoneCityOf(preview.to, language)
  const first = preview.upcoming[0]

  return (
    <Stack gap="xs">
      <Text size="sm">
        {t('teams.settings.timezoneChange.question', {
          ofFrom: zoneCityOf(preview.from, language),
          ofTo: ofCity,
        })}
      </Text>
      <Text size="sm" data-testid="timezone-change-upcoming">
        {first
          ? t('teams.settings.timezoneChange.upcoming', {
              count: preview.upcomingCount,
              example: t(`teams.settings.timezoneChange.example.${first.type}`, {
                title: first.title,
                trip: first.tripTitle ?? '',
                date: formatPattern(
                  first.dateTime,
                  t('teams.settings.timezoneChange.datePattern'),
                  language,
                  preview.from
                ),
                time: formatTime(first.dateTime, language, preview.from),
                ofCity,
              }),
            })
          : t('teams.settings.timezoneChange.none')}
      </Text>
      {preview.pastCount > 0 && (
        <Text size="sm" c="dimmed">
          {t('teams.settings.timezoneChange.past', { count: preview.pastCount, ofCity })}
        </Text>
      )}
      <Text size="sm" c="dimmed">
        {t('teams.settings.timezoneChange.located')}
      </Text>
    </Stack>
  )
}
