import { useCallback } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Box, Button, Group, Menu, MultiSelect, SimpleGrid, Stack, Title } from '@mantine/core'
import { IconCalendarEvent, IconChevronDown, IconPlus, IconTags } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { EmptyState } from '@/components/common/EmptyState'
import { FilteredEmptyState } from '@/components/common/FilteredEmptyState'
import { searchFilter, type FilteredResource } from '@/components/common/filteredEmpty'
import { OutOfRangeState } from '@/components/common/OutOfRangeState'
import { QueryStateBoundary } from '@/components/common/QueryStateBoundary'
import { Pagination } from '@/components/common/Pagination'
import { ResultCount, type CountedResource } from '@/components/common/ResultCount'
import { SearchInput } from '@/components/common/SearchInput'
import { UpcomingFirstSections } from '@/components/common/UpcomingFirstSections'
import { ListViewSwitch, type ListView } from '@/components/common/ListViewSwitch'
import { PublicationCard, PublicationCardActions, PublicationCardSkeleton } from '@/components/card'
import { TeamLayout } from '@/components/team/TeamLayout'
import { TeamUnavailable } from '@/components/team/TeamUnavailable'
import { AgendaFilterBar } from '@/components/agenda/AgendaFilterBar'
import { AgendaRow } from '@/components/agenda/AgendaRow'
import { TagFilter, useTagLabels } from '@/components/tag'
import { paths } from '@/config/paths'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useDebouncedSearch } from '@/hooks/useDebouncedSearch'
import { useScrollToListTop } from '@/hooks/useScrollToListTop'
import { agendaTypeToPublicationType, type AgendaFilters } from '@/hooks/filters/agendaFilters'
import { isDated, type DatedPublication } from '@/utils/publicationTiming'
import type { TeamDetailDto } from '@/api/dto'
import { useTeamAgendaData } from './teamAgendaData'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

/**
 * « Agenda » (`teamAgenda`, ledger `WEB-68`): the team's rides and trips, one list in two sections
 * (RL15) — « À venir », soonest first (a ride under way stays there, marked « En cours »), then
 * « Plus tôt », latest first — over « Toutes les dates » or « Je participe »; the period « Plus
 * tôt » (`?w=earlier`) is the second section alone, one list with one count. The search and the
 * tags head the list, the period and the kind follow (RL6): there is no panel. Viewed as
 * « Vignettes » or « Lignes » (`?view=`), or as a calendar — its own path, `teamCalendar`, for a
 * member only (plan 2026-10-06 §4 and §7).
 */
