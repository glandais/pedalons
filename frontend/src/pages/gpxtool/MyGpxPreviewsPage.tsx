import { useState } from 'react'
import { OutOfRangeState } from '@/components/common/OutOfRangeState'
import { useTranslation } from 'react-i18next'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useQueryClient } from '@tanstack/react-query'
import { IconArrowDown, IconArrowUp, IconMapSearch, IconTrash } from '@tabler/icons-react'
import { Button, Card, Group, Skeleton, Stack, Text, Title } from '@mantine/core'
import { notifications } from '@mantine/notifications'
import type { GpxPreviewSummaryDto } from '@/api/dto'
import {
  getListMyPreviewsQueryKey,
  useDeletePreview,
} from '@/api/endpoints/gpx-previews/gpx-previews'
import { DepartureLine } from '@/components/common/DepartureLine'
import { ConfirmDialog } from '@/components/common/ConfirmDialog'
import { Pagination } from '@/components/common/Pagination'
import { paths } from '@/config/paths'
import { useUnits } from '@/hooks/useUnits'
import { useFormattedDate } from '@/utils/dateFormat'
import { useGpxPreviewListData } from './gpxPreviewListData'

/**
 * Lists the current user's still-available GPX previews (uploaded through the GPX tools page and not
 * yet purged), with per-row view and delete actions.
 */
export function MyGpxPreviewsPage() {
  const { t } = useTranslation()

  const { filters, setFilters, previews: previewsQuery, totalPages } = useGpxPreviewListData()
  const { data, isLoading } = previewsQuery

  const previews = data?.previews ?? []

  return (
    <Stack>
      <Stack gap="xs">
        <Title order={1}>{t('gpxTools.listFiles.title')}</Title>
        <Text c="dimmed">{t('gpxTools.retentionNotice')}</Text>
      </Stack>

      {isLoading ? (
        <Stack>
          {Array.from({ length: 3 }).map((_, index) => (
            <Skeleton key={index} height={72} radius="md" />
          ))}
        </Stack>
      ) : previews.length === 0 ? (
        filters.page > 0 ? (
          <OutOfRangeState onFirstPage={() => setFilters({ page: 0 })} />
        ) : (
          <Card withBorder padding="lg">
            <Stack align="center" gap="sm">
              <Text c="dimmed">{t('gpxTools.listFiles.empty')}</Text>
              <Button component={PrefetchLink} to={paths.gpxTools()} variant="default">
                {t('gpxTools.viewFile.submit')}
              </Button>
            </Stack>
          </Card>
        )
      ) : (
        <Stack>
          {previews.map((preview) => (
            <PreviewRow key={preview.id} preview={preview} />
          ))}
        </Stack>
      )}

      <Pagination
        currentPage={filters.page}
        totalPages={totalPages}
        onPageChange={(page) => setFilters({ page })}
      />
    </Stack>
  )
}

interface PreviewRowProps {
  preview: GpxPreviewSummaryDto
}

function PreviewRow({ preview }: PreviewRowProps) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const { distance, elevation } = useUnits()
  const { formatRelative } = useFormattedDate()

  const [deleteOpened, setDeleteOpened] = useState(false)
  const deletePreviewMutation = useDeletePreview()

  const handleDelete = async () => {
    await deletePreviewMutation.mutateAsync({ previewId: preview.id })
    await queryClient.invalidateQueries({ queryKey: getListMyPreviewsQueryKey() })
    notifications.show({ message: t('gpxTools.preview.deleted'), color: 'green' })
    setDeleteOpened(false)
  }

  return (
    <Card withBorder padding="md">
      <Group justify="space-between" wrap="wrap" gap="sm">
        <Stack gap={4} style={{ minWidth: 0, flex: 1 }}>
          <Text fw={500} truncate>
            {preview.name}
          </Text>
          {/* The departure under the name, in 700 — never one dimmed stat among others (BRAND-8) */}
          {preview.departureTime && (
            <DepartureLine
              date={preview.departureTime}
              zone={preview.departureTimezone}
              size="sm"
              withDay
            />
          )}
          <Group gap="md" c="dimmed">
            <Text size="sm">{distance(preview.distance)}</Text>
            <Group gap={2}>
              <IconArrowUp size={14} />
              <Text size="sm">{elevation(preview.elevationGain)}</Text>
            </Group>
            <Group gap={2}>
              <IconArrowDown size={14} />
              <Text size="sm">{elevation(preview.elevationLoss)}</Text>
            </Group>
            {/* "il y a 2 minutes" is read off the clock: server and client legitimately render
                different text a few seconds apart. */}
            <Text size="sm" suppressHydrationWarning>
              {formatRelative(preview.createdAt)}
            </Text>
          </Group>
        </Stack>

        <Group gap="xs">
          <Button
            component={PrefetchLink}
            to={paths.gpxToolsView(preview.id)}
            variant="default"
            size="sm"
            leftSection={<IconMapSearch size={16} />}
          >
            {t('gpxTools.listFiles.view')}
          </Button>
          <Button
            variant="default"
            size="sm"
            color="danger"
            leftSection={<IconTrash size={16} />}
            onClick={() => setDeleteOpened(true)}
          >
            {t('gpxTools.preview.delete')}
          </Button>
        </Group>
      </Group>

      <ConfirmDialog
        isOpen={deleteOpened}
        onClose={() => setDeleteOpened(false)}
        onConfirm={handleDelete}
        title={t('gpxTools.preview.delete')}
        message={t('gpxTools.preview.deleteConfirm')}
        variant="danger"
        isLoading={deletePreviewMutation.isPending}
      />
    </Card>
  )
}
