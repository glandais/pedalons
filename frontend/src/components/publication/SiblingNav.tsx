import { useRef, type ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { ActionIcon, Group, SegmentedControl, Select } from '@mantine/core'
import { IconChevronLeft, IconChevronRight } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'

/** Up to this many siblings pick from a segmented control; beyond, a select keeps the row short. */
const SEGMENTED_MAX = 4

export interface Sibling {
  id: string
  label: string
  href: string
}

interface SiblingNavProps {
  siblings: Sibling[]
  currentId: string
  /** « Choisir un groupe », « Choisir une étape »: names the picker. */
  label: string
}

/**
 * Moving between a ride's groups or a trip's stages from one of their pages (docs/LEDGER_*.md
 * WEB-155): the previous and the next one either side, and every one in a segmented control — a
 * select beyond four, which keeps the row short. Draws nothing for a lone child.
 */
export function SiblingNav({ siblings, currentId, label }: SiblingNavProps) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  // The Select's input keeps the focus after a pick, and iOS Safari then offers to AutoFill it
  // (« Remplir »): drop the focus once the choice is made.
  const selectRef = useRef<HTMLInputElement>(null)

  if (siblings.length < 2) return null
  const index = siblings.findIndex((s) => s.id === currentId)
  const previous = index > 0 ? siblings[index - 1] : undefined
  const next = index >= 0 && index < siblings.length - 1 ? siblings[index + 1] : undefined
  const data = siblings.map((s) => ({ value: s.id, label: s.label }))
  const choose = (id: string | null) => {
    selectRef.current?.blur()
    const target = siblings.find((s) => s.id === id)
    if (target && target.id !== currentId) navigate(target.href)
  }

  return (
    <Group gap="xs" wrap="nowrap" data-testid="sibling-nav">
      <SiblingArrow
        sibling={previous}
        aria={previous ? t('publication.siblings.previous', { name: previous.label }) : ''}
        icon={<IconChevronLeft size={18} aria-hidden />}
      />
      {siblings.length <= SEGMENTED_MAX ? (
        <SegmentedControl
          data={data}
          value={currentId}
          onChange={choose}
          aria-label={label}
          fullWidth
          style={{ flex: 1, minWidth: 0 }}
        />
      ) : (
        <Select
          ref={selectRef}
          data={data}
          value={currentId}
          onChange={choose}
          aria-label={label}
          allowDeselect={false}
          maxDropdownHeight={400}
          style={{ flex: 1, minWidth: 0, maxWidth: 420 }}
        />
      )}
      <SiblingArrow
        sibling={next}
        aria={next ? t('publication.siblings.next', { name: next.label }) : ''}
        icon={<IconChevronRight size={18} aria-hidden />}
      />
    </Group>
  )
}

function SiblingArrow({
  sibling,
  aria,
  icon,
}: {
  sibling: Sibling | undefined
  aria: string
  icon: ReactNode
}) {
  if (!sibling) {
    return (
      <ActionIcon variant="default" size="lg" disabled aria-hidden>
        {icon}
      </ActionIcon>
    )
  }
  return (
    <ActionIcon
      component={PrefetchLink}
      to={sibling.href}
      variant="default"
      size="lg"
      aria-label={aria}
    >
      {icon}
    </ActionIcon>
  )
}
