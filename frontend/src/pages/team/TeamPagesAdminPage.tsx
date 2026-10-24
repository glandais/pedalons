import { useState } from 'react'
import { useParams, Navigate } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { paths } from '../../config/paths'
import {
  IconPlus,
  IconFileText,
  IconPencil,
  IconTrash,
  IconMenu2,
  IconRestore,
} from '@tabler/icons-react'
import {
  ActionIcon,
  Box,
  Button,
  Center,
  Group,
  Loader,
  Paper,
  Stack,
  Text,
  Title,
} from '@mantine/core'
import { getGetTeamQueryKey } from '@/api/endpoints/teams/teams'
import {
  useDeletePage,
  useUndeletePage,
  useReorderPages,
  getListPagesQueryKey,
} from '@/api/endpoints/team-pages/team-pages'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { TeamAdminLayout } from '../../components/team/TeamAdminLayout'
import { ConfirmDialog } from '../../components/common/ConfirmDialog'
import { VisibilityBadge } from '../../components/card/common'
import { useTeamPagesAdminData } from './teamPagesAdminData'
import type { TeamPageSummaryDto } from '@/api/dto'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

const MAX_ADDITIONAL_PAGES = 3

export function TeamPagesAdminPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const queryClient = useQueryClient()
  const [pageToDelete, setPageToDelete] = useState<TeamPageSummaryDto | null>(null)
  const [draggedItem, setDraggedItem] = useState<TeamPageSummaryDto | null>(null)

  const { team: teamQuery, pages: pagesQuery } = useTeamPagesAdminData(teamSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery
  const { data: pages, isLoading: isLoadingPages } = pagesQuery
  const deleteMutation = useDeletePage()
  const undeleteMutation = useUndeletePage()
  const reorderMutation = useReorderPages()

  useCanonicalPath(team ? paths.teamAdminPages(team.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  const isAdmin = teamAccess(team, isPlatformAdmin).isAdmin
  if (!isAdmin) {
    return <Navigate to={paths.team(team.slug)} replace />
  }

  const canAddMore = (pages?.length ?? 0) < MAX_ADDITIONAL_PAGES

  const handleDelete = (page: TeamPageSummaryDto) => {
    setPageToDelete(page)
  }

  const handleRestore = (page: TeamPageSummaryDto) => {
    if (teamSlug) {
      undeleteMutation.mutate(
        { teamSlug: teamSlug, pageSlug: page.slug },
        {
          onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: getListPagesQueryKey(teamSlug) })
            queryClient.invalidateQueries({ queryKey: getGetTeamQueryKey(teamSlug) })
            notifications.show({
              message: i18next.t('teams.pages.notifications.restored'),
              color: 'green',
            })
          },
        }
      )
    }
  }

  const confirmDelete = () => {
    if (pageToDelete && teamSlug) {
      deleteMutation.mutate(
        { teamSlug: teamSlug, pageSlug: pageToDelete.slug },
        {
          onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: getListPagesQueryKey(teamSlug) })
            queryClient.invalidateQueries({ queryKey: getGetTeamQueryKey(teamSlug) })
            notifications.show({
              message: i18next.t('teams.pages.notifications.deleted'),
              color: 'green',
            })
            setPageToDelete(null)
          },
        }
      )
    }
  }

  const handleDragStart = (e: React.DragEvent, page: TeamPageSummaryDto) => {
    setDraggedItem(page)
    e.dataTransfer.effectAllowed = 'move'
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
    e.dataTransfer.dropEffect = 'move'
  }

  const handleDrop = (e: React.DragEvent, targetPage: TeamPageSummaryDto) => {
    e.preventDefault()
    if (!draggedItem || !pages || draggedItem.id === targetPage.id || !teamSlug) {
      setDraggedItem(null)
      return
    }

    const currentOrder = pages.map((p) => p.id)
    const draggedIndex = currentOrder.indexOf(draggedItem.id)
    const targetIndex = currentOrder.indexOf(targetPage.id)

    // Reorder the array
    currentOrder.splice(draggedIndex, 1)
    currentOrder.splice(targetIndex, 0, draggedItem.id)

    reorderMutation.mutate(
      { teamSlug: teamSlug, data: { pageIds: currentOrder } },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getListPagesQueryKey(teamSlug) })
          queryClient.invalidateQueries({ queryKey: getGetTeamQueryKey(teamSlug) })
          notifications.show({
            message: i18next.t('teams.pages.notifications.reordered'),
            color: 'green',
          })
        },
      }
    )
    setDraggedItem(null)
  }

  const handleDragEnd = () => {
    setDraggedItem(null)
  }

  return (
    <TeamAdminLayout team={team} currentTab="pages">
      <Box py="md">
        <Group justify="space-between" mb="lg">
          <Box>
            <Title order={2}>{t('teams.pages.title')}</Title>
            <Text size="sm" c="dimmed" mt="xs">
              {t('teams.pages.subtitle', { count: pages?.length ?? 0, max: MAX_ADDITIONAL_PAGES })}
            </Text>
          </Box>
          {canAddMore && (
            <Button
              component={PrefetchLink}
              to={paths.teamAdminPageNew(teamSlug!)}
              leftSection={<IconPlus size={16} />}
            >
              {t('teams.pages.add')}
            </Button>
          )}
        </Group>

        {/* Pages List */}
        {isLoadingPages ? (
          <Center py="xl">
            <Loader />
          </Center>
        ) : pages && pages.length > 0 ? (
          <Stack gap="xs">
            {pages.map((page) => (
              <Paper
                key={page.id}
                p="md"
                withBorder
                draggable
                onDragStart={(e) => handleDragStart(e, page)}
                onDragOver={handleDragOver}
                onDrop={(e) => handleDrop(e, page)}
                onDragEnd={handleDragEnd}
                style={{
                  cursor: 'move',
                  opacity: draggedItem?.id === page.id ? 0.5 : 1,
                  transition: 'opacity 0.2s',
                }}
              >
                <Group justify="space-between">
                  <Group gap="sm" style={{ flex: 1, minWidth: 0 }}>
                    <IconMenu2
                      size={20}
                      color="var(--mantine-color-dimmed)"
                      style={{ flexShrink: 0 }}
                    />
                    <Group gap="xs" style={{ minWidth: 0 }}>
                      <Text size="lg" fw={500} truncate>
                        {page.title}
                      </Text>
                      <VisibilityBadge visibility={page.visibility} />
                    </Group>
                  </Group>
                  <Group gap="xs" ml="md">
                    <ActionIcon
                      component={PrefetchLink}
                      to={paths.teamAdminPageEdit(teamSlug!, page.slug)}
                      variant="subtle"
                      color="gray"
                      title={t('actions.edit')}
                    >
                      <IconPencil size={20} />
                    </ActionIcon>
                    {page.deleted && (
                      <ActionIcon
                        variant="subtle"
                        color="green"
                        onClick={() => handleRestore(page)}
                        loading={undeleteMutation.isPending}
                        title={t('actions.restore')}
                      >
                        <IconRestore size={20} />
                      </ActionIcon>
                    )}
                    <ActionIcon
                      variant="subtle"
                      color="danger"
                      onClick={() => handleDelete(page)}
                      title={t('actions.delete')}
                    >
                      <IconTrash size={20} />
                    </ActionIcon>
                  </Group>
                </Group>
              </Paper>
            ))}
          </Stack>
        ) : (
          <Paper p="xl" withBorder>
            <Center>
              <Stack align="center">
                <IconFileText size={48} color="var(--mantine-color-dimmed)" />
                <Title order={3} mt="md">
                  {t('teams.pages.empty.title')}
                </Title>
                <Text c="dimmed">{t('teams.pages.empty.description')}</Text>
                <Button
                  component={PrefetchLink}
                  to={paths.teamAdminPageNew(teamSlug!)}
                  leftSection={<IconPlus size={16} />}
                  mt="md"
                >
                  {t('teams.pages.add')}
                </Button>
              </Stack>
            </Center>
          </Paper>
        )}
      </Box>

      {/* Delete Confirmation Dialog */}
      <ConfirmDialog
        isOpen={!!pageToDelete}
        onClose={() => setPageToDelete(null)}
        onConfirm={confirmDelete}
        title={t('teams.pages.confirmations.deleteTitle')}
        message={t('teams.pages.confirmations.delete', { name: pageToDelete?.title })}
        confirmText={t('actions.delete')}
        variant="danger"
        isLoading={deleteMutation.isPending}
      />
    </TeamAdminLayout>
  )
}
