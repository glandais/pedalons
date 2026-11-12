import { useTranslation } from 'react-i18next'
import { Button, Group, Modal, Stack, Text } from '@mantine/core'
import type { PlannerQuotaDetails, PlannerQuotaScope } from '@/api/dto'
import { resetMonthName } from '@/lib/plannerQuota'

interface PlannerQuotaMessageProps {
  scope: PlannerQuotaScope
  limit: number
  /** First day of the month the count starts again (`YYYY-MM-DD`). */
  resetsOn: string
  /** The team on the free plan, for TEAM. */
  teamName?: string
  /** Help text of a disabled entry point: small and dimmed. The dialog's text is plain. */
  help?: boolean
}

/**
 * Why drawing on the map is closed for the month (plan BILL-10 §3.3): the reason the limit applies
 * (the team is on the free plan, or the user is in no unlocked team), the GPX import that stays,
 * the day the count starts again, and how the limit is lifted. Shared by the dialog of a refusal
 * and the help text of a disabled entry point.
 */
export function PlannerQuotaMessage({
  scope,
  limit,
  resetsOn,
  teamName,
  help = false,
}: PlannerQuotaMessageProps) {
  const { t, i18n } = useTranslation()
  const month = resetMonthName(resetsOn, i18n.language)
  const team = scope === 'TEAM'
  const size = help ? 'xs' : 'sm'
  const c = help ? 'dimmed' : undefined
  return (
    <Stack gap={4} data-testid="planner-quota-message">
      <Text size={size} c={c}>
        {team
          ? t('planner.quota.team', { teamName: teamName ?? '', limit })
          : t('planner.quota.personal', { limit })}
      </Text>
      <Text size={size} c={c}>
        {t('planner.quota.alternative', { month })}
      </Text>
      <Text size={size} c={c}>
        {team ? t('planner.quota.teamLift') : t('planner.quota.personalLift')}
      </Text>
    </Stack>
  )
}

interface PlannerQuotaModalProps {
  /** The refusal to explain; null keeps the dialog closed. */
  refusal: PlannerQuotaDetails | null
  onClose: () => void
}

/**
 * The blocking dialog of a PLANNER_QUOTA_REACHED refusal, whatever call met it: a save of a team
 * route, of a GPX preview, a promotion, or a route calculation. The quota was spent in the meantime
 * (another member saved, another tab): the entry points only close it when it is already spent on
 * loading. A local Mantine Modal: the app has no ModalsProvider.
 */
export function PlannerQuotaModal({ refusal, onClose }: PlannerQuotaModalProps) {
  const { t } = useTranslation()
  return (
    <Modal
      opened={!!refusal}
      onClose={onClose}
      title={t('planner.quota.title')}
      closeButtonProps={{ 'aria-label': t('aria.closeDialog') }}
      // Above the planner's fullscreen editor, which a route calculation is refused from
      zIndex={400}
    >
      {refusal && (
        <Stack data-testid="planner-quota-modal">
          <PlannerQuotaMessage
            scope={refusal.scope}
            limit={refusal.limit}
            resetsOn={refusal.resetsOn}
            teamName={refusal.teamName}
          />
          <Group justify="flex-end">
            <Button onClick={onClose}>{t('actions.close')}</Button>
          </Group>
        </Stack>
      )}
    </Modal>
  )
}
