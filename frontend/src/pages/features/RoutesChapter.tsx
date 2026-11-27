import { useTranslation } from 'react-i18next'
import { Box, Group, List, Paper, SimpleGrid, Stack, Text, ThemeIcon, Title } from '@mantine/core'
import {
  IconAdjustmentsHorizontal,
  IconCheck,
  IconPencil,
  IconRoute,
  IconSparkles,
  type TablerIcon,
} from '@tabler/icons-react'
import { GeneratorVisual } from './visuals/GeneratorVisual'

/**
 * The routes chapter: the page's flagship, laid out full width rather than as a text/illustration
 * pair — the generator in miniature, the three ways to get a route, and the shared library.
 * Routes have no business colour of their own (contracts/brand-colors.yaml): the brand's.
 */
export function RoutesChapter() {
  const { t } = useTranslation()
  const ways: { key: string; icon: TablerIcon; title: string; text: string }[] = [
    {
      key: 'generate',
      icon: IconSparkles,
      title: t('features.routes.generate.title'),
      text: t('features.routes.generate.text'),
    },
    {
      key: 'trace',
      icon: IconPencil,
      title: t('features.routes.trace.title'),
      text: t('features.routes.trace.text'),
    },
    {
      key: 'retouch',
      icon: IconAdjustmentsHorizontal,
      title: t('features.routes.retouch.title'),
      text: t('features.routes.retouch.text'),
    },
  ]
  const points = [
    t('features.routes.library.point1'),
    t('features.routes.library.point2'),
    t('features.routes.library.point3'),
    t('features.routes.library.point4'),
    t('features.routes.library.point5'),
    t('features.routes.library.point6'),
  ]

  return (
    <section id="routes" aria-labelledby="routes-title" className="features-section">
      <Stack gap="xl">
        <Stack gap="md" align="center" ta="center">
          <Group gap="sm">
            <ThemeIcon variant="light" color="primary" size={36} radius="md">
              <IconRoute size={20} />
            </ThemeIcon>
            <Text
              size="sm"
              fw={700}
              tt="uppercase"
              style={{ letterSpacing: 0.4, color: 'var(--mantine-color-primary-light-color)' }}
            >
              {t('features.routes.eyebrow')}
            </Text>
          </Group>
          <Title order={2} id="routes-title" maw={760}>
            {t('features.routes.title')}
          </Title>
          <Text size="lg" c="dimmed" maw={700}>
            {t('features.routes.lead')}
          </Text>
        </Stack>

        <GeneratorVisual />

        <SimpleGrid cols={{ base: 1, md: 3 }} spacing="md">
          {ways.map(({ key, icon: Icon, title, text }) => (
            <Paper key={key} withBorder radius="md" p="lg">
              <Stack gap="xs">
                <ThemeIcon variant="light" color="primary" size={36} radius="md">
                  <Icon size={20} />
                </ThemeIcon>
                <Title order={3} size="h4">
                  {title}
                </Title>
                <Text c="dimmed">{text}</Text>
              </Stack>
            </Paper>
          ))}
        </SimpleGrid>

        <Paper withBorder radius="md" p="lg">
          <Group gap="xl" align="flex-start" wrap="wrap">
            <Stack gap="xs" style={{ flex: '1 1 280px' }}>
              <Title order={3} size="h4">
                {t('features.routes.library.title')}
              </Title>
              <Text c="dimmed">{t('features.routes.library.lead')}</Text>
            </Stack>
            <Box style={{ flex: '1 1 380px' }}>
              <List
                spacing="xs"
                icon={
                  <ThemeIcon variant="light" color="primary" size={22} radius="xl">
                    <IconCheck size={14} />
                  </ThemeIcon>
                }
              >
                {points.map((point) => (
                  <List.Item key={point}>{point}</List.Item>
                ))}
              </List>
            </Box>
          </Group>
        </Paper>
      </Stack>
    </section>
  )
}
