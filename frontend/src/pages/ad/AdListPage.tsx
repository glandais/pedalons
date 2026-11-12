import { useCallback } from 'react'
import { OutOfRangeState } from '@/components/common/OutOfRangeState'
import { AccessRefusedState, QueryStateBoundary } from '@/components/common/QueryStateBoundary'
import { FilteredEmptyState } from '@/components/common/FilteredEmptyState'
import { searchFilter } from '@/components/common/filteredEmpty'
import { formatNumber } from '@/utils/unitFormat'
import { Navigate, useParams } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { IconPlus, IconTag } from '@tabler/icons-react'
import {
  Button,
  NumberInput,
  SegmentedControl,
  Select,
  Stack,
  Group,
  Text,
  Title,
  SimpleGrid,
  Box,
  Space,
} from '@mantine/core'
import { useAdListData } from './adListData'
import { useDebouncedSearch } from '../../hooks/useDebouncedSearch'
import { useScrollToListTop } from '../../hooks/useScrollToListTop'
import { isAdFiltered } from '../../hooks/filters/adFilters'
import { AdCard, AdCardSkeleton } from '../../components/ad'
import { AdCardActions } from '../../components/card'
import {
  AD_SORT_OPTIONS,
  adSortOptionByValue,
  adSortOptionOf,
} from '../../components/ad/adSortOptions'
import { EmptyState } from '../../components/common/EmptyState'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { Pagination } from '../../components/common/Pagination'
import { ResultCount } from '../../components/common/ResultCount'
import { SearchInput } from '../../components/common/SearchInput'
import { TeamLayout } from '../../components/team/TeamLayout'
import { TeamUnavailable } from '../../components/team/TeamUnavailable'
import { TagFilter, useTagLabels } from '../../components/tag'
import { paths } from '@/config/paths'
import { AdType } from '../../api/dto'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'

