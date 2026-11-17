import { Fragment, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { ActionIcon, Button, Menu, Text, ThemeIcon, Tooltip } from '@mantine/core'
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
  /** Load the page in full rather than through the router (the route editor: `RoutesListHeader`
   * links it the same way). */
  reloadDocument?: boolean
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
 * an organizer creates from look the same. With `compact` (a phone, in a header) it is one `+`
 * icon opening the menu. A single action is a plain button.
 */
export function CreateSplitButton({
  actions,
  compact = false,
}: {
  actions: CreateAction[]
  compact?: boolean
}) {
  const { t } = useTranslation()
  const primary = actions.find((a) => !a.disabledReason)
  if (!primary) return null

  if (actions.length === 1) {
    return compact ? (
      <Tooltip label={primary.label}>
        <ActionIcon {...linkProps(primary)} variant="filled" aria-label={primary.label} size="lg">
          <IconPlus size={18} />
        </ActionIcon>
      </Tooltip>
    ) : (
      <Button {...linkProps(primary)} leftSection={<IconPlus size={16} />}>
        {primary.label}
      </Button>
    )
  }

  const menu = (target: ReactNode) => (
    <Menu position="bottom-end" width={300} withinPortal>
      <Menu.Target>{target}</Menu.Target>
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
  )

  if (compact) {
    return menu(
      <ActionIcon variant="filled" size="lg" aria-label={t('actions.new')}>
        <IconPlus size={18} />
      </ActionIcon>
    )
  }

  return (
    <Button.Group>
      <Button {...linkProps(primary)} leftSection={<IconPlus size={16} />}>
        {primary.label}
      </Button>
      {menu(
        <Button px="xs" aria-label={t('aria.createOther')}>
          <IconChevronDown size={16} />
        </Button>
      )}
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
  return action.reloadDocument
    ? { component: PrefetchLink, to: action.to, reloadDocument: true, prefetch: 'none' as const }
    : { component: PrefetchLink, to: action.to }
}
