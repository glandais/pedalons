import { useId } from 'react'
import { useTranslation } from 'react-i18next'
import {
  IconArrowBackUp,
  IconArrowForwardUp,
  IconChevronDown,
  IconChevronUp,
  IconLineDashed,
} from '@tabler/icons-react'
import { ActionIcon, Box, Button, Group, Text, UnstyledButton } from '@mantine/core'
import { RouterProfile } from '@/api/dto'
import { PlannerHelpControl } from './PlannerHelpControl'
import { PlannerStatus } from './PlannerStatus'
import type { RouterTuning, TuningKey } from '@/lib/routerTuning'
import { RouterProfileSelector } from './RouterProfileSelector'

interface PlannerBottomBarProps {
  /** Number of control points the user placed. */
  pointCount: number
  isLoading: boolean
  /** Already translated message of the last routing failure. */
  error: string | null
  /** Distance and ascent (metres) of the computed route; given once it has two points. */
  stats?: { distance: number; ascend: number }
  /** Whether the elevation strip above the bar is unfolded. */
  profileOpen: boolean
  onProfileToggle: () => void
  /** `id` of the element holding the elevation strip: the summary button controls it. */
  profileId: string
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
 * The fullscreen editor's tools on a finger, in thumb reach, on two lines (docs/LEDGER_*.md
 * WEB-157):
 *
 * 1. one 48 px button across the width: the summary of the trace (distance · D+ · points, the
 *    calculation, the routing error) and « Profil » with a chevron. It folds and unfolds the
 *    elevation strip above it: the only control for that action, the strip has no handle of its
 *    own. A button, not a text link: the owner ruled a link out, it is no target for a thumb.
 * 2. undo, redo, the straight-line toggle, routing profile and help (44 px each, `size="xl"`), then
 *    « Done ». Five icons and the button fit in 360 px: « Clear » and « Import » are in the dialog's
 *    header, away from the thumb.
 *
 * The summary line keeps its height whatever it shows, so the map is not resized at the first
 * point (B10 of plan 2026-10-17-editeur-parcours-web). Undo and redo carry no keyboard shortcut in
 * their label: there is no keyboard.
 */
export function PlannerBottomBar({
  pointCount,
  isLoading,
  error,
  stats,
  profileOpen,
  onProfileToggle,
  profileId,
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
  const summaryId = useId()

  return (
    <Box
      bg="var(--mantine-color-body)"
      style={{
        flexShrink: 0,
        borderTop: '1px solid var(--mantine-color-default-border)',
        paddingBottom: 'env(safe-area-inset-bottom, 0px)',
      }}
    >
      {/* The name says what the tap does; the figures are its description. */}
      <UnstyledButton
        w="100%"
        h={48}
        px="sm"
        onClick={onProfileToggle}
        aria-expanded={profileOpen}
        aria-controls={profileId}
        aria-label={t(profileOpen ? 'planner.summary.hideProfile' : 'planner.summary.showProfile')}
        aria-describedby={summaryId}
        style={{ display: 'flex', alignItems: 'center', gap: 'var(--mantine-spacing-sm)' }}
      >
        <PlannerStatus
          id={summaryId}
          variant="summary"
          pointCount={pointCount}
          isLoading={isLoading}
          error={error}
          stats={stats}
        />
        <Group gap={4} wrap="nowrap" c="dimmed" style={{ flexShrink: 0 }}>
          {/* An error takes the room of the word: the chevron alone still says what a tap does. */}
          {!error && (
            <Text size="sm" fw={500}>
              {t('planner.summary.profile')}
            </Text>
          )}
          {profileOpen ? <IconChevronDown size={20} /> : <IconChevronUp size={20} />}
        </Group>
      </UnstyledButton>

      <Group
        justify="space-between"
        wrap="nowrap"
        gap="xs"
        px={6}
        pb={4}
        style={{ borderTop: '1px solid var(--mantine-color-default-border)', paddingTop: 4 }}
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
    </Box>
  )
}
