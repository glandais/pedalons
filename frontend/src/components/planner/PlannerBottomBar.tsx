import { useTranslation } from 'react-i18next'
import { IconArrowBackUp, IconArrowForwardUp, IconLineDashed } from '@tabler/icons-react'
import { ActionIcon, Button, Group } from '@mantine/core'
import { RouterProfile } from '@/api/dto'
import { PlannerHelpControl } from './PlannerHelpControl'
import type { RouterTuning, TuningKey } from '@/lib/routerTuning'
import { RouterProfileSelector } from './RouterProfileSelector'

interface PlannerBottomBarProps {
  canUndo: boolean
  canRedo: boolean
  onUndo: () => void
  onRedo: () => void
  routerProfile: RouterProfile
  onProfileChange: (profile: RouterProfile) => void
  routerTuning: RouterTuning
  onTuningChange: (key: TuningKey, value: number) => void
  onTuningReset: () => void
  /** "Straight line" toggle: the next gestures are drawn without the router. */
  directMode: boolean
  onDirectModeChange: (on: boolean) => void
  onDone: () => void
}

/**
 * The fullscreen editor's tools on a finger, in thumb reach: undo, redo, the straight-line toggle,
 * routing profile, help and « Done ». Every target is 44 px (`size="xl"`). « Clear » is in the
 * toolbar above: at 360 px the bar has no room for one more button (B2 will hit this again). Undo and redo carry no
 * keyboard shortcut in their label, there is no keyboard.
 */
export function PlannerBottomBar({
  canUndo,
  canRedo,
  onUndo,
  onRedo,
  routerProfile,
  onProfileChange,
  routerTuning,
  onTuningChange,
  onTuningReset,
  directMode,
  onDirectModeChange,
  onDone,
}: PlannerBottomBarProps) {
  const { t } = useTranslation()

  return (
    <Group
      justify="space-between"
      wrap="nowrap"
      gap="xs"
      px={6}
      pt="xs"
      bg="var(--mantine-color-body)"
      style={{
        flexShrink: 0,
        borderTop: '1px solid var(--mantine-color-default-border)',
        paddingBottom: 'calc(var(--mantine-spacing-xs) + env(safe-area-inset-bottom, 0px))',
      }}
    >
      <Group gap={0} wrap="nowrap">
        <ActionIcon
          variant="subtle"
          color="gray"
          size="xl"
          onClick={onUndo}
          disabled={!canUndo}
          aria-label={t('planner.undo.touch')}
        >
          <IconArrowBackUp size={22} />
        </ActionIcon>
        <ActionIcon
          variant="subtle"
          color="gray"
          size="xl"
          onClick={onRedo}
          disabled={!canRedo}
          aria-label={t('planner.redo.touch')}
        >
          <IconArrowForwardUp size={22} />
        </ActionIcon>
        <ActionIcon
          variant={directMode ? 'filled' : 'subtle'}
          color={directMode ? undefined : 'gray'}
          size="xl"
          onClick={() => onDirectModeChange(!directMode)}
          aria-pressed={directMode}
          aria-label={t('planner.direct.toggle')}
        >
          <IconLineDashed size={22} />
        </ActionIcon>
        <RouterProfileSelector
          currentProfile={routerProfile}
          onProfileChange={onProfileChange}
          tuning={routerTuning}
          onTuningChange={onTuningChange}
          onTuningReset={onTuningReset}
          trigger="bar"
        />
        <PlannerHelpControl trigger="bar" />
      </Group>

      <Button size="md" px="sm" onClick={onDone}>
        {t('planner.done')}
      </Button>
    </Group>
  )
}
