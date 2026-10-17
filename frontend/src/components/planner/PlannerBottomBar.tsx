import { useTranslation } from 'react-i18next'
import { IconArrowBackUp, IconArrowForwardUp, IconTrash } from '@tabler/icons-react'
import { ActionIcon, Button, Group } from '@mantine/core'
import { RouterProfile } from '@/api/dto'
import { PlannerHelpControl } from './PlannerHelpControl'
import { RouterProfileSelector } from './RouterProfileSelector'

interface PlannerBottomBarProps {
  canUndo: boolean
  canRedo: boolean
  onUndo: () => void
  onRedo: () => void
  routerProfile: RouterProfile
  onProfileChange: (profile: RouterProfile) => void
  /** Control points on the map; the clear button is disabled without any. */
  pointCount: number
  onClear: () => void
  onDone: () => void
}

/**
 * The fullscreen editor's tools on a finger, in thumb reach: undo, redo, routing profile, help,
 * clear (red, apart) and « Done ». Every target is 44 px (`size="xl"`). Undo and redo carry no
 * keyboard shortcut in their label, there is no keyboard.
 */
export function PlannerBottomBar({
  canUndo,
  canRedo,
  onUndo,
  onRedo,
  routerProfile,
  onProfileChange,
  pointCount,
  onClear,
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
        <RouterProfileSelector
          currentProfile={routerProfile}
          onProfileChange={onProfileChange}
          trigger="bar"
        />
        <PlannerHelpControl trigger="bar" />
      </Group>

      <Group gap="xs" wrap="nowrap">
        <ActionIcon
          variant="subtle"
          color="red"
          size="xl"
          onClick={onClear}
          disabled={pointCount === 0}
          aria-label={t('planner.clear')}
        >
          <IconTrash size={22} />
        </ActionIcon>
        <Button size="md" px="sm" onClick={onDone}>
          {t('planner.done')}
        </Button>
      </Group>
    </Group>
  )
}
