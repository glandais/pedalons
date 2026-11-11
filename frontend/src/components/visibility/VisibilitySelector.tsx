import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Alert, Radio, Stack, Text } from '@mantine/core'
import { IconInfoCircle } from '@tabler/icons-react'
import { Visibility } from '@/api/dto'
import { visibilityLabelKey } from './visibilityLabels'

export interface VisibilitySelectorProps {
  /**
   * What the backend lets this content take — `TeamDetailDto.allowedContentVisibilities[kind]` on
   * creation, `permissions.allowedVisibilities` on an edit (see {@link allowedVisibilitiesFor}).
   * Never derived from the team's visibility or the reader's role (docs/LEDGER_*.md WEB-166, D7).
   */
  allowed: Visibility[]
  value: Visibility
  onChange: (value: Visibility) => void
  error?: ReactNode
  /**
   * The team is private (`visibility = TEAM`): « Public » and « Non répertorié » are then readable
   * by link only, out of every list (decision D1). Only chooses the help text, never what is offered.
   */
  teamPrivate: boolean
  /** Under the label, when the field is shown: the editor's own word on what the values mean. */
  description?: string
  /** Why nothing can be chosen, when `allowed` is empty: the editor's own wording. */
  emptyMessage?: string
  disabled?: boolean
}

/**
 * The visibility field of every editor (ride, template, route, trip, post, team page): the values
 * the backend allows, in the order of the `Visibility` enum, and nothing else.
 *
 * - **One value**: nothing to choose, no field — unless the content holds another value, which it
 *   may since the team lost the right to publish outside (plan §4.2): the field then shows that
 *   value, disabled, so the person sees why the save would be refused and picks one of the others.
 * - **No value** (a route used publicly in a team that no longer publishes outside, plan §4.4): an
 *   explanation instead of an empty control.
 */
export function VisibilitySelector({
  allowed,
  value,
  onChange,
  error,
  teamPrivate,
  description,
  emptyMessage,
  disabled,
}: VisibilitySelectorProps) {
  const { t } = useTranslation()

  if (allowed.length === 0) {
    return (
      <Alert
        variant="light"
        color="warning"
        icon={<IconInfoCircle size={18} />}
        title={t('visibility.label')}
        data-testid="visibility-none-allowed"
      >
        {emptyMessage ?? t('visibility.noneAllowed')}
      </Alert>
    )
  }

  const valueAllowed = allowed.includes(value)
  if (allowed.length === 1 && valueAllowed) return null

  // The enum's order, the current value kept in place when it is no longer allowed.
  const shown = Object.values(Visibility).filter((v) => allowed.includes(v) || v === value)
  const offersOutside = allowed.some((v) => v !== Visibility.TEAM)

  // Both go through the group's own description and error, which Mantine ties to the radiogroup's
  // aria-describedby: a screen reader hears why the save would be refused, and what « Public » means
  // in a private team, on entering the group.
  const notAllowed = !valueAllowed && (
    <Text
      component="span"
      display="block"
      size="xs"
      c="warning"
      data-testid="visibility-not-allowed"
    >
      {t('visibility.currentNotAllowed')}
    </Text>
  )
  const privateTeamHint = teamPrivate && offersOutside && (
    <Text
      component="span"
      display="block"
      size="xs"
      c="dimmed"
      data-testid="visibility-private-team-hint"
    >
      {t('visibility.privateTeamHint')}
    </Text>
  )

  return (
    <Radio.Group
      label={t('visibility.label')}
      description={
        description || privateTeamHint ? (
          <>
            {description}
            {privateTeamHint}
          </>
        ) : undefined
      }
      value={value}
      onChange={(v) => onChange(v as Visibility)}
      error={
        error || notAllowed ? (
          <>
            {error}
            {notAllowed}
          </>
        ) : undefined
      }
      data-testid="visibility-selector"
    >
      <Stack gap="xs" mt="xs">
        {shown.map((v) => (
          <Radio
            key={v}
            value={v}
            label={t(visibilityLabelKey(v))}
            disabled={disabled || !allowed.includes(v)}
          />
        ))}
      </Stack>
    </Radio.Group>
  )
}
