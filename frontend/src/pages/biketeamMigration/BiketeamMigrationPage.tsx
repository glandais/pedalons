import { useEffect, useState, type ReactNode } from 'react'
import { useLocation, useNavigate, useSearchParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  Alert,
  Anchor,
  Badge,
  Button,
  Center,
  Divider,
  Group,
  List,
  Loader,
  Paper,
  SimpleGrid,
  Stack,
  Text,
  ThemeIcon,
  Title,
} from '@mantine/core'
import {
  IconAlertTriangle,
  IconBike,
  IconCalendar,
  IconCheck,
  IconFileText,
  IconFlask,
  IconInfoCircle,
  IconLogin,
  IconMapPin,
  IconNews,
  IconPhoto,
  IconRoute,
  IconTemplate,
  IconTransfer,
  IconX,
} from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { paths } from '@/config/paths'
import { useAuthStore } from '@/store/authStore'
import { useFormattedDate } from '@/utils/dateFormat'
import type { ErrorCode } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'
import {
  confirmBiketeamMigration,
  previewBiketeamMigration,
  type BiketeamMigrationPreviewDto,
  type BiketeamMigrationSummaryDto,
} from './biketeamMigrationApi'
import {
  clearStoredRequestToken,
  leaveForBiketeam,
  readStoredRequestToken,
  storeRequestToken,
} from './biketeamMigrationRequest'

/**
 * Where biketeam sends a team admin who asked to move their team to Pédalons.
 *
 * The signed request travels in `?request=`. It is not a credential: the preview is public, so a
 * signed-out visitor is told what is being moved before being asked to sign in, and only the
 * confirmation — which needs a session — mints the single-use grant biketeam redeems. The request
 * is kept in sessionStorage across the login or sign-up detour, and the preview is asked again
 * whenever the session changes, since whether the visitor may confirm depends on who they are.
 *
 * See docs/plans/2026-09-22-biketeam-live-migration.md §4 and §12.2.
 */

/** The request is dead for good: going back to biketeam to start again is the only way on. */
const TERMINAL_CODES = new Set<ErrorCode>(['BIKETEAM_REQUEST_INVALID', 'BIKETEAM_REQUEST_EXPIRED'])

type Phase = 'loading' | 'ready' | 'failed' | 'redirecting'

function errorCodeOf(error: unknown): ErrorCode | null {
  return error instanceof ApiClientError ? error.error.code : null
}

