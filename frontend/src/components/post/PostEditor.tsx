import { VisibilitySelector } from '@/components/visibility/VisibilitySelector'
import { allowedVisibilitiesFor } from '@/components/visibility/visibilityLabels'
import { Visibility } from '@/api/dto'
import { useEffect, useMemo } from 'react'
import { useForm } from '@mantine/form'
import { zodFormValidator } from '@/lib/formUtils'
import { useTranslation } from 'react-i18next'
import { TextInput, Radio, Stack, Group, Button, Text, Checkbox } from '@mantine/core'
import { WallDateTimePicker } from '@/components/common/WallDateTimePicker'
import type { TeamDetailDto } from '@/api/dto'
import { MediaEditor } from '../common/MediaEditor'
import { SlugEditor } from '../common/SlugEditor'
import { paths } from '@/config/paths'
import { Status, PostRequest } from '@/api/dto'
import { CreatePostBody } from '@/api/zod/posts/posts.zod'
import { TagPicker } from '@/components/tag'
import { wallTimeToInstant } from '@/utils/wallTime'

interface PostEditorProps {
  team: TeamDetailDto
  /**
   * The visibilities this content may take, from the entity being edited
   * (`permissions.allowedVisibilities`); the team's list for its kind when absent (creation).
   */
  allowedVisibilities?: Visibility[]
  teamSlug: string
  initialValues: PostRequest
  onSubmit: (data: PostRequest) => void | Promise<void>
  onCancel: () => void
  isPending: boolean
  submitButtonText?: string
  cancelButtonText?: string
  currentSlug?: string
  onSlugChange?: (newSlug: string) => Promise<void>
  canEditSlug?: boolean
  /**
   * The zone the API gave the post being edited (`PostDto.timezone`), which its wall times were
   * converted in; the team's on creation — a post has no place (docs/LEDGER_*.md API-60).
   */
  timezone?: string
}

export function PostEditor({
  team,
  allowedVisibilities,
  teamSlug,
  initialValues,
  onSubmit,
  onCancel,
  isPending,
  submitButtonText,
  cancelButtonText,
  currentSlug,
  onSlugChange,
  canEditSlug = false,
  timezone,
}: PostEditorProps) {
  const { t } = useTranslation()
  const zone = timezone ?? team.timezone

  const postSchema = useMemo(
    () =>
      CreatePostBody.refine(
        (data) => {
          if (data.status === Status.DRAFT && data.publishAt) {
            // A wall time of the post's zone, not the browser's (docs/LEDGER_*.md API-60).
            return wallTimeToInstant(data.publishAt, zone) > new Date()
          }
          return true
        },
        {
          message: t('form.publishAt.futureRequired'),
          path: ['publishAt'],
        }
      ),
    [t, zone]
  )

  const form = useForm<PostRequest>({
    validate: zodFormValidator<PostRequest>(postSchema),
    initialValues,
    validateInputOnChange: true,
  })

  const status = form.values.status

  useEffect(() => {
    form.validateField('publishAt')
  }, [status, form])

  const handleSubmit = (values: PostRequest) => {
    onSubmit(values)
  }

  return (
    <form onSubmit={form.onSubmit(handleSubmit)}>
      <Stack>
        <TextInput
          label={
            <>
              {t('form.title')}{' '}
              <Text span c="red">
                *
              </Text>
            </>
          }
          placeholder={t('posts.create.namePlaceholder')}
          {...form.getInputProps('name')}
        />

        {currentSlug && onSlugChange && (
          <SlugEditor
            currentSlug={currentSlug}
            baseUrl={paths.post(teamSlug, '')}
            onSlugChange={onSlugChange}
            disabled={!canEditSlug}
          />
        )}

        <Stack gap="xs">
          <Text size="sm" fw={500}>
            {t('form.description')}
          </Text>
          <MediaEditor
            value={form.values.media}
            onChange={(val) => form.setFieldValue('media', val)}
            placeholder={t('posts.create.descriptionPlaceholder')}
            minHeight="200px"
            disabled={isPending}
            ariaLabel={t('form.description')}
            teamSlug={teamSlug}
          />
        </Stack>

        <TagPicker
          teamSlug={teamSlug}
          type="POST"
          value={form.values.tagIds}
          onChange={(ids) => form.setFieldValue('tagIds', ids)}
          disabled={isPending}
        />

        <VisibilitySelector
          allowed={allowedVisibilities ?? allowedVisibilitiesFor(team, 'post')}
          value={form.values.visibility}
          onChange={(v) => form.setFieldValue('visibility', v)}
          error={form.errors.visibility}
          teamPrivate={team.visibility === Visibility.TEAM}
          disabled={isPending}
        />

        <Checkbox
          label={t('posts.form.signedAsTeam.label', { team: team.name })}
          description={t('posts.form.signedAsTeam.hint')}
          {...form.getInputProps('signedAsTeam', { type: 'checkbox' })}
        />

        <Radio.Group label={t('form.status')} {...form.getInputProps('status')}>
          <Stack gap="xs" mt="xs">
            <Radio value="DRAFT" label={t('status.DRAFT')} />
            <Radio value="PUBLISHED" label={t('status.PUBLISHED')} />
          </Stack>
        </Radio.Group>

        {status === Status.PUBLISHED && (
          <WallDateTimePicker
            label={
              <>
                {t('posts.create.dateTimeLabel')}{' '}
                <Text span c="red">
                  *
                </Text>
              </>
            }
            description={t('posts.create.dateTimeHint')}
            value={form.values.dateTime}
            onChange={(wall) => {
              if (wall) form.setFieldValue('dateTime', wall)
            }}
            zone={zone}
            error={form.errors.dateTime}
          />
        )}

        {status === Status.DRAFT && (
          <WallDateTimePicker
            label={t('posts.create.publishAtLabel')}
            description={t('form.publishAtHint')}
            value={form.values.publishAt}
            onChange={(wall) => form.setFieldValue('publishAt', wall)}
            zone={zone}
            error={form.errors.publishAt}
            clearable
          />
        )}

        <Group justify="flex-end" pt="md">
          <Button variant="default" onClick={onCancel}>
            {cancelButtonText || t('actions.cancelAction')}
          </Button>
          <Button type="submit" disabled={isPending || !form.isValid()} loading={isPending}>
            {submitButtonText || t('actions.save')}
          </Button>
        </Group>
      </Stack>
    </form>
  )
}
