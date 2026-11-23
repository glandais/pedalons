import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  CloseButton,
  Group,
  Paper,
  Stack,
  Text,
  ThemeIcon,
  Title,
  UnstyledButton,
  VisuallyHidden,
} from '@mantine/core'
import { IconCheck, IconMap2, IconBike, IconUserPlus, type TablerIcon } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { paths } from '@/config/paths'
import type { FirstStepsState } from '@/pages/team/teamHomeData'
import { OPEN_INVITE_STATE } from './dashboardHelpers'
import classes from './FirstSteps.module.css'

const dismissedKey = (teamId: string) => `pedalons.firstSteps.dismissed.${teamId}`

function isDismissed(teamId: string): boolean {
  try {
    return localStorage.getItem(dismissedKey(teamId)) === '1'
  } catch {
    return false
  }
}

function dismiss(teamId: string): void {
  try {
    localStorage.setItem(dismissedKey(teamId), '1')
  } catch {
    // Private mode: it closes for this page only.
  }
}

interface FirstStepsProps {
  teamId: string
  teamSlug: string
  state: FirstStepsState
}

/**
 * « Premières étapes », for whoever administers a team that is still empty (docs/LEDGER_*.md
 * WEB-195): invite members, create a first ride, import or draw a first route — each leading to
 * its screen, each ticked from the team as it is (`useFirstSteps`), nothing stored. The list goes
 * once every step is done, like « À traiter » when nothing waits, and closes by hand — that choice
 * is kept in localStorage, per team, so it is only read after hydration: nothing on the first
 * render, then the list if it was not closed.
 */
export function FirstSteps({ teamId, teamSlug, state }: FirstStepsProps) {
  const { t } = useTranslation()
  const [dismissed, setDismissed] = useState(true)

  useEffect(() => {
    setDismissed(isDismissed(teamId))
  }, [teamId])

  // Only the steps that apply to this team, in this order.
  const candidates: (Omit<Step, 'done'> & { done: boolean | undefined })[] = [
    {
      key: 'invite',
      done: state.invite,
      icon: IconUserPlus,
      label: t('teams.dashboard.firstSteps.invite'),
      to: paths.teamAdminMembers(teamSlug),
      linkState: OPEN_INVITE_STATE,
    },
    {
      key: 'ride',
      done: state.ride,
      icon: IconBike,
      label: t('teams.dashboard.firstSteps.ride'),
      to: paths.rideNew(teamSlug),
    },
    {
      key: 'route',
      done: state.route,
      icon: IconMap2,
      label: t('teams.dashboard.firstSteps.route'),
      to: paths.routeNew(teamSlug),
    },
  ]
  const steps: Step[] = candidates.flatMap((step) =>
    step.done === undefined ? [] : [{ ...step, done: step.done }]
  )
  const doneCount = steps.filter((step) => step.done).length

  if (dismissed || steps.length === 0 || doneCount === steps.length) return null

  return (
    <Paper
      withBorder
      radius="md"
      p="md"
      component="section"
      aria-labelledby="dashboard-first-steps"
    >
      <Stack gap="sm">
        <Group justify="space-between" wrap="nowrap" align="flex-start">
          <Stack gap={2}>
            <Title order={2} id="dashboard-first-steps" size="h3">
              {t('teams.dashboard.firstSteps.title')}
            </Title>
            <Text size="sm" c="dimmed">
              {t('teams.dashboard.firstSteps.progress', { done: doneCount, total: steps.length })}
            </Text>
          </Stack>
          <CloseButton
            aria-label={t('teams.dashboard.firstSteps.dismiss')}
            onClick={() => {
              dismiss(teamId)
              setDismissed(true)
            }}
          />
        </Group>
        <Stack gap={4} component="ol" className={classes.list}>
          {steps.map((step) => (
            <li key={step.key} data-step={step.key} data-done={step.done || undefined}>
              <StepRow step={step} />
            </li>
          ))}
        </Stack>
      </Stack>
    </Paper>
  )
}

interface Step {
  key: string
  done: boolean
  icon: TablerIcon
  label: string
  to: string
  linkState?: unknown
}

function StepRow({ step }: { step: Step }) {
  const { t } = useTranslation()
  const Icon = step.done ? IconCheck : step.icon
  const content = (
    <Group gap="sm" wrap="nowrap">
      <ThemeIcon variant="light" color={step.done ? 'success' : 'primary'} radius="xl" size="md">
        <Icon size={16} aria-hidden />
      </ThemeIcon>
      <Text td={step.done ? 'line-through' : undefined} c={step.done ? 'dimmed' : undefined}>
        {step.label}
      </Text>
      {step.done && <VisuallyHidden>{t('teams.dashboard.firstSteps.done')}</VisuallyHidden>}
    </Group>
  )
  // A done step stays in the list, ticked, but leads nowhere: the next one is the one to take.
  if (step.done) return <div className={classes.row}>{content}</div>
  return (
    <UnstyledButton
      component={PrefetchLink}
      to={step.to}
      state={step.linkState}
      className={classes.row}
    >
      {content}
    </UnstyledButton>
  )
}
