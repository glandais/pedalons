import { useTranslation } from 'react-i18next'
import { Box, Button, Group, Text, Tooltip, UnstyledButton, useMatches } from '@mantine/core'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useActiveMainNavId, useMainNavItems } from '@/hooks/useNavItems'
import classes from './MainNav.module.css'

/**
 * The site's main navigation in the header, from `sm` up: Fil · Équipes · Calendrier · Explorer ·
 * Fonctionnalités for a visitor, Outils GPX for a member (useMainNavItems, gated like the home
 * section). Links to distinct URLs, hence a
 * named `nav` landmark and `aria-current="page"` — see NavButtons for why not a tablist.
 */
export function HeaderMainNav() {
  const { t } = useTranslation()
  const items = useMainNavItems()
  const activeId = useActiveMainNavId(items)
  // Labels show from `lg` (see MainNav.module.css); below, the icon alone gets a tooltip.
  const iconsOnly = useMatches({ base: true, lg: false })

  return (
    <Box component="nav" aria-label={t('nav.landmark.home')} visibleFrom="sm">
      <Group component="ul" gap={4} wrap="nowrap" className={classes.list}>
        {items.map((item) => {
          const Icon = item.icon
          const isActive = item.id === activeId
          return (
            <li key={item.id}>
              <Tooltip label={item.label} disabled={!iconsOnly} withArrow>
                <UnstyledButton
                  component={PrefetchLink}
                  to={item.path}
                  className={classes.item}
                  // A style prop, not the CSS module: UnstyledButton's own `padding: 0` reset can
                  // land after the module in the production bundle and win.
                  px="sm"
                  aria-current={isActive ? 'page' : undefined}
                  aria-label={item.label}
                >
                  <Icon size={16} aria-hidden />
                  <Text span inherit visibleFrom="lg">
                    {item.label}
                  </Text>
                </UnstyledButton>
              </Tooltip>
            </li>
          )
        })}
      </Group>
    </Box>
  )
}

/** The same entries in the mobile drawer, one full-width button each. */
export function DrawerMainNav({ onNavigate }: { onNavigate: () => void }) {
  const items = useMainNavItems()
  const activeId = useActiveMainNavId(items)

  return (
    <>
      {items.map((item) => {
        const Icon = item.icon
        const isActive = item.id === activeId
        return (
          <Button
            key={item.id}
            variant={isActive ? 'light' : 'subtle'}
            leftSection={<Icon size={16} />}
            component={PrefetchLink}
            to={item.path}
            aria-current={isActive ? 'page' : undefined}
            onClick={onNavigate}
          >
            {item.label}
          </Button>
        )
      })}
    </>
  )
}
