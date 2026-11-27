import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Alert,
  Group,
  Paper,
  Progress,
  Select,
  SimpleGrid,
  Skeleton,
  Stack,
  Table,
  Text,
  Title,
} from '@mantine/core'
import { AdminLayout } from '@/components/admin/AdminLayout'
import { useGetPlatformStats, useListDomains } from '@/api/endpoints/admin-domains/admin-domains'
import type { AdminKeyCountDto, AdminPlatformStatsDto } from '@/api/dto'
import { tRegister, type TranslationKey } from '@/lib/i18nUtils'
import { useFormattedDate } from '@/utils/dateFormat'
import { formatNumber, formatPercent } from '@/utils/unitFormat'
import { ADMIN_DOMAIN_FILTER_PARAMS } from './adminTeamsData'

/** Enum-ish keys with a translation; any other key is shown as the server sent it. */
const KEY_LABELS: Record<string, TranslationKey> = {
  MOBILE_APP: tRegister('admin.statsPage.clients.MOBILE_APP'),
  WEB_MOBILE: tRegister('admin.statsPage.clients.WEB_MOBILE'),
  WEB_DESKTOP: tRegister('admin.statsPage.clients.WEB_DESKTOP'),
  OAUTH: tRegister('admin.statsPage.clients.OAUTH'),
  garmin: tRegister('admin.statsPage.clients.garmin'),
  karoo: tRegister('admin.statsPage.clients.karoo'),
  ADMIN: tRegister('roles.ADMIN'),
  MEMBER: tRegister('roles.MEMBER'),
  ORGANIZER: tRegister('roles.ORGANIZER'),
  FREE: tRegister('teams.tier.FREE'),
  UNLOCKED: tRegister('teams.tier.UNLOCKED'),
}

/** Brand names, not translated, but spelled properly. */
const BRAND_LABELS: Record<string, string> = {
  GARMIN: 'Garmin',
  WAHOO: 'Wahoo',
  HAMMERHEAD: 'Hammerhead',
  ANDROID: 'Android',
  IOS: 'iOS',
  WEB: 'Web',
}

function StatCard({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <Paper withBorder p="md" radius="md">
      <Text c="dimmed" size="sm" fw={500}>
        {label}
      </Text>
      <Text size="xl" fw={700} mt={4}>
        {value}
      </Text>
      {hint && (
        <Text c="dimmed" size="xs">
          {hint}
        </Text>
      )}
    </Paper>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <Stack gap="sm">
      <Title order={2} size="h3">
        {title}
      </Title>
      {children}
    </Stack>
  )
}

