import { useTranslation } from 'react-i18next'
import { Anchor, Group, Progress, Stack, Text, UnstyledButton } from '@mantine/core'
import { IconUsers } from '@tabler/icons-react'
import type { PublicUserDto } from '@/api/dto'
import { UserAvatarGroup } from '@/components/common/UserAvatar'
import { clusterHidesSomeone } from '@/lib/avatarCluster'
import { useParticipantsLabel } from '@/hooks/useParticipantsLabel'

/** Faces shown before the « +N » pill. */
const CLUSTER_MAX = 5

interface GroupPeopleRowProps {
  /** The group's first participants, as the API embeds them (empty for an outsider). */
  participants: PublicUserDto[]
  countParticipants: number
  maxParticipants?: number
  full: boolean
  /** A line of the card names them already: out of the cluster (KIT §8). */
  leaderId?: string
  /**
   * Members and platform admins only (docs/LEDGER_*.md API-144): anyone else gets the count and the
   * bar, never a face or a name.
   */
  canSeeParticipants: boolean
  /** Opens the list: the cluster and « Voir tout » both do. Absent, neither is a control. */
  onViewAll?: () => void
  /** The count as the card words it: « B · 11/12 personnes » on « Ma prochaine sortie ». */
  formatLabel?: (label: string) => string
}

/**
 * Who goes in a group, on a card (docs/LEDGER_*.md WEB-167, R5): the cluster — kept when the group
 * is full, without the leader —, « 11/12 personnes » in the text's colour, « Voir tout » as soon as
 * the cluster ends on a « +N », then the places bar when the group has a maximum: primary, red once
 * full. No green, no orange.
 */
export function GroupPeopleRow({
  participants,
  countParticipants,
  maxParticipants,
  full,
  leaderId,
  canSeeParticipants,
  onViewAll,
  formatLabel,
}: GroupPeopleRowProps) {
  const { t } = useTranslation()
  const participantsLabel = useParticipantsLabel()
  const label = participantsLabel(countParticipants, maxParticipants)
  const showFaces = canSeeParticipants && participants.length > 0
  const showViewAll =
    canSeeParticipants &&
    !!onViewAll &&
    showFaces &&
    clusterHidesSomeone(participants, countParticipants, CLUSTER_MAX, leaderId)

  const count = (
    <Text size="sm" fw={500} style={{ whiteSpace: 'nowrap' }} data-testid="group-count">
      {formatLabel ? formatLabel(label) : label}
    </Text>
  )
  const faces = showFaces ? (
    <UserAvatarGroup
      users={participants}
      total={countParticipants}
      max={CLUSTER_MAX}
      excludeId={leaderId}
    />
  ) : (
    <IconUsers size={16} aria-hidden style={{ flexShrink: 0 }} />
  )
  const cluster = (
    <Group gap="xs" wrap="nowrap">
      {faces}
      {count}
    </Group>
  )

  return (
    <Stack gap={6}>
      <Group justify="space-between" gap="xs" wrap="wrap">
        {canSeeParticipants && onViewAll ? (
          <UnstyledButton
            onClick={onViewAll}
            aria-label={t('rides.detail.groups.viewParticipants')}
            style={{ borderRadius: 'var(--mantine-radius-sm)' }}
          >
            {cluster}
          </UnstyledButton>
        ) : (
          cluster
        )}
        {showViewAll && (
          <Anchor component="button" type="button" size="sm" fw={500} onClick={onViewAll}>
            {t('rides.detail.groups.viewAll')}
          </Anchor>
        )}
      </Group>
      {maxParticipants ? (
        <Progress
          value={Math.min(100, (countParticipants / maxParticipants) * 100)}
          color={full ? 'red' : 'primary'}
          size="sm"
          aria-label={label}
          data-testid="group-places-bar"
        />
      ) : null}
    </Stack>
  )
}
