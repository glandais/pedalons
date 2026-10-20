import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Paper,
  Stack,
  Group,
  Title,
  Text,
  Button,
  NumberInput,
  SegmentedControl,
  Table,
  Alert,
} from '@mantine/core'
import { IconMountain, IconEye, IconPlayerPlay } from '@tabler/icons-react'
import { useAdminRetryElevationRefresh } from '@/api/endpoints/admin-elevation/admin-elevation'
import {
  ElevationRefreshKind,
  type ElevationRefreshRetryItem,
  type ElevationRefreshRetryRequest,
  type ElevationRefreshRetryResponse,
} from '@/api/dto'
import { ConfirmDialog } from '@/components/common/ConfirmDialog'
import { FormattedDateTime } from '@/components/common/FormattedDate'

interface ElevationRetryCardProps {
  /** Null leaves `domainId` out: the request's own domain. */
  domainId: string | null
}

type Criteria = Omit<ElevationRefreshRetryRequest, 'dryRun'>

const ALL_KINDS = 'ALL'

/**
 * `POST /admin/elevation-refresh/retry`: list the HD elevation recomputations that used up their
 * attempts, then start them again. The run stays disabled until a preview was made with the
 * criteria as they stand.
 */
export function ElevationRetryCard({ domainId }: ElevationRetryCardProps) {
  const { t } = useTranslation()
  const mutation = useAdminRetryElevationRefresh()

  const [kind, setKind] = useState<ElevationRefreshKind | typeof ALL_KINDS>(ALL_KINDS)
  const [limit, setLimit] = useState<number | undefined>(100)

  const [result, setResult] = useState<ElevationRefreshRetryResponse | null>(null)
  const [previewedKey, setPreviewedKey] = useState<string | null>(null)
  const [confirmOpen, setConfirmOpen] = useState(false)

  const criteria: Criteria = { kind: kind === ALL_KINDS ? undefined : kind, limit }
  const criteriaKey = JSON.stringify(criteria)
  const canRun = previewedKey === criteriaKey && !!result?.dryRun && result.items.length > 0

  const submit = (dryRun: boolean) => {
    mutation.mutate(
      { data: { ...criteria, dryRun }, params: domainId ? { domainId } : undefined },
      {
        onSuccess: (response) => {
          setResult(response)
          setPreviewedKey(dryRun ? criteriaKey : null)
          setConfirmOpen(false)
        },
      }
    )
  }

  const targetLabel = (item: ElevationRefreshRetryItem) =>
    item.kind === ElevationRefreshKind.ROUTE
      ? `${item.teamSlug ?? ''} / ${item.routeSlug ?? item.targetId}`
      : (item.previewPublicId ?? item.targetId)

  return (
    <Paper withBorder p="lg" radius="md">
      <Stack>
        <Group gap="xs">
          <IconMountain size={20} />
          <Title order={4}>{t('admin.maintenance.elevation.title')}</Title>
        </Group>
        <Text size="sm" c="dimmed">
          {t('admin.maintenance.elevation.description')}
        </Text>

        <Group grow align="flex-end">
          <Stack gap={4}>
            <Text size="sm" fw={500}>
              {t('admin.maintenance.elevation.kind')}
            </Text>
            <SegmentedControl
              value={kind}
              onChange={(value) => setKind(value as ElevationRefreshKind | typeof ALL_KINDS)}
              data={[
                { value: ALL_KINDS, label: t('admin.maintenance.elevation.kinds.ALL') },
                {
                  value: ElevationRefreshKind.ROUTE,
                  label: t('admin.maintenance.elevation.kinds.ROUTE'),
                },
                {
                  value: ElevationRefreshKind.PREVIEW,
                  label: t('admin.maintenance.elevation.kinds.PREVIEW'),
                },
              ]}
            />
          </Stack>
          <NumberInput
            label={t('admin.maintenance.limit')}
            description={t('admin.maintenance.limitDescription')}
            value={limit ?? ''}
            onChange={(v) => setLimit(typeof v === 'number' ? v : undefined)}
            min={1}
            max={1000}
            allowDecimal={false}
          />
        </Group>

        <Group>
          <Button
            variant="default"
            leftSection={<IconEye size={16} />}
            onClick={() => submit(true)}
            loading={mutation.isPending && !confirmOpen}
          >
            {t('admin.maintenance.preview')}
          </Button>
          <Button
            leftSection={<IconPlayerPlay size={16} />}
            onClick={() => setConfirmOpen(true)}
            disabled={!canRun}
          >
            {t('admin.maintenance.run')}
          </Button>
        </Group>

        {result && (
          <Stack gap="xs">
            <Alert color={result.dryRun ? 'blue' : 'green'}>
              {result.dryRun
                ? t('admin.maintenance.previewSummary', {
                    matched: result.matched,
                    listed: result.items.length,
                  })
                : t('admin.maintenance.runSummary', {
                    matched: result.matched,
                    listed: result.items.length,
                  })}
            </Alert>
            {result.items.length > 0 && (
              <Table.ScrollContainer minWidth={700}>
                <Table striped>
                  <Table.Thead>
                    <Table.Tr>
                      <Table.Th>{t('admin.maintenance.elevation.target')}</Table.Th>
                      <Table.Th>{t('admin.maintenance.elevation.attempts')}</Table.Th>
                      <Table.Th>{t('admin.maintenance.elevation.firstRequestedAt')}</Table.Th>
                      <Table.Th>{t('admin.maintenance.elevation.lastError')}</Table.Th>
                    </Table.Tr>
                  </Table.Thead>
                  <Table.Tbody>
                    {result.items.map((item) => (
                      <Table.Tr key={`${item.kind}-${item.targetId}`}>
                        <Table.Td>
                          <Text size="sm">
                            {t(`admin.maintenance.elevation.kinds.${item.kind}`)}
                          </Text>
                          <Text size="xs" c="dimmed">
                            {targetLabel(item)}
                          </Text>
                        </Table.Td>
                        <Table.Td>
                          <Text size="sm">{item.attempts}</Text>
                        </Table.Td>
                        <Table.Td>
                          <Text size="sm">
                            <FormattedDateTime date={item.firstRequestedAt} />
                          </Text>
                        </Table.Td>
                        <Table.Td>
                          <Text size="xs" c="dimmed">
                            {item.lastError}
                          </Text>
                        </Table.Td>
                      </Table.Tr>
                    ))}
                  </Table.Tbody>
                </Table>
              </Table.ScrollContainer>
            )}
          </Stack>
        )}
      </Stack>

      <ConfirmDialog
        isOpen={confirmOpen}
        onClose={() => setConfirmOpen(false)}
        onConfirm={() => submit(false)}
        title={t('admin.maintenance.elevation.confirmTitle')}
        message={t('admin.maintenance.elevation.confirmMessage', {
          listed: result?.items.length ?? 0,
        })}
        confirmText={t('admin.maintenance.run')}
        isLoading={mutation.isPending}
      />
    </Paper>
  )
}
