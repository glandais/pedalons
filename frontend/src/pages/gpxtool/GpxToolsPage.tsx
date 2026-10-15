import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import {
  IconArrowsJoin,
  IconListDetails,
  IconMap,
  IconMapSearch,
  IconRoute,
} from '@tabler/icons-react'
import { Button, Card, Group, SimpleGrid, Stack, Text, Title } from '@mantine/core'
import { notifications } from '@mantine/notifications'
import {
  createPreview,
  getListMyPreviewsQueryKey,
  mergePreviews,
} from '@/api/endpoints/gpx-previews/gpx-previews'
import { paths } from '@/config/paths'
import { isGpxPlannerEnabled } from '@/config/appConfig'

/**
 * Hub for the GPX tools: view an uploaded file, draw a route from scratch on an empty map, open a
 * map with no track on it, merge several files into one track, or browse your own previews. Import
 * from a URL or from OpenRunner/VisuGPX is deliberately out (docs/LEDGER_*.md API-113, API-114).
 *
 * Merging sends the files as soon as they are picked, like viewing one: the server chooses the
 * order and direction of the tracks (docs/LEDGER_*.md API-112), so there is nothing to arrange
 * here. The 2..10 bound is checked before upload; the server checks it again, and bounds the files'
 * summed size like one upload (FILE_TOO_LARGE).
 */
const MIN_MERGE_FILES = 2
const MAX_MERGE_FILES = 10

export function GpxToolsPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [isUploading, setIsUploading] = useState(false)
  const mergeInputRef = useRef<HTMLInputElement>(null)
  const [isMerging, setIsMerging] = useState(false)

  const handleFileSelected = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0]
    // Reset so re-picking the same file fires another change event.
    event.target.value = ''
    if (!file) return

    setIsUploading(true)
    try {
      const preview = await createPreview({ gpxFile: file })
      // Refresh "my files": the key prefix matches every paginated variant.
      queryClient.invalidateQueries({ queryKey: getListMyPreviewsQueryKey() })
      navigate(paths.gpxToolsView(preview.id))
    } finally {
      setIsUploading(false)
    }
  }

  const handleMergeSelected = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(event.target.files ?? [])
    event.target.value = ''
    if (files.length === 0) return
    if (files.length < MIN_MERGE_FILES || files.length > MAX_MERGE_FILES) {
      notifications.show({
        color: 'yellow',
        message: t('gpxTools.merge.fileCount', {
          min: MIN_MERGE_FILES,
          max: MAX_MERGE_FILES,
          selected: files.length,
        }),
      })
      return
    }

    setIsMerging(true)
    try {
      const preview = await mergePreviews({ gpxFiles: files })
      queryClient.invalidateQueries({ queryKey: getListMyPreviewsQueryKey() })
      navigate(paths.gpxToolsView(preview.id))
    } finally {
      setIsMerging(false)
    }
  }

  return (
    <Stack>
      <Stack gap="xs">
        <Title order={1}>{t('gpxTools.title')}</Title>
        <Text c="dimmed">{t('gpxTools.subtitle')}</Text>
      </Stack>

      <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }}>
        <Card withBorder padding="lg">
          <Stack justify="space-between" h="100%">
            <Stack gap="xs">
              <Group gap="xs">
                <IconMapSearch size={20} />
                <Text fw={500}>{t('gpxTools.viewFile.title')}</Text>
              </Group>
              <Text size="sm" c="dimmed">
                {t('gpxTools.viewFile.description')}
              </Text>
            </Stack>

            <input
              ref={fileInputRef}
              type="file"
              accept=".gpx"
              hidden
              onChange={handleFileSelected}
            />
            <Button onClick={() => fileInputRef.current?.click()} loading={isUploading}>
              {t('gpxTools.viewFile.submit')}
            </Button>
          </Stack>
        </Card>

        <Card withBorder padding="lg">
          <Stack justify="space-between" h="100%">
            <Stack gap="xs">
              <Group gap="xs">
                <IconArrowsJoin size={20} />
                <Text fw={500}>{t('gpxTools.merge.title')}</Text>
              </Group>
              <Text size="sm" c="dimmed">
                {t('gpxTools.merge.description')}
              </Text>
            </Stack>

            <input
              ref={mergeInputRef}
              type="file"
              accept=".gpx"
              multiple
              hidden
              data-testid="gpx-merge-input"
              onChange={handleMergeSelected}
            />
            <Button
              variant="default"
              onClick={() => mergeInputRef.current?.click()}
              loading={isMerging}
            >
              {t('gpxTools.merge.submit')}
            </Button>
          </Stack>
        </Card>

        {/* Drawing from scratch is a domain-level feature; the upload and list cards stay. */}
        {isGpxPlannerEnabled() && (
          <Card withBorder padding="lg">
            <Stack justify="space-between" h="100%">
              <Stack gap="xs">
                <Group gap="xs">
                  <IconRoute size={20} />
                  <Text fw={500}>{t('gpxTools.createFromScratch.title')}</Text>
                </Group>
                <Text size="sm" c="dimmed">
                  {t('gpxTools.createFromScratch.description')}
                </Text>
              </Stack>

              <Button variant="default" onClick={() => navigate(paths.gpxToolsNew())}>
                {t('gpxTools.createFromScratch.submit')}
              </Button>
            </Stack>
          </Card>
        )}

        <Card withBorder padding="lg">
          <Stack justify="space-between" h="100%">
            <Stack gap="xs">
              <Group gap="xs">
                <IconMap size={20} />
                <Text fw={500}>{t('gpxTools.blankMap.title')}</Text>
              </Group>
              <Text size="sm" c="dimmed">
                {t('gpxTools.blankMap.description')}
              </Text>
            </Stack>

            <Button variant="default" onClick={() => navigate(paths.gpxToolsBlankMap())}>
              {t('gpxTools.blankMap.submit')}
            </Button>
          </Stack>
        </Card>

        <Card withBorder padding="lg">
          <Stack justify="space-between" h="100%">
            <Stack gap="xs">
              <Group gap="xs">
                <IconListDetails size={20} />
                <Text fw={500}>{t('gpxTools.listFiles.title')}</Text>
              </Group>
              <Text size="sm" c="dimmed">
                {t('gpxTools.listFiles.description')}
              </Text>
            </Stack>

            <Button variant="default" onClick={() => navigate(paths.gpxToolsList())}>
              {t('gpxTools.listFiles.submit')}
            </Button>
          </Stack>
        </Card>
      </SimpleGrid>

      <Text size="sm" c="dimmed">
        {t('gpxTools.retentionNotice')}
      </Text>
    </Stack>
  )
}
