import { useTranslation } from 'react-i18next'
import { NavLink, Paper, Stack, Text, Title } from '@mantine/core'
import {
  IconChevronRight,
  IconDeviceMobile,
  IconFileText,
  IconLifebuoy,
  IconMessageReport,
  IconShieldCheck,
} from '@tabler/icons-react'
import { useGetVersion } from '@/api/endpoints/server-version/server-version'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { ProfileCard, ProfileShell } from '@/components/profile/ProfileShell'
import { paths } from '@/config/paths'
import { openFeedback } from '@/lib/feedback/feedbackStore'

/**
 * « Aide et à propos »: the pages the footer also lists, reporting a problem, and the version. The
 * site and the server are built from one commit, so the web has a single version line where the app
 * shows its own and the server's.
 */
export function ProfileHelpPage() {
  const { t } = useTranslation()
  // Same options as the footer's, so both read the entry the server prefetched for every document.
  const { data: version } = useGetVersion({ query: { staleTime: Infinity } })

  const links = [
    { label: t('footer.apps'), to: paths.apps(), icon: IconDeviceMobile },
    { label: t('footer.support'), to: paths.support(), icon: IconLifebuoy },
    { label: t('footer.privacy'), to: paths.privacy(), icon: IconShieldCheck },
    { label: t('footer.terms'), to: paths.terms(), icon: IconFileText },
  ]

  return (
    <ProfileShell section="help" title={t('profile.nav.help')}>
      <Paper withBorder radius="md" style={{ overflow: 'hidden' }}>
        {links.slice(0, 2).map(({ label, to, icon: Icon }) => (
          <NavLink
            key={to}
            component={PrefetchLink}
            to={to}
            label={label}
            leftSection={<Icon size={20} stroke={1.5} />}
            rightSection={<IconChevronRight size={16} />}
            py="sm"
            mih={44}
          />
        ))}
        <NavLink
          component="button"
          type="button"
          onClick={() => openFeedback()}
          label={t('feedback.menu')}
          leftSection={<IconMessageReport size={20} stroke={1.5} />}
          py="sm"
          mih={44}
        />
        {links.slice(2).map(({ label, to, icon: Icon }) => (
          <NavLink
            key={to}
            component={PrefetchLink}
            to={to}
            label={label}
            leftSection={<Icon size={20} stroke={1.5} />}
            rightSection={<IconChevronRight size={16} />}
            py="sm"
            mih={44}
          />
        ))}
      </Paper>

      {version && (
        <ProfileCard>
          <Stack gap={4}>
            <Title order={2} size="h5">
              {t('profile.help.version')}
            </Title>
            <Text size="sm" c="dimmed">
              {version.commit
                ? t('footer.version', { version: version.apiVersion, commit: version.commit })
                : t('footer.versionShort', { version: version.apiVersion })}
            </Text>
          </Stack>
        </ProfileCard>
      )}
    </ProfileShell>
  )
}