export function TeamAgendaPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const navigate = useNavigate()
  const { teamSlug } = useParams<{ teamSlug: string }>()

  const { filters, setFilters, team, publications, totalPages } = useTeamAgendaData(teamSlug)
  const commitSearch = useCallback(
    (value: string) => setFilters({ search: value || undefined }),
    [setFilters]
  )
  const [search, setSearch] = useDebouncedSearch(filters.search ?? '', commitSearch)
  const { listTopRef, scrollToListTop } = useScrollToListTop()

  const { data: teamData, isLoading: isLoadingTeam } = team
  const { data: publicationsData, isLoading: isLoadingPublications } = publications
  const tagTarget = agendaTypeToPublicationType[filters.filter]
  const tagLabels = useTagLabels(teamSlug ?? '', tagTarget, tagTarget ? filters.tags : undefined)

  useCanonicalPath(teamData ? paths.teamAgenda(teamData.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('teams.detail.tabs.agenda')} />
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

  const canCreate = teamAccess(teamData, isPlatformAdmin).isOrganizer
  const createItems = [
    ...(teamData.enableRides && teamData.enableRoutes
      ? [{ path: paths.rideNew(teamData.slug), label: t('list.create.ride') }]
      : []),
    ...(teamData.enableTrips && teamData.enableRoutes
      ? [{ path: paths.tripNew(teamData.slug), label: t('list.create.trip') }]
      : []),
  ]

  // The calendar is the members' (CalendarAccessChecker) and a platform admin's: a visitor only has
  // the two lists.
  const hasCalendar =
    (!!teamData.role || isPlatformAdmin) && (!!teamData.enableRides || !!teamData.enableTrips)
  const views: ListView[] = hasCalendar ? ['card', 'row', 'calendar'] : ['card', 'row']
  const density = filters.density ?? 'card'
  const onViewChange = (view: ListView) => {
    if (view === 'calendar') {
      navigate(calendarPathFor(teamData.slug, filters))
    } else {
      setFilters({ density: view === 'row' ? 'row' : undefined, page: filters.page })
    }
  }

  const hasFilters =
    !!filters.search ||
    (!!tagTarget && !!filters.tags?.length) ||
    filters.filter !== 'all' ||
    filters.scope !== 'all'
  // RL4: the search, the kind and the tags lifted, the period back to its default.
  const clearFilters = () => {
    setSearch('')
    setFilters({
      search: undefined,
      filter: 'all',
      scope: 'all',
      tags: undefined,
      page: 0,
    })
  }

  // `isDated` narrows the type: `dated=true` keeps the agenda to rides and trips.
  const items = (publicationsData?.publications ?? []).filter(isDated)
  // « Plus tôt » is the second section by itself: one list, one count (RL8).
  const earlier = filters.scope === 'earlier'
  const counted = sectionCounts(filters.filter)
  // What the filtered empty state names (RL10): the period is a filter too.
  const activeFilters = [
    ...(filters.search ? [searchFilter(t, filters.search)] : []),
    ...(filters.scope === 'me' ? [t('publications.scope.me')] : []),
    ...(earlier ? [t('list.sections.earlier')] : []),
    ...(filters.filter !== 'all'
      ? [t(`agenda.type.${filters.filter satisfies 'ride' | 'trip'}`)]
      : []),
    ...tagLabels,
  ]

  const renderRows = (rows: DatedPublication[]) =>
    density === 'row' ? (
      <Stack gap="sm">
        {rows.map((publication) => (
          <AgendaRow
            key={publication.id}
            publication={publication}
            actions={<PublicationCardActions publication={publication} />}
          />
        ))}
      </Stack>
    ) : (
      <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
        {rows.map((publication) => (
          <PublicationCard
            key={publication.id}
            publication={publication}
            showTeam={false}
            actions={<PublicationCardActions publication={publication} />}
          />
        ))}
      </SimpleGrid>
    )

  return (
    <TeamLayout team={teamData} currentTab="agenda">
      <Stack gap="lg">
        <Group justify="space-between" align="center" wrap="wrap">
          <Title order={2}>{t('teams.detail.tabs.agenda')}</Title>
          {canCreate && createItems.length > 0 && (
            <Button.Group>
              <Button
                component={PrefetchLink}
                to={createItems[0].path}
                leftSection={<IconPlus size={16} />}
              >
                {createItems[0].label}
              </Button>
              {createItems.length > 1 && (
                <Menu position="bottom-end">
                  <Menu.Target>
                    <Button px="xs" aria-label={t('aria.createOther')}>
                      <IconChevronDown size={16} />
                    </Button>
                  </Menu.Target>
                  <Menu.Dropdown>
                    {createItems.map((item) => (
                      <Menu.Item key={item.path} component={PrefetchLink} to={item.path}>
                        {item.label}
                      </Menu.Item>
                    ))}
                  </Menu.Dropdown>
                </Menu>
              )}
            </Button.Group>
          )}
        </Group>

        <Stack gap="sm">
          {/* Top-aligned: the disabled tag field carries its hint *under* the input, so a bottom
              alignment would lift that input above the search. Both inputs share a line, the hint
              hangs below (and on a narrow screen the fields stack). */}
          <Group gap="sm" align="flex-start" wrap="wrap">
            <SearchInput
              id="agenda-search"
              value={search}
              onChange={setSearch}
              label={t('agenda.search.label')}
              placeholder={t('agenda.search.placeholder')}
              style={{ flex: '1 1 260px' }}
              fullWidth
            />
            {tagTarget ? (
              <TagFilter
                teamSlug={teamData.slug}
                type={tagTarget}
                value={filters.tags}
                onChange={(tags) => setFilters({ tags })}
                style={{ flex: '1 1 220px' }}
              />
            ) : (
              // Tags belong to one kind (plan D3): pick it first.
              <MultiSelect
                disabled
                data={[]}
                aria-label={t('tags.filter.label')}
                placeholder={t('tags.filter.placeholder')}
                leftSection={<IconTags size={16} />}
                description={t('agenda.tags.pickKind')}
                inputWrapperOrder={['input', 'description']}
                style={{ flex: '1 1 220px' }}
              />
            )}
          </Group>

          <Group justify="space-between" align="center" wrap="wrap" gap="sm">
            <AgendaFilterBar
              team={teamData}
              mode="list"
              scope={filters.scope}
              onScopeChange={(scope) => setFilters({ scope })}
              type={filters.filter}
              // A ride tag means nothing to a trip: switching kind drops the selection.
              onTypeChange={(filter) => setFilters({ filter, tags: undefined })}
            />
            {/* In two sections the counts are theirs (RL15); « Plus tôt » is one list, its count
                here, left of the view switch (RL8). */}
            {earlier && <ResultCount total={publicationsData?.total} resource={counted.earlier} />}
            {/* Right-aligned even when a narrow screen wraps it under the criteria. */}
            <Box ml="auto">
              <ListViewSwitch views={views} value={density} onChange={onViewChange} />
            </Box>
          </Group>
        </Stack>

        <QueryStateBoundary
          isLoading={isLoadingPublications}
          isError={publications.isError}
          error={publications.error}
          onRetry={() => void publications.refetch()}
          isRefreshing={publications.isPlaceholderData}
          skeleton={
            <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
              {[...Array(6)].map((_, i) => (
                <PublicationCardSkeleton key={i} />
              ))}
            </SimpleGrid>
          }
        >
          {items.length > 0 ? (
            <Stack gap="xl">
              <div ref={listTopRef}>
                {earlier ? (
                  renderRows(items)
                ) : (
                  <UpcomingFirstSections
                    items={items}
                    page={filters.page}
                    size={filters.size}
                    total={publicationsData?.total ?? 0}
                    upcomingTotal={publicationsData?.upcomingTotal ?? 0}
                    counts={counted}
                  >
                    {renderRows}
                  </UpcomingFirstSections>
                )}
              </div>
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
          ) : hasFilters ? (
            <FilteredEmptyState
              resource={filteredResource(filters.filter)}
              filters={activeFilters}
              onClear={clearFilters}
            />
          ) : (
            <EmptyState
              icon={<IconCalendarEvent size={48} />}
              title={t('agenda.empty.title')}
              description={t('agenda.empty.description')}
              actions={
                canCreate && createItems.length > 0 ? (
                  <Button component={PrefetchLink} to={createItems[0].path} variant="light">
                    {createItems[0].label}
                  </Button>
                ) : undefined
              }
            />
          )}
        </QueryStateBoundary>
      </Stack>
    </TeamLayout>
  )
}

