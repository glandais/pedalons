import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Paper,
  Stack,
  Group,
  Title,
  Text,
  Button,
  Checkbox,
  NumberInput,
  Table,
  Badge,
  Alert,
} from '@mantine/core'
import { DateTimePicker } from '@mantine/dates'
import { IconPhoto, IconEye, IconPlayerPlay } from '@tabler/icons-react'
import dayjs from 'dayjs'
import { useAdminRegenerateThumbnails } from '@/api/endpoints/admin-thumbnails/admin-thumbnails'
import type {
  ThumbnailFile,
  ThumbnailRegenerationRequest,
  ThumbnailRegenerationResponse,
} from '@/api/dto'
import { ConfirmDialog } from '@/components/common/ConfirmDialog'

interface ThumbnailRegenerationCardProps {
  /** Null leaves `domainId` out: the request's own domain. */
  domainId: string | null
}

type Criteria = Omit<ThumbnailRegenerationRequest, 'dryRun'>

const OUTCOME_COLORS = { PENDING: 'gray', REGENERATED: 'green', FAILED: 'red' } as const

/**
 * `POST /admin/thumbnails/regenerate`: preview what the criteria select, then redraw exactly that.
 * The run stays disabled until a preview was made with the criteria as they stand.
 */
export function ThumbnailRegenerationCard({ domainId }: ThumbnailRegenerationCardProps) {
  const { t } = useTranslation()
  const mutation = useAdminRegenerateThumbnails()

  // Mantine hands back the picked local time as `YYYY-MM-DD HH:mm:ss`; the API wants an instant.
  const [renderedFrom, setRenderedFrom] = useState<string | null>(null)
  const [renderedTo, setRenderedTo] = useState<string | null>(null)
  const [suspectBelowBytes, setSuspectBelowBytes] = useState<number | undefined>(undefined)
  const [includeMissing, setIncludeMissing] = useState(false)
  const [limit, setLimit] = useState<number | undefined>(100)

  const [result, setResult] = useState<ThumbnailRegenerationResponse | null>(null)
  const [previewedKey, setPreviewedKey] = useState<string | null>(null)
  const [confirmOpen, setConfirmOpen] = useState(false)

  const criteria: Criteria = {
    renderedFrom: renderedFrom ? dayjs(renderedFrom).toISOString() : undefined,
    renderedTo: renderedTo ? dayjs(renderedTo).toISOString() : undefined,
    suspectBelowBytes,
    includeMissing: includeMissing || undefined,
    limit,
  }
  const criteriaKey = JSON.stringify(criteria)
  const hasCriterion =
    !!criteria.renderedFrom ||
    !!criteria.renderedTo ||
    criteria.suspectBelowBytes !== undefined ||
    includeMissing
  const canRun = previewedKey === criteriaKey && !!result?.dryRun && result.entities.length > 0

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

  const formatFiles = (files: ThumbnailFile[] | undefined) =>
    files
      ?.map((f) =>
        f.bytes < 0
          ? t('admin.maintenance.thumbnails.fileMissing', { type: f.type })
          : t('admin.maintenance.thumbnails.fileSize', {
              type: f.type,
              kb: Math.ceil(f.bytes / 1024),
            })
      )
      .join(' · ') ?? ''

  return (
    <Paper withBorder p="lg" radius="md">
      <Stack>
        <Group gap="xs">
          <IconPhoto size={20} />
          <Title order={4}>{t('admin.maintenance.thumbnails.title')}</Title>
        </Group>
        <Text size="sm" c="dimmed">
          {t('admin.maintenance.thumbnails.description')}
        </Text>

        <Group grow align="flex-start">
          <DateTimePicker
            label={t('admin.maintenance.thumbnails.renderedFrom')}
            value={renderedFrom}
            onChange={setRenderedFrom}
            clearable
          />
          <DateTimePicker
            label={t('admin.maintenance.thumbnails.renderedTo')}
            value={renderedTo}
            onChange={setRenderedTo}
            clearable
          />
        </Group>
        <Group grow align="flex-start">
          <NumberInput
            label={t('admin.maintenance.thumbnails.suspectBelowBytes')}
            description={t('admin.maintenance.thumbnails.suspectBelowBytesDescription')}
            value={suspectBelowBytes ?? ''}
            onChange={(v) => setSuspectBelowBytes(typeof v === 'number' ? v : undefined)}
            min={1}
            allowDecimal={false}
          />
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
        <Checkbox
          label={t('admin.maintenance.thumbnails.includeMissing')}
          description={t('admin.maintenance.thumbnails.includeMissingDescription')}
          checked={includeMissing}
          onChange={(e) => setIncludeMissing(e.currentTarget.checked)}
        />

        {!hasCriterion && (
          <Text size="sm" c="dimmed">
            {t('admin.maintenance.thumbnails.criterionRequired')}
          </Text>
        )}

        <Group>
          <Button
            variant="default"
            leftSection={<IconEye size={16} />}
            onClick={() => submit(true)}
            disabled={!hasCriterion}
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
                    listed: result.entities.length,
                  })
                : t('admin.maintenance.runSummary', {
                    matched: result.matched,
                    listed: result.entities.length,
                  })}
            </Alert>
            {result.entities.length > 0 && (
              <Table.ScrollContainer minWidth={700}>
                <Table striped>
                  <Table.Thead>
                    <Table.Tr>
                      <Table.Th>{t('admin.maintenance.thumbnails.entity')}</Table.Th>
                      <Table.Th>{t('admin.maintenance.thumbnails.reasons')}</Table.Th>
                      <Table.Th>{t('admin.maintenance.thumbnails.before')}</Table.Th>
                      {!result.dryRun && (
                        <Table.Th>{t('admin.maintenance.thumbnails.after')}</Table.Th>
                      )}
                      <Table.Th>{t('admin.maintenance.thumbnails.outcome')}</Table.Th>
                    </Table.Tr>
                  </Table.Thead>
                  <Table.Tbody>
                    {result.entities.map((entity) => (
                      <Table.Tr key={`${entity.kind}-${entity.id}`}>
                        <Table.Td>
                          <Text size="sm">
                            {t(`admin.maintenance.thumbnails.kind.${entity.kind}`)}
                          </Text>
                          <Text size="xs" c="dimmed">
                            {entity.teamSlug} / {entity.slug}
                          </Text>
                        </Table.Td>
                        <Table.Td>
                          <Group gap={4}>
                            {entity.reasons.map((reason) => (
                              <Badge key={reason} variant="light" size="sm">
                                {t(`admin.maintenance.thumbnails.reason.${reason}`)}
                              </Badge>
                            ))}
                          </Group>
                        </Table.Td>
                        <Table.Td>
                          <Text size="xs">{formatFiles(entity.before)}</Text>
                        </Table.Td>
                        {!result.dryRun && (
                          <Table.Td>
                            <Text size="xs">{formatFiles(entity.after)}</Text>
                          </Table.Td>
                        )}
                        <Table.Td>
                          <Badge color={OUTCOME_COLORS[entity.outcome]} variant="light" size="sm">
                            {t(`admin.maintenance.thumbnails.outcomes.${entity.outcome}`)}
                          </Badge>
                          {entity.error && (
                            <Text size="xs" c="red">
                              {entity.error}
                            </Text>
                          )}
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
        title={t('admin.maintenance.thumbnails.confirmTitle')}
        message={t('admin.maintenance.thumbnails.confirmMessage', {
          listed: result?.entities.length ?? 0,
        })}
        confirmText={t('admin.maintenance.run')}
        isLoading={mutation.isPending}
      />
    </Paper>
  )
}
