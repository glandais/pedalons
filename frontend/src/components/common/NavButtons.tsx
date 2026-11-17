import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { Badge, Group, UnstyledButton, Text, ScrollArea, Box } from '@mantine/core'
import type { TablerIcon } from '@tabler/icons-react'

export interface NavButtonItem {
  id: string
  path: string
  label: string
  icon: TablerIcon
  /**
   * A short word under the label saying who else can see the destination — set only where the
   * reader might take it for public (docs/LEDGER_*.md WEB-120).
   */
  badge?: string
}

interface NavButtonsProps {
  items: NavButtonItem[]
  currentId: string
  /**
   * Accessible name of the navigation landmark. Several navigations coexist on a page (header,
   * breadcrumb, this row), so each needs its own name to be told apart in a landmark list.
   */
  label: string
}

/** Width of the edge fade, kept in sync with the gradient stops in index.css. */
const FADE = 28

/**
 * A row of section links: coloured square + label, the site's identity pattern.
 *
 * These are links to distinct URLs, NOT tabs: each is server-rendered, shareable, and lands in
 * history. Hence a `nav` landmark with `aria-current="page"` and plain tab order, and deliberately
 * not a `tablist` with arrow-key roving focus — the ARIA tab pattern promises panels swapped in
 * place, which would be a lie here, and roving focus would break the tab order users expect from a
 * list of links. See ../../../docs/plans/archive/2026-07-31-navbuttons.md.
 */
export function NavButtons({ items, currentId, label }: NavButtonsProps) {
  const viewportRef = useRef<HTMLDivElement>(null)
  const activeRef = useRef<HTMLAnchorElement>(null)
  // The fade only appears on a side that actually has content beyond the edge. Shown
  // unconditionally it is a signal that cries wolf, and stops being read the day the row really
  // does overflow.
  const [fade, setFade] = useState({ start: false, end: false })

  const syncFade = useCallback(() => {
    const vp = viewportRef.current
    if (!vp) return
    const max = vp.scrollWidth - vp.clientWidth
    setFade({ start: vp.scrollLeft > 1, end: vp.scrollLeft < max - 1 })
  }, [])

  // Bring the current section into view: on a deep link into the last section of a team the row
  // would otherwise stay at scrollLeft 0, with the active item off-screen and nothing saying so.
  // scrollLeft is written directly rather than via scrollIntoView, which would also move the page.
  useLayoutEffect(() => {
    const vp = viewportRef.current
    const el = activeRef.current
    if (!vp || !el || vp.scrollWidth <= vp.clientWidth) return

    const vpRect = vp.getBoundingClientRect()
    const elRect = el.getBoundingClientRect()
    if (elRect.left < vpRect.left) {
      vp.scrollLeft -= vpRect.left - elRect.left + FADE
    } else if (elRect.right > vpRect.right) {
      vp.scrollLeft += elRect.right - vpRect.right + FADE
    }
    syncFade()
  }, [currentId, items, syncFade])

  useEffect(() => {
    const vp = viewportRef.current
    if (!vp) return
    syncFade()
    vp.addEventListener('scroll', syncFade, { passive: true })
    const observer = new ResizeObserver(syncFade)
    observer.observe(vp)
    return () => {
      vp.removeEventListener('scroll', syncFade)
      observer.disconnect()
    }
  }, [syncFade])

  return (
    <Box
      component="nav"
      aria-label={label}
      style={
        {
          '--nav-fade-start': fade.start ? `${FADE}px` : '0px',
          '--nav-fade-end': fade.end ? `${FADE}px` : '0px',
        } as React.CSSProperties
      }
    >
      {/* The row scrolls horizontally with no scrollbar; the fade tells the user there is more. */}
      <ScrollArea
        type="never"
        offsetScrollbars={false}
        viewportRef={viewportRef}
        classNames={{ viewport: 'nav-buttons-viewport' }}
      >
        <Group
          component="ul"
          className="nav-buttons-list"
          gap="xs"
          wrap="nowrap"
          align="flex-start"
        >
          {items.map((item) => {
            const isActive = item.id === currentId
            const Icon = item.icon

            return (
              <Box component="li" key={item.id} style={{ display: 'flex' }}>
                <UnstyledButton
                  component={PrefetchLink}
                  to={item.path}
                  ref={isActive ? activeRef : undefined}
                  aria-current={isActive ? 'page' : undefined}
                  className="nav-buttons-item"
                  style={{
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'center',
                    gap: 4,
                    padding: 'var(--mantine-spacing-xs)',
                    borderRadius: 'var(--mantine-radius-md)',
                    // A blue-tinted surface: the neutral default-hover measured 1.05:1 against a
                    // white page, which is to say invisible in the light theme.
                    backgroundColor: isActive ? 'var(--mantine-primary-color-light)' : undefined,
                    minWidth: 64,
                  }}
                >
                  <Box
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      width: 40,
                      height: 40,
                      borderRadius: 'var(--mantine-radius-md)',
                      backgroundColor: isActive
                        ? 'var(--mantine-primary-color-filled)'
                        : 'var(--mantine-color-default-hover)',
                    }}
                  >
                    <Icon
                      size={20}
                      color={isActive ? 'var(--mantine-color-white)' : 'var(--mantine-color-text)'}
                    />
                  </Box>
                  {/* No `dimmed` on inactive labels: at 12px it measured 4.04:1 in dark and 3.32:1
                      in light, both under the 4.5:1 AA floor — and it made the whole row read as
                      disabled. The active state is carried by the filled square, the tinted surface
                      and the weight, not by fading everything else. */}
                  <Text
                    size="xs"
                    fw={isActive ? 600 : 400}
                    ta="center"
                    title={item.label}
                    className="nav-buttons-label"
                  >
                    {item.label}
                  </Text>
                  {item.badge && (
                    <Badge size="xs" variant="light" color="gray">
                      {item.badge}
                    </Badge>
                  )}
                </UnstyledButton>
              </Box>
            )
          })}
        </Group>
      </ScrollArea>
    </Box>
  )
}
