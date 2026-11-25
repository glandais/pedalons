import { useState } from 'react'
import { useSearchParams, useNavigate } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { useForm } from '@mantine/form'
import { notifications } from '@mantine/notifications'
import { IconArrowLeft, IconLock, IconX } from '@tabler/icons-react'
import { Center, Paper, Stack, Title, Text, Button, Anchor, PasswordInput } from '@mantine/core'
import { useAuthStore } from '../../store/authStore'
import { paths } from '@/config/paths'
import { resetPassword as resetPasswordApi } from '@/api/endpoints/authentication/authentication'
import { apiErrorCode } from '@/lib/apiError'

export function ResetPasswordPage() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const token = searchParams.get('token')
  const { setAccessToken, setUser } = useAuthStore()

  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<'invalid' | null>(null)

  const form = useForm({
    initialValues: { newPassword: '', confirmPassword: '' },
    validate: {
      newPassword: (v) => (!v || v.length < 8 ? t('auth.validation.passwordMin') : null),
      confirmPassword: (v, values) =>
        v !== values.newPassword ? t('auth.validation.passwordMismatch') : null,
    },
  })

  if (!token || error === 'invalid') {
    return (
      <Center mih="70vh">
        <Paper shadow="lg" radius="lg" p="xl" w="100%" maw={420}>
          <Stack ta="center">
            <IconX size={48} style={{ margin: '0 auto' }} color="var(--mantine-color-red-6)" />
            <Title order={1} size="h2">
              {t('auth.resetPassword.error.title')}
            </Title>
            <Text c="dimmed">{t('auth.resetPassword.error.message')}</Text>
            <Button component={PrefetchLink} to={paths.forgotPassword()} fullWidth>
              {t('auth.resetPassword.error.requestNew')}
            </Button>
            <Anchor component={PrefetchLink} to={paths.login()} size="sm">
              <IconArrowLeft size={14} style={{ verticalAlign: 'middle', marginRight: 4 }} />
              {t('auth.forgotPassword.backToLogin')}
            </Anchor>
          </Stack>
        </Paper>
      </Center>
    )
  }

  const handleResetPassword = async (values: { newPassword: string }) => {
    setIsLoading(true)
    try {
      // The page says what went wrong itself: the mutator's toast would only repeat it.
      const data = await resetPasswordApi(
        { token, newPassword: values.newPassword },
        { skipErrorToast: true }
      )
      if (data.accessToken) setAccessToken(data.accessToken)
      if (data.user) setUser(data.user)
      navigate(paths.home())
    } catch (err: unknown) {
      console.error('Reset password failed', err)
      const code = apiErrorCode(err)
      if (code === 'TOKEN_INVALID') {
        setError('invalid')
      } else {
        notifications.show({ message: t('auth.errors.resetPasswordFailed'), color: 'red' })
      }
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <Center mih="70vh">
      <Paper shadow="lg" radius="lg" p="xl" w="100%" maw={420}>
        <Stack>
          <Stack gap="xs" ta="center">
            <Title order={1} size="h2">
              {t('auth.resetPassword.title')}
            </Title>
            <Text c="dimmed">{t('auth.resetPassword.subtitle')}</Text>
          </Stack>

          <form onSubmit={form.onSubmit(handleResetPassword)}>
            <Stack>
              <PasswordInput
                label={t('auth.form.newPassword')}
                placeholder={t('auth.form.passwordPlaceholder')}
                autoComplete="new-password"
                leftSection={<IconLock size={16} />}
                {...form.getInputProps('newPassword')}
              />
              <PasswordInput
                label={t('auth.form.confirmPassword')}
                placeholder={t('auth.form.confirmPasswordPlaceholder')}
                autoComplete="new-password"
                leftSection={<IconLock size={16} />}
                {...form.getInputProps('confirmPassword')}
              />
              <Button type="submit" fullWidth loading={isLoading}>
                {t('auth.resetPassword.submit')}
              </Button>
            </Stack>
          </form>

          <Anchor component={PrefetchLink} to={paths.login()} size="sm" ta="center">
            <IconArrowLeft size={14} style={{ verticalAlign: 'middle', marginRight: 4 }} />
            {t('auth.forgotPassword.backToLogin')}
          </Anchor>
        </Stack>
      </Paper>
    </Center>
  )
}
