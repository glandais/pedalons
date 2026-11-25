import { Navigate } from 'react-router-dom'
import { Container } from '@mantine/core'
import { QueryStateBoundary } from '@/components/common/QueryStateBoundary'
import { apiErrorStatus } from '@/lib/apiError'
import { paths } from '@/config/paths'

interface TeamUnavailableProps {
  /** The team query's error, when it failed. */
  error: unknown
  isError: boolean
  onRetry: () => void
}

/**
 * What a team page renders when `GET /api/teams/{slug}` gave no team. A team that does not exist,
 * or that this visitor may not see, sends them to the team list; a server or network failure says
 * so and offers to retry — the team is probably still there (e2e/error-states.e2e.ts).
 */
export function TeamUnavailable({ error, isError, onRetry }: TeamUnavailableProps) {
  const status = apiErrorStatus(error)
  if (isError && (status === undefined || status >= 500)) {
    return (
      <Container size="xl" py="xl">
        <QueryStateBoundary isLoading={false} isError error={error} onRetry={onRetry} replacesPage>
          {null}
        </QueryStateBoundary>
      </Container>
    )
  }
  return <Navigate to={paths.teams()} replace />
}
