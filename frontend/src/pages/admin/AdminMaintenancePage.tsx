import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Stack, Select, Text } from '@mantine/core'
import { AdminLayout } from '@/components/admin/AdminLayout'
import { ThumbnailRegenerationCard } from '@/components/admin/ThumbnailRegenerationCard'
import { ElevationRetryCard } from '@/components/admin/ElevationRetryCard'
import { useListDomains } from '@/api/endpoints/admin-domains/admin-domains'
import { ADMIN_DOMAIN_FILTER_PARAMS } from './adminTeamsData'

/**
 * The platform's catch-up actions, each over one domain: redraw map thumbnails, retry the HD
 * elevation recomputations that used up their attempts. Both run a dry run first.
 */
export function AdminMaintenancePage() {
  const { t } = useTranslation()
  // Null leaves `domainId` out: the backend then acts on the request's own domain.
  const [domainId, setDomainId] = useState<string | null>(null)

  const { data: domainsData } = useListDomains(ADMIN_DOMAIN_FILTER_PARAMS)
  const domainOptions = domainsData?.domains.map((d) => ({ value: d.id, label: d.name })) ?? []

  return (
    <AdminLayout currentTab="maintenance">
      <Stack mt="lg">
        <Select
          label={t('admin.maintenance.domain')}
          description={t('admin.maintenance.domainDescription')}
          placeholder={t('admin.maintenance.currentDomain')}
          data={domainOptions}
          value={domainId}
          onChange={setDomainId}
          clearable
          maw={320}
        />
        <Text size="sm" c="dimmed">
          {t('admin.maintenance.intro')}
        </Text>
        {/* Keyed on the domain: a preview never carries over to another domain's run. */}
        <ThumbnailRegenerationCard key={`thumbnails-${domainId}`} domainId={domainId} />
        <ElevationRetryCard key={`elevation-${domainId}`} domainId={domainId} />
      </Stack>
    </AdminLayout>
  )
}
