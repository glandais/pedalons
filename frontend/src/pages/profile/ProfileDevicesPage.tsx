import { useTranslation } from 'react-i18next'
import { Button, Group, Stack, Text, Title } from '@mantine/core'
import { IconDeviceMobile } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { GpsConnectionsManager } from '@/components/profile/GpsConnectionsManager'
import { PairedDevicesManager } from '@/components/profile/PairedDevicesManager'
import { ProfileCard, ProfileShell } from '@/components/profile/ProfileShell'
import { paths } from '@/config/paths'

/**
 * « Appareils et services »: the accounts a route is sent to (Hammerhead, Garmin Connect, Wahoo),
 * the bike computers paired by code (Karoo, Garmin), and how to pair one. The GPS OAuth callback
 * returns here (`GpsConnectReturn.PROFILE`), and the member home's « send your routes » card leads
 * here (docs/LEDGER_*.md WEB-51).
 */
export function ProfileDevicesPage() {
  const { t } = useTranslation()
  return (
    <ProfileShell section="devices" title={t('profile.nav.devices')}>
      <ProfileCard>
        <GpsConnectionsManager />
      </ProfileCard>
      <ProfileCard>
        <PairedDevicesManager />
      </ProfileCard>
      <ProfileCard>
        <Stack gap="xs">
          <Title order={2} size="h5">
            {t('profile.devices.howTo.title')}
          </Title>
          <Text size="sm" c="dimmed">
            {t('profile.devices.howTo.text')}
          </Text>
          <Group>
            <Button
              component={PrefetchLink}
              to={paths.apps()}
              variant="default"
              leftSection={<IconDeviceMobile size={16} />}
            >
              {t('profile.devices.howTo.link')}
            </Button>
          </Group>
        </Stack>
      </ProfileCard>
    </ProfileShell>
  )
}
