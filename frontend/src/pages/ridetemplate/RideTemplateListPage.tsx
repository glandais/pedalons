import { useState, useCallback } from 'react'
import { invalidateTeamDashboard } from '@/lib/teamDashboardCache'
import { Navigate, useParams } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import { paths } from '../../config/paths'
import { IconPlus, IconFiles } from '@tabler/icons-react'
import { Box, Button, Group, Stack, Title, Text, Paper, Center, Loader } from '@mantine/core'
import { useGetTeam } from '@/api/endpoints/teams/teams'
import {
  useDeleteTemplate,
  getListTemplatesQueryKey,
} from '@/api/endpoints/ride-templates/ride-templates'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { TeamAdminLayout } from '../../components/team/TeamAdminLayout'
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

  const { filters, setFilters, templates, totalPages } = useRideTemplateListData(teamSlug)
  const { data: templatesData, isLoading: isLoadingTemplates } = templates
  const commitSearch = useCallback(
    (value: string) => setFilters({ search: value || undefined }),
    [setFilters]
  )
  const [search, setSearch] = useDebouncedSearch(filters.search ?? '', commitSearch)
  const { listTopRef, scrollToListTop } = useScrollToListTop()

  const { data: team, isLoading: isLoadingTeam } = useGetTeam(teamSlug!, {
    query: { enabled: !!teamSlug },
  })
  const deleteMutation = useDeleteTemplate()

  useCanonicalPath(team ? paths.rideTemplates(team.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  const canManage = teamAccess(team, isPlatformAdmin).isOrganizer

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
              {t('rideTemplates.create.title')}
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

        {/* Templates List */}
        {isLoadingTemplates ? (
          <Center py="xl">
            <Loader />
          </Center>
        ) : templatesData?.templates && templatesData.templates.length > 0 ? (
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
        ) : (
          <Paper withBorder py="xl">
            <Center>
              <Stack align="center">
                <IconFiles size={48} color="var(--mantine-color-dimmed)" />
                <Title order={3}>
                  {search ? t('rideTemplates.list.noResults') : t('rideTemplates.list.empty.title')}
                </Title>
                {!search && (
                  <Text c="dimmed">
                    {canManage
                      ? t('rideTemplates.list.empty.admin')
                      : t('rideTemplates.list.empty.member')}
                  </Text>
                )}
                {canManage && !search && (
                  <Button component={PrefetchLink} to={paths.rideTemplateNew(teamSlug!)} mt="sm">
                    {t('rideTemplates.create.title')}
                  </Button>
                )}
              </Stack>
            </Center>
          </Paper>
        )}
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