export function BiketeamMigrationPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const location = useLocation()
  const [searchParams] = useSearchParams()
  const isInitialized = useAuthStore((state) => state.isInitialized)
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated)
  const user = useAuthStore((state) => state.user)
  const logout = useAuthStore((state) => state.logout)

  const queryToken = searchParams.get('request')?.trim() || null

  // undefined while not yet resolved: sessionStorage only exists in the browser, so the server
  // render and the first client render both show the loader.
  const [requestToken, setRequestToken] = useState<string | null | undefined>(undefined)
  const [phase, setPhase] = useState<Phase>('loading')
  const [preview, setPreview] = useState<BiketeamMigrationPreviewDto | null>(null)
  const [failureCode, setFailureCode] = useState<ErrorCode | null>(null)
  const [confirmErrorCode, setConfirmErrorCode] = useState<ErrorCode | 'unknown' | null>(null)
  const [isConfirming, setIsConfirming] = useState(false)
  const [reloadKey, setReloadKey] = useState(0)

  useEffect(() => {
    if (queryToken) {
      storeRequestToken(queryToken)
      setRequestToken(queryToken)
    } else {
      setRequestToken(readStoredRequestToken())
    }
  }, [queryToken])

  const userId = user?.id ?? null

  useEffect(() => {
    if (requestToken === undefined) {
      return
    }
    if (requestToken === null) {
      setFailureCode(null)
      setPhase('failed')
      return
    }
    // Waiting for the session keeps a signed-in visitor from being told to sign in first.
    if (!isInitialized) {
      return
    }
    let cancelled = false
    previewBiketeamMigration({ requestToken })
      .then((data) => {
        if (cancelled) return
        setPreview(data)
        setPhase('ready')
      })
      .catch((error: unknown) => {
        if (cancelled) return
        const code = errorCodeOf(error)
        if (code && TERMINAL_CODES.has(code)) {
          clearStoredRequestToken()
        }
        setFailureCode(code)
        setPhase('failed')
      })
    return () => {
      cancelled = true
    }
    // isAuthenticated and userId are not read here: they are what makes the preview stale.
  }, [requestToken, isInitialized, isAuthenticated, userId, reloadKey])

  const handleConfirm = () => {
    if (!requestToken) return
    setIsConfirming(true)
    setConfirmErrorCode(null)
    confirmBiketeamMigration({ requestToken })
      .then((result) => {
        clearStoredRequestToken()
        setPhase('redirecting')
        leaveForBiketeam(result.redirectUrl)
      })
      .catch((error: unknown) => {
        const code = errorCodeOf(error)
        if (code && TERMINAL_CODES.has(code)) {
          clearStoredRequestToken()
          setFailureCode(code)
          setPhase('failed')
          return
        }
        // A conflict, a lost session: the preview says what stands in the way now.
        setConfirmErrorCode(code ?? 'unknown')
        setReloadKey((key) => key + 1)
      })
      .finally(() => setIsConfirming(false))
  }

  const handleCancel = (url: string) => {
    clearStoredRequestToken()
    setPhase('redirecting')
    leaveForBiketeam(url)
  }

  // Whoever is signed in cannot confirm (or is not who should own the team): signing out and
  // coming back to this very URL is the way through.
  const handleSwitchAccount = async () => {
    await logout()
    navigate(`${location.pathname}${location.search}`, { replace: true })
  }

  if (phase === 'loading' || phase === 'redirecting') {
    return (
      <Center mih="60vh">
        <Stack align="center" gap="sm">
          <Loader />
          {phase === 'redirecting' && <Text c="dimmed">{t('biketeamMigration.redirecting')}</Text>}
        </Stack>
      </Center>
    )
  }

  if (phase === 'failed' || !preview) {
    return (
      <Center mih="60vh">
        <Paper p="xl" withBorder maw={520} w="100%">
          <Stack align="center">
            <IconX size={40} color="var(--mantine-color-danger-6)" />
            <Title order={3} ta="center">
              {t('biketeamMigration.unavailable.title')}
            </Title>
            <Text c="dimmed" ta="center">
              {failureCode
                ? t(`errors.api.${failureCode}`)
                : t('biketeamMigration.unavailable.missing')}
            </Text>
            {failureCode && (
              <Text size="sm" c="dimmed" ta="center">
                {t('biketeamMigration.unavailable.restart')}
              </Text>
            )}
            <Button component={PrefetchLink} to={paths.home()} variant="default">
              {t('biketeamMigration.backHome')}
            </Button>
          </Stack>
        </Paper>
      </Center>
    )
  }

  const site = preview.targetDomainName
  const blockParams = {
    team: preview.existingTeamName ?? preview.teamName,
    site,
    slug: preview.targetTeamSlug,
  }

  return (
    <Center py="xl">
      <Paper p={{ base: 'md', sm: 'xl' }} withBorder maw={640} w="100%">
        <Stack gap="lg">
          <Stack gap={4} align="center" ta="center">
            <ThemeIcon size={48} radius="xl" variant="light">
              <IconTransfer size={28} />
            </ThemeIcon>
            <Title order={2}>
              {t('biketeamMigration.title', { team: preview.teamName, site })}
            </Title>
            <Text c="dimmed">
              {t('biketeamMigration.requestedBy', { name: preview.requestedBy })}
            </Text>
            <ExpiresAt date={preview.expiresAt} />
          </Stack>

          <ModeNotice dryRun={preview.dryRun} site={site} />

          {preview.reset && (
            <Alert
              color="orange"
              icon={<IconAlertTriangle size={18} />}
              title={t('biketeamMigration.reset.title')}
            >
              {preview.targetState === 'EXISTING_MIGRATED' && preview.existingTeamName
                ? t('biketeamMigration.reset.existing', { team: preview.existingTeamName })
                : preview.trashedTeamSetAside
                  ? t('biketeamMigration.trashed.setAside', {
                      team: preview.trashedTeamSetAside,
                      site,
                    })
                  : t('biketeamMigration.reset.none', { site })}
            </Alert>
          )}

          {!preview.reset && preview.trashedTeamSetAside && (
            <Alert color="blue" icon={<IconInfoCircle size={18} />}>
              {t('biketeamMigration.trashed.setAside', {
                team: preview.trashedTeamSetAside,
                site,
              })}
            </Alert>
          )}

          {!preview.reset &&
            preview.targetState === 'EXISTING_MIGRATED' &&
            preview.existingTeamName && (
              <Alert color="blue" icon={<IconInfoCircle size={18} />}>
                {t('biketeamMigration.existing.update', { team: preview.existingTeamName, site })}
              </Alert>
            )}

          <Section title={t('biketeamMigration.target.title')}>
            <SimpleGrid cols={{ base: 1, xs: 2 }} spacing="xs">
              <LabelValue label={t('biketeamMigration.target.site')} value={site} />
              <LabelValue
                label={t('biketeamMigration.target.address')}
                value={paths.team(preview.targetTeamSlug)}
              />
            </SimpleGrid>
          </Section>

          <Section title={t('biketeamMigration.imported.title')}>
            <ImportedSummary summary={preview.summary} />
          </Section>

          <Section title={t('biketeamMigration.notImported.title')}>
            <List
              size="sm"
              spacing={4}
              icon={<IconX size={14} color="var(--mantine-color-dimmed)" />}
            >
              <List.Item>{t('biketeamMigration.notImported.members')}</List.Item>
              <List.Item>{t('biketeamMigration.notImported.participations')}</List.Item>
              <List.Item>{t('biketeamMigration.notImported.comments')}</List.Item>
              <List.Item>{t('biketeamMigration.notImported.routeRatings')}</List.Item>
            </List>
            <Text size="sm" c="dimmed">
              {t('biketeamMigration.notImported.body')}
            </Text>
          </Section>

          <Divider />

          {confirmErrorCode && (
            <Alert color="red" icon={<IconX size={18} />}>
              {t(`errors.api.${confirmErrorCode}`)}
            </Alert>
          )}

          {preview.blockReason === 'LOGIN_REQUIRED' && (
            <Stack gap="xs" align="center">
              <Text size="sm" ta="center">
                {t('biketeamMigration.block.LOGIN_REQUIRED', blockParams)}
              </Text>
              <Button
                component={PrefetchLink}
                to={paths.login()}
                state={{ from: location }}
                leftSection={<IconLogin size={16} />}
              >
                {t('biketeamMigration.signIn')}
              </Button>
            </Stack>
          )}

          {preview.blockReason && preview.blockReason !== 'LOGIN_REQUIRED' && (
            <Alert color="orange" icon={<IconAlertTriangle size={18} />}>
              {t(
                `biketeamMigration.block.${
                  preview.blockReason satisfies
                    | 'SLUG_CONFLICT'
                    | 'MIGRATED_IN_OTHER_DOMAIN'
                    | 'REQUEST_ALREADY_USED'
                    | 'MIGRATION_RUNNING'
                    | 'NOT_TEAM_ADMIN'
                    | 'RESET_BLOCKED'
                }`,
                blockParams
              )}
            </Alert>
          )}

          {isAuthenticated && user && (
            <Text size="sm" c="dimmed" ta="center">
              {t('biketeamMigration.signedInAs', { name: user.displayName, email: user.email })}{' '}
              <Anchor component="button" type="button" size="sm" onClick={handleSwitchAccount}>
                {t('biketeamMigration.switchAccount')}
              </Anchor>
            </Text>
          )}

          <Group justify="flex-end" gap="sm">
            <Button variant="default" onClick={() => handleCancel(preview.cancelUrl)}>
              {preview.confirmable
                ? t('biketeamMigration.cancel')
                : t('biketeamMigration.backToBiketeam')}
            </Button>
            {preview.confirmable && (
              <Button
                onClick={handleConfirm}
                loading={isConfirming}
                leftSection={<IconCheck size={16} />}
              >
                {t('biketeamMigration.confirm')}
              </Button>
            )}
          </Group>
        </Stack>
      </Paper>
    </Center>
  )
}

