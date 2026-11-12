import { useTranslation } from 'react-i18next'
import { IconUsers, IconShieldCheck } from '@tabler/icons-react'
import { Stack, Group, Text, Box, ThemeIcon, Center, Loader } from '@mantine/core'
import { useGetRideParticipants } from '@/api/endpoints/rides/rides'
import { useGetTripParticipants } from '@/api/endpoints/trips/trips'
import {
  PARTICIPANTS_PAGE_SIZE,
  groupParticipantsParams,
  participantsPageParams,
} from '@/hooks/filters/groupParticipantFilters'
import { UserAvatar } from '../common/UserAvatar'
import { ContentActionsMenu } from '../moderation/ContentActionsMenu'
import { ReportTargetType } from '@/api/dto'
import { Pagination } from '../common/Pagination'
import { SearchInput } from '../common/SearchInput'
import { QueryStateBoundary } from '../common/QueryStateBoundary'
import { FilteredEmptyState } from '../common/FilteredEmptyState'
import { searchFilter } from '../common/filteredEmpty'
import { LIST_QUERY, LIST_REQUEST } from '@/lib/listQuery'

/** Whose participants: a ride (optionally one of its groups) or a trip. */
export type ParticipantSource = (
  | { kind: 'ride'; teamSlug: string; rideSlug: string; groupId?: string }
  | { kind: 'trip'; teamSlug: string; tripSlug: string }
) & {
  /**
   * The team's name, which a report names as its recipient: with it, every row but the reader's
   * own gets the « Signaler / Bloquer » menu (docs/LEDGER_*.md WEB-167, R13).
   */
  teamName?: string
}

interface ParticipantListProps {
  source: ParticipantSource
  /** The total the detail already knows, shown until the first page arrives. */
  count: number
  /** `RideGroupDto.leader.id`, when the group has a designated leader. */
  leaderId?: string
  /** The committed search — what the server is asked — and the page, 0-based. */
  search: string | undefined
  page: number
  /** What the search box shows, ahead of the debounced `search`. */
  searchInput: string
  onSearchInputChange: (value: string) => void
  onPageChange: (page: number) => void
  /** False while the list is not on screen (a closed modal): nothing is fetched. */
  enabled?: boolean
}

/**
 * The whole list of participants, read page by page from the server and searched there: the
 * ride and trip details only embed the first few (docs/LEDGER_*.md API-12). Its search and page
 * belong to the caller — the URL on a group's page, a modal's own state on the cards.
 */
export function ParticipantList({
  source,
  count,
  leaderId,
  search,
  page,
  searchInput,
  onSearchInputChange,
  onPageChange,
  enabled = true,
}: ParticipantListProps) {
  const { t } = useTranslation()

  const params = participantsPageParams(search, page)
  // Both hooks are called unconditionally (rules of hooks); only the one for this source runs.
  const ride = useGetRideParticipants(
    source.teamSlug,
    source.kind === 'ride' ? source.rideSlug : '',
    source.kind === 'ride' && source.groupId
      ? groupParticipantsParams(source.groupId, { search, page })
      : params,
    { query: { ...LIST_QUERY, enabled: enabled && source.kind === 'ride' }, request: LIST_REQUEST }
  )
  const trip = useGetTripParticipants(
    source.teamSlug,
    source.kind === 'trip' ? source.tripSlug : '',
    params,
    { query: { ...LIST_QUERY, enabled: enabled && source.kind === 'trip' }, request: LIST_REQUEST }
  )
  const { data, isPending, isError, error, refetch, isPlaceholderData } =
    source.kind === 'ride' ? ride : trip

  const participants = data?.participants ?? []
  const total = data?.total ?? count
  const totalPages = Math.ceil((data?.total ?? 0) / PARTICIPANTS_PAGE_SIZE)
  const firstShown = page * PARTICIPANTS_PAGE_SIZE + 1

  return (
    <Stack>
      {count > 0 && (
        <SearchInput
          value={searchInput}
          onChange={onSearchInputChange}
          placeholder={t('participants.searchPlaceholder')}
          fullWidth
        />
      )}
      <QueryStateBoundary
        isLoading={isPending}
        isError={isError}
        error={error}
        onRetry={() => void refetch()}
        isRefreshing={isPlaceholderData}
        skeleton={
          <Center py="xl">
            <Loader />
          </Center>
        }
        isEmpty={participants.length === 0}
        empty={
          search ? (
            <FilteredEmptyState
              resource="participants"
              filters={[searchFilter(t, search)]}
              onClear={() => onSearchInputChange('')}
            />
          ) : (
            <Stack align="center" py="xl">
              <IconUsers size={48} color="var(--mantine-color-dimmed)" />
              <Text size="sm" fw={500} c="dimmed">
                {t('participants.empty')}
              </Text>
            </Stack>
          )
        }
      >
        <Stack gap="xs" component="ul" style={{ listStyle: 'none', padding: 0, margin: 0 }}>
          {participants.map((participant) => {
            const isLeader = !!leaderId && participant.id === leaderId
            return (
              <Box
                key={participant.id}
                component="li"
                p="sm"
                style={{
                  borderRadius: 'var(--mantine-radius-md)',
                  transition: 'all 200ms ease',
                  cursor: 'default',
                }}
                mod={{ hover: true }}
                __vars={{
                  '--hover-bg':
                    'linear-gradient(to right, var(--mantine-primary-color-light), var(--mantine-primary-color-light))',
                }}
              >
                <Group gap="sm" wrap="nowrap">
                  {/* Avatar with leader badge */}
                  <Box pos="relative" style={{ flexShrink: 0 }}>
                    <UserAvatar user={participant} size="md" />
                    {isLeader && (
                      <ThemeIcon
                        size={20}
                        radius="xl"
                        color="primary"
                        pos="absolute"
                        bottom={-4}
                        right={-4}
                        style={{ border: '2px solid var(--mantine-color-body)' }}
                        title={t('rides.detail.groups.leader')}
                      >
                        <IconShieldCheck size={12} />
                      </ThemeIcon>
                    )}
                  </Box>

                  {/* Participant info */}
                  <Box style={{ flex: 1, minWidth: 0 }}>
                    <Text size="sm" fw={600} truncate>
                      {participant.displayName}
                    </Text>
                    {isLeader && (
                      <Text size="xs" c="dimmed" mt={2}>
                        {t('rides.detail.groups.leader')}
                      </Text>
                    )}
                  </Box>
                  {/* No chevron: the row opens nothing (docs/LEDGER_*.md WEB-167). Its ⋯ menu,
                        the comments' one with the member as target; the menu itself hides on
                        the reader's own row (R13). */}
                  {source.teamName && (
                    <ContentActionsMenu
                      teamSlug={source.teamSlug}
                      teamName={source.teamName}
                      targetType={ReportTargetType.MEMBER}
                      targetId={participant.id}
                      author={participant}
                      placement="inline"
                    />
                  )}
                </Group>
              </Box>
            )
          })}
        </Stack>
        <Text size="xs" c="dimmed" ta="center" data-testid="participants-shown-of">
          {t('participants.shownOf', {
            from: firstShown,
            to: firstShown + participants.length - 1,
            total,
          })}
        </Text>
        <Pagination currentPage={page} totalPages={totalPages} onPageChange={onPageChange} />
      </QueryStateBoundary>
    </Stack>
  )
}
