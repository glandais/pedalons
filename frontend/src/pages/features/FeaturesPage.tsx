import type { MouseEvent } from 'react'
import { useLocation } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  Badge,
  Box,
  Button,
  Group,
  List,
  Paper,
  SimpleGrid,
  Stack,
  Text,
  ThemeIcon,
  Title,
} from '@mantine/core'
import {
  IconArrowLeft,
  IconBike,
  IconCalendar,
  IconCheck,
  IconCloudRain,
  IconDeviceWatch,
  IconLock,
  IconLogin,
  IconMap2,
  IconNews,
  IconRoute,
  IconTags,
  type TablerIcon,
} from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { RoleBadge } from '@/components/card/common'
import { useAuth } from '@/hooks/useAuth'
import { isSingleTeam } from '@/config/appConfig'
import { paths } from '@/config/paths'
import { PUBLICATION_TYPE_COLORS } from '@/lib/badgeColors.generated'
import type { TeamRole } from '@/api/dto'
import { FeatureSection, type FeatureSectionProps } from './FeatureSection'
import { RideGroupsVisual } from './visuals/RideGroupsVisual'
import { RouteVisual } from './visuals/RouteVisual'
import { TripVisual } from './visuals/TripVisual'
import { PostVisual } from './visuals/PostVisual'
import { AdVisual } from './visuals/AdVisual'
import { CalendarVisual } from './visuals/CalendarVisual'
import { DevicesVisual } from './visuals/DevicesVisual'
import { PrivacyVisual } from './visuals/PrivacyVisual'
import { WeatherVisual } from './visuals/WeatherVisual'

type Section = Omit<FeatureSectionProps, 'reverse'> & { chip: string }

/**
 * Jump to a section without a hash navigation: React Router would read the hash change as a POP
 * and hand it to useScrollRestoration (the skip link in Layout does the same for the same reason).
 * The hash is still written, by replaceState, so the address bar can be shared.
 */
function jumpTo(event: MouseEvent<HTMLAnchorElement>, id: string) {
  const target = document.getElementById(id)
  if (!target) return
  event.preventDefault()
  const reduceMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
  target.scrollIntoView({ behavior: reduceMotion ? 'auto' : 'smooth', block: 'start' })
  window.history.replaceState(window.history.state, '', `#${id}`)
}

/**
 * The features page (`/fonctionnalites`, `/features`): a static presentation of the product, for
 * visitors first. Server-rendered, no API call — every illustration is a presentational component
 * fed with fictional demo content from the translations.
 */
