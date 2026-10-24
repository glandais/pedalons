import { useCallback } from 'react'
import { OutOfRangeState } from '@/components/common/OutOfRangeState'
import { Navigate, useParams } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { IconLock, IconPlus, IconSearchOff, IconTag } from '@tabler/icons-react'
import {
  Button,
  NumberInput,
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
import { TagFilter } from '../../components/tag'
import { paths } from '@/config/paths'
import { AdType } from '../../api/dto'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function AdListPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug } = useParams<{ teamSlug: string }>()

  const { filters, setFilters, team, ads, totalPages } = useAdListData(teamSlug)
  const { data: teamData, isLoading: isLoadingTeam } = team
  const { data: adsResponse, isLoading: isLoadingAds, isFetching } = ads

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
    return <Navigate to={paths.teams()} replace />
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
        <EmptyState
          icon={<IconLock size={48} />}
          title={t('ads.list.membersOnly.title')}
          description={t('ads.list.membersOnly.description')}
        />
      </TeamLayout>
    )
  }

  const adsList = adsResponse?.ads || []
  const hasFiltersOrSearch = isAdFiltered(filters)
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
            {t('ads.list.createAd')}
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
        <Select
          w={{ base: '100%', sm: 180 }}
          value={filters.adType ?? 'ALL'}
          onChange={(value: string | null) =>
            setFilters({ adType: value && value !== 'ALL' ? (value as AdType) : undefined })
          }
          placeholder={t('ads.list.filterByType')}
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
      {isLoadingAds ? (
        <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
          {Array.from({ length: 6 }).map((_, i) => (
            <AdCardSkeleton key={i} />
          ))}
        </SimpleGrid>
      ) : adsList.length === 0 ? (
        filters.page > 0 ? (
          <OutOfRangeState onFirstPage={() => setFilters({ page: 0 })} />
        ) : (
          <EmptyState
            variant={hasFiltersOrSearch ? 'filtered' : 'absolute'}
            icon={hasFiltersOrSearch ? <IconSearchOff size={48} /> : <IconTag size={48} />}
            title={hasFiltersOrSearch ? t('ads.list.noResultsTitle') : t('ads.list.empty.title')}
            description={hasFiltersOrSearch ? t('ads.list.noResults') : t('ads.list.empty.member')}
            actions={
              hasFiltersOrSearch ? (
                <Button variant="light" onClick={clearFilters}>
                  {t('common.clearFilters')}
                </Button>
              ) : undefined
            }
          />
        )
      ) : (
        <Stack>
          <SimpleGrid
            ref={listTopRef}
            cols={{ base: 1, sm: 2, lg: 3 }}
            spacing="lg"
            style={{ opacity: isFetching ? 0.5 : 1 }}
          >
            {adsList.map((ad) => (
              <AdCard
                key={ad.id}
                ad={ad}
                actions={
                  <AdCardActions
                    ad={ad}
                    isTeamAdmin={teamAccess(teamData, isPlatformAdmin).isAdmin}
                  />
                }
              />
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
    </TeamLayout>
  )
}
