import { useForm } from '@mantine/form'
import { useTranslation } from 'react-i18next'
import { Button, Group, Modal, Stack, TextInput } from '@mantine/core'
import { DuplicateRouteBody, duplicateRouteBodyNameMax } from '@/api/zod/routes/routes.zod'
import { zodFormValidator } from '@/lib/formUtils'

interface DuplicateRouteFormValues {
  name: string
}

// Judged on the trimmed name, as the API does (`@NotBlank @Size(min = 3, max = 200)`).
const validateName = zodFormValidator<DuplicateRouteFormValues>(DuplicateRouteBody)

const trimName = (values: DuplicateRouteFormValues): DuplicateRouteFormValues => ({
  name: values.name.trim(),
})

interface DuplicateRouteModalProps {
  /** The source route's name: the field starts at « Copie de {name} ». */
  sourceName: string
  /** The duplication is under way: the submit button spins and the modal cannot be dismissed. */
  loading?: boolean
  /** The name is the only thing sent: the API copies every other attribute (ledger WEB-168). */
  onSubmit: (name: string) => void
  onClose: () => void
}

/**
 * Asks for the copy's name before an organizer duplicates a route (ledger WEB-168). The page
 * runs the call: it owns the cache, the notification and the redirection to the copy's edit page.
 */
export function DuplicateRouteModal({
  sourceName,
  loading = false,
  onSubmit,
  onClose,
}: DuplicateRouteModalProps) {
  const { t } = useTranslation()
  const form = useForm<DuplicateRouteFormValues>({
    // A long name would make the default too long to submit: it is cut to what the API takes.
    initialValues: {
      name: t('routes.duplicate.defaultName', { name: sourceName }).slice(
        0,
        duplicateRouteBodyNameMax
      ),
    },
    validate: (values) => validateName(trimName(values)),
    transformValues: trimName,
    validateInputOnChange: true,
  })

  return (
    <Modal
      opened
      onClose={loading ? () => {} : onClose}
      title={t('routes.duplicate.title')}
      size="md"
    >
      <form onSubmit={form.onSubmit((values) => onSubmit(values.name))}>
        <Stack>
          <TextInput
            label={t('routes.duplicate.nameLabel')}
            maxLength={duplicateRouteBodyNameMax}
            withAsterisk
            data-autofocus
            {...form.getInputProps('name')}
          />
          <Group justify="flex-end" pt="md">
            <Button variant="default" onClick={onClose} disabled={loading}>
              {t('actions.cancelAction')}
            </Button>
            <Button type="submit" loading={loading} disabled={!form.isValid()}>
              {t('routes.duplicate.submit')}
            </Button>
          </Group>
        </Stack>
      </form>
    </Modal>
  )
}
