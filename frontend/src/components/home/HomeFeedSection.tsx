import { useCallback, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Box, Button, Chip, Group, Select, SimpleGrid, Stack, Text, Title } from '@mantine/core'
import { IconNews, IconSearchOff } from '@tabler/icons-react'
import { isSingleTeam } from '@/config/appConfig'
import { PublicationCard, PublicationCardSkeleton } from '@/components/card'
import { EmptyState } from '@/components/common/EmptyState'
import { OutOfRangeState } from '@/components/common/OutOfRangeState'
import { QueryStateBoundary } from '@/components/common/QueryStateBoundary'
import { Pagination } from '@/components/common/Pagination'
import { ResultCount } from '@/components/common/ResultCount'
import { SearchInput } from '@/components/common/SearchInput'
import { useDebouncedSearch } from '@/hooks/useDebouncedSearch'
import { useScrollToListTop } from '@/hooks/useScrollToListTop'
import { useAuth } from '@/hooks/useAuth'
import type {
  PublicationFilterValue,
  PublicationScopeValue,
} from '@/hooks/filters/publicationFilters'
import type { MembershipFilterValue } from '@/hooks/filters/membership'
import { PublicationScopeControl } from './PublicationScopeControl'
import type { useHomeFeedData } from '@/pages/home/homeFeedData'

const TYPE_FILTERS = [
  'all',
  'ride',
  'post',
  'trip',
] as const satisfies readonly PublicationFilterValue[]

interface HomeFeedSectionProps {
  /** `useHomeFeedData()`'s result — owned by the page, which also derives other blocks from it. */
  feed: ReturnType<typeof useHomeFeedData>
  title: string
  subtitle?: ReactNode
}

/**
 * The publications feed of the home page, visitor and member alike: search, type chips, scope,
 * membership (signed in), the grid and its pagination. Every filter lives in the URL
 * (`useUrlFilters`, through `useHomeFeedData`).
 *
 * Its own `region`, named by its heading: the member home's « Cette semaine » rows also link to
 * rides, and the e2e specs find a feed card inside this region.
 */
export function HomeFeedSection({ feed, title, subtitle }: HomeFeedSectionProps) {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()
  const { listTopRef, scrollToListTop } = useScrollToListTop()
  const { membershipDefault, filters, setFilters, publications, totalPages } = feed

  const commitSearch = useCallback(
    (value: string) => setFilters({ search: value || undefined }),
    [setFilters]
  )
  const [search, setSearch] = useDebouncedSearch(filters.search ?? '', commitSearch)

  // An empty feed reads differently depending on whether anything is narrowing it down.
  const hasFiltersOrSearch =
    !!filters.search ||
    filters.filter !== 'all' ||
    filters.scope !== 'all' ||
    filters.membership !== membershipDefault
  const clearFilters = useCallback(() => {
    setSearch('')
    setFilters({
      search: undefined,
      filter: 'all',
      scope: 'all',
      membership: membershipDefault,
      page: 0,
    })
  }, [setSearch, setFilters, membershipDefault])

  const { data: publicationsData, isLoading, isError, error, refetch } = publications

  return (
    <Stack component="section" aria-labelledby="home-feed-title">
      <Box>
        <Title id="home-feed-title" order={2}>
          {title}
        </Title>
        {subtitle && (
          <Text c="dimmed" mt={4}>
            {subtitle}
          </Text>
        )}
      </Box>

      <Group align="flex-end" wrap="wrap">
        <SearchInput
          id="publications-search"
          value={search}
          onChange={setSearch}
          placeholder={t('home.feed.search.placeholder')}
          label={t('home.feed.search.label')}
          style={{ flex: 1, minWidth: 200 }}
        />
        <PublicationScopeControl
          value={filters.scope}
          onChange={(scope: PublicationScopeValue) => setFilters({ scope, page: 0 })}
        />
        {isAuthenticated && (
          <Select
            value={filters.membership}
            onChange={(value) => setFilters({ membership: value as MembershipFilterValue })}
            data={[
              { value: 'all', label: t('filters.membership.all') },
              { value: 'member', label: t('roles.MEMBER') },
              { value: 'organizer', label: t('roles.ORGANIZER') },
              { value: 'admin', label: t('roles.ADMIN') },
            ]}
            aria-label={t('filters.membership.label')}
            allowDeselect={false}
            w={{ base: '100%', sm: 180 }}
          />
        )}
      </Group>

      <Chip.Group
        multiple={false}
        value={filters.filter}
        onChange={(value) => setFilters({ filter: value as PublicationFilterValue })}
      >
        <Group gap="xs" role="radiogroup" aria-label={t('teams.publications.list.filter.label')}>
          {TYPE_FILTERS.map((value) => (
            <Chip key={value} value={value} variant="light">
              {t(`teams.publications.list.filter.${value}`)}
            </Chip>
          ))}
        </Group>
      </Chip.Group>

      <ResultCount total={publicationsData?.total} resource="publications" />

      {isLoading ? (
        <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
          {[...Array(6)].map((_, i) => (
            <PublicationCardSkeleton key={i} />
          ))}
        </SimpleGrid>
      ) : isError ? (
        <QueryStateBoundary isLoading={false} isError error={error} onRetry={() => void refetch()}>
          {null}
        </QueryStateBoundary>
      ) : publicationsData?.publications && publicationsData.publications.length > 0 ? (
        <Stack>
          <SimpleGrid ref={listTopRef} cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
            {publicationsData.publications.map((publication) => (
              <PublicationCard
                key={publication.id}
                publication={publication}
                showTeam={!isSingleTeam()}
              />
            ))}
          </SimpleGrid>

          <Pagination
            currentPage={filters.page}
            totalPages={totalPages}
            onPageChange={(page) => {
              setFilters({ page })
              scrollToListTop()
            }}
          />
        </Stack>
      ) : filters.page > 0 ? (
        <OutOfRangeState onFirstPage={() => setFilters({ page: 0 })} />
      ) : (
        <EmptyState
          variant={hasFiltersOrSearch ? 'filtered' : 'absolute'}
          icon={hasFiltersOrSearch ? <IconSearchOff size={48} /> : <IconNews size={48} />}
          title={hasFiltersOrSearch ? t('home.feed.noResultsTitle') : t('home.feed.empty')}
          description={
            hasFiltersOrSearch ? t('home.feed.noResults') : t('home.feed.emptyDescription')
          }
          actions={
            hasFiltersOrSearch ? (
              <Button variant="light" onClick={clearFilters}>
                {t('common.clearFilters')}
              </Button>
            ) : undefined
          }
        />
      )}
    </Stack>
  )
}
