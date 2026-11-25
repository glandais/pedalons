import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Button, Menu } from '@mantine/core'
import { IconChevronDown, IconPencil } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'

interface EditMenuButtonProps {
  /** Where « Modifier » goes. */
  to: string
  /** Defaults to « Modifier ». */
  label?: string
  /** The menu's `Menu.Item`s: publish, unpublish, cancel, delete… */
  children: ReactNode
}

/**
 * « Modifier ▾ »: the organiser's split button — edit on the left, the page's other actions in the
 * menu on the chevron (docs/LEDGER_*.md WEB-206, rule 4). The same on every detail page that has
 * such a menu.
 */
export function EditMenuButton({ to, label, children }: EditMenuButtonProps) {
  const { t } = useTranslation()
  return (
    <Button.Group>
      <Button
        component={PrefetchLink}
        to={to}
        variant="outline"
        leftSection={<IconPencil size={16} />}
      >
        {label ?? t('actions.edit')}
      </Button>
      <Menu position="bottom-end">
        <Menu.Target>
          <Button variant="outline" px="xs" aria-label={t('aria.manageActions')}>
            <IconChevronDown size={16} />
          </Button>
        </Menu.Target>
        <Menu.Dropdown>{children}</Menu.Dropdown>
      </Menu>
    </Button.Group>
  )
}
