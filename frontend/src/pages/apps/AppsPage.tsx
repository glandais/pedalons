import { useTranslation } from 'react-i18next'
import {
  Anchor,
  Container,
  Stack,
  Title,
  Text,
  SimpleGrid,
  Paper,
  Badge,
  Button,
  ThemeIcon,
} from '@mantine/core'
import {
  IconDeviceWatch,
  IconDeviceMobile,
  IconMountain,
  IconExternalLink,
  IconWorldWww,
  IconDownload,
} from '@tabler/icons-react'
import { useInstallOffer } from '@/lib/install/useInstallOffer'

// The karoo-latest release, rewritten on every karoo.X.Y.Z tag (karoo/PUBLISH.md). A GitHub URL on
// purpose: the Companion's sideloading is only verified by Hammerhead for GitHub links.
const KAROO_APK_URL =
  'https://github.com/glandais/pedalons/releases/download/karoo-latest/pedalons.apk'
// The mobile-latest release, rewritten on every mobile.X.Y.Z.N tag pushed by mobile/publish_beta.sh
// (.github/workflows/mobile-release.yml): the app for Android devices without Google Play.
const MOBILE_APK_URL =
  'https://github.com/glandais/pedalons/releases/download/mobile-latest/pedalons-android.apk'
const KAROO_SIDELOADING_URL =
  'https://support.hammerhead.io/hc/en-us/articles/31576497036827-Companion-App-Sideloading'
const APP_STORE_URL = 'https://apps.apple.com/app/id6761760079'
// The Connect IQ Store listing (garmin-app/PUBLISH.md); without a locale, the store picks the
// browser's language.
const GARMIN_STORE_URL = 'https://apps.garmin.com/apps/262ea335-a5b7-4a6a-bb30-fc6f5db9b115'

type AppStatus = 'available' | 'comingSoon' | 'installed'

function AppCard({
  icon,
  title,
  description,
  status,
  action,
}: {
  icon: React.ReactNode
  title: string
  description: string
  status: AppStatus
  action?: React.ReactNode
}) {
  const { t } = useTranslation()
  return (
    <Paper shadow="sm" radius="lg" p="lg" withBorder>
      <Stack gap="sm">
        <ThemeIcon size={48} radius="lg" variant="light">
          {icon}
        </ThemeIcon>
        <Title order={3}>{title}</Title>
        <Badge color={status === 'comingSoon' ? 'gray' : 'green'} w="fit-content">
          {t(`apps.status.${status}`)}
        </Badge>
        <Text c="dimmed" size="sm">
          {description}
        </Text>
        {action}
      </Stack>
    </Paper>
  )
}

/**
 * The site itself, installed as an app. Always the site, never the store: that is the whole point
 * of this card, for those who don't want (or can't get) the mobile app.
 */
function WebAppCard() {
  const { t } = useTranslation()
  const { offer, standalone, install } = useInstallOffer()
  return (
    <AppCard
      icon={<IconWorldWww size={28} />}
      title={t('apps.web.title')}
      description={t('apps.web.description')}
      status={standalone ? 'installed' : 'available'}
      action={
        offer ? (
          <Button variant="light" leftSection={<IconDownload size={16} />} onClick={install}>
            {t('install.action')}
          </Button>
        ) : standalone ? undefined : (
          <Text size="xs" c="dimmed">
            {t('apps.web.browserMenu')}
          </Text>
        )
      }
    />
  )
}

export function AppsPage() {
  const { t } = useTranslation()

  return (
    <Container size="md" py="xl">
      <Stack gap="xl">
        <Stack gap="xs" ta="center">
          <Title order={1}>{t('apps.title')}</Title>
          <Text c="dimmed">{t('apps.subtitle')}</Text>
        </Stack>

        <SimpleGrid cols={{ base: 1, sm: 2, md: 4 }}>
          <WebAppCard />
          <AppCard
            icon={<IconDeviceMobile size={28} />}
            title={t('apps.mobile.title')}
            description={t('apps.mobile.description')}
            status="available"
            action={
              <Stack gap="xs">
                <Button
                  component="a"
                  href={APP_STORE_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  variant="light"
                  rightSection={<IconExternalLink size={16} />}
                >
                  {t('apps.mobile.download')}
                </Button>
                <Button
                  component="a"
                  href={MOBILE_APK_URL}
                  variant="subtle"
                  rightSection={<IconDownload size={16} />}
                >
                  {t('apps.mobile.apk')}
                </Button>
                <Text size="xs" c="dimmed">
                  {t('apps.mobile.apkHint')}
                </Text>
              </Stack>
            }
          />
          <AppCard
            icon={<IconDeviceWatch size={28} />}
            title={t('apps.garmin.title')}
            description={t('apps.garmin.description')}
            status="available"
            action={
              <Button
                component="a"
                href={GARMIN_STORE_URL}
                target="_blank"
                rel="noopener noreferrer"
                variant="light"
                rightSection={<IconExternalLink size={16} />}
              >
                {t('apps.garmin.download')}
              </Button>
            }
          />
          <AppCard
            icon={<IconMountain size={28} />}
            title={t('apps.karoo.title')}
            description={t('apps.karoo.description')}
            status="available"
            action={
              <Stack gap="xs">
                <Button
                  component="a"
                  href={KAROO_APK_URL}
                  variant="light"
                  rightSection={<IconDownload size={16} />}
                >
                  {t('apps.karoo.download')}
                </Button>
                <Text size="xs" c="dimmed">
                  {t('apps.karoo.install')}
                </Text>
                <Anchor
                  href={KAROO_SIDELOADING_URL}
                  target="_blank"
                  rel="noopener noreferrer"
                  size="xs"
                >
                  {t('apps.karoo.instructions')}
                </Anchor>
              </Stack>
            }
          />
        </SimpleGrid>
      </Stack>
    </Container>
  )
}
