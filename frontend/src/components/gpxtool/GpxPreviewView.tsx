import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import {
  IconArrowUp,
  IconArrowDown,
  IconDeviceMobile,
  IconDownload,
  IconEdit,
  IconRoute,
  IconTrash,
} from '@tabler/icons-react'
import { Box, Button, Group, Loader, Menu, Modal, Select, Stack, Text, Title } from '@mantine/core'
import { notifications } from '@mantine/notifications'
import type { GpsServiceType, GpxPreviewDto } from '@/api/dto'
import { ElevationState, ErrorCode, SurfaceType } from '@/api/dto'
import { createRouteFromPreview, useDeletePreview } from '@/api/endpoints/gpx-previews/gpx-previews'
import { useListTeams } from '@/api/endpoints/teams/teams'
import { ConfirmDialog } from '@/components/common/ConfirmDialog'
import { ShareButton } from '@/components/common/ShareButton'
import { RouteMapView } from '@/components/route/RouteMapView'
import { RouteSurfaceSummary } from '@/components/route/RouteSurfaceSummary'
import { paths } from '@/config/paths'
import { useAuth } from '@/hooks/useAuth'
import { useGpsConnections } from '@/hooks/useGpsConnections'
import { useUnits } from '@/hooks/useUnits'
import { apiErrorCode, ApiClientError } from '@/lib/apiError'
import { defaultMedia } from '@/lib/apiUtils'
import { invalidateRouteQueries } from '@/lib/routeCacheInvalidation'
import type { PlannerColorBy } from '@/lib/plannerSurface'

interface GpxPreviewViewProps {
  preview: GpxPreviewDto
}

/**
 * Renders an analysed GPX file: the same map and elevation profile as a route. Anyone holding the
 * link sees those, and can share that link; the actions below need an account, and deletion needs
 * to be the creator.
 */
