import { useCallback } from 'react'
import { useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Box, Button, Group, SimpleGrid, Stack, Title } from '@mantine/core'
import { IconArticle, IconPlus, IconSearchOff } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { EmptyState } from '@/components/common/EmptyState'
import { OutOfRangeState } from '@/components/common/OutOfRangeState'
import { Pagination } from '@/components/common/Pagination'
import { ResultCount } from '@/components/common/ResultCount'
import { SearchInput } from '@/components/common/SearchInput'
import { PublicationCard, PublicationCardActions, PublicationCardSkeleton } from '@/components/card'
import { TeamLayout } from '@/components/team/TeamLayout'
import { TeamUnavailable } from '@/components/team/TeamUnavailable'
import { TagFilter } from '@/components/tag'
import { PublicationType } from '@/api/dto'
import { paths } from '@/config/paths'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useDebouncedSearch } from '@/hooks/useDebouncedSearch'
import { useScrollToListTop } from '@/hooks/useScrollToListTop'
import { useTeamPostsData } from './teamPostsData'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

/**
 * « Publications » (`teamPosts`, ledger `WEB-68`): the team's posts alone, read like a blog —
 * newest first, with no date filter, only a search and the post tags. Rides and trips live in the
 * agenda.
 */
export function TeamPostsPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug } = useParams<{ teamSlug: string }>()

  const { filters, setFilters, team, publications, totalPages } = useTeamPostsData(teamSlug)
  const commitSearch = useCallback(
    (value: string) => setFilters({ search: value || undefined }),
    [setFilters]
  )
  const [search, setSearch] = useDebouncedSearch(filters.search ?? '', commitSearch)
  const { listTopRef, scrollToListTop } = useScrollToListTop()

  const { data: teamData, isLoading: isLoadingTeam } = team
  const { data: publicationsData, isLoading: isLoadingPublications } = publications

  useCanonicalPath(teamData ? paths.teamPosts(teamData.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('teams.detail.tabs.posts')} />
  }

  if (!teamData) {
    return (
      <TeamUnavailable
        error={team.error}
        isError={team.isError}
        onRetry={() => void team.refetch()}
      />
    )
  }

  const canCreate = teamAccess(teamData, isPlatformAdmin).isOrganizer && !!teamData.enablePosts
  const hasTagFilter = !!filters.tags?.length
  const hasFilters = !!search || hasTagFilter
  const clearFilters = () => {
    setSearch('')
    setFilters({ search: undefined, tags: undefined, page: 0 })
  }
  const posts = publicationsData?.publications ?? []

  return (
    <TeamLayout team={teamData} currentTab="posts">
      <Stack gap="lg">
        <Group justify="space-between" align="center" wrap="wrap">
          <Title order={2}>{t('teams.detail.tabs.posts')}</Title>
          {canCreate && (
            <Button
              component={PrefetchLink}
              to={paths.postNew(teamData.slug)}
              leftSection={<IconPlus size={16} />}
            >
              {t('posts.create.title')}
            </Button>
          )}
        </Group>

        <Group gap="sm" align="flex-end" wrap="wrap">
          <SearchInput
            id="posts-search"
            value={search}
            onChange={setSearch}
            placeholder={t('teams.posts.search.placeholder')}
            style={{ flex: '1 1 260px' }}
            fullWidth
          />
          <TagFilter
            teamSlug={teamData.slug}
            type={PublicationType.POST}
            value={filters.tags}
            onChange={(tags) => setFilters({ tags })}
            style={{ flex: '1 1 220px' }}
          />
        </Group>

        <ResultCount total={publicationsData?.total} resource="publications" />

        {isLoadingPublications ? (
          <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
            {[...Array(6)].map((_, i) => (
              <PublicationCardSkeleton key={i} />
            ))}
          </SimpleGrid>
        ) : posts.length > 0 ? (
          <Stack gap="xl">
            <SimpleGrid ref={listTopRef} cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
              {posts.map((publication, index) => (
                <PublicationCard
                  key={publication.id}
                  publication={publication}
                  showTeam={false}
                  priority={index === 0}
                  actions={
                    <PublicationCardActions publication={publication} canManage={canCreate} />
                  }
                />
              ))}
            </SimpleGrid>
            <Box>
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
        ) : (
          <EmptyState
            variant={hasFilters ? 'filtered' : 'absolute'}
            icon={hasFilters ? <IconSearchOff size={48} /> : <IconArticle size={48} />}
            title={hasFilters ? t('noResults') : t('teams.posts.empty')}
            description={
              hasFilters
                ? t('teams.posts.search.noResultsDescription')
                : t('teams.posts.emptyDescription')
            }
            actions={
              hasFilters ? (
                <Button variant="light" onClick={clearFilters}>
                  {hasTagFilter ? t('common.clearFilters') : t('common.clearSearch')}
                </Button>
              ) : undefined
            }
          />
        )}
      </Stack>
    </TeamLayout>
  )
}
