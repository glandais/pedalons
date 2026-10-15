import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { IconListDetails, IconMap, IconMapSearch, IconRoute } from '@tabler/icons-react'
import { Button, Card, Group, SimpleGrid, Stack, Text, Title } from '@mantine/core'
import { createPreview, getListMyPreviewsQueryKey } from '@/api/endpoints/gpx-previews/gpx-previews'
import { paths } from '@/config/paths'
import { isGpxPlannerEnabled } from '@/config/appConfig'

/**
 * Hub for the GPX tools: view an uploaded file, draw a route from scratch on an empty map, open a
 * map with no track on it, or browse your own previews. The grid is where further tools (merging)
 * will land.
 */
export function GpxToolsPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [isUploading, setIsUploading] = useState(false)

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
