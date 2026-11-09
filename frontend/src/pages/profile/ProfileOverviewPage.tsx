import { useTranslation } from 'react-i18next'
import {
  Box,
  Button,
  Center,
  Group,
  Loader,
  NavLink,
  Paper,
  SimpleGrid,
  Stack,
  Text,
  ThemeIcon,
  Title,
} from '@mantine/core'
import { IconChevronRight } from '@tabler/icons-react'
import { useGetMyProfileSummary } from '@/api/endpoints/users/users'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { UserAvatar } from '@/components/common/UserAvatar'
import {
  PROFILE_SIDEBAR_FROM,
  ProfileShell,
  ProfileSignOutButton,
} from '@/components/profile/ProfileShell'
import {
  PROFILE_HELP,
  PROFILE_NAV_GROUPS,
  type ProfileNavItem,
  type ProfileSection,
} from '@/components/profile/profileNav'
import { profileStatusLines } from '@/components/profile/profileStatus'
import { paths } from '@/config/paths'
import { useAuth } from '@/hooks/useAuth'

/** The shortcuts a desktop shows as cards, in the sidebar's order: « Mon compte » first although
 * the identity card leads there too, « Aide » last. */
const DESKTOP_CARDS: ProfileSection[] = [
  'account',
  'preferences',
  'notifications',
  'devices',
  'security',
  'privacy',
  'help',
]

const NAV_ITEMS: ProfileNavItem[] = [
  ...PROFILE_NAV_GROUPS.flatMap((group) => group.items),
  PROFILE_HELP,
]

function IdentityCard() {
  const { t } = useTranslation()
  const { user } = useAuth()
  if (!user) return null
  return (
    <Paper withBorder radius="md" p="lg">
      <Group wrap="wrap" gap="lg">
        <UserAvatar user={user} size="xl" />
        <Box style={{ flex: '1 1 200px', minWidth: 0 }}>
          <Text fw={700} size="xl" truncate>
            {user.displayName}
          </Text>
          <Text size="sm" c="dimmed" truncate>
            {user.email}
          </Text>
        </Box>
        <Button component={PrefetchLink} to={paths.profileAccount()} variant="default">
          {t('profile.nav.account')}
        </Button>
      </Group>
    </Paper>
  )
}

/** A row of the phone list: the subject, its state line, and the way to its page. */
function PhoneRow({ item, status }: { item: ProfileNavItem; status: string | undefined }) {
  const { t } = useTranslation()
  const Icon = item.icon
  return (
    <NavLink
      component={PrefetchLink}
      to={item.to()}
      label={t(item.labelKey)}
      description={status}
      leftSection={<Icon size={20} stroke={1.5} />}
      rightSection={<IconChevronRight size={16} />}
      py="sm"
      mih={44}
    />
  )
}

/** A desktop shortcut: the subject, its state line, and the way to its page. */
function StatusCard({ item, status }: { item: ProfileNavItem; status: string | undefined }) {
  const { t } = useTranslation()
  const Icon = item.icon
  return (
    <Paper
      withBorder
      radius="md"
      p="md"
      component={PrefetchLink}
      to={item.to()}
      style={{ color: 'inherit', textDecoration: 'none' }}
    >
      <Group wrap="nowrap" gap="md">
        <ThemeIcon variant="light" size={40} radius="md">
          <Icon size={20} stroke={1.5} />
        </ThemeIcon>
        <Box style={{ flex: 1, minWidth: 0 }}>
          <Text fw={600}>{t(item.labelKey)}</Text>
          <Text size="sm" c="dimmed" lineClamp={2}>
            {status ?? ' '}
          </Text>
        </Box>
        <IconChevronRight size={18} color="var(--mantine-color-dimmed)" />
      </Group>
    </Paper>
  )
}

/**
 * `/profil`: who is signed in, and one shortcut per subject with
 * its state line. Two calls in all — `/me`, which the server seeds, and the profile summary.
 *
 * A desktop has the sidebar (ProfileShell) and the subjects as cards; a phone has the grouped list,
 * which stands in for the sidebar, with « Se déconnecter » at its foot.
 */
export function ProfileOverviewPage() {
  const { t, i18n } = useTranslation()
  const { user, isLoading } = useAuth()
  const { data: summary } = useGetMyProfileSummary()

  if (isLoading || !user) {
    return (
      <Center py="xl">
        <Loader size="lg" />
      </Center>
    )
  }

  const status = profileStatusLines(t, user, summary, i18n.language)
  const itemOf = (section: ProfileSection) => NAV_ITEMS.find((item) => item.section === section)!

  return (
    <ProfileShell section="overview" title={t('profile.title')}>
      <IdentityCard />

      <Stack gap="sm" visibleFrom={PROFILE_SIDEBAR_FROM}>
        <Title order={3} size="h4">
          {t('profile.nav.group.settings')}
        </Title>
        <SimpleGrid cols={{ base: 1, lg: 2 }} spacing="sm">
          {DESKTOP_CARDS.map((section) => (
            <StatusCard key={section} item={itemOf(section)} status={status[section]} />
          ))}
        </SimpleGrid>
      </Stack>

      <Stack gap="lg" hiddenFrom={PROFILE_SIDEBAR_FROM}>
        {PROFILE_NAV_GROUPS.map((group) => (
          <Stack key={group.labelKey} gap={6}>
            <Text size="xs" fw={600} tt="uppercase" c="dimmed" px="xs">
              {t(group.labelKey)}
            </Text>
            <Paper withBorder radius="md" style={{ overflow: 'hidden' }}>
              {group.items.map((item) => (
                <PhoneRow key={item.section} item={item} status={status[item.section]} />
              ))}
            </Paper>
          </Stack>
        ))}
        {/* « Aide » in no group, last before « Se déconnecter ». */}
        <Paper withBorder radius="md" style={{ overflow: 'hidden' }}>
          <PhoneRow item={PROFILE_HELP} status={status.help} />
        </Paper>
        <Paper withBorder radius="md" p={4}>
          <ProfileSignOutButton />
        </Paper>
      </Stack>
    </ProfileShell>
  )
}
