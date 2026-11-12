import type { ComponentType } from 'react'
import { useTranslation } from 'react-i18next'
import { Button, Group, Menu } from '@mantine/core'
import {
  IconChevronDown,
  IconPencil,
  IconPlus,
  IconRoute,
  type IconProps,
} from '@tabler/icons-react'
import type { TeamDetailDto } from '@/api/dto'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { paths } from '@/config/paths'
import { canOrganize } from './memberHomeHelpers'

interface QuickActionsProps {
  /** The member's teams (« Mes équipes »). Only those they organize or administer count. */
  teams: TeamDetailDto[] | undefined
}

interface Action {
  key: string
  label: string
  icon: ComponentType<IconProps>
  primary?: boolean
  teams: TeamDetailDto[]
  path: (teamSlug: string) => string
}

/**
 * The organizer's shortcuts on the member home: create a ride, add a route, write a post. Nothing
 * for a plain member. Each one targets the team's own creation form, and only the teams where the
 * module is on (a ride needs the routes module too, as on the team page); with several such teams,
 * the button opens a menu to pick one.
 */
export function QuickActions({ teams }: QuickActionsProps) {
  const { t } = useTranslation()
  const organized = (teams ?? []).filter(canOrganize)
  if (organized.length === 0) return null

  const actions: Action[] = [
    {
      key: 'ride',
      label: t('list.create.ride'),
      icon: IconPlus,
      primary: true,
      teams: organized.filter((team) => team.enableRides && team.enableRoutes),
      path: paths.rideNew,
    },
    {
      key: 'route',
      label: t('list.create.route'),
      icon: IconRoute,
      teams: organized.filter((team) => team.enableRoutes),
      path: paths.routeNew,
    },
    {
      key: 'post',
      label: t('list.create.post'),
      icon: IconPencil,
      teams: organized.filter((team) => team.enablePosts),
      path: paths.postNew,
    },
  ].filter((action) => action.teams.length > 0)

  if (actions.length === 0) return null

  return (
    <Group gap="xs" role="group" aria-label={t('home.actions.label')}>
      {actions.map(({ key, label, icon: Icon, primary, teams: targets, path }) => {
        const variant = primary ? 'filled' : 'default'
        if (targets.length === 1) {
          return (
            <Button
              key={key}
              component={PrefetchLink}
              to={path(targets[0].slug)}
              variant={variant}
              leftSection={<Icon size={16} />}
            >
              {label}
            </Button>
          )
        }
        return (
          <Menu key={key} position="bottom-start" shadow="md">
            <Menu.Target>
              <Button
                variant={variant}
                leftSection={<Icon size={16} />}
                rightSection={<IconChevronDown size={14} />}
              >
                {label}
              </Button>
            </Menu.Target>
            <Menu.Dropdown>
              <Menu.Label>{t('home.actions.pickTeam')}</Menu.Label>
              {targets.map((team) => (
                <Menu.Item key={team.id} component={PrefetchLink} to={path(team.slug)}>
                  {team.name}
                </Menu.Item>
              ))}
            </Menu.Dropdown>
          </Menu>
        )
      })}
    </Group>
  )
}
