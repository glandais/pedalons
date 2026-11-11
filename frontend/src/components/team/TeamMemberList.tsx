import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Paper, Group, Text, Badge, Button, Select, Box, Stack, Skeleton } from '@mantine/core'
import { UserAvatar } from '../common/UserAvatar'
import { ConfirmDialog } from '../common/ConfirmDialog'
import type { MemberDto } from '@/api/dto'
import { TeamRole } from '@/api/dto'
import { useFormattedDate } from '../../utils/dateFormat'

interface TeamMemberListProps {
  members: MemberDto[]
  currentUserRole: TeamRole | null
  currentUserId: string | null
  onUpdateRole?: (memberId: string, role: TeamRole) => void
  onRemoveMember?: (memberId: string) => void
  isUpdating?: boolean
  isRemoving?: boolean
}

const roleBadgeColors: Record<string, string> = {
  ADMIN: 'grape',
  ORGANIZER: 'blue',
  MEMBER: 'gray',
}

export function TeamMemberList({
  members,
  currentUserRole,
  currentUserId,
  onUpdateRole,
  onRemoveMember,
  isUpdating = false,
  isRemoving = false,
}: TeamMemberListProps) {
  const { t } = useTranslation()
  const { formatMonthYear, isGuessedTimezone } = useFormattedDate()
  const [editingMemberId, setEditingMemberId] = useState<string | null>(null)
  const [selectedRole, setSelectedRole] = useState<TeamRole>(TeamRole.MEMBER)
  const [showRemoveConfirm, setShowRemoveConfirm] = useState(false)
  const [memberToRemove, setMemberToRemove] = useState<string | null>(null)

  const canManageMembers = currentUserRole === TeamRole.ADMIN
  const canAssignOrganizers =
    currentUserRole === TeamRole.ADMIN || currentUserRole === TeamRole.ORGANIZER

  const handleRoleChange = (memberId: string) => {
    if (onUpdateRole) {
      onUpdateRole(memberId, selectedRole)
      setEditingMemberId(null)
    }
  }

  const handleRemove = (memberId: string) => {
    setMemberToRemove(memberId)
    setShowRemoveConfirm(true)
  }

  const handleConfirmRemove = () => {
    if (onRemoveMember && memberToRemove) {
      onRemoveMember(memberToRemove)
      setShowRemoveConfirm(false)
      setMemberToRemove(null)
    }
  }

  const getRoleOptions = () => {
    const options = []
    if (canManageMembers) {
      options.push({ value: 'ADMIN', label: t('roles.ADMIN') })
    }
    if (canAssignOrganizers) {
      options.push({ value: 'ORGANIZER', label: t('roles.ORGANIZER') })
    }
    options.push({ value: 'MEMBER', label: t('roles.MEMBER') })
    return options
  }

  return (
    <Paper shadow="xs" withBorder>
      <Stack gap={0}>
        {members.map((member, index) => {
          const isCurrentUser = member.user.id === currentUserId
          // `role` is null when the caller is not entitled to it — an organiser reading a team
          // that has not opened its directory. On the admin screen it is always present; on the
          // members' directory (TeamDirectoryPage) it may not be, and the actions are off there
          // anyway. The actions that depend on knowing the role stay off when it is absent.
          const memberRole = member.role
          const canEdit =
            canManageMembers && !isCurrentUser && memberRole != null && memberRole !== 'ADMIN'
          const canRemove = canManageMembers && !isCurrentUser

          return (
            <Box
              key={member.id}
              p="md"
              style={{
                borderBottom:
                  index < members.length - 1
                    ? '1px solid var(--mantine-color-default-border)'
                    : undefined,
              }}
            >
              <Group justify="space-between" wrap="nowrap">
                <Group gap="sm" wrap="nowrap" style={{ minWidth: 0 }}>
                  <UserAvatar
                    user={{
                      displayName: member.user.displayName,
                      avatarUrl: member.user.avatarUrl,
                    }}
                    size="md"
                  />
                  <Box style={{ minWidth: 0 }}>
                    <Group gap="xs">
                      <Text size="sm" fw={500} truncate>
                        {member.user.displayName}
                      </Text>
                      {isCurrentUser && (
                        <Text size="xs" c="dimmed">
                          {t('teams.detail.members.you')}
                        </Text>
                      )}
                    </Group>
                    {/* Null, like `role`, when the caller is not entitled to it (API-39). */}
                    {member.joinedAt && (
                      <Text size="xs" c="dimmed" suppressHydrationWarning={isGuessedTimezone}>
                        {t('teams.detail.members.since', {
                          date: formatMonthYear(member.joinedAt) || t('unknown'),
                        })}
                      </Text>
                    )}
                  </Box>
                </Group>

                <Group gap="xs" wrap="nowrap">
                  {editingMemberId === member.id ? (
                    <>
                      <Select
                        size="xs"
                        aria-label={t('teams.detail.members.roleOf', {
                          name: member.user.displayName,
                        })}
                        value={selectedRole}
                        onChange={(value) => value && setSelectedRole(value as TeamRole)}
                        data={getRoleOptions()}
                        disabled={isUpdating}
                        w={120}
                      />
                      <Button
                        size="xs"
                        variant="subtle"
                        onClick={() => handleRoleChange(member.user.id)}
                        disabled={isUpdating}
                        loading={isUpdating}
                      >
                        {t('actions.save')}
                      </Button>
                      <Button
                        size="xs"
                        variant="subtle"
                        color="gray"
                        onClick={() => setEditingMemberId(null)}
                        disabled={isUpdating}
                      >
                        {t('actions.cancelAction')}
                      </Button>
                    </>
                  ) : (
                    <>
                      {memberRole && (
                        <Badge color={roleBadgeColors[memberRole]} variant="light">
                          {t(`roles.${memberRole satisfies 'ADMIN' | 'ORGANIZER' | 'MEMBER'}`)}
                        </Badge>
                      )}

                      {canEdit && (
                        <Button
                          size="xs"
                          variant="subtle"
                          color="gray"
                          onClick={() => {
                            setSelectedRole(memberRole)
                            setEditingMemberId(member.id)
                          }}
                        >
                          {t('actions.edit')}
                        </Button>
                      )}

                      {canRemove && (
                        <Button
                          size="xs"
                          variant="subtle"
                          color="danger"
                          onClick={() => handleRemove(member.user.id)}
                          disabled={isRemoving}
                          loading={isRemoving}
                        >
                          {t('teams.detail.members.remove')}
                        </Button>
                      )}
                    </>
                  )}
                </Group>
              </Group>
            </Box>
          )
        })}
      </Stack>

      <ConfirmDialog
        isOpen={showRemoveConfirm}
        onClose={() => {
          setShowRemoveConfirm(false)
          setMemberToRemove(null)
        }}
        onConfirm={handleConfirmRemove}
        title={t('teams.detail.members.remove')}
        message={t('teams.detail.members.confirmRemove')}
        confirmText={t('teams.detail.members.remove')}
        variant="danger"
        isLoading={isRemoving}
      />
    </Paper>
  )
}

export function TeamMemberListSkeleton({ count = 3 }: { count?: number }) {
  return (
    <Paper shadow="xs" withBorder>
      <Stack gap={0}>
        {Array.from({ length: count }).map((_, i) => (
          <Box
            key={i}
            p="md"
            style={{
              borderBottom:
                i < count - 1 ? '1px solid var(--mantine-color-default-border)' : undefined,
            }}
          >
            <Group>
              <Skeleton circle height={40} width={40} />
              <Box style={{ flex: 1 }}>
                <Skeleton height={16} width="25%" mb="xs" />
                <Skeleton height={12} width="33%" />
              </Box>
              <Skeleton height={20} width={60} radius="xl" />
            </Group>
          </Box>
        ))}
      </Stack>
    </Paper>
  )
}
