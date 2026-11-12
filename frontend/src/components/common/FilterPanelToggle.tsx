import { Badge, Button, Group } from '@mantine/core'
import { IconChevronDown, IconChevronUp, IconFilter, IconX } from '@tabler/icons-react'
import { useTranslation } from 'react-i18next'

interface FilterPanelToggleProps {
  /**
   * What « Effacer les filtres » would lift (RL4): the search, each criterion, the tags, a scope off
   * its default — never the sort, never the page's own team. Zero: no badge, no « Effacer ».
   */
  activeCount: number
  open: boolean
  onToggle: () => void
  /** The id of the panel the button opens. */
  controls: string
  onClear: () => void
}

/**
 * The « Filtres » button of a list whose criteria fold into a panel, with « Effacer les filtres »
 * beside it (RL4, docs/LEDGER_*.md WEB-175). Folded, the panel says nothing of what it holds: the
 * button carries the count, tinted, and the one way to lift it all.
 */
export function FilterPanelToggle({
  activeCount,
  open,
  onToggle,
  controls,
  onClear,
}: FilterPanelToggleProps) {
  const { t } = useTranslation()
  const active = activeCount > 0
  return (
    <Group gap="xs" wrap="nowrap">
      <Button
        variant={active ? 'light' : 'default'}
        leftSection={<IconFilter size={16} />}
        rightSection={
          <Group gap={6} wrap="nowrap">
            {active && (
              <Badge size="sm" circle aria-hidden>
                {activeCount}
              </Badge>
            )}
            {open ? <IconChevronUp size={16} /> : <IconChevronDown size={16} />}
          </Group>
        }
        onClick={onToggle}
        aria-expanded={open}
        aria-controls={controls}
        aria-label={active ? t('list.filters.toggleActive', { count: activeCount }) : undefined}
      >
        {t('list.filters.toggle')}
      </Button>
      {active && (
        <Button variant="subtle" leftSection={<IconX size={16} />} onClick={onClear}>
          {t('common.clearFilters')}
        </Button>
      )}
    </Group>
  )
}
