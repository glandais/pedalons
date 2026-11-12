import { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Badge as MantineBadge } from '@mantine/core'
import { IconTrash } from '@tabler/icons-react'
import {
  PUBLICATION_TYPE_COLORS,
  AD_TYPE_COLORS,
  STATUS_COLORS,
  TEAM_ROLE_COLORS,
  SURFACE_TYPE_COLORS,
  VISIBILITY_COLORS,
} from '@/lib/badgeColors.generated'

// A publication type or an ad type: both series share the `TypeBadge`.
const TYPE_COLORS = { ...PUBLICATION_TYPE_COLORS, ...AD_TYPE_COLORS }

// Direct color variants
type ColorVariant =
  | 'blue'
  | 'green'
  | 'red'
  | 'yellow'
  | 'gray'
  | 'primary'
  | 'purple'
  | 'pink'
  | 'orange'
  | 'teal'
  | 'indigo'
  | 'dark'
  | 'grape'

interface BadgeProps {
  variant?: ColorVariant
  children: ReactNode
  icon?: ReactNode
}

const variantColors: Record<ColorVariant, string> = {
  blue: 'blue',
  green: 'green',
  red: 'red',
  yellow: 'yellow',
  gray: 'gray',
  primary: 'primary',
  purple: 'grape',
  pink: 'pink',
  orange: 'orange',
  teal: 'teal',
  indigo: 'indigo',
  dark: 'dark',
  grape: 'grape',
}

export function Badge({ variant = 'gray', children, icon }: BadgeProps) {
  return (
    <MantineBadge color={variantColors[variant]} variant="light" size="sm" leftSection={icon}>
      {children}
    </MantineBadge>
  )
}

// Semantic badge components for common use cases

interface TypeBadgeProps {
  type: keyof typeof TYPE_COLORS
  children: ReactNode
  icon?: ReactNode
}

export function TypeBadge({ type, children, icon }: TypeBadgeProps) {
  return (
    <MantineBadge color={TYPE_COLORS[type]} variant="light" size="sm" leftSection={icon}>
      {children}
    </MantineBadge>
  )
}

interface StatusBadgeProps {
  status: keyof typeof STATUS_COLORS
  children: ReactNode
  icon?: ReactNode
}

/**
 * A status never shrinks beside a title on one line (« BROUI… », docs/LEDGER_*.md WEB-167 N22):
 * the title gives way first.
 */
export function StatusBadge({ status, children, icon }: StatusBadgeProps) {
  return (
    <MantineBadge
      color={STATUS_COLORS[status]}
      variant="light"
      size="sm"
      leftSection={icon}
      style={{ flexShrink: 0 }}
      data-testid="status-badge"
    >
      {children}
    </MantineBadge>
  )
}

/**
 * The "deleted" badge of a soft-deleted entity.
 *
 * `deleted` is not a `Status` value — it is a separate boolean the backend only
 * returns to team admins (`IncludeDeletedService`). A deleted publication stays
 * in an admin's feed carrying its original status, `PUBLISHED` most of the
 * time; without this badge it is indistinguishable from a live one, which reads
 * as "the deletion didn't work".
 *
 * Rendered **filled** rather than light: `CANCELLED` already owns light red and
 * both badges can sit on the same card. Two light red pills would have to be
 * read to be told apart.
 */
export function DeletedBadge() {
  const { t } = useTranslation()
  return (
    <MantineBadge color="red" variant="filled" size="sm" leftSection={<IconTrash size={12} />}>
      {t('status.DELETED')}
    </MantineBadge>
  )
}

interface RoleBadgeProps {
  role: keyof typeof TEAM_ROLE_COLORS
  children: ReactNode
  icon?: ReactNode
}

export function RoleBadge({ role, children, icon }: RoleBadgeProps) {
  return (
    <MantineBadge color={TEAM_ROLE_COLORS[role]} variant="light" size="sm" leftSection={icon}>
      {children}
    </MantineBadge>
  )
}

interface SurfaceBadgeProps {
  surface: keyof typeof SURFACE_TYPE_COLORS
  children: ReactNode
  icon?: ReactNode
}

export function SurfaceBadge({ surface, children, icon }: SurfaceBadgeProps) {
  return (
    <MantineBadge color={SURFACE_TYPE_COLORS[surface]} variant="light" size="sm" leftSection={icon}>
      {children}
    </MantineBadge>
  )
}

interface VisibilityBadgeSemanticProps {
  visibility: keyof typeof VISIBILITY_COLORS
  children: ReactNode
  icon?: ReactNode
}

export function VisibilityBadgeSemantic({
  visibility,
  children,
  icon,
}: VisibilityBadgeSemanticProps) {
  return (
    <MantineBadge
      color={VISIBILITY_COLORS[visibility]}
      variant="light"
      size="sm"
      leftSection={icon}
    >
      {children}
    </MantineBadge>
  )
}
