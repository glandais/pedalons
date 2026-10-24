import { useEffect, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { Anchor, Group, MultiSelect, Stack, Text } from '@mantine/core'
import { IconTags } from '@tabler/icons-react'
import { useListTeamTags } from '@/api/endpoints/tags/tags'
import { useGetTeam } from '@/api/endpoints/teams/teams'
import type { TagTarget } from '@/api/dto'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { paths } from '@/config/paths'
import { TagDot } from './TagList'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

/** At most this many tags on one content — the API refuses more (plan D16, `TOO_MANY_TAGS`). */
export const MAX_TAGS_PER_CONTENT = 10

interface TagPickerProps {
  teamSlug: string
  /** The kind of content edited: only that kind's tags apply (plan D3). */
  type: TagTarget
  /** Tag ids, as the request's `tagIds` carries them. */
  value: string[] | undefined
  onChange: (tagIds: string[]) => void
  disabled?: boolean
}

/**
 * The tags of a content being edited, picked among the team's existing tags of its kind — never
 * created here, even by an admin: the vocabulary is only managed from the admin screen (plan D4).
 * Whoever may edit the content may pick any of them (D5).
 *
 * When the team has no tag of this kind, the field becomes a hint, which for an admin links to the
 * admin screen. While the vocabulary loads, or if it fails to, nothing is shown — and `value` is
 * left as it came, so the form sends the content's tags back unchanged.
 *
 * Once the vocabulary is loaded, an id it no longer has — a tag deleted since the content was
 * cached, or copied from a template — is dropped from `value` itself, not only from what is shown:
 * sent back, it would make the API refuse the whole save (`TAG_INVALID`).
 */
export function TagPicker({ teamSlug, type, value, onChange, disabled }: TagPickerProps) {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  // Already in the cache: every editor's page reads its team.
  const { data: team } = useGetTeam(teamSlug, { query: { enabled: !!teamSlug } })
  const { data: tags } = useListTeamTags(teamSlug, { type }, { request: { skipErrorToast: true } })

  const colorById = useMemo(
    () => new Map<string, string>((tags ?? []).map((tag) => [tag.id, tag.color])),
    [tags]
  )

  const known = useMemo(() => (value ?? []).filter((id) => colorById.has(id)), [value, colorById])
  const hasUnknown = !!tags && !!value && known.length !== value.length
  useEffect(() => {
    if (hasUnknown) {
      onChange(known)
    }
  }, [hasUnknown, known, onChange])

  if (!tags) {
    return null
  }

  if (tags.length === 0) {
    return (
      <Stack gap={4}>
        <Text size="sm" fw={500}>
          {t('tags.picker.label')}
        </Text>
        <Text size="sm" c="dimmed">
          {teamAccess(team, isPlatformAdmin).isAdmin ? (
            <>
              {t('tags.picker.emptyAdmin')}{' '}
              <Anchor component={PrefetchLink} to={paths.teamAdminTags(teamSlug)} size="sm">
                {t('tags.picker.manageLink')}
              </Anchor>
            </>
          ) : (
            t('tags.picker.empty')
          )}
        </Text>
      </Stack>
    )
  }

  return (
    <MultiSelect
      label={t('tags.picker.label')}
      description={t('tags.picker.hint', { max: MAX_TAGS_PER_CONTENT })}
      placeholder={known.length === 0 ? t('tags.picker.placeholder') : undefined}
      leftSection={<IconTags size={16} />}
      data={tags.map((tag) => ({ value: tag.id, label: tag.label }))}
      value={known}
      onChange={onChange}
      maxValues={MAX_TAGS_PER_CONTENT}
      renderOption={({ option }) => (
        <Group gap="xs" wrap="nowrap">
          <TagDot color={colorById.get(option.value) ?? 'gray'} />
          <Text size="sm">{option.label}</Text>
        </Group>
      )}
      searchable
      clearable
      hidePickedOptions
      nothingFoundMessage={t('tags.filter.nothingFound')}
      disabled={disabled}
    />
  )
}
