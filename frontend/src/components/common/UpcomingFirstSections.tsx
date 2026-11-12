import { useId, type ReactNode } from 'react'
import { Group, Stack, Title } from '@mantine/core'
import { useTranslation } from 'react-i18next'
import { splitUpcomingFirst } from '@/lib/upcomingFirst'
import { ResultCount, type CountedResource } from './ResultCount'

interface UpcomingFirstSectionsProps<T> {
  /** The rows of the page on screen, in the order the API served them. */
  items: readonly T[]
  page: number
  /** The page size the request sent. */
  size: number
  /** `total` of the response: both sections. */
  total: number
  /** `upcomingTotal` of the response: the first section. */
  upcomingTotal: number
  /** What each section's count names: « 18 sorties et voyages », « 35 publications ». */
  counts: { upcoming: CountedResource; earlier: CountedResource }
  /** Draws a run of rows — the page's grid of cards, or its rows. */
  children: (rows: T[]) => ReactNode
}

/**
 * One paginated list in two sections, « À venir » then « Plus tôt » (RL15, docs/LEDGER_*.md
 * WEB-175), as `when=UPCOMING_FIRST` serves it: each section under its heading, which carries its
 * count — the list's one count takes their place. A page shows the heading of every section it
 * holds rows of, so a page that opens in the middle of a section repeats its heading at the top.
 */
export function UpcomingFirstSections<T>({
  items,
  page,
  size,
  total,
  upcomingTotal,
  counts,
  children,
}: UpcomingFirstSectionsProps<T>) {
  const { t } = useTranslation()
  const upcomingId = useId()
  const earlierId = useId()
  const { upcoming, earlier } = splitUpcomingFirst(items, { page, size, upcomingTotal })

  return (
    <Stack gap="xl">
      {upcoming.length > 0 && (
        <Stack component="section" gap="sm" aria-labelledby={upcomingId}>
          <Group gap="sm" align="baseline">
            <Title order={3} id={upcomingId} size="h4">
              {t('list.sections.upcoming')}
            </Title>
            <ResultCount total={upcomingTotal} resource={counts.upcoming} />
          </Group>
          {children(upcoming)}
        </Stack>
      )}
      {earlier.length > 0 && (
        <Stack component="section" gap="sm" aria-labelledby={earlierId}>
          <Group gap="sm" align="baseline">
            <Title order={3} id={earlierId} size="h4">
              {t('list.sections.earlier')}
            </Title>
            <ResultCount total={total - upcomingTotal} resource={counts.earlier} />
          </Group>
          {children(earlier)}
        </Stack>
      )}
    </Stack>
  )
}