function StatsContent({ stats }: { stats: AdminPlatformStatsDto }) {
  const { t, i18n } = useTranslation()
  const lang = i18n.language
  const { formatDateTime, isGuessedTimezone } = useFormattedDate()
  const num = (n: number) => formatNumber(n, lang)
  const { users, authMethods, passkeys, teams, calendarFeeds } = stats
  const pct = (n: number, total: number) =>
    total > 0 ? formatPercent((n / total) * 100, lang) : '—'
  const label = (key: string): string => {
    const i18nKey = KEY_LABELS[key]
    return i18nKey ? t(i18nKey) : (BRAND_LABELS[key] ?? key)
  }

  const keyCountTable = (rows: AdminKeyCountDto[], head: string) => (
    <Table withTableBorder>
      <Table.Thead>
        <Table.Tr>
          <Table.Th>{head}</Table.Th>
          <Table.Th ta="right">{t('admin.statsPage.count')}</Table.Th>
        </Table.Tr>
      </Table.Thead>
      <Table.Tbody>
        {rows.map((r) => (
          <Table.Tr key={r.key}>
            <Table.Td>{label(r.key)}</Table.Td>
            <Table.Td ta="right">{num(r.count)}</Table.Td>
          </Table.Tr>
        ))}
      </Table.Tbody>
    </Table>
  )

  const authRows: [string, number][] = [
    [t('admin.statsPage.auth.passwordOnly'), authMethods.passwordOnly],
    [t('admin.statsPage.auth.passkeyOnly'), authMethods.passkeyOnly],
    [t('admin.statsPage.auth.passwordAndPasskey'), authMethods.passwordAndPasskey],
    [t('admin.statsPage.auth.neither'), authMethods.neither],
  ]
  const authTotal = authRows.reduce((sum, [, n]) => sum + n, 0)
  const maxMonth = Math.max(1, ...stats.signupsByMonth.map((m) => m.count))

  return (
    <Stack gap="xl">
      <Section title={t('admin.statsPage.users.title')}>
        <SimpleGrid cols={{ base: 2, sm: 3, lg: 5 }}>
          <StatCard label={t('admin.statsPage.users.total')} value={num(users.total)} />
          <StatCard
            label={t('admin.statsPage.users.active7')}
            value={num(users.activeLast7Days)}
            hint={pct(users.activeLast7Days, users.total)}
          />
          <StatCard
            label={t('admin.statsPage.users.active30')}
            value={num(users.activeLast30Days)}
            hint={pct(users.activeLast30Days, users.total)}
          />
          <StatCard
            label={t('admin.statsPage.users.active90')}
            value={num(users.activeLast90Days)}
            hint={pct(users.activeLast90Days, users.total)}
          />
          <StatCard
            label={t('admin.statsPage.users.neverLoggedIn')}
            value={num(users.neverLoggedIn)}
            hint={pct(users.neverLoggedIn, users.total)}
          />
          <StatCard
            label={t('admin.statsPage.users.emailVerified')}
            value={num(users.emailVerified)}
            hint={pct(users.emailVerified, users.total)}
          />
          <StatCard
            label={t('admin.statsPage.users.termsAccepted')}
            value={num(users.termsAccepted)}
            hint={pct(users.termsAccepted, users.total)}
          />
          <StatCard
            label={t('admin.statsPage.users.withAvatar')}
            value={num(users.withAvatar)}
            hint={pct(users.withAvatar, users.total)}
          />
          <StatCard
            label={t('admin.statsPage.users.platformAdmins')}
            value={num(users.platformAdmins)}
          />
          <StatCard label={t('admin.statsPage.users.deleted')} value={num(users.deleted)} />
        </SimpleGrid>
      </Section>

      <Section title={t('admin.statsPage.auth.title')}>
        <Paper withBorder p="md" radius="md">
          <Stack gap="sm">
            {authRows.map(([name, n]) => (
              <div key={name}>
                <Group justify="space-between">
                  <Text size="sm">{name}</Text>
                  <Text size="sm">
                    {num(n)} · {pct(n, authTotal)}
                  </Text>
                </Group>
                <Progress value={authTotal > 0 ? (n / authTotal) * 100 : 0} />
              </div>
            ))}
          </Stack>
        </Paper>
        <SimpleGrid cols={{ base: 1, sm: 2 }}>
          <StatCard label={t('admin.statsPage.auth.passkeys')} value={num(passkeys.total)} />
          <StatCard
            label={t('admin.statsPage.auth.passkeysUsed30')}
            value={num(passkeys.usedLast30Days)}
          />
        </SimpleGrid>
      </Section>

      <Section title={t('admin.statsPage.signups.title')}>
        <Table withTableBorder>
          <Table.Thead>
            <Table.Tr>
              <Table.Th>{t('admin.statsPage.signups.month')}</Table.Th>
              <Table.Th ta="right">{t('admin.statsPage.count')}</Table.Th>
              <Table.Th w="50%" />
            </Table.Tr>
          </Table.Thead>
          <Table.Tbody>
            {stats.signupsByMonth.map((m) => (
              <Table.Tr key={m.month}>
                <Table.Td>{m.month}</Table.Td>
                <Table.Td ta="right">{num(m.count)}</Table.Td>
                <Table.Td>
                  <Progress value={(m.count / maxMonth) * 100} />
                </Table.Td>
              </Table.Tr>
            ))}
          </Table.Tbody>
        </Table>
      </Section>

      <Section title={t('admin.statsPage.teams.title')}>
        <SimpleGrid cols={{ base: 2 }}>
          <StatCard label={t('admin.statsPage.teams.active')} value={num(teams.active)} />
          <StatCard label={t('admin.statsPage.teams.deleted')} value={num(teams.deleted)} />
        </SimpleGrid>
        <SimpleGrid cols={{ base: 1, md: 3 }}>
          {keyCountTable(teams.byTier, t('admin.statsPage.teams.byTier'))}
          {keyCountTable(teams.membershipsByRole, t('admin.statsPage.teams.byRole'))}
          {keyCountTable(teams.usersByTeamCount, t('admin.statsPage.teams.usersByTeamCount'))}
        </SimpleGrid>
      </Section>

      <Section title={t('admin.statsPage.gps.title')}>
        <StatCard
          label={t('admin.statsPage.gps.usersWithService')}
          value={num(stats.usersWithGpsService)}
        />
        <Table.ScrollContainer minWidth={700}>
          <Table withTableBorder>
            <Table.Thead>
              <Table.Tr>
                <Table.Th>{t('admin.statsPage.gps.service')}</Table.Th>
                <Table.Th ta="right">{t('admin.statsPage.gps.connections')}</Table.Th>
                <Table.Th ta="right">{t('admin.statsPage.gps.users')}</Table.Th>
                <Table.Th ta="right">{t('admin.statsPage.gps.autoSync')}</Table.Th>
                <Table.Th ta="right">{t('admin.statsPage.gps.reconnectRequired')}</Table.Th>
                <Table.Th ta="right">{t('admin.statsPage.gps.usedLast30Days')}</Table.Th>
                <Table.Th ta="right">{t('admin.statsPage.gps.routeSyncs')}</Table.Th>
                <Table.Th ta="right">{t('admin.statsPage.gps.succeeded')}</Table.Th>
                <Table.Th ta="right">{t('admin.statsPage.gps.failed')}</Table.Th>
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {stats.gpsServices.map((s) => (
                <Table.Tr key={s.service}>
                  <Table.Td>{label(s.service)}</Table.Td>
                  <Table.Td ta="right">{num(s.connections)}</Table.Td>
                  <Table.Td ta="right">{num(s.users)}</Table.Td>
                  <Table.Td ta="right">{num(s.autoSync)}</Table.Td>
                  <Table.Td ta="right">{num(s.reconnectRequired)}</Table.Td>
                  <Table.Td ta="right">{num(s.usedLast30Days)}</Table.Td>
                  <Table.Td ta="right">{num(s.routeSyncs)}</Table.Td>
                  <Table.Td ta="right">{num(s.routeSyncsSucceeded)}</Table.Td>
                  <Table.Td ta="right">{num(s.routeSyncsFailed)}</Table.Td>
                </Table.Tr>
              ))}
            </Table.Tbody>
          </Table>
        </Table.ScrollContainer>
      </Section>

      <SimpleGrid cols={{ base: 1, md: 2 }}>
        <Section title={t('admin.statsPage.clients.title')}>
          {keyCountTable(stats.clientsLast30Days, t('admin.statsPage.clients.client'))}
          <Text size="xs" c="dimmed">
            {t('admin.statsPage.clients.note')}
          </Text>
        </Section>
        <Section title={t('admin.statsPage.push.title')}>
          <Table withTableBorder>
            <Table.Thead>
              <Table.Tr>
                <Table.Th>{t('admin.statsPage.push.platform')}</Table.Th>
                <Table.Th ta="right">{t('admin.statsPage.push.devices')}</Table.Th>
                <Table.Th ta="right">{t('admin.statsPage.push.users')}</Table.Th>
                <Table.Th ta="right">{t('admin.statsPage.push.seenLast7Days')}</Table.Th>
              </Table.Tr>
            </Table.Thead>
            <Table.Tbody>
              {stats.pushDevices.map((p) => (
                <Table.Tr key={p.platform}>
                  <Table.Td>{label(p.platform)}</Table.Td>
                  <Table.Td ta="right">{num(p.devices)}</Table.Td>
                  <Table.Td ta="right">{num(p.users)}</Table.Td>
                  <Table.Td ta="right">{num(p.seenLast7Days)}</Table.Td>
                </Table.Tr>
              ))}
            </Table.Tbody>
          </Table>
        </Section>
      </SimpleGrid>

      <Section title={t('admin.statsPage.calendar.title')}>
        <SimpleGrid cols={{ base: 1, sm: 3 }}>
          <StatCard
            label={t('admin.statsPage.calendar.tokens')}
            value={num(calendarFeeds.tokens)}
          />
          <StatCard
            label={t('admin.statsPage.calendar.usedEver')}
            value={num(calendarFeeds.usedEver)}
          />
          <StatCard
            label={t('admin.statsPage.calendar.usedLast7Days')}
            value={num(calendarFeeds.usedLast7Days)}
          />
        </SimpleGrid>
      </Section>

      <Text size="xs" c="dimmed" suppressHydrationWarning={isGuessedTimezone}>
        {t('admin.statsPage.generatedAt', {
          date: formatDateTime(stats.generatedAt),
        })}
      </Text>
    </Stack>
  )
}

