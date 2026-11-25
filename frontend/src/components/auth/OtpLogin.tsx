import { useEffect, useState } from 'react'
import { useTranslation, Trans } from 'react-i18next'
import { useForm } from '@mantine/form'
import { notifications } from '@mantine/notifications'
import { IconArrowLeft, IconMail } from '@tabler/icons-react'
import {
  Anchor,
  Button,
  Group,
  PinInput,
  Stack,
  Text,
  TextInput,
  Title,
  type TitleOrder,
} from '@mantine/core'
import { requestOtp, verifyOtp } from '@/api/endpoints/authentication/authentication'
import type { AuthResponse } from '@/api/dto'

// Matches the server's silent rate limit (3 codes per 5 minutes) closely enough that a user who
// waits out the countdown is not quietly refused.
const RESEND_COOLDOWN_SECONDS = 60
const CODE_LENGTH = 6
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

interface OtpLoginProps {
  initialEmail: string
  onSuccess: (response: AuthResponse) => void
  onBack: () => void
  titleOrder: TitleOrder
}

/**
 * Passwordless sign-in: an e-mailed 6-digit code, through `POST /api/auth/otp` then
 * `/api/auth/otp/verify`. For members migrated without a password, or who simply prefer it.
 *
 * The request step always "succeeds" — the server answers the same for an unknown address, so as
 * not to reveal which ones have an account — hence the neutral « a code has been sent to … ».
 */
export function OtpLogin({ initialEmail, onSuccess, onBack, titleOrder }: OtpLoginProps) {
  const { t } = useTranslation()
  const [sentTo, setSentTo] = useState<string | null>(null)
  const [code, setCode] = useState('')
  const [codeError, setCodeError] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [cooldown, setCooldown] = useState(0)

  useEffect(() => {
    if (cooldown <= 0) return
    const timer = setTimeout(() => setCooldown((seconds) => seconds - 1), 1000)
    return () => clearTimeout(timer)
  }, [cooldown])

  const emailForm = useForm({
    initialValues: { email: initialEmail },
    validate: {
      email: (v) => (!v || !EMAIL_PATTERN.test(v) ? t('auth.validation.email') : null),
    },
  })

  const sendCode = async (email: string) => {
    setIsLoading(true)
    try {
      await requestOtp({ email }, { skipErrorToast: true })
      setSentTo(email)
      setCode('')
      setCodeError(null)
      setCooldown(RESEND_COOLDOWN_SECONDS)
    } catch {
      notifications.show({ message: t('auth.errors.otpFailed'), color: 'red' })
    } finally {
      setIsLoading(false)
    }
  }

  const submitCode = async (value: string) => {
    if (!sentTo || value.length !== CODE_LENGTH) return
    setIsLoading(true)
    setCodeError(null)
    try {
      onSuccess(await verifyOtp({ email: sentTo, code: value }, { skipErrorToast: true }))
    } catch {
      // One message for a wrong, an expired and a burnt code alike: the fix is the same — retype
      // it, or ask for another.
      setCodeError(t('auth.errors.otpInvalid'))
      setCode('')
    } finally {
      setIsLoading(false)
    }
  }

  if (!sentTo) {
    return (
      <Stack>
        <Stack gap="xs" ta="center">
          <Title order={titleOrder} size="h2">
            {t('auth.otp.title')}
          </Title>
          <Text c="dimmed">{t('auth.otp.description')}</Text>
        </Stack>

        <form onSubmit={emailForm.onSubmit(({ email }) => sendCode(email))}>
          <Stack>
            <TextInput
              label={t('auth.form.email')}
              placeholder="email@example.com"
              name="email"
              autoComplete="email"
              {...emailForm.getInputProps('email')}
            />
            <Button
              type="submit"
              fullWidth
              loading={isLoading}
              leftSection={<IconMail size={20} />}
            >
              {t('auth.otp.send')}
            </Button>
          </Stack>
        </form>

        <Anchor component="button" size="sm" onClick={onBack}>
          <Group gap={4} justify="center">
            <IconArrowLeft size={14} />
            {t('actions.back')}
          </Group>
        </Anchor>
      </Stack>
    )
  }

  return (
    <Stack>
      <Stack gap="xs" ta="center">
        <Title order={titleOrder} size="h2">
          {t('auth.otp.verify.title')}
        </Title>
        <Text c="dimmed">
          <Trans
            i18nKey="auth.otp.verify.sentTo"
            values={{ email: sentTo }}
            components={{ strong: <strong /> }}
          />
        </Text>
        <Text size="sm" c="dimmed">
          {t('auth.otp.verify.instruction')}
        </Text>
      </Stack>

      <form
        onSubmit={(event) => {
          event.preventDefault()
          submitCode(code)
        }}
      >
        <Stack align="center">
          <PinInput
            length={CODE_LENGTH}
            type="number"
            oneTimeCode
            autoFocus
            value={code}
            onChange={(value) => {
              setCode(value)
              setCodeError(null)
            }}
            // Submitting on the sixth digit spares a click, and a pasted code logs in at once.
            onComplete={submitCode}
            error={!!codeError}
            disabled={isLoading}
            // One name per cell. `aria-label` would land on the wrapping Group, a role-less div,
            // and Mantine's own `ariaLabel` gives all six the same English « PinInput ».
            getInputProps={(index) => ({
              'aria-label': t('auth.otp.verify.digit', {
                position: index + 1,
                length: CODE_LENGTH,
              }),
            })}
          />
          {codeError && (
            <Text size="sm" c="red" role="alert">
              {codeError}
            </Text>
          )}
          <Button
            type="submit"
            fullWidth
            loading={isLoading}
            disabled={code.length !== CODE_LENGTH}
          >
            {t('auth.login.button')}
          </Button>
        </Stack>
      </form>

      <Group justify="space-between">
        <Anchor component="button" size="sm" onClick={() => setSentTo(null)}>
          <Group gap={4}>
            <IconArrowLeft size={14} />
            {t('actions.back')}
          </Group>
        </Anchor>
        <Anchor
          component="button"
          size="sm"
          disabled={cooldown > 0 || isLoading}
          onClick={() => sendCode(sentTo)}
          c={cooldown > 0 ? 'dimmed' : undefined}
        >
          {cooldown > 0 ? t('auth.otp.resendIn', { seconds: cooldown }) : t('auth.otp.resend')}
        </Anchor>
      </Group>
    </Stack>
  )
}
