import { useTranslation } from 'react-i18next'
import { BlockedUsers } from '@/components/profile/BlockedUsers'
import { ProfileCard, ProfileShell } from '@/components/profile/ProfileShell'

/** « Personnes bloquées »: a sub-page of « Confidentialité », which stays current in the sidebar. */
export function BlockedUsersPage() {
  const { t } = useTranslation()
  return (
    <ProfileShell section="privacy" title={t('profile.blockedUsers.title')}>
      <ProfileCard>
        <BlockedUsers />
      </ProfileCard>
    </ProfileShell>
  )
}
