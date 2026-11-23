import { useTranslation } from 'react-i18next'
import { Badge, Paper, Skeleton, Stack, Table, Text, Title } from '@mantine/core'
import type { AdminActivationWeekDto } from '@/api/dto'
import { formatNumber } from '@/utils/unitFormat'

interface ActivationTableProps {
  weeks: AdminActivationWeekDto[] | undefined
  isLoading: boolean
  isError: boolean
}

/**
 * « Activation des nouveaux comptes » (docs/LEDGER_*.md API-213): per sign-up week and domain,
 * the share of the accounts created that week that joined a team, and that signed up to a ride,
 * within 7 days — the measure WEB-193, MOB-179, WEB-194 and WEB-195 are judged by. Counts from the
 * server, the rates computed here; there is no target to reach, only the trend before and after.
 * A week whose accounts have not all had their 7 days is marked « en cours »: its rates can still
 * grow.
 */
export function ActivationTable({ weeks, isLoading, isError }: ActivationTableProps) {
  const { t, i18n } = useTranslation()

  const rate = (part: number, whole: number) =>
    whole === 0 ? '—' : `${formatNumber(Math.round((part / whole) * 100), i18n.language)} %`

  return (
    <Paper withBorder p="lg" radius="md" component="section" aria-labelledby="admin-activation">
      <Stack gap="sm">
        <Stack gap={2}>
          <Title order={2} size="h4" id="admin-activation">
            {t('admin.activation.title')}
          </Title>
          <Text size="sm" c="dimmed">
            {t('admin.activation.subtitle')}
          </Text>
        </Stack>
        {isLoading ? (
          <Skeleton height={160} />
        ) : isError ? (
          <Text size="sm" c="dimmed">
            {t('error.loading')}
          </Text>
        ) : !weeks || weeks.length === 0 ? (
          <Text size="sm" c="dimmed">
            {t('admin.activation.empty')}
          </Text>
        ) : (
          <Table.ScrollContainer minWidth={640}>
            <Table striped>
              <Table.Thead>
                <Table.Tr>
                  <Table.Th>{t('admin.activation.week')}</Table.Th>
                  <Table.Th>{t('admin.activation.domain')}</Table.Th>
                  <Table.Th ta="right">{t('admin.activation.signedUp')}</Table.Th>
                  <Table.Th ta="right">{t('admin.activation.verified')}</Table.Th>
                  <Table.Th ta="right">{t('admin.activation.joinedTeam')}</Table.Th>
                  <Table.Th ta="right">{t('admin.activation.joinedRide')}</Table.Th>
                </Table.Tr>
              </Table.Thead>
              <Table.Tbody>
                {weeks.map((week) => (
                  <Table.Tr key={`${week.weekStart}-${week.domainId}`}>
                    <Table.Td>
                      {/* A calendar date, not an instant: shown as is, never shifted by a zone. */}
                      {week.weekStart}
                      {!week.complete && (
                        <Badge ml="xs" size="xs" variant="light" color="gray">
                          {t('admin.activation.inProgress')}
                        </Badge>
                      )}
                    </Table.Td>
                    <Table.Td>{week.domainName}</Table.Td>
                    <Table.Td ta="right">{formatNumber(week.signedUp, i18n.language)}</Table.Td>
                    <Table.Td ta="right">{rate(week.verified, week.signedUp)}</Table.Td>
                    <Table.Td ta="right">{rate(week.joinedTeam, week.signedUp)}</Table.Td>
                    <Table.Td ta="right">{rate(week.joinedRide, week.signedUp)}</Table.Td>
                  </Table.Tr>
                ))}
              </Table.Tbody>
            </Table>
          </Table.ScrollContainer>
        )}
      </Stack>
    </Paper>
  )
}