/**
 * Platform usage statistics, for all domains or one: counts only, no person is named.
 * Counterpart of `adminStatsData.ts` (prefetch with the same default params).
 */
export function AdminStatsPage() {
  const { t } = useTranslation()
  const [domainId, setDomainId] = useState<string | null>(null)

  const { data: domainsData } = useListDomains(ADMIN_DOMAIN_FILTER_PARAMS)
  const domainOptions = domainsData?.domains.map((d) => ({ value: d.id, label: d.name })) ?? []

  // No `domainId` key at all for « all domains »: the same query key as the prefetch.
  const {
    data: stats,
    isLoading,
    isError,
  } = useGetPlatformStats(domainId ? { domainId } : undefined)

  return (
    <AdminLayout currentTab="stats" subtitle={t('admin.statsPage.subtitle')}>
      <Stack mt="lg" gap="lg">
        <Select
          label={t('admin.statsPage.domain')}
          placeholder={t('admin.statsPage.allDomains')}
          data={domainOptions}
          value={domainId}
          onChange={setDomainId}
          clearable
          maw={320}
        />
        {isError ? (
          <Alert color="red">{t('admin.statsPage.error')}</Alert>
        ) : isLoading || !stats ? (
          <Stack data-testid="stats-skeleton">
            <Skeleton height={90} />
            <Skeleton height={160} />
            <Skeleton height={160} />
          </Stack>
        ) : (
          <StatsContent stats={stats} />
        )}
      </Stack>
    </AdminLayout>
  )
}