export function FeaturesPage() {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()
  const location = useLocation()
  const singleTeam = isSingleTeam()

  const sections: Section[] = [
    {
      id: 'rides',
      color: PUBLICATION_TYPE_COLORS.RIDE,
      icon: IconBike,
      chip: t('features.rides.eyebrow'),
      eyebrow: t('features.rides.eyebrow'),
      title: t('features.rides.title'),
      lead: t('features.rides.lead'),
      points: [
        t('features.rides.point1'),
        t('features.rides.point2'),
        t('features.rides.point3'),
        t('features.rides.point4'),
      ],
      visual: <RideGroupsVisual />,
    },
    {
      id: 'routes',
      // Routes have no business colour of their own (contracts/brand-colors.yaml): the brand's.
      color: 'primary',
      icon: IconRoute,
      chip: t('features.routes.eyebrow'),
      eyebrow: t('features.routes.eyebrow'),
      title: t('features.routes.title'),
      lead: t('features.routes.lead'),
      points: [
        t('features.routes.point1'),
        t('features.routes.point2'),
        t('features.routes.point3'),
        t('features.routes.point4'),
        t('features.routes.point5'),
      ],
      visual: <RouteVisual />,
    },
    {
      id: 'trips',
      color: PUBLICATION_TYPE_COLORS.TRIP,
      icon: IconMap2,
      chip: t('features.trips.eyebrow'),
      eyebrow: t('features.trips.eyebrow'),
      title: t('features.trips.title'),
      lead: t('features.trips.lead'),
      points: [
        t('features.trips.point1'),
        t('features.trips.point2'),
        t('features.trips.point3'),
        t('features.trips.point4'),
      ],
      visual: <TripVisual />,
    },
    {
      id: 'weather',
      // Weather has no business colour of its own (contracts/brand-colors.yaml): a sky tint.
      color: 'cyan',
      icon: IconCloudRain,
      chip: t('features.weather.eyebrow'),
      eyebrow: t('features.weather.eyebrow'),
      title: t('features.weather.title'),
      lead: t('features.weather.lead'),
      points: [
        t('features.weather.point1'),
        t('features.weather.point2'),
        t('features.weather.point3'),
        t('features.weather.point4'),
      ],
      visual: <WeatherVisual />,
    },
    {
      id: 'posts',
      color: PUBLICATION_TYPE_COLORS.POST,
      icon: IconNews,
      chip: t('features.posts.eyebrow'),
      eyebrow: t('features.posts.eyebrow'),
      title: t('features.posts.title'),
      lead: t('features.posts.lead'),
      points: [t('features.posts.point1'), t('features.posts.point2'), t('features.posts.point3')],
      visual: <PostVisual />,
    },
    {
      id: 'ads',
      color: 'orange',
      icon: IconTags,
      chip: t('features.ads.eyebrow'),
      eyebrow: t('features.ads.eyebrow'),
      title: t('features.ads.title'),
      lead: t('features.ads.lead'),
      points: [t('features.ads.point1'), t('features.ads.point2'), t('features.ads.point3')],
      visual: <AdVisual />,
    },
    {
      id: 'calendar',
      color: 'primary',
      icon: IconCalendar,
      chip: t('features.calendar.chip'),
      eyebrow: t('features.calendar.eyebrow'),
      title: t('features.calendar.title'),
      lead: t('features.calendar.lead'),
      points: [
        t('features.calendar.point1'),
        t('features.calendar.point2'),
        t('features.calendar.point3'),
        t('features.calendar.point4'),
        t('features.calendar.point5'),
      ],
      visual: <CalendarVisual />,
    },
    {
      id: 'devices',
      color: 'gray',
      icon: IconDeviceWatch,
      chip: t('features.devices.eyebrow'),
      eyebrow: t('features.devices.eyebrow'),
      title: t('features.devices.title'),
      lead: t('features.devices.lead'),
      points: [
        t('features.devices.karoo'),
        t('features.devices.garmin'),
        t('features.devices.wahoo'),
      ],
      visual: <DevicesVisual />,
    },
    {
      id: 'privacy',
      color: 'gray',
      icon: IconLock,
      chip: t('features.privacy.eyebrow'),
      eyebrow: t('features.privacy.eyebrow'),
      title: t('features.privacy.title'),
      lead: t('features.privacy.lead'),
      points: [
        t('features.privacy.point1'),
        t('features.privacy.point2'),
        t('features.privacy.point3'),
        t('features.privacy.point4'),
      ],
      visual: <PrivacyVisual />,
    },
  ]

  const roles: { role: TeamRole; title: string; points: string[] }[] = [
    {
      role: 'MEMBER',
      title: t('features.roles.member.title'),
      points: [
        t('features.roles.member.point1'),
        t('features.roles.member.point2'),
        t('features.roles.member.point3'),
        t('features.roles.member.point4'),
      ],
    },
    {
      role: 'ORGANIZER',
      title: t('features.roles.organizer.title'),
      points: [
        t('features.roles.organizer.point1'),
        t('features.roles.organizer.point2'),
        t('features.roles.organizer.point3'),
        t('features.roles.organizer.point4'),
      ],
    },
    {
      role: 'ADMIN',
      title: t('features.roles.admin.title'),
      points: [
        t('features.roles.admin.point1'),
        t('features.roles.admin.point2'),
        t('features.roles.admin.point3'),
        t('features.roles.admin.point4'),
      ],
    },
  ]

  // Sign-up and sign-in both go through the login page; sign-up opens it on its register step.
  const signInLink = { component: PrefetchLink, to: paths.login(), state: { from: location } }
  const signUpLink = {
    component: PrefetchLink,
    to: paths.login(),
    state: { from: location, mode: 'register' },
  }

  return (
    <Stack gap={0} pb={{ base: 0, sm: 'xl' }}>
      {/* Hero */}
      <section aria-labelledby="features-hero-title" className="features-hero">
        <Stack align="center" ta="center" gap="lg" maw={880} mx="auto">
          <Badge variant="light" size="sm">
            {t('features.hero.eyebrow')}
          </Badge>
          <Title
            order={1}
            id="features-hero-title"
            fz={{ base: 30, sm: 48 }}
            lh={{ base: 1.15, sm: 1.1 }}
            c="var(--mantine-color-bright)"
          >
            {t('features.hero.title')}
          </Title>
          <Text size="lg" maw={640} c="var(--mantine-primary-color-light-color)">
            {t('features.hero.subtitle')}
          </Text>
          {isAuthenticated ? (
            <Button
              size="md"
              component={PrefetchLink}
              to={paths.home()}
              leftSection={<IconArrowLeft size={18} />}
            >
              {t('features.cta.backToFeed')}
            </Button>
          ) : (
            <Group justify="center" gap="sm" visibleFrom="sm">
              <Button size="md" {...signUpLink}>
                {t('features.cta.signUp')}
              </Button>
              <Button
                size="md"
                variant="default"
                leftSection={<IconLogin size={18} />}
                {...signInLink}
              >
                {t('features.cta.signIn')}
              </Button>
            </Group>
          )}
          <nav aria-label={t('features.jump.label')} className="features-chips">
            {sections.map((section) => {
              const Icon: TablerIcon = section.icon
              return (
                <a
                  key={section.id}
                  href={`#${section.id}`}
                  className="features-chip"
                  onClick={(event) => jumpTo(event, section.id)}
                >
                  <Icon size={16} aria-hidden />
                  {section.chip}
                </a>
              )
            })}
          </nav>
        </Stack>
      </section>

      {/* Features */}
      <Box px={{ base: 'xs', sm: 'md' }}>
        {sections.map((section, index) => (
          <FeatureSection key={section.id} {...section} reverse={index % 2 === 1} />
        ))}

        {/* Roles */}
        <section aria-labelledby="features-roles-title" className="features-section">
          <Stack gap="lg">
            <Stack gap="xs" align="center" ta="center">
              <Title order={2} id="features-roles-title">
                {t('features.roles.title')}
              </Title>
              <Text size="lg" c="dimmed" maw={600}>
                {t('features.roles.subtitle')}
              </Text>
            </Stack>
            <SimpleGrid cols={{ base: 1, md: 3 }} spacing="lg">
              {roles.map((role) => (
                <Paper key={role.role} withBorder radius="lg" p="lg">
                  <Stack gap="sm">
                    <Box>
                      <RoleBadge role={role.role}>
                        {t(`roles.${role.role satisfies 'MEMBER' | 'ORGANIZER' | 'ADMIN'}`)}
                      </RoleBadge>
                    </Box>
                    <Title order={3}>{role.title}</Title>
                    <List
                      spacing="xs"
                      icon={
                        <ThemeIcon variant="light" size={22} radius="xl">
                          <IconCheck size={14} />
                        </ThemeIcon>
                      }
                    >
                      {role.points.map((point) => (
                        <List.Item key={point}>{point}</List.Item>
                      ))}
                    </List>
                  </Stack>
                </Paper>
              ))}
            </SimpleGrid>
          </Stack>
        </section>

        {/* Final call to action */}
        <Box
          component="section"
          aria-labelledby="features-final-title"
          className="features-final-cta"
        >
          <Group justify="space-between" align="center" gap="lg">
            <Stack gap={6} style={{ flex: '999 1 320px' }}>
              <Title order={2} id="features-final-title" c="white">
                {t('features.final.title')}
              </Title>
              <Text size="lg" c="white" opacity={0.85}>
                {isAuthenticated
                  ? t('features.final.subtitleMember')
                  : singleTeam
                    ? t('features.final.subtitleSingleTeam')
                    : t('features.final.subtitle')}
              </Text>
            </Stack>
            <Group gap="sm">
              {isAuthenticated ? (
                <Button size="md" variant="white" component={PrefetchLink} to={paths.home()}>
                  {t('features.cta.backToFeed')}
                </Button>
              ) : (
                <Button size="md" variant="white" {...signUpLink}>
                  {t('features.cta.signUp')}
                </Button>
              )}
              {!singleTeam && (
                <Button
                  size="md"
                  variant="outline"
                  color="white"
                  component={PrefetchLink}
                  to={paths.teams()}
                >
                  {t('features.cta.browseTeams')}
                </Button>
              )}
            </Group>
          </Group>
        </Box>
      </Box>

      {/* Phone, visitors only: the two entry points stay at hand. */}
      {!isAuthenticated && (
        <Box hiddenFrom="sm" className="features-sticky-bar">
          <SimpleGrid cols={2} spacing="sm">
            <Button {...signUpLink}>{t('features.cta.signUp')}</Button>
            <Button variant="default" {...signInLink}>
              {t('features.cta.signIn')}
            </Button>
          </SimpleGrid>
        </Box>
      )}
    </Stack>
  )
}
