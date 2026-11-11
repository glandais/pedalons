import { useLocation } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Alert, Anchor, Text } from '@mantine/core'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { paths } from '@/config/paths'
import { KIND_LABELS, type PublicationKind } from './publicationKind'

interface AccessAlertsProps {
  kind: PublicationKind
  teamSlug: string
  isAuthenticated: boolean
  isMember: boolean
  /**
   * Whether the team answers the reader (the entity's `team.accessible`): the « view the team » link
   * only when it does — a private team's public content is read by link, its team stays closed.
   */
  teamAccessible: boolean
}

/**
 * Why the reader cannot join (docs/LEDGER_*.md WEB-155): signed out, a sign-in link that comes back
 * here; signed in outside the team, a link to the team. Nothing for a member.
 */
export function AccessAlerts({
  kind,
  teamSlug,
  isAuthenticated,
  isMember,
  teamAccessible,
}: AccessAlertsProps) {
  const { t } = useTranslation()
  const location = useLocation()
  const labels = KIND_LABELS[kind]

  if (!isAuthenticated) {
    return (
      <Alert color="blue" variant="light">
        <Text size="sm">
          {t(labels.notAuthenticatedMessage)}{' '}
          <Anchor component={PrefetchLink} to={paths.login()} state={{ from: location }} fw={500}>
            {t(labels.notAuthenticatedSignIn)}
          </Anchor>
        </Text>
      </Alert>
    )
  }
  if (!isMember) {
    return (
      <Alert color="yellow" variant="light">
        <Text size="sm">
          {t(labels.nonMemberMessage)}
          {teamAccessible && (
            <>
              {' '}
              <Anchor component={PrefetchLink} to={paths.team(teamSlug)} fw={500}>
                {t(labels.nonMemberViewTeam)}
              </Anchor>
            </>
          )}
        </Text>
      </Alert>
    )
  }
  return null
}
