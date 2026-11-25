import { useState } from 'react'
import { Trans, useTranslation } from 'react-i18next'
import { Anchor, Button, Group, Stack, Text, Title } from '@mantine/core'
import { notifications } from '@mantine/notifications'
import { IconLogout2 } from '@tabler/icons-react'
import { PasskeyManager } from '@/components/auth/PasskeyManager'
import { ConfirmDialog } from '@/components/common/ConfirmDialog'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { ProfileCard, ProfileShell } from '@/components/profile/ProfileShell'
import { paths } from '@/config/paths'
import { useAuth } from '@/hooks/useAuth'

/**
 * « Connexion et sécurité »: the passkeys, and closing every session at once. Deleting the account
 * is not here but in « Mon compte », which the foot of the page points to.
 */
export function ProfileSecurityPage() {
  const { t } = useTranslation()
  const { logoutAll } = useAuth()
  const [showLogoutAllConfirm, setShowLogoutAllConfirm] = useState(false)
  const [isLoggingOutAll, setIsLoggingOutAll] = useState(false)

  const handleLogoutAll = async () => {
    setIsLoggingOutAll(true)
    try {
      // Reloads on the login page once done.
      await logoutAll()
    } catch {
      setIsLoggingOutAll(false)
      setShowLogoutAllConfirm(false)
      notifications.show({ message: t('profile.account.logoutAllFailed'), color: 'red' })
    }
  }

  return (
    <ProfileShell section="security" title={t('profile.nav.security')}>
      <ProfileCard>
        <PasskeyManager />
      </ProfileCard>

      <ProfileCard>
        <Stack gap="xs">
          <Title order={2} size="h5">
            {t('profile.security.sessions.title')}
          </Title>
          <Text size="sm" c="dimmed">
            {t('profile.account.logoutAllDescription')}
          </Text>
          <Group>
            <Button
              variant="default"
              leftSection={<IconLogout2 size={16} />}
              onClick={() => setShowLogoutAllConfirm(true)}
            >
              {t('profile.account.logoutAll')}
            </Button>
          </Group>
        </Stack>
      </ProfileCard>

      <Text size="sm" c="dimmed">
        <Trans
          i18nKey="profile.security.deleteHint"
          components={{ link: <Anchor component={PrefetchLink} to={paths.profileAccount()} /> }}
        />
      </Text>

      <ConfirmDialog
        isOpen={showLogoutAllConfirm}
        onClose={() => setShowLogoutAllConfirm(false)}
        onConfirm={() => void handleLogoutAll()}
        title={t('profile.account.logoutAllTitle')}
        message={t('profile.account.logoutAllMessage')}
        confirmText={t('profile.account.logoutAll')}
        variant="warning"
        isLoading={isLoggingOutAll}
      />
    </ProfileShell>
  )
}
