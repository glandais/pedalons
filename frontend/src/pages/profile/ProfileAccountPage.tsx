import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useForm } from '@mantine/form'
import { Box, Button, Center, Group, Loader, Stack, Text, TextInput, Title } from '@mantine/core'
import { IconCamera, IconTrash } from '@tabler/icons-react'
import { useGetMyDeletionImpact } from '@/api/endpoints/users/users'
import { UpdateMeBody } from '@/api/zod/users/users.zod'
import type { UpdateUserRequest } from '@/api/dto'
import { ConfirmDialog } from '@/components/common/ConfirmDialog'
import { UserAvatar } from '@/components/common/UserAvatar'
import { AccountDeletionImpact } from '@/components/profile/AccountDeletionImpact'
import { ProfileCard, ProfileShell } from '@/components/profile/ProfileShell'
import { useAuth } from '@/hooks/useAuth'
import { zodFormValidator } from '@/lib/formUtils'

/**
 * « Mon compte »: the photo, the display name — a field always editable, saved by its own button,
 * where there used to be a « Modifier le profil » mode — the address, read-only, and the danger
 * zone. The identity card of the overview leads here.
 */
export function ProfileAccountPage() {
  const { t } = useTranslation()
  const {
    user,
    isLoading,
    updateProfile,
    isUpdatingProfile,
    deleteAccount,
    isDeletingAccount,
    uploadAvatar,
    isUploadingAvatar,
    deleteAvatar,
    isDeletingAvatar,
  } = useAuth()

  const avatarInputRef = useRef<HTMLInputElement>(null)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  // Read when the confirmation opens, and again on every opening: a team may have gained a member
  // or an admin since.
  const deletionImpact = useGetMyDeletionImpact({
    query: { enabled: showDeleteConfirm, staleTime: 0 },
  })
  const deletionBlocked = deletionImpact.data?.blocked === true

  const form = useForm<UpdateUserRequest>({
    validate: zodFormValidator<UpdateUserRequest>(UpdateMeBody),
    validateInputOnChange: true,
    initialValues: { displayName: user?.displayName ?? '' },
  })

  // The saved name is the form's reference: once saved (or once /me lands), « Enregistrer » goes
  // back to disabled until the next edit.
  const savedName = user?.displayName
  useEffect(() => {
    if (savedName === undefined) return
    form.setInitialValues({ displayName: savedName })
    form.setValues({ displayName: savedName })
    form.resetDirty({ displayName: savedName })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [savedName])

  if (isLoading || !user) {
    return (
      <Center py="xl">
        <Loader size="lg" />
      </Center>
    )
  }

  const handleSubmit = (values: UpdateUserRequest) => {
    updateProfile({ displayName: values.displayName?.trim() })
  }

  const handleDelete = () => {
    // A refusal (SOLE_TEAM_ADMIN: the last admin of a team others still belong to) is toasted by
    // the API client; the dialog closes so the message is not left behind a confirmation that
    // can only fail again.
    deleteAccount(undefined, { onError: () => setShowDeleteConfirm(false) })
  }

  const handleAvatarSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      uploadAvatar(file)
    }
    if (avatarInputRef.current) {
      avatarInputRef.current.value = ''
    }
  }

  return (
    <ProfileShell section="account" title={t('profile.nav.account')}>
      <ProfileCard>
        <Stack gap="sm">
          <Title order={2} size="h5">
            {t('profile.account.photo')}
          </Title>
          <Group gap="lg" wrap="wrap">
            <UserAvatar user={user} size="xl" />
            <input
              ref={avatarInputRef}
              type="file"
              accept="image/*,.heic,.heif"
              onChange={handleAvatarSelect}
              style={{ display: 'none' }}
            />
            <Group gap="xs">
              <Button
                variant="default"
                leftSection={<IconCamera size={16} />}
                onClick={() => avatarInputRef.current?.click()}
                loading={isUploadingAvatar}
              >
                {t('profile.avatar.upload')}
              </Button>
              {user.avatarUrl && (
                <Button
                  variant="subtle"
                  color="danger"
                  leftSection={<IconTrash size={16} />}
                  onClick={() => deleteAvatar()}
                  loading={isDeletingAvatar}
                >
                  {t('profile.avatar.remove')}
                </Button>
              )}
            </Group>
          </Group>
        </Stack>
      </ProfileCard>

      <ProfileCard>
        <form onSubmit={form.onSubmit(handleSubmit)}>
          <Stack gap="md">
            <TextInput
              label={t('profile.form.displayName.label')}
              {...form.getInputProps('displayName')}
            />
            <TextInput
              label={t('profile.form.email.label')}
              description={t('profile.form.email.readOnly')}
              value={user.email}
              readOnly
              variant="filled"
            />
            <Group>
              <Button
                type="submit"
                disabled={isUpdatingProfile || !form.isDirty() || !form.isValid()}
                loading={isUpdatingProfile}
              >
                {t('actions.save')}
              </Button>
            </Group>
          </Stack>
        </form>
      </ProfileCard>

      <ProfileCard tone="danger">
        <Box>
          <Title order={2} size="h5" c="danger">
            {t('profile.account.dangerZone.title')}
          </Title>
          <Text size="sm" c="dimmed" mt={4}>
            {t('profile.account.dangerZone.deleteDescription')}
          </Text>
          <Button
            variant="outline"
            color="danger"
            mt="md"
            onClick={() => setShowDeleteConfirm(true)}
          >
            {t('profile.account.dangerZone.deleteButton')}
          </Button>
        </Box>
      </ProfileCard>

      <ConfirmDialog
        isOpen={showDeleteConfirm}
        onClose={() => setShowDeleteConfirm(false)}
        onConfirm={handleDelete}
        title={t('profile.account.dangerZone.title')}
        message={
          <AccountDeletionImpact
            impact={deletionImpact.data}
            isLoading={deletionImpact.isFetching}
          />
        }
        confirmText={t('profile.account.dangerZone.confirmButton')}
        variant="danger"
        isLoading={isDeletingAccount}
        confirmDisabled={deletionImpact.isFetching || deletionBlocked}
      />
    </ProfileShell>
  )
}
