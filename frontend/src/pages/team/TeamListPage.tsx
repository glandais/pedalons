import { useCallback } from 'react'
import { OutOfRangeState } from '@/components/common/OutOfRangeState'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { paths } from '../../config/paths'
import { IconPlus, IconUsersGroup } from '@tabler/icons-react'
import { useAuth } from '../../hooks/useAuth'
import { getAppConfig } from '../../config/appConfig'
import { useDebouncedSearch } from '../../hooks/useDebouncedSearch'
import { useScrollToListTop } from '../../hooks/useScrollToListTop'
import { isJoinableFilterOn } from '../../hooks/filters/teamFilters'
import { MembershipSelect } from '../../components/common/MembershipSelect'
import { membershipLabel } from '../../components/common/membershipLabel'
import { FilteredEmptyState } from '../../components/common/FilteredEmptyState'
import { searchFilter } from '../../components/common/filteredEmpty'
import { ResultCount } from '../../components/common/ResultCount'
import { TeamCard, TeamCardSkeleton } from '../../components/card'
import { EmptyState } from '../../components/common/EmptyState'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { Pagination } from '../../components/common/Pagination'
import { SearchInput } from '../../components/common/SearchInput'
import { PendingInvitationsBanner } from '../../components/team/PendingInvitationsBanner'
import { Box, Chip, Group, Title, Text, Stack, Button, SimpleGrid } from '@mantine/core'
import { useTeamListData } from './teamListData'

export function TeamListPage() {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()
  const config = getAppConfig()

  const {
    membershipDefault,
    filters,
    setFilters,
    teams: teamsQuery,
    totalPages,
  } = useTeamListData()
  const commitSearch = useCallback(
    (value: string) => setFilters({ search: value || undefined }),
    [setFilters]
  )
  const [search, setSearch] = useDebouncedSearch(filters.search ?? '', commitSearch)
  const { listTopRef, scrollToListTop } = useScrollToListTop()

  const { data: teamsData, isLoading, isError, error, refetch, isPlaceholderData } = teamsQuery

  const teams = teamsData?.teams
  const hasTeams = (teamsData?.total ?? 0) > 0
  const canCreateTeam = isAuthenticated && (!config?.singleTeam || !hasTeams)

  const joinable = isJoinableFilterOn(filters)
  const hasFiltersOrSearch =
    !!filters.search || filters.membership !== membershipDefault || joinable
  const activeFilters = [
    ...(filters.search ? [searchFilter(t, filters.search)] : []),
    ...(joinable ? [t('teams.list.filter.joinable')] : []),
    ...(filters.membership !== membershipDefault ? [membershipLabel(t, filters.membership)] : []),
  ]
  const clearFilters = () => {
    setSearch('')
    setFilters({ search: undefined, membership: membershipDefault, joinable: false, page: 0 })
  }

  const createTeamButton = canCreateTeam ? (
    <Button component={PrefetchLink} to={paths.teamsNew()} leftSection={<IconPlus size={20} />}>
      {t('list.create.team')}
    </Button>
  ) : null

  return (
    <Stack>
      <PendingInvitationsBanner />
      <Group justify="space-between" align="flex-start" wrap="wrap">
        <div>
          <Title order={2}>{t('teams.title')}</Title>
          <Text c="dimmed" mt={4}>
            {t('teams.list.subtitle')}
          </Text>
        </div>
        {createTeamButton}
      </Group>

      <Group align="flex-end" wrap="wrap">
        <SearchInput
          id="team-search"
          value={search}
          onChange={setSearch}
          placeholder={t('teams.list.search.placeholder')}
          label={t('teams.list.search.label')}
          style={{ flex: 1, minWidth: 200 }}
        />
        {/* « Ouvertes à l'adhésion » (RL3): only under « Toutes les équipes », where there is
            something to join — a visitor's scope. */}
        {filters.membership === 'all' && (
          <Chip
            checked={filters.joinable}
            onChange={(checked) => setFilters({ joinable: checked })}
            variant="light"
            mb={6}
          >
            {t('teams.list.filter.joinable')}
          </Chip>
        )}
        <MembershipSelect
          value={filters.membership}
          onChange={(membership) => setFilters({ membership })}
        />
      </Group>

      {/* The order follows the scope (RL5), and is said beside the count. */}
      <ResultCount
        total={teamsData?.total}
        resource="teams"
        order={
          filters.membership === 'all' ? t('teams.list.order.members') : t('teams.list.order.name')
        }
      />

      {/* A failure shows the error alone: the empty state under it (« Aucune équipe n'a encore été
          créée ») would contradict it. */}
      <QueryStateBoundary
        isLoading={isLoading}
        isError={isError}
        error={error}
        onRetry={() => void refetch()}
        isRefreshing={isPlaceholderData}
        skeleton={
          <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
            <TeamCardSkeleton count={6} />
          </SimpleGrid>
        }
      >
        {teams && teams.length > 0 ? (
          <Stack>
            <SimpleGrid ref={listTopRef} cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
              {teams.map((team) => (
                <TeamCard key={team.id} team={team} showRole={true} />
              ))}
            </SimpleGrid>

            <Box mt="lg">
              <Pagination
                currentPage={filters.page}
                totalPages={totalPages}
                onPageChange={(page) => {
                  setFilters({ page })
                  scrollToListTop()
                }}
              />
            </Box>
          </Stack>
        ) : filters.page > 0 ? (
          <OutOfRangeState onFirstPage={() => setFilters({ page: 0 })} />
        ) : hasFiltersOrSearch ? (
          <FilteredEmptyState resource="teams" filters={activeFilters} onClear={clearFilters} />
        ) : (
          <EmptyState
            icon={<IconUsersGroup size={48} />}
            title={t('teams.list.empty.noTeamsTitle')}
            description={t('teams.list.empty.noTeamsDescription')}
            actions={createTeamButton}
          />
        )}
      </QueryStateBoundary>
    </Stack>
  )
}