function ExpiresAt({ date }: { date: string }) {
  const { t } = useTranslation()
  const { formatDateTime } = useFormattedDate()
  return (
    <Text size="sm" c="dimmed" suppressHydrationWarning>
      {t('biketeamMigration.expiresAt', { date: formatDateTime(date) })}
    </Text>
  )
}

function ModeNotice({ dryRun, site }: { dryRun: boolean; site: string }) {
  const { t } = useTranslation()
  return (
    <Alert
      color={dryRun ? 'blue' : 'orange'}
      icon={dryRun ? <IconFlask size={18} /> : <IconAlertTriangle size={18} />}
      title={
        <Group gap="xs">
          <Text fw={600} size="sm">
            {t('biketeamMigration.mode.title')}
          </Text>
          <Badge color={dryRun ? 'blue' : 'orange'} variant="light">
            {dryRun ? t('biketeamMigration.mode.dryRun') : t('biketeamMigration.mode.final')}
          </Badge>
        </Group>
      }
    >
      {dryRun
        ? t('biketeamMigration.mode.dryRunBody', { site })
        : t('biketeamMigration.mode.finalBody', { site })}
    </Alert>
  )
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <Stack gap="xs">
      <Title order={4}>{title}</Title>
      {children}
    </Stack>
  )
}

