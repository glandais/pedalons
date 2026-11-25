import { useTranslation } from 'react-i18next'
import { Stack, Title, Text, Button, Group, Badge, Loader } from '@mantine/core'
import { IconDatabaseExport } from '@tabler/icons-react'
import { useDataExport } from '@/hooks/useDataExport'
import { useFormattedDate } from '@/utils/dateFormat'
import { UserExportStatus } from '@/api/dto'

/**
 * "Download my data" — requests a GDPR export and reports its progress.
 *
 * There is no download button: the archive is delivered by an emailed link, so possession of the
 * mailbox is part of the identity check.
 */
export function DataExportManager() {
  const { t } = useTranslation()
  const { formatDateTime, isGuessedTimezone } = useFormattedDate()
  const { latestExport, isLoading, requestExport, isRequesting, isExporting } = useDataExport()

  const status = latestExport?.status

  return (
    <Stack>
      <Group justify="space-between">
        <Title order={2} size="h5">
          {t('profile.dataExport.title')}
        </Title>
        {isExporting && (
          <Badge color="blue" variant="light" leftSection={<Loader size={10} color="blue" />}>
            {t('profile.dataExport.inProgress')}
          </Badge>
        )}
      </Group>

      <Text size="sm" c="dimmed">
        {t('profile.dataExport.description')}
      </Text>

      {!isLoading && status === UserExportStatus.READY && latestExport?.expiresAt && (
        <Text size="sm" suppressHydrationWarning={isGuessedTimezone}>
          {t('profile.dataExport.ready', {
            date: formatDateTime(latestExport.expiresAt),
          })}
        </Text>
      )}

      {!isLoading && status === UserExportStatus.EXPIRED && (
        <Text size="sm" c="dimmed">
          {t('profile.dataExport.expired')}
        </Text>
      )}

      {!isLoading && status === UserExportStatus.FAILED && (
        <Text size="sm" c="danger">
          {t('profile.dataExport.failed')}
        </Text>
      )}

      <Group>
        <Button
          variant="outline"
          leftSection={<IconDatabaseExport size={16} />}
          onClick={() => requestExport()}
          loading={isRequesting}
          disabled={isExporting}
        >
          {t('profile.dataExport.requestButton')}
        </Button>
      </Group>
    </Stack>
  )
}
