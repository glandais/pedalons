import { useCallback, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import {
  Stack,
  Group,
  Title,
  Button,
  Text,
  Paper,
  Box,
  Badge,
  ActionIcon,
  Anchor,
  Center,
  Loader,
  Pagination,
} from '@mantine/core'
import { IconPencil, IconTrash, IconPlus, IconMapPin } from '@tabler/icons-react'
import {
  useListPlaces,
  useDeletePlace,
  getListPlacesQueryKey,
} from '../../api/endpoints/places/places'
import { useScrollToListTop } from '../../hooks/useScrollToListTop'
import { useUrlFilters } from '../../hooks/useUrlFilters'
import { useDebouncedSearch } from '../../hooks/useDebouncedSearch'
import { placeListFilterOptions } from '../../pages/team/teamPlacesData'
import { ConfirmDialog } from '../common/ConfirmDialog'
import { SearchInput } from '../common/SearchInput'
import { PlaceForm } from './PlaceForm'
import type { PlaceDetailDto } from '../../api/dto'

interface PlaceListProps {
  teamSlug: string
  canManage: boolean
}

export function PlaceList({ teamSlug, canManage }: PlaceListProps) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const { filters, setFilters } = useUrlFilters(placeListFilterOptions)
  const commitSearch = useCallback(
    (value: string) => setFilters({ search: value || undefined }),
    [setFilters]
  )
  const [search, setSearch] = useDebouncedSearch(filters.search ?? '', commitSearch)
  const { listTopRef, scrollToListTop } = useScrollToListTop()
  const { data: placesData, isLoading } = useListPlaces(teamSlug, filters)
  const deleteMutation = useDeletePlace()

  const [editingPlace, setEditingPlace] = useState<PlaceDetailDto | null>(null)
  const [showCreateForm, setShowCreateForm] = useState(false)
  const [deleteConfirm, setDeleteConfirm] = useState<string | null>(null)

  const places = placesData?.places ?? []

  const totalPages = placesData ? Math.ceil(placesData.total / filters.size) : 0

  const handleDelete = (placeId: string) => {
    deleteMutation.mutate(
      { teamSlug: teamSlug, placeId },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getListPlacesQueryKey(teamSlug) })
          notifications.show({
            message: i18next.t('teams.notifications.placeDeleted'),
            color: 'green',
          })
          setDeleteConfirm(null)
        },
      }
    )
  }

  function newPlace(): PlaceDetailDto {
    return {
      id: '',
      name: '',
      address: '',
      link: '',
      startPlace: true,
      endPlace: true,
    }
  }

  return (
    <Stack>
      <Group justify="space-between">
        <Title order={2}>{t('teams.admin.tabs.places')}</Title>
        {canManage && (
          <Button leftSection={<IconPlus size={16} />} onClick={() => setShowCreateForm(true)}>
            {t('places.add')}
          </Button>
        )}
      </Group>

      <SearchInput
        id="places-search"
        value={search}
        onChange={setSearch}
        placeholder={t('places.search.placeholder')}
        label={t('places.search.label')}
      />

      {isLoading ? (
        <Center py="xl">
          <Loader />
        </Center>
      ) : places.length === 0 ? (
        <Text size="sm" c="dimmed" py="md">
          {search ? t('places.noResults') : t('places.empty')}
        </Text>
      ) : (
        <Paper ref={listTopRef} withBorder>
          <Stack gap={0}>
            {places.map((place, index) => (
              <Box
                key={place.id}
                py="md"
                px="md"
                style={{
                  borderBottom:
                    index < places.length - 1
                      ? '1px solid var(--mantine-color-default-border)'
                      : undefined,
                }}
              >
                <Group justify="space-between" wrap="nowrap">
                  <Group gap="sm" wrap="nowrap" align="flex-start">
                    <IconMapPin
                      size={20}
                      color="var(--mantine-color-dimmed)"
                      style={{ marginTop: 2, flexShrink: 0 }}
                    />
                    <Box>
                      <Text size="sm" fw={500}>
                        {place.name}
                      </Text>
                      {place.address && (
                        <Text size="sm" c="dimmed">
                          {place.address}
                        </Text>
                      )}
                      {place.link && (
                        <Anchor
                          href={place.link}
                          target="_blank"
                          rel="noopener noreferrer"
                          size="sm"
                        >
                          {t('places.viewLink')}
                        </Anchor>
                      )}
                      <Group gap="xs" mt="xs">
                        {place.startPlace && (
                          <Badge size="sm" color="green" variant="light">
                            {t('startPlace')}
                          </Badge>
                        )}
                        {place.endPlace && (
                          <Badge size="sm" color="blue" variant="light">
                            {t('endPlace')}
                          </Badge>
                        )}
                      </Group>
                    </Box>
                  </Group>
                  {canManage && (
                    <Group gap="xs">
                      <ActionIcon
                        variant="subtle"
                        color="gray"
                        onClick={() => setEditingPlace(place)}
                        title={t('actions.edit')}
                        aria-label={t('actions.edit')}
                      >
                        <IconPencil size={16} />
                      </ActionIcon>
                      <ActionIcon
                        variant="subtle"
                        color="danger"
                        onClick={() => setDeleteConfirm(place.id)}
                        title={t('places.delete')}
                        aria-label={t('places.delete')}
                      >
                        <IconTrash size={16} />
                      </ActionIcon>
                    </Group>
                  )}
                </Group>
              </Box>
            ))}
          </Stack>
        </Paper>
      )}

      {totalPages > 1 && (
        <Pagination
          value={filters.page + 1}
          onChange={(nextPage) => {
            setFilters({ page: nextPage - 1 })
            scrollToListTop()
          }}
          total={totalPages}
        />
      )}

      {/* Create Form Modal */}
      {showCreateForm && (
        <PlaceForm
          teamSlug={teamSlug}
          place={newPlace()}
          onClose={() => setShowCreateForm(false)}
        />
      )}

      {/* Edit Form Modal */}
      {editingPlace && (
        <PlaceForm teamSlug={teamSlug} place={editingPlace} onClose={() => setEditingPlace(null)} />
      )}

      {/* Delete Confirmation */}
      <ConfirmDialog
        isOpen={!!deleteConfirm}
        onClose={() => setDeleteConfirm(null)}
        onConfirm={() => deleteConfirm && handleDelete(deleteConfirm)}
        title={t('places.deleteConfirm.title')}
        message={t('places.deleteConfirm.message')}
        confirmText={t('places.deleteConfirm.confirm')}
        variant="danger"
        isLoading={deleteMutation.isPending}
      />
    </Stack>
  )
}
