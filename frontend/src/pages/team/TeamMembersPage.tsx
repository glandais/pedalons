import { useState, useCallback } from 'react'
import { invalidateTeamDashboard } from '@/lib/teamDashboardCache'
import { useParams, Navigate, useLocation, useSearchParams } from 'react-router-dom'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import { paths } from '../../config/paths'
import { IconPlus, IconSend } from '@tabler/icons-react'
import {
  Alert,
  Box,
  Button,
  Group,
  Modal,
  Select,
  Stack,
  Text,
  TextInput,
  Title,
} from '@mantine/core'
import { useGetTeam, getGetTeamQueryKey } from '@/api/endpoints/teams/teams'
import {
  useUpdateMemberRole,
  useRemoveMember,
  getGetMembersQueryKey,
} from '@/api/endpoints/team-members/team-members'
import {
  useInvite,
  getListInvitationsQueryKey,
} from '@/api/endpoints/team-invitations/team-invitations'

import { useAuth } from '../../hooks/useAuth'
import { LoadingPage } from '../../components/common/LoadingSpinner'
import { TeamMemberList, TeamMemberListSkeleton } from '../../components/team/TeamMemberList'
import { TeamAdminLayout } from '../../components/team/TeamAdminLayout'
import { TeamInvitationList } from '../../components/team/TeamInvitationList'
import { SearchInput } from '../../components/common/SearchInput'
import { TeamRole } from '@/api/dto'
import { Pagination } from '../../components/common/Pagination'
import { useDebouncedSearch } from '../../hooks/useDebouncedSearch'
import { useScrollToListTop } from '../../hooks/useScrollToListTop'
import { useTeamMembersData } from './teamMembersData'

