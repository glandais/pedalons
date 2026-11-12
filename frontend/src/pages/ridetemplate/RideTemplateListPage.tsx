import { useState, useCallback } from 'react'
import { invalidateTeamDashboard } from '@/lib/teamDashboardCache'
import { useParams } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import { paths } from '../../config/paths'
import { IconPlus, IconFiles } from '@tabler/icons-react'
import { Box, Button, Group, Stack, Title, Center, Loader } from '@mantine/core'
import { useGetTeam } from '@/api/endpoints/teams/teams'
import {
  useDeleteTemplate,
  getListTemplatesQueryKey,
} from '@/api/endpoints/ride-templates/ride-templates'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { TeamAdminLayout } from '../../components/team/TeamAdminLayout'
import { TeamUnavailable } from '../../components/team/TeamUnavailable'
import { EmptyState } from '../../components/common/EmptyState'
import { OutOfRangeState } from '../../components/common/OutOfRangeState'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { FilteredEmptyState } from '../../components/common/FilteredEmptyState'
import { searchFilter } from '../../components/common/filteredEmpty'
import { ResultCount } from '../../components/common/ResultCount'
import { Pagination } from '../../components/common/Pagination'
import { useDebouncedSearch } from '../../hooks/useDebouncedSearch'
import { useScrollToListTop } from '../../hooks/useScrollToListTop'
import { useRideTemplateListData } from './rideTemplateListData'
import { SearchInput } from '../../components/common/SearchInput'
import { ConfirmDialog } from '../../components/common/ConfirmDialog'
import type { RideTemplateDto } from '@/api/dto'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { RideTemplateCard } from '@/components/ridetemplate/RideTemplateCard'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function RideTemplateListPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const queryClient = useQueryClient()
  const [templateToDelete, setTemplateToDelete] = useState<RideTemplateDto | null>(null)

  const teamQuery = useGetTeam(teamSlug!, {
    query: { enabled: !!teamSlug },
  })
  const { data: team, isLoading: isLoadingTeam } = teamQuery
  // The server lists the templates to an organizer only: nothing is asked before the role is known,
  // nor for a plain member, whom `TeamAdminLayout` sends back to the team (DL23).
  const canManage = teamAccess(team, isPlatformAdmin).isOrganizer

  const { filters, setFilters, templates, totalPages } = useRideTemplateListData(
    teamSlug,
    !!team && canManage
  )
  const { data: templatesData, isLoading: isLoadingTemplates } = templates
  const commitSearch = useCallback(
    (value: string) => setFilters({ search: value || undefined }),
    [setFilters]
  )
  const [search, setSearch] = useDebouncedSearch(filters.search ?? '', commitSearch)
  const { listTopRef, scrollToListTop } = useScrollToListTop()

  const deleteMutation = useDeleteTemplate()

  useCanonicalPath(team ? paths.rideTemplates(team.slug) : undefined)

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

  const clearSearch = () => {
    setSearch('')
    setFilters({ search: undefined, page: 0 })
  }

  const handleDelete = (template: RideTemplateDto) => {
    setTemplateToDelete(template)
  }

  const confirmDelete = () => {
    if (templateToDelete && teamSlug) {
      deleteMutation.mutate(
        { teamSlug: teamSlug, templateSlug: templateToDelete.slug },
        {
          onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: getListTemplatesQueryKey(teamSlug) })
            invalidateTeamDashboard(queryClient, teamSlug)
            notifications.show({
              message: t('rideTemplates.notifications.deleted'),
              color: 'green',
            })
            setTemplateToDelete(null)
          },
        }
      )
    }
  }

  return (
    <TeamAdminLayout team={team} currentTab="ride-templates">
      <Stack py="lg">
        <Group justify="space-between">
          <Title order={2}>{t('rideTemplates.list.title')}</Title>
          {canManage && (
            <Button
              component={PrefetchLink}
              to={paths.rideTemplateNew(teamSlug!)}
              leftSection={<IconPlus size={16} />}
            >
              {t('list.create.template')}
            </Button>
          )}
        </Group>

        {/* Search Input */}
        <SearchInput
          id="templates-search"
          value={search}
          onChange={setSearch}
          placeholder={t('rideTemplates.list.search.placeholder')}
          label={t('rideTemplates.list.search.label')}
        />

        <ResultCount total={templatesData?.total} resource="templates" />

        {/* Templates List */}
        <QueryStateBoundary
          isLoading={isLoadingTemplates}
          isError={templates.isError}
          error={templates.error}
          onRetry={() => void templates.refetch()}
          isRefreshing={templates.isPlaceholderData}
          skeleton={
            <Center py="xl">
              <Loader />
            </Center>
          }
        >
          {templatesData?.templates && templatesData.templates.length > 0 ? (
            <>
              <Stack ref={listTopRef}>
                {templatesData.templates.map((template) => (
                  <RideTemplateCard
                    key={template.id}
                    template={template}
                    canManage={canManage}
                    onDelete={handleDelete}
                  />
                ))}
              </Stack>

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
            </>
          ) : filters.page > 0 ? (
            <OutOfRangeState onFirstPage={() => setFilters({ page: 0 })} />
          ) : filters.search ? (
            <FilteredEmptyState
              resource="templates"
              filters={[searchFilter(t, filters.search)]}
              onClear={clearSearch}
            />
          ) : (
            <EmptyState
              icon={<IconFiles size={48} />}
              title={t('rideTemplates.list.empty.title')}
              description={
                canManage
                  ? t('rideTemplates.list.empty.admin')
                  : t('rideTemplates.list.empty.member')
              }
              actions={
                canManage ? (
                  <Button
                    component={PrefetchLink}
                    to={paths.rideTemplateNew(teamSlug!)}
                    variant="light"
                  >
                    {t('list.create.template')}
                  </Button>
                ) : undefined
              }
            />
          )}
        </QueryStateBoundary>
      </Stack>

      {/* Delete Confirmation Dialog */}
      <ConfirmDialog
        isOpen={!!templateToDelete}
        onClose={() => setTemplateToDelete(null)}
        onConfirm={confirmDelete}
        title={t('rideTemplates.confirmations.deleteTitle')}
        message={t('rideTemplates.confirmations.delete', { name: templateToDelete?.name })}
        confirmText={t('rideTemplates.buttons.delete')}
        variant="danger"
        isLoading={deleteMutation.isPending}
      />
    </TeamAdminLayout>
  )
}
