import { useEffect, useRef, useState, type ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { ActionIcon, Box, Group, SegmentedControl, Select } from '@mantine/core'
import { IconChevronLeft, IconChevronRight } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'

/**
 * Up to this many siblings pick from a segmented control; beyond, a select keeps the row short. A
 * control whose segments do not fit their room (four « Groupe G1 · 0/1 » at 390 px) is a select
 * too (WEB-188).
 */
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
  const slotRef = useRef<HTMLDivElement>(null)
  // The room the segments need, read off the control while it is drawn: kept once it gave way to
  // the select, so that widening the window brings it back
  const neededRef = useRef(0)
  const [tooWide, setTooWide] = useState(false)
  const segmented = siblings.length >= 2 && siblings.length <= SEGMENTED_MAX
  const labelsKey = siblings.map((s) => s.label).join('\n')

  // After the mount (SSR and the first render draw the segmented control) and on every resize
  useEffect(() => {
    const slot = slotRef.current
    if (!segmented || !slot) return
    neededRef.current = 0
    setTooWide(false)
    const check = () => {
      const control = slot.querySelector<HTMLElement>('.mantine-SegmentedControl-root')
      if (control) neededRef.current = control.scrollWidth
      setTooWide(neededRef.current > slot.clientWidth)
    }
    check()
    const observer = new ResizeObserver(check)
    observer.observe(slot)
    return () => observer.disconnect()
  }, [segmented, labelsKey])

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
      <Box ref={slotRef} style={{ flex: 1, minWidth: 0 }}>
        {segmented && !tooWide ? (
          <SegmentedControl
            data={data}
            value={currentId}
            onChange={choose}
            aria-label={label}
            fullWidth
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
            style={{ maxWidth: 420 }}
          />
        )}
      </Box>
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
