import { useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { Group, Paper, Stack, Text, Title } from '@mantine/core'
import { ParticipantList, type ParticipantSource } from '@/components/ride/ParticipantList'
import { useDebouncedSearch } from '@/hooks/useDebouncedSearch'
import { useUrlFilters } from '@/hooks/useUrlFilters'
import {
  groupParticipantFiltersAlias,
  groupParticipantFiltersSchema,
} from '@/hooks/filters/groupParticipantFilters'

interface ParticipantsSectionProps {
  /** Whose people: a ride, one of its groups, or a trip. */
  source: ParticipantSource
  count: number
  /** The group's leader, marked in the list. */
  leaderId?: string
  /** The heading's id, which names the section. */
  titleId?: string
  /** Members and platform admins only: the names are never sent to anyone else (API-144). */
  canSeeParticipants?: boolean
}

/**
 * Everyone taking part — in a ride, one of its groups or a trip (docs/LEDGER_*.md WEB-155) —,
 * searchable and paged, its search and page in the query string (`?q=`/`?p=`,
 * `groupParticipantFilters.ts`): the key the pages' prefetches fill (`participantsPageParams`,
 * `groupParticipantsParams` for a group). Without the right to read names, the count only.
 */
export function ParticipantsSection({
  source,
  count,
  leaderId,
  titleId = 'participants-title',
  canSeeParticipants = true,
}: ParticipantsSectionProps) {
  const { t } = useTranslation()
  const { filters, setFilters } = useUrlFilters({
    schema: groupParticipantFiltersSchema,
    alias: groupParticipantFiltersAlias,
  })
  const commitSearch = useCallback(
    (value: string) => setFilters({ search: value || undefined }),
    [setFilters]
  )
  const [searchInput, setSearchInput] = useDebouncedSearch(filters.search ?? '', commitSearch)

  return (
    <Paper withBorder p="lg" component="section" aria-labelledby={titleId}>
      <Stack gap="md">
        <Group justify="space-between" wrap="wrap" gap="xs">
          <Title order={3} size="h4" id={titleId}>
            {t('rides.group.participantsTitle')}
          </Title>
          <Text size="sm" c="dimmed">
            {t('rides.detail.groups.participantsNoMax', { count })}
          </Text>
        </Group>
        {canSeeParticipants && (
          <ParticipantList
            source={source}
            count={count}
            leaderId={leaderId}
            search={filters.search}
            page={filters.page}
            searchInput={searchInput}
            onSearchInputChange={setSearchInput}
            onPageChange={(page) => setFilters({ page })}
          />
        )}
      </Stack>
    </Paper>
  )
}
