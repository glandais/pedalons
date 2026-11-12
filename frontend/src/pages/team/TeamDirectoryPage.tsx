import { useCallback } from 'react'
import { useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Box, Button, Group, Select, Stack, Title } from '@mantine/core'
import { IconUsers } from '@tabler/icons-react'
import { useGetTeam } from '@/api/endpoints/teams/teams'
import { PlatformRole, TeamRole } from '@/api/dto'
import { apiErrorStatus } from '@/lib/apiError'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { paths } from '../../config/paths'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useAuth } from '../../hooks/useAuth'
import { useDebouncedSearch } from '../../hooks/useDebouncedSearch'
import { useScrollToListTop } from '../../hooks/useScrollToListTop'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { AccessRefusedState, QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { FilteredEmptyState } from '../../components/common/FilteredEmptyState'
import { searchFilter } from '../../components/common/filteredEmpty'
import { EmptyState } from '../../components/common/EmptyState'
import { OutOfRangeState } from '../../components/common/OutOfRangeState'
import { ResultCount } from '../../components/common/ResultCount'
import { SearchInput } from '../../components/common/SearchInput'
import { Pagination } from '../../components/common/Pagination'
import { TeamLayout } from '../../components/team/TeamLayout'
import { TeamUnavailable } from '../../components/team/TeamUnavailable'
import { TeamMemberList, TeamMemberListSkeleton } from '../../components/team/TeamMemberList'
import { useTeamMembersData } from './teamMembersData'
import { teamAccess } from '@/lib/teamAccess'

/**
 * The member directory as the members read it (docs/LEDGER_*.md WEB-1) — the admin screen
 * (`TeamMembersPage`) without invitations, role changes or removals.
 *
 * Who may read it, and how much, is the server's call (API-39, `UserTeamAccessChecker` and
 * `TeamMembershipService`): an organiser always, a member once the team has opened its directory,
 * and `role`/`joinedAt` only when the caller is entitled to them. This page renders what comes
 * back and nothing more; a refusal (403) is a state of the page, never something to work around.
 */
export function TeamDirectoryPage() {
  const { t } = useTranslation()
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const { user } = useAuth()

  const { filters, setFilters, members, totalPages } = useTeamMembersData(teamSlug)
  const commitSearch = useCallback(
    (value: string) => setFilters({ search: value || undefined }),
    [setFilters]
  )
  const [search, setSearch] = useDebouncedSearch(filters.search ?? '', commitSearch)
  const { listTopRef, scrollToListTop } = useScrollToListTop()

  const teamQuery = useGetTeam(teamSlug!, {
    query: { enabled: !!teamSlug },
  })
  const { data: team, isLoading: isLoadingTeam } = teamQuery

  useCanonicalPath(team ? paths.teamMembers(team.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return (
      <TeamUnavailable
        error={teamQuery.error}
        isError={teamQuery.isError}
        onRetry={() => void teamQuery.refetch()}
      />
    )
  }

  // Roles come back only to an admin, or to everyone once the directory is open: filtering on a
  // role nobody on the page can see would be a way to learn it.
  const admin = teamAccess(team, user?.platformRole === PlatformRole.PLATFORM_ADMIN).isAdmin
  const rolesShown = admin || team.enableMemberDirectory
  // Only an administrator's search also matches e-mail addresses.
  const searchPlaceholder = admin
    ? t('teams.detail.members.search.placeholder')
    : t('teams.detail.members.searchPlaceholder')

  const refused = members.isError && apiErrorStatus(members.error) === 403
  const isFiltered = !!filters.search || !!filters.role
  const activeFilters = [
    ...(filters.search ? [searchFilter(t, filters.search)] : []),
    ...(filters.role ? [t(`roles.${filters.role}`)] : []),
  ]
  const list = members.data?.members ?? []

  return (
    <TeamLayout team={team} currentTab="members">
      <Box py="md">
        <Stack gap="lg">
          <Title order={2}>{t('teams.detail.members.title')}</Title>

          {refused ? (
            <AccessRefusedState
              title={t('teams.directory.forbidden.title')}
              message={t('teams.directory.forbidden.message')}
              action={
                <Button variant="default" component={PrefetchLink} to={paths.teamAbout(team.slug)}>
                  {t('teams.detail.about.title')}
                </Button>
              }
            />
          ) : (
            <>
              <Group align="flex-end">
                <SearchInput
                  id="directory-search"
                  value={search}
                  onChange={setSearch}
                  placeholder={searchPlaceholder}
                  label={t('teams.detail.members.search.label')}
                />
                {rolesShown && (
                  // No visible label, like the search beside it: the two fields line up (C6).
                  <Select
                    aria-label={t('teams.detail.members.filterRole')}
                    value={filters.role ?? null}
                    onChange={(value) =>
                      setFilters({ role: (value as TeamRole | null) ?? undefined })
                    }
                    data={[
                      { value: TeamRole.MEMBER, label: t('roles.MEMBER') },
                      { value: TeamRole.ORGANIZER, label: t('roles.ORGANIZER') },
                      { value: TeamRole.ADMIN, label: t('roles.ADMIN') },
                    ]}
                    placeholder={t('teams.detail.members.filterRoleAll')}
                    clearable
                    w={{ base: '100%', sm: 200 }}
                  />
                )}
              </Group>

              <ResultCount total={members.data?.total} resource="members" />

              <QueryStateBoundary
                isLoading={members.isLoading}
                isError={members.isError}
                error={members.error}
                onRetry={() => members.refetch()}
                isRefreshing={members.isPlaceholderData}
                isEmpty={list.length === 0}
                skeleton={<TeamMemberListSkeleton count={5} />}
                empty={
                  filters.page > 0 ? (
                    <OutOfRangeState onFirstPage={() => setFilters({ page: 0 })} />
                  ) : isFiltered ? (
                    <FilteredEmptyState
                      resource="members"
                      filters={activeFilters}
                      onClear={() => {
                        setSearch('')
                        setFilters({ search: undefined, role: undefined, page: 0 })
                      }}
                    />
                  ) : (
                    <EmptyState
                      icon={<IconUsers size={48} />}
                      title={t('teams.detail.members.empty')}
                    />
                  )
                }
              >
                <Box ref={listTopRef}>
                  {/* No role: TeamMemberList offers its admin actions to an admin only. */}
                  <TeamMemberList
                    members={list}
                    currentUserRole={null}
                    currentUserId={user?.id ?? null}
                  />
                </Box>
                <Box mt="xl">
                  <Pagination
                    currentPage={filters.page}
                    totalPages={totalPages}
                    onPageChange={(page) => {
                      setFilters({ page })
                      scrollToListTop()
                    }}
                  />
                </Box>
              </QueryStateBoundary>
            </>
          )}
        </Stack>
      </Box>
    </TeamLayout>
  )
}
