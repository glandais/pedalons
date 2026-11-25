import { useState } from 'react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { useForm } from '@mantine/form'
import { notifications } from '@mantine/notifications'
import { IconMail, IconArrowLeft } from '@tabler/icons-react'
import { Center, Paper, Stack, Title, Text, Button, Anchor, TextInput } from '@mantine/core'
import { paths } from '@/config/paths'
import { forgotPassword } from '@/api/endpoints/authentication/authentication'

export function ForgotPasswordPage() {
  const { t } = useTranslation()
  const [isLoading, setIsLoading] = useState(false)
  const [sent, setSent] = useState(false)

  const form = useForm({
    initialValues: { email: '' },
    validate: {
      email: (v) =>
        !v || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v) ? t('auth.validation.email') : null,
    },
  })

  const handleSubmit = async (values: { email: string }) => {
    setIsLoading(true)
    try {
      await forgotPassword(values)
      setSent(true)
    } catch (error: unknown) {
      console.error('Forgot password request failed', error)
      notifications.show({ message: t('auth.errors.resetPasswordFailed'), color: 'red' })
    } finally {
      setIsLoading(false)
    }
  }

  if (sent) {
    return (
      <Center mih="70vh">
        <Paper shadow="lg" radius="lg" p="xl" w="100%" maw={420}>
          <Stack ta="center">
            <IconMail size={48} style={{ margin: '0 auto' }} color="var(--mantine-color-green-6)" />
            <Title order={1} size="h2">
              {t('auth.forgotPassword.sent.title')}
            </Title>
            <Text c="dimmed">{t('auth.forgotPassword.sent.checkEmail')}</Text>
            <Anchor component={PrefetchLink} to={paths.login()} size="sm">
              <IconArrowLeft size={14} style={{ verticalAlign: 'middle', marginRight: 4 }} />
              {t('auth.forgotPassword.backToLogin')}
            </Anchor>
          </Stack>
        </Paper>
      </Center>
    )
  }

  return (
    <Center mih="70vh">
      <Paper shadow="lg" radius="lg" p="xl" w="100%" maw={420}>
        <Stack>
          <Stack gap="xs" ta="center">
            <Title order={1} size="h2">
              {t('auth.forgotPassword.title')}
            </Title>
            <Text c="dimmed">{t('auth.forgotPassword.subtitle')}</Text>
          </Stack>

          <form onSubmit={form.onSubmit(handleSubmit)}>
            <Stack>
              <TextInput
                label={t('auth.form.email')}
                placeholder="email@example.com"
                autoComplete="email"
                {...form.getInputProps('email')}
              />
              <Button type="submit" fullWidth loading={isLoading}>
                {t('auth.forgotPassword.submit')}
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