/** « Aucune sortie pour ces filtres »: the filtered empty state names what the kind keeps. */
function filteredResource(filter: AgendaFilters['filter']): FilteredResource {
  return filter === 'ride' ? 'agendaRides' : filter === 'trip' ? 'agendaTrips' : 'agenda'
}

/** What each section's count names, by kind: « 18 sorties et voyages », « 5 sorties ». */
function sectionCounts(filter: AgendaFilters['filter']): {
  upcoming: CountedResource
  earlier: CountedResource
} {
  const resource: CountedResource =
    filter === 'ride' ? 'rides' : filter === 'trip' ? 'trips' : 'ridesAndTrips'
  return { upcoming: resource, earlier: resource }
}

/**
 * The calendar view of the same agenda (`teamCalendar`): the kind and « Je participe » carry
 * over, the period does not — a calendar is browsed by month.
 */
function calendarPathFor(teamSlug: TeamDetailDto['slug'], filters: AgendaFilters): string {
  const query = new URLSearchParams()
  if (filters.filter !== 'all') query.set('type', filters.filter)
  if (filters.scope === 'me') query.set('w', 'me')
  const qs = query.toString()
  return qs ? `${paths.teamCalendar(teamSlug)}?${qs}` : paths.teamCalendar(teamSlug)
}
