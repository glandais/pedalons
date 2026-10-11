import type { ComponentType } from 'react'
import {
  IconAdjustmentsHorizontal,
  IconBell,
  IconBike,
  IconDeviceWatch,
  IconHelpCircle,
  IconLayoutDashboard,
  IconLock,
  IconShieldLock,
  IconUserCircle,
  IconUsersGroup,
} from '@tabler/icons-react'
import { paths } from '@/config/paths'
import { tRegister, type TranslationKey } from '@/lib/i18nUtils'

/**
 * The subjects of the profile, one per page (contracts/routes.yaml, « profile's sub-pages »). The
 * same tree, labels and order as the mobile app: the sidebar on a desktop, the grouped list of the
 * overview on a phone, and each page's `section` all read it from here.
 */
export type ProfileSection =
  | 'overview'
  | 'rides'
  | 'teams'
  | 'preferences'
  | 'notifications'
  | 'devices'
  | 'security'
  | 'privacy'
  | 'account'
  | 'help'

export interface ProfileNavItem {
  section: ProfileSection
  /** i18n key of the label. */
  labelKey: TranslationKey
  icon: ComponentType<{ size?: number | string; stroke?: number }>
  /** Read at render: `paths.*()` follows the current language. */
  to: () => string
  /** Leaves the profile (« Mes équipes » is the teams tab, not a page of the profile). */
  leavesProfile?: boolean
}

export interface ProfileNavGroup {
  /** i18n key of the group's label. The overview stands above the groups, in none of them. */
  labelKey: TranslationKey
  items: ProfileNavItem[]
}

export const PROFILE_OVERVIEW: ProfileNavItem = {
  section: 'overview',
  labelKey: tRegister('profile.nav.overview'),
  icon: IconLayoutDashboard,
  to: () => paths.profile(),
}

export const PROFILE_NAV_GROUPS: ProfileNavGroup[] = [
  {
    labelKey: tRegister('profile.nav.group.activity'),
    items: [
      {
        section: 'rides',
        labelKey: tRegister('profile.nav.rides'),
        icon: IconBike,
        to: () => paths.myParticipations(),
      },
      {
        section: 'teams',
        labelKey: tRegister('profile.nav.teams'),
        icon: IconUsersGroup,
        to: () => paths.teams(),
        leavesProfile: true,
      },
    ],
  },
  {
    labelKey: tRegister('profile.nav.group.settings'),
    items: [
      {
        section: 'preferences',
        labelKey: tRegister('profile.nav.preferences'),
        icon: IconAdjustmentsHorizontal,
        to: () => paths.profilePreferences(),
      },
      {
        section: 'notifications',
        labelKey: tRegister('profile.nav.notifications'),
        icon: IconBell,
        to: () => paths.profileNotifications(),
      },
      {
        section: 'devices',
        labelKey: tRegister('profile.nav.devices'),
        icon: IconDeviceWatch,
        to: () => paths.profileDevices(),
      },
    ],
  },
  {
    labelKey: tRegister('profile.nav.group.security'),
    items: [
      {
        section: 'security',
        labelKey: tRegister('profile.nav.security'),
        icon: IconLock,
        to: () => paths.profileSecurity(),
      },
      {
        section: 'privacy',
        labelKey: tRegister('profile.nav.privacy'),
        icon: IconShieldLock,
        to: () => paths.profilePrivacy(),
      },
    ],
  },
  {
    labelKey: tRegister('profile.nav.group.account'),
    items: [
      {
        section: 'account',
        labelKey: tRegister('profile.nav.account'),
        icon: IconUserCircle,
        to: () => paths.profileAccount(),
      },
      {
        section: 'help',
        labelKey: tRegister('profile.nav.help'),
        icon: IconHelpCircle,
        to: () => paths.profileHelp(),
      },
    ],
  },
]