export function TeamMembersPage() {
  const { t } = useTranslation()
  const { teamSlug } = useParams<{ teamSlug: string }>()
  const { user } = useAuth()
  const queryClient = useQueryClient()
  // « Inviter » on the team dashboard lands here with the dialog open: router state on the web
  // (`OPEN_INVITE_STATE`), `?invite=1` from the mobile dashboard, which opens the site in a browser
  // (mobile `TeamWebPaths.adminMembersInvite`).
  const location = useLocation()
  const [searchParams] = useSearchParams()
  const [showAddMember, setShowAddMember] = useState(
    () =>
      !!(location.state as { openInvite?: boolean } | null)?.openInvite ||
      searchParams.get('invite') === '1'
  )
  const [selectedRole, setSelectedRole] = useState<TeamRole>(TeamRole.MEMBER)
  const [inviteEmail, setInviteEmail] = useState('')

  const { filters, setFilters, members, totalPages } = useTeamMembersData(teamSlug)
  const { data: membersData, isLoading: isLoadingMembers } = members
  const commitSearch = useCallback(
    (value: string) => setFilters({ search: value || undefined }),
    [setFilters]
  )
  const [search, setSearch] = useDebouncedSearch(filters.search ?? '', commitSearch)
  const { listTopRef, scrollToListTop } = useScrollToListTop()

  const { data: team, isLoading: isLoadingTeam } = useGetTeam(teamSlug!, {
    query: { enabled: !!teamSlug },
  })

  const updateRoleMutation = useUpdateMemberRole()
  const removeMemberMutation = useRemoveMember()
  const inviteMutation = useInvite()

  useCanonicalPath(team ? paths.teamAdminMembers(team.slug) : undefined)

  if (isLoadingTeam) {
    return <LoadingPage message={t('loading')} />
  }

  if (!team) {
    return <Navigate to={paths.teams()} replace />
  }

  // Only admins can see member list
  if (team.role !== 'ADMIN') {
    return <Navigate to={paths.team(teamSlug!)} replace />
  }

  const closeInviteModal = () => {
    setShowAddMember(false)
    setSelectedRole(TeamRole.MEMBER)
    setInviteEmail('')
  }

  // The address is the only field, and the server is the authority on it (@Email). This is just the
  // cheap check that spares a round trip on an obviously malformed entry.
  const emailLooksValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(inviteEmail.trim())

  const handleInvite = () => {
    if (!teamSlug || !emailLooksValid) return
    inviteMutation.mutate(
      { teamSlug, data: { email: inviteEmail.trim(), role: selectedRole } },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getListInvitationsQueryKey(teamSlug) })
          notifications.show({
            message: i18next.t('teams.invitations.sent', { email: inviteEmail.trim() }),
            color: 'green',
          })
          closeInviteModal()
        },
        // No Alert here on purpose: axiosMutator already raises a toast carrying the translated
        // errors.api.<CODE>, and a second copy inside the modal is the doubling this codebase
        // already gets wrong elsewhere. What the modal owes the admin is the address they typed,
        // which stays put so a typo can be corrected rather than retyped.
      }
    )
  }

  const handleUpdateRole = (memberId: string, role: TeamRole) => {
    if (!teamSlug) return
    updateRoleMutation.mutate(
      { teamSlug: teamSlug, memberId, data: { role } },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetMembersQueryKey(teamSlug) })
          invalidateTeamDashboard(queryClient, teamSlug)
        },
      }
    )
  }

  const handleRemoveMember = (memberId: string) => {
    if (!teamSlug) return
    removeMemberMutation.mutate(
      { teamSlug: teamSlug, memberId },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getGetTeamQueryKey(teamSlug) })
          queryClient.invalidateQueries({ queryKey: getGetMembersQueryKey(teamSlug) })
          invalidateTeamDashboard(queryClient, teamSlug)
          notifications.show({
            message: i18next.t('teams.notifications.memberRemoved'),
            color: 'green',
          })
        },
      }
    )
  }

  return (
    <TeamAdminLayout team={team} currentTab="members">
      <Box py="md">
        <Group justify="space-between" mb="lg">
          <Title order={2}>{t('teams.admin.tabs.members')}</Title>
          {team.addMemberAllowed && (
            <Button onClick={() => setShowAddMember(true)} leftSection={<IconPlus size={16} />}>
              {t('teams.invitations.invite')}
            </Button>
          )}
        </Group>

        <Group align="flex-end" mb="lg">
          <SearchInput
            id="members-search"
            value={search}
            onChange={setSearch}
            placeholder={t('teams.detail.members.search.placeholder')}
            label={t('teams.detail.members.search.label')}
          />
          <Select
            label={t('teams.detail.members.filterRole')}
            value={filters.role ?? null}
            onChange={(value) => setFilters({ role: (value as TeamRole | null) ?? undefined })}
            data={[
              { value: TeamRole.MEMBER, label: t('roles.MEMBER') },
              { value: TeamRole.ORGANIZER, label: t('roles.ORGANIZER') },
              { value: TeamRole.ADMIN, label: t('roles.ADMIN') },
            ]}
            placeholder={t('teams.detail.members.filterRoleAll')}
            clearable
            w={{ base: '100%', sm: 200 }}
          />
        </Group>

        {isLoadingMembers ? (
          <TeamMemberListSkeleton count={5} />
        ) : membersData?.members && membersData.members.length > 0 ? (
          <>
            <Box ref={listTopRef}>
              <TeamMemberList
                members={membersData.members}
                currentUserRole={team.role}
                currentUserId={user?.id ?? null}
                onUpdateRole={handleUpdateRole}
                onRemoveMember={handleRemoveMember}
                isUpdating={updateRoleMutation.isPending}
                isRemoving={removeMemberMutation.isPending}
              />
            </Box>

            <Box mt="xl">
              <Pagination
                currentPage={filters.page}
                totalPages={totalPages}
                onPageChange={(page) => {
                  setFilters({ page })
                  scrollToListTop()
                }}
              />
            </Box>
          </>
        ) : (
          <Text c="dimmed">
            {search || filters.role
              ? t('teams.detail.members.noResults')
              : t('teams.detail.members.empty')}
          </Text>
        )}

        <Box mt="xl">
          <TeamInvitationList teamSlug={teamSlug!} />
        </Box>

        {/* Invite by e-mail */}
        <Modal
          opened={showAddMember && !!team.addMemberAllowed}
          onClose={closeInviteModal}
          title={t('teams.invitations.invite')}
          size="md"
        >
          <form
            onSubmit={(event) => {
              event.preventDefault()
              handleInvite()
            }}
          >
            <Stack>
              <Alert color="blue" variant="light">
                {t('teams.invitations.consentNotice')}
              </Alert>
              <TextInput
                type="email"
                label={t('teams.invitations.email')}
                placeholder={t('teams.invitations.emailPlaceholder')}
                description={t('teams.invitations.emailHelp')}
                value={inviteEmail}
                onChange={(event) => setInviteEmail(event.currentTarget.value)}
                required
                data-autofocus
              />
              <Select
                label={t('teams.detail.members.role')}
                value={selectedRole}
                onChange={(value) => setSelectedRole(value as TeamRole)}
                data={[
                  { value: TeamRole.MEMBER, label: t('roles.MEMBER') },
                  { value: TeamRole.ORGANIZER, label: t('roles.ORGANIZER') },
                  { value: TeamRole.ADMIN, label: t('roles.ADMIN') },
                ]}
              />
            </Stack>
            <Group mt="md" justify="flex-end">
              <Button
                variant="default"
                onClick={closeInviteModal}
                disabled={inviteMutation.isPending}
              >
                {t('actions.cancelAction')}
              </Button>
              <Button
                type="submit"
                loading={inviteMutation.isPending}
                disabled={!emailLooksValid}
                leftSection={<IconSend size={16} />}
              >
                {t('teams.invitations.send')}
              </Button>
            </Group>
          </form>
        </Modal>
      </Box>
    </TeamAdminLayout>
  )
}