export function AdListPage() {
  const { t, i18n } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug } = useParams<{ teamSlug: string }>()

  const { filters, setFilters, team, ads, totalPages } = useAdListData(teamSlug)
  const { data: teamData, isLoading: isLoadingTeam } = team
  const { data: adsResponse, isLoading: isLoadingAds } = ads
  const tagLabels = useTagLabels(teamSlug ?? '', 'AD', filters.tags)

  const commitSearch = useCallback(
    (value: string) => setFilters({ search: value || undefined }),
    [setFilters]
  )
  const [search, setSearch] = useDebouncedSearch(filters.search ?? '', commitSearch)
  const { listTopRef, scrollToListTop } = useScrollToListTop()

  useCanonicalPath(teamData ? paths.ads(teamData.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('loading')} />
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

  // The module is off for this team: the API refuses every ad, so there is nothing to show here.
  if (teamData && !teamData.enableAds) {
    return <Navigate to={paths.team(teamData.slug)} replace />
  }

  const isMember = !!teamData.role

  // The API refuses the list to anyone outside the team (AdAccessChecker LIST) but a platform
  // admin: saying there are no ads would be untrue, and filters over a list that cannot come would
  // be noise.
  if (!isMember && !isPlatformAdmin) {
    return (
      <TeamLayout team={teamData} currentTab="ads">
        <Title order={2}>{t('ads.title')}</Title>
        <Space h="md" />
        <AccessRefusedState
          title={t('ads.list.membersOnly.title')}
          message={t('ads.list.membersOnly.description')}
          action={
            <Button variant="default" component={PrefetchLink} to={paths.teamAbout(teamData.slug)}>
              {t('teams.detail.tabs.about')}
            </Button>
          }
        />
      </TeamLayout>
    )
  }

  const adsList = adsResponse?.ads || []
  const hasFiltersOrSearch = isAdFiltered(filters)
  const price = (value: number) => formatNumber(value, i18n.language)
  const activeFilters = [
    ...(filters.search ? [searchFilter(t, filters.search)] : []),
    ...(filters.adType ? [t(`ads.adType.${filters.adType}`)] : []),
    ...(filters.minPrice !== undefined
      ? [t('ads.list.filters.minPriceActive', { price: price(filters.minPrice) })]
      : []),
    ...(filters.maxPrice !== undefined
      ? [t('ads.list.filters.maxPriceActive', { price: price(filters.maxPrice) })]
      : []),
    ...tagLabels,
  ]
  // The sort survives: clearing brings the list back into view, it does not reorder what the
  // reader chose to read.
  const clearFilters = () => {
    setSearch('')
    setFilters({
      search: undefined,
      adType: undefined,
      minPrice: undefined,
      maxPrice: undefined,
      tags: undefined,
      page: 0,
    })
  }

  return (
    <TeamLayout team={teamData} currentTab="ads">
      {/* Header */}
      <Group justify="space-between" align="center" wrap="wrap">
        <Title order={2}>{t('ads.title')}</Title>
        {isMember && (
          <Button
            component={PrefetchLink}
            to={paths.adNew(teamSlug!)}
            leftSection={<IconPlus size={20} />}
          >
            {t('list.create.ad')}
          </Button>
        )}
      </Group>
      <Space h="md" />

      {/* Filters */}
      <Group align="flex-end" wrap="wrap">
        <SearchInput
          id="ads-search"
          value={search}
          onChange={setSearch}
          placeholder={t('ads.list.search.placeholder')}
          label={t('ads.list.search.label')}
          style={{ flex: 1, minWidth: 200 }}
        />
        {/* A kind is a segmented control on the site, wherever it is (RL6). */}
        <SegmentedControl
          value={filters.adType ?? 'ALL'}
          onChange={(value) =>
            setFilters({ adType: value !== 'ALL' ? (value as AdType) : undefined })
          }
          aria-label={t('ads.list.filterByType')}
          data={[
            { value: 'ALL', label: t('ads.list.allTypes') },
            { value: AdType.SALE, label: t('ads.adType.SALE') },
            { value: AdType.RENTAL, label: t('ads.adType.RENTAL') },
            { value: AdType.WANTED, label: t('ads.adType.WANTED') },
          ]}
        />
        <Select
          w={{ base: '100%', sm: 220 }}
          label={t('ads.sort.title')}
          allowDeselect={false}
          value={adSortOptionOf(filters.sortBy, filters.sortDir)}
          onChange={(value) => {
            const option = value ? adSortOptionByValue(value) : undefined
            if (option) setFilters({ sortBy: option.sortBy, sortDir: option.sortDir })
          }}
          data={AD_SORT_OPTIONS.map((option) => ({
            value: option.value,
            label: t(
              `ads.sort.${option.value satisfies 'newest' | 'oldest' | 'priceAsc' | 'priceDesc' | 'nameAsc' | 'nameDesc'}`
            ),
          }))}
        />
      </Group>

      <Space h="xs" />

      {/* Price bounds. Either one drops the ads with no price — said in the hint, because a
          "Prix à négocier" ad vanishing from a filtered list is otherwise unexplained. */}
      <Group align="flex-end" wrap="wrap">
        <NumberInput
          w={{ base: '100%', sm: 160 }}
          label={t('ads.list.filters.minPrice')}
          placeholder={t('ads.list.filters.pricePlaceholder')}
          min={0}
          step={10}
          suffix=" €"
          value={filters.minPrice ?? ''}
          onChange={(value) =>
            setFilters({ minPrice: typeof value === 'number' ? value : undefined })
          }
        />
        <NumberInput
          w={{ base: '100%', sm: 160 }}
          label={t('ads.list.filters.maxPrice')}
          placeholder={t('ads.list.filters.pricePlaceholder')}
          min={0}
          step={10}
          suffix=" €"
          value={filters.maxPrice ?? ''}
          onChange={(value) =>
            setFilters({ maxPrice: typeof value === 'number' ? value : undefined })
          }
        />
        <Text size="xs" c="dimmed" pb={8}>
          {t('ads.list.filters.priceHint')}
        </Text>
      </Group>

      <TagFilter
        teamSlug={teamData.slug}
        type="AD"
        value={filters.tags}
        onChange={(tags) => setFilters({ tags })}
        mt="xs"
      />

      <Space h="md" />

      <ResultCount total={adsResponse?.total} resource="ads" />

      {/* Content */}
      <QueryStateBoundary
        isLoading={isLoadingAds}
        isError={ads.isError}
        error={ads.error}
        onRetry={() => void ads.refetch()}
        isRefreshing={ads.isPlaceholderData}
        skeleton={
          <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
            {Array.from({ length: 6 }).map((_, i) => (
              <AdCardSkeleton key={i} />
            ))}
          </SimpleGrid>
        }
      >
        {adsList.length === 0 ? (
          filters.page > 0 ? (
            <OutOfRangeState onFirstPage={() => setFilters({ page: 0 })} />
          ) : hasFiltersOrSearch ? (
            <FilteredEmptyState resource="ads" filters={activeFilters} onClear={clearFilters} />
          ) : (
            <EmptyState
              icon={<IconTag size={48} />}
              title={t('ads.list.empty.title')}
              description={t('ads.list.empty.member')}
              actions={
                isMember ? (
                  <Button component={PrefetchLink} to={paths.adNew(teamData.slug)} variant="light">
                    {t('list.create.ad')}
                  </Button>
                ) : undefined
              }
            />
          )
        ) : (
          <Stack>
            <SimpleGrid ref={listTopRef} cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
              {adsList.map((ad) => (
                <AdCard key={ad.id} ad={ad} actions={<AdCardActions ad={ad} />} />
              ))}
            </SimpleGrid>

            {totalPages > 1 && (
              <Box mt="md">
                <Pagination
                  currentPage={filters.page}
                  totalPages={totalPages}
                  onPageChange={(page) => {
                    setFilters({ page })
                    scrollToListTop()
                  }}
                />
              </Box>
            )}
          </Stack>
        )}
      </QueryStateBoundary>
    </TeamLayout>
  )
}
