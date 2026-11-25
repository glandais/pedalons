import { Fragment } from 'react'
import { useTranslation } from 'react-i18next'
import { Button, Menu, Text, ThemeIcon } from '@mantine/core'
import { IconChevronDown, IconPlus, type Icon } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import type { BadgeFamily } from '@/lib/badgeColors.generated'

/** One thing the button creates. */
export interface CreateAction {
  /** Stable, unique among the actions: the React key and the item's `data-testid` suffix. */
  key: string
  label: string
  icon: Icon
  /** The entity's family from the business colour code, for the item's icon. */
  color: BadgeFamily
  /** Where the action leads. */
  to: string
  /** A second line under the label. */
  description?: string
  /** Set when the action exists but cannot be taken now: the item is disabled, with this reason. */
  disabledReason?: string
  /** The menu section the item sits in; consecutive items sharing it share a label. */
  group?: string
}

/**
 * « Créer une sortie ▾ »: the first available action as the button, every action in the menu behind
 * the chevron, by section. The team's agenda and its dashboard header share it, so the two places
 * an organizer creates from look the same. `fullWidth` stretches it over its row (a phone, as in the
 * app). A single action is a plain button.
 */
export function CreateSplitButton({
  actions,
  fullWidth = false,
}: {
  actions: CreateAction[]
  fullWidth?: boolean
}) {
  const { t } = useTranslation()
  const primary = actions.find((a) => !a.disabledReason)
  if (!primary) return null

  const primaryButton = (
    <Button
      {...linkProps(primary)}
      leftSection={<IconPlus size={16} />}
      fullWidth={fullWidth}
      style={fullWidth ? { flex: 1 } : undefined}
    >
      {primary.label}
    </Button>
  )
  if (actions.length === 1) return primaryButton

  return (
    <Button.Group style={fullWidth ? { width: '100%' } : undefined}>
      {primaryButton}
      <Menu position="bottom-end" width={300} withinPortal>
        <Menu.Target>
          <Button
            px="xs"
            aria-label={t('aria.createOther')}
            // The two halves share a colour: a darker seam tells them apart.
            style={{ borderLeft: '1px solid var(--mantine-color-primary-filled-hover)' }}
          >
            <IconChevronDown size={16} />
          </Button>
        </Menu.Target>
        <Menu.Dropdown>
          {actions.map((action, index) => {
            const previous = actions[index - 1]
            const newGroup = index === 0 || previous.group !== action.group
            return (
              <Fragment key={action.key}>
                {newGroup && index > 0 && <Menu.Divider />}
                {newGroup && action.group && <Menu.Label>{action.group}</Menu.Label>}
                <CreateMenuItem action={action} />
              </Fragment>
            )
          })}
        </Menu.Dropdown>
      </Menu>
    </Button.Group>
  )
}

function CreateMenuItem({ action }: { action: CreateAction }) {
  const ActionGlyph = action.icon
  const icon = (
    <ThemeIcon variant="light" color={action.color} size="lg" radius="md">
      <ActionGlyph size={18} />
    </ThemeIcon>
  )
  const text = (
    <>
      <Text size="sm" fw={500}>
        {action.label}
      </Text>
      {(action.disabledReason ?? action.description) && (
        <Text size="xs" c="dimmed">
          {action.disabledReason ?? action.description}
        </Text>
      )}
    </>
  )
  // Disabled: a plain item, with the reason as its second line.
  if (action.disabledReason) {
    return (
      <Menu.Item disabled data-testid={`create-${action.key}`} leftSection={icon}>
        {text}
      </Menu.Item>
    )
  }
  return (
    <Menu.Item {...linkProps(action)} data-testid={`create-${action.key}`} leftSection={icon}>
      {text}
    </Menu.Item>
  )
}

function linkProps(action: CreateAction) {
  return { component: PrefetchLink, to: action.to }
}
