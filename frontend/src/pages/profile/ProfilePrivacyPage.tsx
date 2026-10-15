import { useTranslation } from 'react-i18next'
import { Center, Loader, NavLink, Paper } from '@mantine/core'
import { IconChevronRight, IconUserOff } from '@tabler/icons-react'
import { useListMyBlockedUsers } from '@/api/endpoints/moderation/moderation'
import { AnalyticsPreference } from '@/components/analytics/AnalyticsPreference'
import { ErrorReportingPreference } from '@/components/feedback/ErrorReportingPreference'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { ContactPreference } from '@/components/profile/ContactPreference'
import { DataExportManager } from '@/components/profile/DataExportManager'
import { ProfileCard, ProfileShell } from '@/components/profile/ProfileShell'
import { paths } from '@/config/paths'
import { useAuth } from '@/hooks/useAuth'

/**
 * « Confidentialité »: who may reach the member, whom they blocked (a page of its own), the error
 * reports this browser sends, the site's audience measurement on this browser, and the export of
 * their data.
 */
export function ProfilePrivacyPage() {
  const { t } = useTranslation()
  const { user, isLoading } = useAuth()
  const { data: blocked } = useListMyBlockedUsers()

  if (isLoading || !user) {
    return (
      <Center py="xl">
        <Loader size="lg" />
      </Center>
    )
  }

  const blockedCount = blocked?.users.length

  return (
    <ProfileShell section="privacy" title={t('profile.nav.privacy')}>
      <ProfileCard>
        <ContactPreference contactableByMembers={user.contactableByMembers} />
      </ProfileCard>

      <Paper withBorder radius="md" style={{ overflow: 'hidden' }}>
        <NavLink
          component={PrefetchLink}
          to={paths.blockedUsers()}
          label={t('profile.blockedUsers.title')}
          description={
            blockedCount === undefined
              ? undefined
              : blockedCount === 0
                ? t('profile.blockedUsers.empty')
                : t('profile.status.blocked', { count: blockedCount })
          }
          leftSection={<IconUserOff size={20} stroke={1.5} />}
          rightSection={<IconChevronRight size={16} />}
          py="md"
          px="lg"
        />
      </Paper>

      <ProfileCard>
        <ErrorReportingPreference />
      </ProfileCard>

      <ProfileCard>
        <AnalyticsPreference />
      </ProfileCard>

      <ProfileCard>
        <DataExportManager />
      </ProfileCard>
    </ProfileShell>
  )
}
