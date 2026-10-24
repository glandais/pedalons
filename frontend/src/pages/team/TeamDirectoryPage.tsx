import { useCallback } from 'react'
import { Navigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Box, Button, Group, Select, Stack, Title } from '@mantine/core'
import { IconLock, IconSearchOff, IconUsers } from '@tabler/icons-react'
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
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { EmptyState } from '../../components/common/EmptyState'
import { ResultCount } from '../../components/common/ResultCount'
import { SearchInput } from '../../components/common/SearchInput'
import { Pagination } from '../../components/common/Pagination'
import { TeamLayout } from '../../components/team/TeamLayout'
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

  const { data: team, isLoading: isLoadingTeam } = useGetTeam(teamSlug!, {
    query: { enabled: !!teamSlug },
  })

  useCanonicalPath(team ? paths.teamMembers(team.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
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
  const list = members.data?.members ?? []

  return (
    <TeamLayout team={team} currentTab="members">
      <Box py="md">
        <Stack gap="lg">
          <Group justify="space-between" align="baseline">
            <Title order={2}>{t('teams.detail.members.title')}</Title>
            <ResultCount total={members.data?.total} resource="members" />
          </Group>

          {refused ? (
            <EmptyState
              icon={<IconLock size={48} />}
              title={t('teams.directory.forbidden.title')}
              description={t('teams.directory.forbidden.message')}
              actions={
                <Button variant="default" component={PrefetchLink} to={paths.teamAbout(team.slug)}>
                  {t('teams.detail.tabs.about')}
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
                  <Select
                    label={t('teams.detail.members.filterRole')}
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

              <QueryStateBoundary
                isLoading={members.isLoading}
                isError={members.isError}
                error={members.error}
                onRetry={() => members.refetch()}
                isEmpty={list.length === 0}
                skeleton={<TeamMemberListSkeleton count={5} />}
                empty={
                  isFiltered ? (
                    <EmptyState
                      variant="filtered"
                      icon={<IconSearchOff size={48} />}
                      title={t('teams.detail.members.noResults')}
                      actions={
                        <Button
                          variant="default"
                          onClick={() => setFilters({ search: undefined, role: undefined })}
                        >
                          {t('common.clearFilters')}
                        </Button>
                      }
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
