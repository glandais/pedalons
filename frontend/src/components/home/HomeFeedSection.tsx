import { useCallback, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Box, Group, SegmentedControl, SimpleGrid, Stack, Text, Title } from '@mantine/core'
import { IconNews } from '@tabler/icons-react'
import { isSingleTeam } from '@/config/appConfig'
import { PublicationCard, PublicationCardSkeleton } from '@/components/card'
import { EmptyState } from '@/components/common/EmptyState'
import { FilteredEmptyState } from '@/components/common/FilteredEmptyState'
import { searchFilter } from '@/components/common/filteredEmpty'
import { OutOfRangeState } from '@/components/common/OutOfRangeState'
import { MembershipSelect } from '@/components/common/MembershipSelect'
import { membershipLabel } from '@/components/common/membershipLabel'
import { QueryStateBoundary } from '@/components/common/QueryStateBoundary'
import { Pagination } from '@/components/common/Pagination'
import { ResultCount, type CountedResource } from '@/components/common/ResultCount'
import { SearchInput } from '@/components/common/SearchInput'
import { UpcomingFirstSections } from '@/components/common/UpcomingFirstSections'
import { useDebouncedSearch } from '@/hooks/useDebouncedSearch'
import { useScrollToListTop } from '@/hooks/useScrollToListTop'
import {
  publicationFeedHasSections,
  type PublicationFilterValue,
  type PublicationScopeValue,
} from '@/hooks/filters/publicationFilters'
import { PublicationScopeControl } from './PublicationScopeControl'
import type { useHomeFeedData } from '@/pages/home/homeFeedData'
import type { PublicationDto } from '@/api/dto'

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
 * The publications feed of the home page, visitor and member alike: search, period and scope
 * (signed in), kind, the grid and its pagination. Every filter lives in the URL (`useUrlFilters`,
 * through `useHomeFeedData`). A feed that holds rides or trips reads in two sections, « À venir »
 * then « Plus tôt », each with its count (RL15); the posts alone, and the period « Plus tôt » —
 * the second section by itself — are one list with one count.
 *
 * Its own `region`, named by its heading: the member home's « Cette semaine » rows also link to
 * rides, and the e2e specs find a feed card inside this region.
 */
export function HomeFeedSection({ feed, title, subtitle }: HomeFeedSectionProps) {
  const { t } = useTranslation()
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

  const {
    data: publicationsData,
    isLoading,
    isError,
    error,
    refetch,
    isPlaceholderData,
  } = publications

  // What the filtered empty state names, in the bar's order (RL10).
  const activeFilters = [
    ...(filters.search ? [searchFilter(t, filters.search)] : []),
    ...(filters.scope === 'me' ? [t('publications.scope.me')] : []),
    ...(filters.scope === 'earlier' ? [t('list.sections.earlier')] : []),
    ...(filters.membership !== membershipDefault ? [membershipLabel(t, filters.membership)] : []),
    ...(filters.filter !== 'all'
      ? [t(`teams.publications.list.filter.${filters.filter satisfies 'ride' | 'post' | 'trip'}`)]
      : []),
  ]

  // Two sections as soon as the feed holds rides or trips and the API said where the first ends;
  // « Plus tôt » is the second alone.
  const sectioned =
    publicationFeedHasSections(filters.filter, filters.scope) &&
    publicationsData?.upcomingTotal != null
  const renderGrid = (rows: PublicationDto[]) => (
    <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
      {rows.map((publication) => (
        <PublicationCard
          key={publication.id}
          publication={publication}
          showTeam={!isSingleTeam()}
        />
      ))}
    </SimpleGrid>
  )

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
        <MembershipSelect
          value={filters.membership}
          onChange={(membership) => setFilters({ membership })}
        />
      </Group>

      <Group gap="sm" wrap="wrap">
        <PublicationScopeControl
          value={filters.scope}
          onChange={(scope: PublicationScopeValue) => setFilters({ scope, page: 0 })}
        />
        <SegmentedControl
          value={filters.filter}
          onChange={(value) => setFilters({ filter: value as PublicationFilterValue })}
          data={TYPE_FILTERS.map((value) => ({
            value,
            label: t(`teams.publications.list.filter.${value}`),
          }))}
          aria-label={t('teams.publications.list.filter.label')}
        />
      </Group>

      {!sectioned && (
        <ResultCount
          total={publicationsData?.total}
          resource={sectionCounts(filters.filter).earlier}
        />
      )}

      <QueryStateBoundary
        isLoading={isLoading}
        isError={isError}
        error={error}
        onRetry={() => void refetch()}
        isRefreshing={isPlaceholderData}
        skeleton={
          <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
            {[...Array(6)].map((_, i) => (
              <PublicationCardSkeleton key={i} />
            ))}
          </SimpleGrid>
        }
      >
        {publicationsData?.publications && publicationsData.publications.length > 0 ? (
          <Stack>
            <Box ref={listTopRef}>
              {sectioned ? (
                <UpcomingFirstSections
                  items={publicationsData.publications}
                  page={filters.page}
                  size={filters.size}
                  total={publicationsData.total}
                  upcomingTotal={publicationsData.upcomingTotal ?? 0}
                  counts={sectionCounts(filters.filter)}
                >
                  {renderGrid}
                </UpcomingFirstSections>
              ) : (
                renderGrid(publicationsData.publications)
              )}
            </Box>

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
        ) : hasFiltersOrSearch ? (
          <FilteredEmptyState
            resource="publications"
            filters={activeFilters}
            onClear={clearFilters}
          />
        ) : (
          <EmptyState
            icon={<IconNews size={48} />}
            title={t('home.feed.empty')}
            description={t('home.feed.emptyDescription')}
          />
        )}
      </QueryStateBoundary>
    </Stack>
  )
}

/**
 * What each section's count names. « À venir » holds rides and trips only; « Plus tôt » mixes in
 * the posts, hence « publications », unless the kind narrows both. A list without sections — the
 * posts, or the period « Plus tôt » — counts as « Plus tôt » does.
 */
function sectionCounts(filter: PublicationFilterValue): {
  upcoming: CountedResource
  earlier: CountedResource
} {
  if (filter === 'ride') return { upcoming: 'rides', earlier: 'rides' }
  if (filter === 'trip') return { upcoming: 'trips', earlier: 'trips' }
  if (filter === 'post') return { upcoming: 'publications', earlier: 'publications' }
  return { upcoming: 'ridesAndTrips', earlier: 'publications' }
}
