import type { MouseEvent } from 'react'
import { useLocation } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  Badge,
  Box,
  Button,
  Divider,
  Group,
  List,
  Paper,
  SimpleGrid,
  Stack,
  Text,
  ThemeIcon,
  Title,
  type MantineColor,
} from '@mantine/core'
import {
  IconAdjustmentsHorizontal,
  IconArrowLeft,
  IconBike,
  IconCalendar,
  IconCheck,
  IconCloudRain,
  IconNavigation,
  IconLock,
  IconLogin,
  IconMap2,
  IconNews,
  IconSparkles,
  IconTags,
  IconUsers,
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
import { RoutesChapter } from './RoutesChapter'
import { RideGroupsVisual } from './visuals/RideGroupsVisual'
import { TripVisual } from './visuals/TripVisual'
import { DevicesVisual } from './visuals/DevicesVisual'
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

  const rides: Section = {
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
  }
  const weather: Section = {
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
  }
  const devices: Section = {
    id: 'devices',
    color: 'gray',
    icon: IconNavigation,
    chip: t('features.devices.eyebrow'),
    eyebrow: t('features.devices.eyebrow'),
    title: t('features.devices.title'),
    lead: t('features.devices.lead'),
    points: [
      t('features.devices.point1'),
      t('features.devices.point2'),
      t('features.devices.point3'),
      t('features.devices.point4'),
    ],
    visual: <DevicesVisual />,
  }
  const trips: Section = {
    id: 'trips',
    color: PUBLICATION_TYPE_COLORS.TRIP,
    icon: IconMap2,
    chip: t('features.trips.eyebrow'),
    eyebrow: t('features.trips.eyebrow'),
    title: t('features.trips.title'),
    lead: t('features.trips.lead'),
    points: [t('features.trips.point1'), t('features.trips.point2'), t('features.trips.point3')],
    visual: <TripVisual />,
  }

  // The jump chips, in page order; « routes », « more » and « roles » are not FeatureSections.
  const chips = [
    { id: 'rides', label: rides.chip },
    { id: 'routes', label: t('features.routes.eyebrow') },
    { id: 'weather', label: weather.chip },
    { id: 'devices', label: devices.chip },
    { id: 'trips', label: trips.chip },
    { id: 'more', label: t('features.more.eyebrow') },
    { id: 'roles', label: t('features.roles.chip') },
  ]

  const news: { id: string; icon: TablerIcon; title: string; text: string }[] = [
    {
      id: 'routes',
      icon: IconSparkles,
      title: t('features.news.generate.title'),
      text: t('features.news.generate.text'),
    },
    {
      id: 'routes',
      icon: IconAdjustmentsHorizontal,
      title: t('features.news.retouch.title'),
      text: t('features.news.retouch.text'),
    },
    {
      id: 'devices',
      icon: IconNavigation,
      title: t('features.news.gps.title'),
      text: t('features.news.gps.text'),
    },
    {
      id: 'rides',
      icon: IconUsers,
      title: t('features.news.groups.title'),
      text: t('features.news.groups.text'),
    },
  ]

  const more: { icon: TablerIcon; color: MantineColor; title: string; text: string }[] = [
    {
      icon: IconNews,
      color: PUBLICATION_TYPE_COLORS.POST,
      title: t('features.more.posts.title'),
      text: t('features.more.posts.text'),
    },
    {
      icon: IconTags,
      color: 'orange',
      title: t('features.more.ads.title'),
      text: t('features.more.ads.text'),
    },
    {
      icon: IconCalendar,
      color: 'primary',
      title: t('features.more.calendar.title'),
      text: t('features.more.calendar.text'),
    },
    {
      icon: IconLock,
      color: 'gray',
      title: t('features.more.privacy.title'),
      text: t('features.more.privacy.text'),
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
      ],
    },
    {
      role: 'ORGANIZER',
      title: t('features.roles.organizer.title'),
      points: [
        t('features.roles.organizer.point1'),
        t('features.roles.organizer.point2'),
        t('features.roles.organizer.point3'),
      ],
    },
    {
      role: 'ADMIN',
      title: t('features.roles.admin.title'),
      points: [
        t('features.roles.admin.point1'),
        t('features.roles.admin.point2'),
        t('features.roles.admin.point3'),
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
          <Stack gap="sm" align="stretch" ta="left" mt="md" w="100%">
            <Group gap="sm" wrap="nowrap" justify="center">
              <Divider style={{ flex: '1 1 40px', maxWidth: 120 }} />
              <Title
                order={2}
                size="sm"
                tt="uppercase"
                style={{
                  letterSpacing: 0.4,
                  color: 'var(--mantine-primary-color-light-color)',
                }}
              >
                {t('features.news.title')}
              </Title>
              <Divider style={{ flex: '1 1 40px', maxWidth: 120 }} />
            </Group>
            <SimpleGrid cols={{ base: 1, xs: 2, md: 4 }} spacing="md">
              {news.map((item) => {
                const Icon: TablerIcon = item.icon
                return (
                  <Paper
                    key={item.title}
                    component="a"
                    href={`#${item.id}`}
                    onClick={(event: MouseEvent<HTMLAnchorElement>) => jumpTo(event, item.id)}
                    withBorder
                    radius="md"
                    p="md"
                    className="features-news"
                  >
                    <Stack gap="xs">
                      <ThemeIcon variant="light" size={36} radius="md">
                        <Icon size={20} />
                      </ThemeIcon>
                      <Text fw={700}>{item.title}</Text>
                      <Text size="sm" c="dimmed">
                        {item.text}
                      </Text>
                    </Stack>
                  </Paper>
                )
              })}
            </SimpleGrid>
          </Stack>
          <nav aria-label={t('features.jump.label')} className="features-chips">
            {chips.map((chip) => (
              <a
                key={chip.id}
                href={`#${chip.id}`}
                className="features-chip"
                onClick={(event) => jumpTo(event, chip.id)}
              >
                {chip.label}
              </a>
            ))}
          </nav>
        </Stack>
      </section>

      {/* Features */}
      <Box px={{ base: 'xs', sm: 'md' }}>
        <FeatureSection {...rides} />
        <RoutesChapter />
        <FeatureSection {...weather} reverse />
        <FeatureSection {...devices} />
        <FeatureSection {...trips} reverse />

        {/* And also */}
        <section id="more" aria-labelledby="more-title" className="features-section">
          <Stack gap="lg">
            <Stack gap="xs" align="center" ta="center">
              <Text
                size="sm"
                fw={700}
                tt="uppercase"
                style={{ letterSpacing: 0.4, color: 'var(--mantine-primary-color-light-color)' }}
              >
                {t('features.more.eyebrow')}
              </Text>
              <Title order={2} id="more-title">
                {t('features.more.title')}
              </Title>
              <Text size="lg" c="dimmed" maw={600}>
                {t('features.more.subtitle')}
              </Text>
            </Stack>
            <SimpleGrid cols={{ base: 1, sm: 2, lg: 4 }} spacing="md">
              {more.map(({ icon: Icon, color, title, text }) => (
                <Paper key={title} withBorder radius="md" p="lg">
                  <Stack gap="xs">
                    <ThemeIcon variant="light" color={color} size={36} radius="md">
                      <Icon size={20} />
                    </ThemeIcon>
                    <Title order={3} size="h4">
                      {title}
                    </Title>
                    <Text size="sm" c="dimmed">
                      {text}
                    </Text>
                  </Stack>
                </Paper>
              ))}
            </SimpleGrid>
          </Stack>
        </section>

        {/* Roles */}
        <section id="roles" aria-labelledby="features-roles-title" className="features-section">
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
