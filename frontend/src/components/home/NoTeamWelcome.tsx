import { useTranslation } from 'react-i18next'
import { Button, Divider, Group, Paper, Stack, Text, Title } from '@mantine/core'
import { IconMailOpened, IconPlus, IconSearch } from '@tabler/icons-react'
import { useListMyInvitations } from '@/api/endpoints/invitations/invitations'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useAcceptPendingInvitation } from '@/components/team/useAcceptPendingInvitation'
import { isSingleTeam } from '@/config/appConfig'
import { paths } from '@/config/paths'

/**
 * The member home of someone who belongs to no team yet, in place of « Ma prochaine sortie », the
 * week and « Mes équipes » — three empty states that said nothing about what to do first
 * (docs/LEDGER_*.md WEB-194). One block, one next step, in this order: the invitations waiting for
 * them, with « Rejoindre » on the spot; « Trouver une équipe »; « Créer mon équipe ». No carousel
 * and no tutorial (ruled out by the research of 22 November 2026). It goes away with the first team.
 *
 * The first action that applies is the filled button, the others are light: with an invitation,
 * joining is the obvious step; without, finding a team.
 */
export function NoTeamWelcome() {
  const { t } = useTranslation()
  const singleTeam = isSingleTeam()
  const { data } = useListMyInvitations()
  const { acceptInvitation, isPending } = useAcceptPendingInvitation()
  const invitations = data?.invitations ?? []
  const hasInvitations = invitations.length > 0
  // Spelled out: the list otherwise opens on the member's own teams (`useMembershipDefault`).
  const findTeamHref = `${paths.teams()}?role=all`

  return (
    <Paper
      withBorder
      radius="md"
      p="lg"
      component="section"
      aria-labelledby="home-no-team-title"
      data-testid="home-no-team"
    >
      <Stack gap="md">
        <Stack gap={4}>
          <Title id="home-no-team-title" order={2} size="h3">
            {t('home.noTeam.title')}
          </Title>
          <Text c="dimmed">{t('home.noTeam.subtitle')}</Text>
        </Stack>

        {hasInvitations && (
          <Stack gap="sm">
            <Group gap="xs">
              <IconMailOpened size={18} aria-hidden />
              <Text fw={600}>{t('invitations.banner.title', { count: invitations.length })}</Text>
            </Group>
            {invitations.map((invitation) => (
              <Group key={invitation.id} justify="space-between" wrap="wrap" gap="sm">
                <Text size="sm">
                  {t('invitations.banner.line', {
                    inviter: invitation.inviterName,
                    team: invitation.team.name,
                  })}
                </Text>
                <Button
                  size="sm"
                  loading={isPending}
                  onClick={() => acceptInvitation(invitation)}
                  aria-label={t('home.noTeam.joinTeam', { team: invitation.team.name })}
                >
                  {t('home.noTeam.join')}
                </Button>
              </Group>
            ))}
            <Divider />
          </Stack>
        )}

        {!singleTeam && (
          <Group justify="space-between" wrap="wrap" gap="sm">
            <Stack gap={0} style={{ flex: 1, minWidth: 200 }}>
              <Text fw={600}>{t('home.noTeam.find.title')}</Text>
              <Text size="sm" c="dimmed">
                {t('home.noTeam.find.description')}
              </Text>
            </Stack>
            <Button
              component={PrefetchLink}
              to={findTeamHref}
              variant={hasInvitations ? 'light' : 'filled'}
              leftSection={<IconSearch size={16} />}
            >
              {t('home.noTeam.find.action')}
            </Button>
          </Group>
        )}

        <Group justify="space-between" wrap="wrap" gap="sm">
          <Stack gap={0} style={{ flex: 1, minWidth: 200 }}>
            <Text fw={600}>{t('home.noTeam.create.title')}</Text>
            <Text size="sm" c="dimmed">
              {t('home.noTeam.create.description')}
            </Text>
          </Stack>
          <Button
            component={PrefetchLink}
            to={paths.teamsNew()}
            variant={singleTeam && !hasInvitations ? 'filled' : 'light'}
            leftSection={<IconPlus size={16} />}
          >
            {t('home.noTeam.create.action')}
          </Button>
        </Group>
      </Stack>
    </Paper>
  )
}
