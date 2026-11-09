import { Paper, Stack, Title } from '@mantine/core'
import { RideGroupRouteActions } from '@/components/ride/RideGroupRouteActions'

/**
 * The route's card in a child page's side column (docs/LEDGER_*.md WEB-155): its name, then its
 * files and devices — beside the map rather than under it, the map filling the visible height.
 */
export function RouteCard({
  title,
  teamSlug,
  routeSlug,
  route,
}: {
  title: string
  teamSlug: string
  routeSlug: string
  route: Parameters<typeof RideGroupRouteActions>[0]['route']
}) {
  return (
    <Paper withBorder p="md">
      <Stack gap="xs">
        <Title order={3} size="h5">
          {title}
        </Title>
        <RideGroupRouteActions teamSlug={teamSlug} routeSlug={routeSlug} route={route} size="sm" />
      </Stack>
    </Paper>
  )
}
