import { useMemo, useState } from 'react'
import { Navigate, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import {
  ActionIcon,
  Badge,
  Box,
  Button,
  Center,
  Group,
  Loader,
  Paper,
  Stack,
  Tabs,
  Text,
  Title,
} from '@mantine/core'
import { IconPencil, IconPlus, IconTags, IconTrash } from '@tabler/icons-react'
import { useDeleteTeamTag } from '@/api/endpoints/tags/tags'
import { invalidateTeamTags } from '@/lib/tagCacheInvalidation'
import { TagTarget, type TagWithUsageDto, type TeamDetailDto } from '@/api/dto'
import { paths } from '@/config/paths'
import { useCanonicalPath } from '@/hooks/useCanonicalPath'
import { useUrlFilters } from '@/hooks/useUrlFilters'
import { LoadingPage } from '@/components/common/LoadingSpinner'
import { ConfirmDialog } from '@/components/common/ConfirmDialog'
import { EmptyState } from '@/components/common/EmptyState'
import { TeamAdminLayout } from '@/components/team/TeamAdminLayout'
import { TagChip } from '@/components/tag'
import { TagFormModal } from '@/components/tag/TagFormModal'
import { useTeamTagsData, teamTagsTabOptions } from './teamTagsData'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

/** At most this many tags per team and kind — the API refuses more (plan D16, `TAG_LIMIT_REACHED`). */
const MAX_TAGS_PER_KIND = 100

const KINDS: TagTarget[] = [
  TagTarget.RIDE,
  TagTarget.POST,
  TagTarget.TRIP,
  TagTarget.ROUTE,
  TagTarget.AD,
]

/** Whether the team has the section this kind of tag applies to. */
function kindEnabled(team: TeamDetailDto, kind: TagTarget): boolean {
  switch (kind) {
    case TagTarget.RIDE:
      return team.enableRides
    case TagTarget.POST:
      return team.enablePosts
    case TagTarget.TRIP:
      return team.enableTrips
    case TagTarget.ROUTE:
      return team.enableRoutes
    case TagTarget.AD:
      return team.enableAds
  }
}

/**
 * The team's tag vocabulary, one tab per kind of content (ledger `WEB-40`): create, rename,
 * recolour, delete, each with its usage count (plan D12). Team admins only (D4) — organizers do not
 * get the tab, and the page sends them back to the team.
 */
export function TeamTagsPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const queryClient = useQueryClient()
  const { team: teamQuery, tags: tagsQuery } = useTeamTagsData(teamSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery
  const { data: tags, isLoading: isLoadingTags } = tagsQuery
  const { filters, setFilters } = useUrlFilters(teamTagsTabOptions)
  const deleteMutation = useDeleteTeamTag()

  const [formOpen, setFormOpen] = useState(false)
  const [editing, setEditing] = useState<TagWithUsageDto | null>(null)
  const [toDelete, setToDelete] = useState<TagWithUsageDto | null>(null)

  useCanonicalPath(team ? paths.teamAdminTags(team.slug) : undefined)

  const byKind = useMemo(() => {
    const grouped = new Map<TagTarget, TagWithUsageDto[]>(KINDS.map((kind) => [kind, []]))
    for (const tag of tags ?? []) grouped.get(tag.type)?.push(tag)
    return grouped
  }, [tags])

  if (isLoadingTeam) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  if (!teamAccess(team, isPlatformAdmin).isAdmin) {
    return <Navigate to={paths.team(team.slug)} replace />
  }

  // A kind whose section is off keeps its tab while it still has tags, so they stay manageable.
  const kinds = KINDS.filter(
    (kind) => kindEnabled(team, kind) || (byKind.get(kind)?.length ?? 0) > 0
  )
  const requested = filters.type?.toUpperCase() as TagTarget | undefined
  const current = requested && kinds.includes(requested) ? requested : kinds[0]
  const currentTags = current ? (byKind.get(current) ?? []) : []
  const atLimit = currentTags.length >= MAX_TAGS_PER_KIND

  const confirmDelete = () => {
    if (!toDelete || !teamSlug) return
    deleteMutation.mutate(
      { teamSlug, tagId: toDelete.id },
      {
        onSuccess: (result) => {
          invalidateTeamTags(queryClient, teamSlug)
          notifications.show({
            message: i18next.t('tags.admin.notifications.deleted', {
              count: result.detachedCount,
            }),
            color: 'green',
          })
          setToDelete(null)
        },
      }
    )
  }

  return (
    <TeamAdminLayout team={team} currentTab="tags">
      <Stack py="lg">
        <Group justify="space-between">
          <Title order={4}>{t('tags.admin.title')}</Title>
          {current && (
            <Button
              leftSection={<IconPlus size={16} />}
              onClick={() => setFormOpen(true)}
              disabled={atLimit}
            >
              {t('tags.admin.add')}
            </Button>
          )}
        </Group>
        <Text size="sm" c="dimmed">
          {t('tags.admin.description')}
        </Text>

        {kinds.length === 0 ? (
          <EmptyState
            icon={<IconTags size={48} />}
            title={t('tags.admin.noKind.title')}
            description={t('tags.admin.noKind.description')}
          />
        ) : (
          <Tabs
            value={current}
            onChange={(value) =>
              value && setFilters({ type: value.toLowerCase() as typeof filters.type })
            }
            keepMounted={false}
          >
            <Tabs.List>
              {kinds.map((kind) => (
                <Tabs.Tab
                  key={kind}
                  value={kind}
                  rightSection={
                    <Badge size="xs" variant="light" color="gray">
                      {byKind.get(kind)?.length ?? 0}
                    </Badge>
                  }
                >
                  {t(`tags.admin.kind.${kind satisfies TagTarget}`)}
                </Tabs.Tab>
              ))}
            </Tabs.List>

            {kinds.map((kind) => (
              <Tabs.Panel key={kind} value={kind} pt="md">
                {isLoadingTags ? (
                  <Center py="xl">
                    <Loader />
                  </Center>
                ) : (byKind.get(kind)?.length ?? 0) === 0 ? (
                  <EmptyState
                    icon={<IconTags size={48} />}
                    title={t('tags.admin.empty.title')}
                    description={t(`tags.admin.empty.${kind satisfies TagTarget}`)}
                    actions={
                      <Button
                        leftSection={<IconPlus size={16} />}
                        onClick={() => setFormOpen(true)}
                      >
                        {t('tags.admin.add')}
                      </Button>
                    }
                  />
                ) : (
                  <TagRows tags={byKind.get(kind)!} onEdit={setEditing} onDelete={setToDelete} />
                )}
              </Tabs.Panel>
            ))}
          </Tabs>
        )}

        {current && (
          <Text size="xs" c={atLimit ? 'danger' : 'dimmed'}>
            {t('tags.admin.limit', { used: currentTags.length, max: MAX_TAGS_PER_KIND })}
          </Text>
        )}
      </Stack>

      {formOpen && current && (
        <TagFormModal teamSlug={team.slug} type={current} onClose={() => setFormOpen(false)} />
      )}
      {editing && (
        <TagFormModal
          teamSlug={team.slug}
          type={editing.type}
          tag={editing}
          onClose={() => setEditing(null)}
        />
      )}

      <ConfirmDialog
        isOpen={!!toDelete}
        onClose={() => setToDelete(null)}
        onConfirm={confirmDelete}
        title={t('tags.admin.deleteConfirm.title')}
        message={
          toDelete && (
            <Stack gap="sm">
              <Group gap="xs">
                <TagChip tag={toDelete} />
              </Group>
              <Text size="sm">
                {toDelete.usageCount > 0
                  ? t('tags.admin.deleteConfirm.used', { count: toDelete.usageCount })
                  : t('tags.admin.deleteConfirm.unused')}
              </Text>
            </Stack>
          )
        }
        confirmText={t('tags.admin.deleteConfirm.confirm')}
        variant="danger"
        isLoading={deleteMutation.isPending}
      />
    </TeamAdminLayout>
  )
}

interface TagRowsProps {
  tags: TagWithUsageDto[]
  onEdit: (tag: TagWithUsageDto) => void
  onDelete: (tag: TagWithUsageDto) => void
}

/** One kind's tags, as the API sorts them (by label), each with its usage and its actions. */
function TagRows({ tags, onEdit, onDelete }: TagRowsProps) {
  const { t } = useTranslation()
  return (
    <Paper withBorder>
      <Stack gap={0}>
        {tags.map((tag, index) => (
          <Box
            key={tag.id}
            py="sm"
            px="md"
            style={{
              borderBottom:
                index < tags.length - 1
                  ? '1px solid var(--mantine-color-default-border)'
                  : undefined,
            }}
          >
            <Group justify="space-between" wrap="nowrap">
              <Group gap="md" wrap="wrap">
                <TagChip tag={tag} size="md" />
                <Text size="sm" c="dimmed">
                  {t('tags.admin.usage', { count: tag.usageCount })}
                </Text>
              </Group>
              <Group gap="xs" wrap="nowrap">
                <ActionIcon
                  variant="subtle"
                  color="gray"
                  onClick={() => onEdit(tag)}
                  title={t('tags.admin.edit', { label: tag.label })}
                  aria-label={t('tags.admin.edit', { label: tag.label })}
                >
                  <IconPencil size={16} />
                </ActionIcon>
                <ActionIcon
                  variant="subtle"
                  color="danger"
                  onClick={() => onDelete(tag)}
                  title={t('tags.admin.delete', { label: tag.label })}
                  aria-label={t('tags.admin.delete', { label: tag.label })}
                >
                  <IconTrash size={16} />
                </ActionIcon>
              </Group>
            </Group>
          </Box>
        ))}
      </Stack>
    </Paper>
  )
}
