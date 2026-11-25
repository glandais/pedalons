import { useState } from 'react'
import { TransactionalCard } from '@/components/common/TransactionalCard'
import { useTranslation } from 'react-i18next'
import { useForm } from '@mantine/form'
import { notifications } from '@mantine/notifications'
import { IconMail } from '@tabler/icons-react'
import { Stack, Button, TextInput } from '@mantine/core'
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

  const back = { label: t('auth.forgotPassword.backToLogin'), to: paths.login() }

  if (sent) {
    return (
      <TransactionalCard
        icon={<IconMail size={48} color="var(--mantine-color-green-6)" />}
        title={t('auth.forgotPassword.sent.title')}
        description={t('auth.forgotPassword.sent.checkEmail')}
        back={back}
      />
    )
  }

  return (
    <TransactionalCard
      title={t('auth.forgotPassword.title')}
      description={t('auth.forgotPassword.subtitle')}
      back={back}
    >
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
    </TransactionalCard>
  )
}
