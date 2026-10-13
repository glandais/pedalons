import { useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { Group, Paper, Stack, Text, Title } from '@mantine/core'
import type { RideDto, RideGroupDto } from '@/api/dto'
import { ParticipantList } from '@/components/ride/ParticipantList'
import { useDebouncedSearch } from '@/hooks/useDebouncedSearch'
import { useUrlFilters } from '@/hooks/useUrlFilters'
import {
  groupParticipantFiltersAlias,
  groupParticipantFiltersSchema,
} from '@/hooks/filters/groupParticipantFilters'

/**
 * Everyone riding with the group, searchable and paged, its search and page in the query string
 * (`?q=`/`?p=`, `groupParticipantFilters.ts`) — the key `prefetchRideGroup` and, for a solo ride,
 * `prefetchRideDetail` fill through `groupParticipantsParams`.
 */
export function GroupParticipantsSection({
  teamSlug,
  ride,
  group,
  titleId = 'group-participants-title',
}: {
  teamSlug: string
  ride: RideDto
  group: RideGroupDto
  /** The heading's id, which names the section. */
  titleId?: string
}) {
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
            {t('rides.detail.groups.participantsNoMax', {
              current: group.countParticipants,
            })}
          </Text>
        </Group>
        <ParticipantList
          source={{
            kind: 'ride',
            teamSlug,
            rideSlug: ride.slug,
            groupId: group.id,
          }}
          count={group.countParticipants}
          leaderId={group.leader?.id}
          search={filters.search}
          page={filters.page}
          searchInput={searchInput}
          onSearchInputChange={setSearchInput}
          onPageChange={(page) => setFilters({ page })}
          searchPlaceholder={t('participants.searchByName')}
          noMatch={t('participants.noMatchGeneric')}
        />
      </Stack>
    </Paper>
  )
}