export function GpxPreviewView({ preview }: GpxPreviewViewProps) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const { distance, elevation } = useUnits()
  const { isAuthenticated } = useAuth()
  const { connectedServices, uploadPreview, isUploadingPreview } = useGpsConnections()

  const [saveOpened, setSaveOpened] = useState(false)
  const [selectedTeam, setSelectedTeam] = useState<string | null>(null)
  const [isSaving, setIsSaving] = useState(false)
  const [deleteOpened, setDeleteOpened] = useState(false)
  const [colorBy, setColorBy] = useState<PlannerColorBy>('grade')

  const deletePreviewMutation = useDeletePreview()

  // Only teams the user may create routes on.
  const { data: teams } = useListTeams(
    { minRole: 'ORGANIZER', size: 100 },
    { query: { enabled: saveOpened && isAuthenticated } }
  )
  const teamOptions = (teams?.teams ?? [])
    .filter((team) => team.enableRoutes)
    .map((team) => ({
      value: team.slug,
      // A drawn track only becomes a route where drawing is open (the backend refuses it with
      // ROUTE_PLANNER_DISABLED otherwise). Disabled rather than hidden, so the user sees why a team
      // they belong to is out of reach; an imported file goes anywhere.
      disabled: preview.drawn && !team.enableRoutePlanner,
      label: team.name,
    }))
  const hasClosedPlanner = teamOptions.some((option) => option.disabled)

  const handleSendToDevice = (serviceType: GpsServiceType) => {
    uploadPreview({ serviceType, previewId: preview.id })
  }

  const handleDelete = async () => {
    await deletePreviewMutation.mutateAsync({ previewId: preview.id })
    notifications.show({ message: t('gpxTools.preview.deleted'), color: 'green' })
    navigate(paths.gpxTools())
  }

  const handleSaveAsRoute = async () => {
    if (!selectedTeam) return
    const team = teams?.teams.find((candidate) => candidate.slug === selectedTeam)
    if (!team) return

    setIsSaving(true)
    try {
      const route = await createRouteFromPreview(
        preview.id,
        selectedTeam,
        {
          name: preview.name,
          media: defaultMedia(),
          surfaceType: SurfaceType.ROAD,
          visibility: team.visibility,
        },
        // The global toast would blame the site for a refusal that comes from the team.
        { skipErrorToast: true }
      )
      invalidateRouteQueries(queryClient, selectedTeam)
      notifications.show({ message: t('routes.notifications.created'), color: 'green' })
      navigate(paths.route(selectedTeam, route.slug))
    } catch (e) {
      const code = apiErrorCode(e)
      if (!code) throw e
      notifications.show({
        message:
          code === ErrorCode.ROUTE_PLANNER_DISABLED
            ? t('gpxTools.preview.plannerClosedForTeam')
            : t(`errors.api.${code}`, e instanceof ApiClientError ? e.error.errorDetails : {}),
        color: 'red',
      })
    } finally {
      setIsSaving(false)
    }
  }

  return (
    <Stack>
      {/* Sharing is open to anyone: the preview page is public, the link is all it takes. */}
      <Group justify="space-between" align="flex-start" wrap="nowrap">
        <Title order={1}>{preview.name}</Title>
        <ShareButton title={preview.name} />
      </Group>

      <Box>
        <RouteMapView
          route={preview}
          fullscreenPath={paths.gpxToolsMap(preview.id)}
          colorBy={colorBy}
        />
      </Box>

      {/* Under the map, like the route sheet: its switch colours the map and the profile above */}
      <RouteSurfaceSummary tracks={preview.tracks} colorBy={colorBy} onColorByChange={setColorBy} />

      <Group gap="lg">
        <Text>{distance(preview.distance)}</Text>
        <Group gap={4}>
          <IconArrowUp size={16} />
          <Text>{elevation(preview.elevationGain)}</Text>
        </Group>
        <Group gap={4}>
          <IconArrowDown size={16} />
          <Text>{elevation(preview.elevationLoss)}</Text>
        </Group>
      </Group>

      {/* Downloads are open to anyone with the link; the actions below need an account. */}
      <Group gap="sm" wrap="wrap">
        <Button
          variant="default"
          size="sm"
          component="a"
          href={preview.gpxUrl}
          leftSection={<IconDownload size={16} />}
        >
          {t('routes.detail.download.gpx')}
        </Button>
        <Button
          variant="default"
          size="sm"
          component="a"
          href={preview.fitUrl}
          leftSection={<IconDownload size={16} />}
        >
          {t('routes.detail.download.fit')}
        </Button>

        {isAuthenticated && (
          <Button
            variant="default"
            size="sm"
            leftSection={<IconRoute size={16} />}
            onClick={() => setSaveOpened(true)}
          >
            {t('gpxTools.preview.saveAsRoute')}
          </Button>
        )}

        {isAuthenticated && connectedServices.length > 0 && (
          <Menu shadow="md" width={200}>
            <Menu.Target>
              <Button
                variant="default"
                size="sm"
                leftSection={
                  isUploadingPreview ? <Loader size={16} /> : <IconDeviceMobile size={16} />
                }
                disabled={isUploadingPreview}
              >
                {t('routes.detail.sendToDevice')}
              </Button>
            </Menu.Target>
            <Menu.Dropdown>
              {connectedServices.map((service) => (
                <Menu.Item
                  key={service.serviceType}
                  onClick={() => handleSendToDevice(service.serviceType)}
                >
                  {service.serviceType}
                </Menu.Item>
              ))}
            </Menu.Dropdown>
          </Menu>
        )}

        {preview.owned && (
          <Button
            variant="default"
            size="sm"
            leftSection={<IconEdit size={16} />}
            onClick={() => navigate(paths.gpxToolsEdit(preview.id))}
          >
            {t('gpxTools.preview.edit')}
          </Button>
        )}

        {preview.owned && (
          <Button
            variant="default"
            size="sm"
            color="danger"
            leftSection={<IconTrash size={16} />}
            onClick={() => setDeleteOpened(true)}
          >
            {t('gpxTools.preview.delete')}
          </Button>
        )}
      </Group>

      {preview.elevationState === ElevationState.PENDING && (
        <Text size="xs" c="dimmed">
          {t('gpxTools.preview.elevationRefining')}
        </Text>
      )}

      <Modal
        opened={saveOpened}
        onClose={() => setSaveOpened(false)}
        title={t('gpxTools.preview.saveAsRoute')}
        closeButtonProps={{ 'aria-label': t('aria.closeDialog') }}
      >
        <Stack>
          <Select
            label={t('gpxTools.preview.selectTeam')}
            data={teamOptions}
            value={selectedTeam}
            onChange={setSelectedTeam}
            nothingFoundMessage={t('gpxTools.preview.noTeam')}
            description={hasClosedPlanner ? t('gpxTools.preview.drawnNeedsPlanner') : undefined}
            searchable
          />
          <Group justify="flex-end">
            <Button variant="default" onClick={() => setSaveOpened(false)}>
              {t('actions.cancelAction')}
            </Button>
            <Button onClick={handleSaveAsRoute} disabled={!selectedTeam} loading={isSaving}>
              {t('gpxTools.preview.save')}
            </Button>
          </Group>
        </Stack>
      </Modal>

      <ConfirmDialog
        isOpen={deleteOpened}
        onClose={() => setDeleteOpened(false)}
        onConfirm={handleDelete}
        title={t('gpxTools.preview.delete')}
        message={t('gpxTools.preview.deleteConfirm')}
        variant="danger"
        isLoading={deletePreviewMutation.isPending}
      />
    </Stack>
  )
}
