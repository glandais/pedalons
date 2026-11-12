import { useTranslation } from 'react-i18next'

/** « 11/12 personnes », « 11 personnes » without a maximum — one form on every card (R5). */
export function useParticipantsLabel() {
  const { t } = useTranslation()
  return (count: number, max?: number) =>
    max
      ? t('rides.detail.groups.participants', { current: count, count: max })
      : t('rides.detail.groups.participantsNoMax', { count })
}
