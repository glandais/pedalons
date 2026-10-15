import { useTranslation } from 'react-i18next'
import { useForm } from '@mantine/form'
import { zodFormValidator } from '@/lib/formUtils'
import { useUnits } from '@/hooks/useUnits'
import {
  TextInput,
  Radio,
  Stack,
  Group,
  Button,
  Text,
  Paper,
  SimpleGrid,
  NumberInput,
  ActionIcon,
  Box,
} from '@mantine/core'
import { TimeInput } from '@mantine/dates'
import { IconX } from '@tabler/icons-react'
import { ReorderControls } from '../common/ReorderControls'
import { MarkdownEditor } from '../common/MarkdownEditor'
import type { RideTemplateRequest, TeamDetailDto } from '@/api/dto'
import { CreateTemplateBody } from '@/api/zod/ride-templates/ride-templates.zod'
import { TagPicker } from '@/components/tag'

interface RideTemplateEditorProps {
  team: TeamDetailDto
  teamSlug: string
  initialValues: RideTemplateRequest
  onSubmit: (data: RideTemplateRequest) => void | Promise<void>
  onCancel: () => void
  isPending: boolean
  submitButtonText?: string
}

export function RideTemplateEditor({
  team,
  teamSlug,
  initialValues,
  onSubmit,
  onCancel,
  isPending,
  submitButtonText,
}: RideTemplateEditorProps) {
  const { t } = useTranslation()
  const { config, speedToDisplay, speedFromDisplay } = useUnits()

  const form = useForm<RideTemplateRequest>({
    validate: zodFormValidator<RideTemplateRequest>(CreateTemplateBody),
    initialValues,
    validateInputOnChange: true,
  })

  const groups = form.values.groups

  const handleAddGroup = () => {
    form.insertListItem('groups', {
      name: `Groupe ${groups.length + 1}`,
    })
  }

  const handleRemoveGroup = (index: number) => {
    form.removeListItem('groups', index)
  }

  const handleMoveGroup = (index: number, direction: 'up' | 'down') => {
    const newIndex = direction === 'up' ? index - 1 : index + 1
    if (newIndex >= 0 && newIndex < groups.length) {
      form.reorderListItem('groups', { from: index, to: newIndex })
    }
  }

  const handleSubmit = (values: RideTemplateRequest) => {
    onSubmit(values)
  }

  return (
    <form onSubmit={form.onSubmit(handleSubmit)}>
      <Stack>
        <TextInput
          label={
            <>
              {t('rideTemplates.form.name.label')}{' '}
              <Text span c="red">
                *
              </Text>
            </>
          }
          placeholder={t('rideTemplates.form.name.placeholder')}
          {...form.getInputProps('name')}
        />

        <Stack gap="xs">
          <Text size="sm" fw={500}>
            {t('form.description')}
          </Text>
          <MarkdownEditor
            value={form.values.markdown || ''}
            onChange={(val) => form.setFieldValue('markdown', val)}
            placeholder={t('form.description')}
            minHeight="150px"
            disabled={isPending}
            ariaLabel={t('form.description')}
          />
        </Stack>

        <NumberInput
          label={t('rideTemplates.form.nextNumber.label')}
          description={t('rideTemplates.form.nextNumber.description')}
          placeholder={t('rideTemplates.form.nextNumber.placeholder')}
          min={0}
          allowDecimal={false}
          allowNegative={false}
          value={form.values.nextNumber ?? ''}
          onChange={(val) => form.setFieldValue('nextNumber', val === '' ? undefined : Number(val))}
          disabled={isPending}
        />

        <TagPicker
          teamSlug={teamSlug}
          type="RIDE"
          value={form.values.tagIds}
          onChange={(ids) => form.setFieldValue('tagIds', ids)}
          disabled={isPending}
        />

        {team.visibility !== 'TEAM' && (
          <Radio.Group label={t('visibility.label')} {...form.getInputProps('visibility')}>
            <Stack gap="xs" mt="xs">
              <Radio value="TEAM" label={t('visibility.team')} />
              <Radio value="PUBLIC_UNLISTED" label={t('visibility.public_unlisted')} />
              <Radio value="PUBLIC" label={t('visibility.public')} />
            </Stack>
          </Radio.Group>
        )}

        <Radio.Group label={t('form.status')} {...form.getInputProps('status')}>
          <Stack gap="xs" mt="xs">
            <Radio value="DRAFT" label={t('status.DRAFT')} />
            <Radio value="PUBLISHED" label={t('status.PUBLISHED')} />
            <Radio value="CANCELLED" label={t('status.CANCELLED')} />
          </Stack>
        </Radio.Group>

        {/* Groups */}
        <Stack gap="xs">
          <Group justify="space-between">
            <Text size="sm" fw={500}>
              {t('rides.create.form.groups.label')}
            </Text>
            <Button variant="subtle" size="xs" onClick={handleAddGroup}>
              {t('groups.add')}
            </Button>
          </Group>

          <Stack gap="sm">
            {groups.map((group, index) => (
              <Paper key={index} withBorder p="sm">
                <Group justify="space-between" mb="sm">
                  <Group gap="xs">
                    <ReorderControls
                      index={index}
                      total={groups.length}
                      onMove={(dir) => handleMoveGroup(index, dir)}
                    />
                    <Text size="sm" fw={500}>
                      {group.name ||
                        t('rides.create.form.groups.defaultName', { number: index + 1 })}
                    </Text>
                  </Group>
                  <Button
                    variant="subtle"
                    size="xs"
                    color="danger"
                    onClick={() => handleRemoveGroup(index)}
                  >
                    {t('rides.create.form.groups.remove')}
                  </Button>
                </Group>

                <SimpleGrid cols={{ base: 1, sm: 4 }} spacing="xs">
                  <TextInput
                    placeholder={t('rides.create.form.groups.name.placeholder')}
                    {...form.getInputProps(`groups.${index}.name`)}
                  />
                  <Box pos="relative">
                    <TimeInput
                      value={form.values.groups[index]?.time || ''}
                      onChange={(e) =>
                        form.setFieldValue(
                          `groups.${index}.time`,
                          e.currentTarget.value || undefined
                        )
                      }
                    />
                    {group.time && (
                      <ActionIcon
                        variant="subtle"
                        size="sm"
                        pos="absolute"
                        right={30}
                        top="50%"
                        style={{ transform: 'translateY(-50%)' }}
                        onClick={() => form.setFieldValue(`groups.${index}.time`, undefined)}
                      >
                        <IconX size={14} />
                      </ActionIcon>
                    )}
                  </Box>
                  <NumberInput
                    placeholder={t('rides.create.form.groups.speed.placeholder', {
                      unit: config.speedUnit,
                    })}
                    min={0}
                    suffix={` ${config.speedUnit}`}
                    value={speedToDisplay(form.values.groups[index]?.averageSpeed) ?? ''}
                    onChange={(val) =>
                      form.setFieldValue(`groups.${index}.averageSpeed`, speedFromDisplay(val))
                    }
                  />
                  <NumberInput
                    placeholder={t('rides.create.form.groups.maxParticipants.placeholder')}
                    min={1}
                    value={form.values.groups[index]?.maxParticipants ?? ''}
                    onChange={(val) =>
                      form.setFieldValue(
                        `groups.${index}.maxParticipants`,
                        val === '' ? undefined : Number(val)
                      )
                    }
                  />
                </SimpleGrid>
              </Paper>
            ))}
            {groups.length === 0 && (
              <Text size="sm" c="dimmed" fs="italic">
                {t('rides.create.form.groups.empty')}
              </Text>
            )}
          </Stack>
          <Text size="xs" c="dimmed">
            {t('rides.create.form.groups.hint')}
          </Text>
        </Stack>

        <Group justify="flex-end" pt="md">
          <Button variant="default" onClick={onCancel} disabled={isPending}>
            {t('actions.cancelAction')}
          </Button>
          <Button type="submit" disabled={isPending || !form.isValid()} loading={isPending}>
            {submitButtonText || t('actions.save')}
          </Button>
        </Group>
      </Stack>
    </form>
  )
}
