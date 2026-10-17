import { useTranslation } from 'react-i18next'
import { IconHelp } from '@tabler/icons-react'
import { Group, Stack, Text } from '@mantine/core'
import { MapPanel } from '@/components/map/MapPanel'
import { useMediaMatch } from '@/hooks/useResponsive'
import { isApplePlatform } from '@/lib/platform'

/** The planner's gestures, in the map's control column; the list follows the primary pointer. */
interface PlannerHelpControlProps {
  /** `'bar'`: a button of the touch toolbar instead of the map's control column. */
  trigger?: 'map' | 'bar'
}

export function PlannerHelpControl({ trigger }: PlannerHelpControlProps) {
  const { t } = useTranslation()
  const isCoarsePointer = useMediaMatch('(pointer: coarse)')
  const pointer = isCoarsePointer ? 'touch' : 'mouse'
  const apple = isApplePlatform()
  const mod = apple ? '⌘' : 'Ctrl'
  const shift = apple ? '⇧' : 'Shift'

  const rows: { action: string; gesture: string }[] = [
    { action: t('planner.help.add'), gesture: t(`planner.help.add.${pointer}`) },
    { action: t('planner.help.move'), gesture: t(`planner.help.move.${pointer}`) },
    { action: t('planner.help.insert'), gesture: t(`planner.help.insert.${pointer}`) },
    { action: t('planner.help.remove'), gesture: t(`planner.help.remove.${pointer}`) },
  ]
  if (!isCoarsePointer) {
    rows.push(
      {
        action: t('planner.help.direct'),
        // On macOS Ctrl+click is a right click: only Option draws a straight line.
        gesture: apple
          ? t('planner.help.direct.apple', { alt: '⌥' })
          : t('planner.help.direct.mouse', { alt: 'Alt' }),
      },
      { action: t('planner.help.undo'), gesture: `${mod}+Z` },
      { action: t('planner.help.redo'), gesture: `${shift}+${mod}+Z` },
      { action: t('planner.help.hide'), gesture: 'H' }
    )
  }

  return (
    <MapPanel
      id="help"
      label={t('planner.help.label')}
      title={t('planner.help.title')}
      icon={<IconHelp size={20} />}
      width={300}
      trigger={trigger}
    >
      <Stack gap="xs">
        {rows.map((row) => (
          <Group key={row.action} justify="space-between" align="flex-start" wrap="nowrap" gap="md">
            <Text size="sm" fw={500}>
              {row.action}
            </Text>
            <Text size="sm" c="dimmed" ta="right">
              {row.gesture}
            </Text>
          </Group>
        ))}
      </Stack>
    </MapPanel>
  )
}
