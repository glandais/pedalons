import { Avatar, Tooltip } from '@mantine/core'
import type { UserDto } from '@/api/dto'
import { clusterFaces } from '@/lib/avatarCluster'
import { avatarBackground, avatarInitials } from '@/lib/avatarTint'
import { useAuthStore } from '@/store/authStore'

type AvatarSize = 'xs' | 'sm' | 'md' | 'lg' | 'xl' | number

/** Initials size per diameter, the app's (`PdlAvatar._fontSizes`, 700); 0.35 of it otherwise. */
const INITIALS_SIZE: Record<number, number> = { 16: 8, 20: 10, 26: 10, 32: 12, 40: 14, 56: 19 }

interface UserAvatarProps {
  /** `id` marks the reader, drawn in the primary colour. */
  user: Pick<UserDto, 'displayName' | 'avatarUrl'> & { id?: string }
  size?: AvatarSize
}

/**
 * A person's avatar: the photo, else the initials on their own colour — one per person, the reader
 * in the primary colour, the same on the app (`lib/avatarTint.ts`, docs/LEDGER_*.md WEB-167 R5).
 */
export function UserAvatar({ user, size = 'md' }: UserAvatarProps) {
  const readerId = useAuthStore((state) => state.user?.id)
  const isReader = !!user.id && user.id === readerId
  const fontSize =
    typeof size === 'number' ? (INITIALS_SIZE[size] ?? Math.round(size * 0.35)) : undefined

  return (
    <Tooltip label={user.displayName} withArrow>
      <Avatar
        src={user.avatarUrl}
        alt={user.displayName}
        size={size}
        radius="xl"
        variant="filled"
        styles={{
          placeholder: {
            background: avatarBackground(user.displayName, isReader),
            color: 'var(--mantine-color-white)',
            fontWeight: 700,
            fontSize,
            letterSpacing: 0,
          },
        }}
      >
        {avatarInitials(user.displayName)}
      </Avatar>
    </Tooltip>
  )
}

interface UserAvatarGroupProps {
  users: Array<Pick<UserDto, 'id' | 'displayName' | 'avatarUrl'>>
  max?: number
  size?: AvatarSize
  /**
   * Everyone the avatars stand for, when `users` is only a preview of them (a ride group or a trip
   * embeds its first few participants): the « +N » counts from it rather than from `users`.
   */
  total?: number
  /**
   * Someone a line of the card already names — a group's leader (KIT §8): left out of the cluster,
   * and out of the « +N » with it.
   */
  excludeId?: string
}

/**
 * Overlapping avatars (docs/LEDGER_*.md WEB-167 R5): 26 px discs with a 2 px ring, 4 px of overlap
 * so that the initials stay readable, then a « +N » pill that stands for no one.
 */
export function UserAvatarGroup({
  users,
  max = 5,
  size = 26,
  total,
  excludeId,
}: UserAvatarGroupProps) {
  const cluster = clusterFaces(users, total, excludeId)
  const visibleUsers = cluster.faces.slice(0, max)
  const remainingCount = cluster.total - visibleUsers.length
  if (visibleUsers.length === 0 && remainingCount <= 0) return null

  return (
    <Avatar.Group spacing={4} data-testid="avatar-cluster">
      {visibleUsers.map((user) => (
        <UserAvatar key={user.id} user={user} size={size} />
      ))}
      {remainingCount > 0 && (
        <Avatar
          size={size}
          radius="xl"
          color="gray"
          styles={{
            placeholder: {
              fontSize: 10,
              fontWeight: 600,
              color: 'var(--mantine-color-dimmed)',
              letterSpacing: 0,
            },
          }}
        >
          +{remainingCount}
        </Avatar>
      )}
    </Avatar.Group>
  )
}