function LabelValue({ label, value }: { label: string; value: string }) {
  return (
    <Stack gap={0}>
      <Text size="xs" c="dimmed">
        {label}
      </Text>
      <Text size="sm" fw={500} style={{ overflowWrap: 'anywhere' }}>
        {value}
      </Text>
    </Stack>
  )
}

function SummaryItem({ icon, label, muted }: { icon: ReactNode; label: string; muted: boolean }) {
  return (
    <Group gap="xs" wrap="nowrap">
      <ThemeIcon size="sm" variant="light" color={muted ? 'gray' : undefined}>
        {icon}
      </ThemeIcon>
      <Text size="sm" c={muted ? 'dimmed' : undefined}>
        {label}
      </Text>
    </Group>
  )
}

function ImportedSummary({ summary }: { summary: BiketeamMigrationSummaryDto }) {
  const { t } = useTranslation()
  const counted = [
    {
      key: 'rides',
      icon: <IconBike size={14} />,
      label: t('biketeamMigration.imported.rides', { count: summary.rides }),
      count: summary.rides,
    },
    {
      key: 'rideTemplates',
      icon: <IconTemplate size={14} />,
      label: t('biketeamMigration.imported.rideTemplates', { count: summary.rideTemplates }),
      count: summary.rideTemplates,
    },
    {
      key: 'routes',
      icon: <IconRoute size={14} />,
      label: t('biketeamMigration.imported.routes', { count: summary.routes }),
      count: summary.routes,
    },
    {
      key: 'trips',
      icon: <IconCalendar size={14} />,
      label: t('biketeamMigration.imported.trips', {
        count: summary.trips,
        stages: t('biketeamMigration.imported.tripStages', { count: summary.tripStages }),
      }),
      count: summary.trips,
    },
    {
      key: 'publications',
      icon: <IconNews size={14} />,
      label: t('biketeamMigration.imported.publications', { count: summary.publications }),
      count: summary.publications,
    },
    {
      key: 'places',
      icon: <IconMapPin size={14} />,
      label: t('biketeamMigration.imported.places', { count: summary.places }),
      count: summary.places,
    },
  ]
  return (
    <Stack gap="xs">
      <SimpleGrid cols={{ base: 1, xs: 2 }} spacing="xs">
        {counted.map((item) => (
          <SummaryItem
            key={item.key}
            icon={item.icon}
            label={item.label}
            muted={item.count === 0}
          />
        ))}
        <SummaryItem
          icon={<IconFileText size={14} />}
          label={
            summary.faqPage
              ? t('biketeamMigration.imported.pagesWithFaq')
              : t('biketeamMigration.imported.pages')
          }
          muted={false}
        />
        <SummaryItem
          icon={<IconPhoto size={14} />}
          label={
            summary.logo
              ? t('biketeamMigration.imported.logo')
              : t('biketeamMigration.imported.noLogo')
          }
          muted={!summary.logo}
        />
      </SimpleGrid>
      <Text size="xs" c="dimmed">
        {t('biketeamMigration.imported.note')}
      </Text>
    </Stack>
  )
}
