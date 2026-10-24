import { useCallback, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  Box,
  Button,
  Collapse,
  Group,
  Menu,
  MultiSelect,
  Paper,
  SimpleGrid,
  Stack,
  Title,
} from '@mantine/core'
import {
  IconCalendarEvent,
  IconChevronDown,
  IconChevronUp,
  IconFilter,
  IconPlus,
  IconSearchOff,
  IconTags,
} from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { EmptyState } from '@/components/common/EmptyState'
import { OutOfRangeState } from '@/components/common/OutOfRangeState'
import { Pagination } from '@/components/common/Pagination'
import { ResultCount, type CountedResource } from '@/components/common/ResultCount'
import { SearchInput } from '@/components/common/SearchInput'
import { ListViewSwitch, type ListView } from '@/components/common/ListViewSwitch'
import { PublicationCard, PublicationCardActions, PublicationCardSkeleton } from '@/components/card'
import { TeamLayout } from '@/components/team/TeamLayout'
import { TeamUnavailable } from '@/components/team/TeamUnavailable'
import { AgendaFilterBar } from '@/components/agenda/AgendaFilterBar'
import { AgendaRow } from '@/components/agenda/AgendaRow'
import { TagFilter } from '@/components/tag'
import { paths } from '@/config/paths'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useDebouncedSearch } from '@/hooks/useDebouncedSearch'
import { useScrollToListTop } from '@/hooks/useScrollToListTop'
import {
  agendaTypeToPublicationType,
  type AgendaFilters,
  type AgendaScopeValue,
} from '@/hooks/filters/agendaFilters'
import { isDated } from '@/utils/publicationTiming'
import type { TeamDetailDto } from '@/api/dto'
import { useTeamAgendaData } from './teamAgendaData'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

/**
 * « Agenda » (`teamAgenda`, ledger `WEB-68`): the team's rides and trips, by time — « À venir »
 * (the default; a ride under way stays there, marked « En cours »), « Je participe », « Passées ».
 * The server sorts by `when` (API-85): soonest first, latest first for the past. Viewed as
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
  // Open from the start when the URL already narrows the list by what the panel holds.
  const [filtersOpen, setFiltersOpen] = useState(() => !!filters.search || !!filters.tags)

  const { data: teamData, isLoading: isLoadingTeam } = team
  const { data: publicationsData, isLoading: isLoadingPublications } = publications

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
      ? [{ path: paths.rideNew(teamData.slug), label: t('rides.create.title') }]
      : []),
    ...(teamData.enableTrips && teamData.enableRoutes
      ? [{ path: paths.tripNew(teamData.slug), label: t('trips.create.title') }]
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

  const tagTarget = agendaTypeToPublicationType[filters.filter]
  const hasPanelFilters = !!filters.search || (!!tagTarget && !!filters.tags?.length)
  const hasFilters = hasPanelFilters || filters.filter !== 'all' || filters.scope !== 'upcoming'
  const clearFilters = () => {
    setSearch('')
    setFilters({
      search: undefined,
      filter: 'all',
      scope: 'upcoming',
      tags: undefined,
      page: 0,
    })
  }

  const items = (publicationsData?.publications ?? []).filter(isDated)

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
          <AgendaFilterBar
            team={teamData}
            mode="list"
            scope={filters.scope}
            onScopeChange={(scope) => setFilters({ scope: scope as AgendaScopeValue })}
            type={filters.filter}
            // A ride tag means nothing to a trip: switching kind drops the selection.
            onTypeChange={(filter) => setFilters({ filter, tags: undefined })}
          >
            <Button
              variant={hasPanelFilters ? 'light' : 'default'}
              leftSection={<IconFilter size={16} />}
              rightSection={
                filtersOpen ? <IconChevronUp size={16} /> : <IconChevronDown size={16} />
              }
              onClick={() => setFiltersOpen((open) => !open)}
              aria-expanded={filtersOpen}
              aria-controls="agenda-filters"
            >
              {t('agenda.filters')}
            </Button>
          </AgendaFilterBar>

          <Collapse expanded={filtersOpen} id="agenda-filters">
            <Paper withBorder p="md">
              <SimpleGrid cols={{ base: 1, sm: 2 }} spacing="md">
                <SearchInput
                  id="agenda-search"
                  value={search}
                  onChange={setSearch}
                  label={t('agenda.search.label')}
                  placeholder={t('agenda.search.placeholder')}
                  fullWidth
                />
                {tagTarget ? (
                  <TagFilter
                    teamSlug={teamData.slug}
                    type={tagTarget}
                    value={filters.tags}
                    onChange={(tags) => setFilters({ tags })}
                    style={{ alignSelf: 'end' }}
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
                  />
                )}
              </SimpleGrid>
            </Paper>
          </Collapse>
        </Stack>

        <Group justify="space-between" align="center" wrap="wrap">
          <ResultCount
            total={publicationsData?.total}
            resource={countResource(filters.scope, filters.filter)}
          />
          <ListViewSwitch views={views} value={density} onChange={onViewChange} />
        </Group>

        {isLoadingPublications ? (
          <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
            {[...Array(6)].map((_, i) => (
              <PublicationCardSkeleton key={i} />
            ))}
          </SimpleGrid>
        ) : items.length > 0 ? (
          <Stack gap="xl">
            {density === 'row' ? (
              <Stack ref={listTopRef} gap="sm">
                {items.map((publication) => (
                  <AgendaRow
                    key={publication.id}
                    publication={publication}
                    actions={
                      <PublicationCardActions publication={publication} canManage={canCreate} />
                    }
                  />
                ))}
              </Stack>
            ) : (
              <SimpleGrid ref={listTopRef} cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
                {items.map((publication) => (
                  <PublicationCard
                    key={publication.id}
                    publication={publication}
                    showTeam={false}
                    actions={
                      <PublicationCardActions publication={publication} canManage={canCreate} />
                    }
                  />
                ))}
              </SimpleGrid>
            )}
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
        ) : hasFilters ? (
          <EmptyState
            variant="filtered"
            icon={<IconSearchOff size={48} />}
            title={t('noResults')}
            description={t('agenda.empty.filteredDescription')}
            actions={
              <Button variant="light" onClick={clearFilters}>
                {hasPanelFilters && filters.filter === 'all' && filters.scope === 'upcoming'
                  ? t('common.clearSearch')
                  : t('common.clearFilters')}
              </Button>
            }
          />
        ) : (
          <EmptyState
            icon={<IconCalendarEvent size={48} />}
            title={t('agenda.empty.title')}
            description={t('agenda.empty.description')}
            actions={
              <Button variant="light" onClick={() => setFilters({ scope: 'past' })}>
                {t('agenda.empty.seePast')}
              </Button>
            }
          />
        )}
      </Stack>
    </TeamLayout>
  )
}

/** « 5 sorties et voyages à venir »: the count says what the list holds, by period and kind. */
function countResource(scope: AgendaScopeValue, filter: AgendaFilters['filter']): CountedResource {
  const kind = filter === 'ride' ? 'Rides' : filter === 'trip' ? 'Trips' : ''
  const period = scope === 'past' ? 'Past' : scope === 'me' ? 'Mine' : 'Upcoming'
  return `agenda${period}${kind}` as CountedResource
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
