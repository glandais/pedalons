import { useTranslation } from 'react-i18next'
import { Group, Stack, Text, UnstyledButton } from '@mantine/core'
import { IconChevronRight, IconTemplate } from '@tabler/icons-react'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import type { RideTemplateListResponse } from '@/api/dto'
import { paths } from '@/config/paths'
import { DashboardSection } from './DashboardSection'

interface TemplatesPanelProps {
  teamSlug: string
  templates: RideTemplateListResponse
}

/**
 * « Créer depuis un modèle »: each template opens the ride form already filled from it — the
 * template travels as router state (`CreateRidePage` reads `location.state.template`), the same
 * values its own « Utiliser un modèle » picker applies. The mobile dashboard, which opens the site
 * in a browser, names it in the URL instead (`?template=<slug>`).
 */
export function TemplatesPanel({ teamSlug, templates }: TemplatesPanelProps) {
  const { t } = useTranslation()
  return (
    <DashboardSection
      id="dashboard-templates"
      title={t('teams.dashboard.templates.title')}
      framed
      seeAllTo={paths.rideTemplates(teamSlug)}
      isEmpty={templates.templates.length === 0}
      empty={t('teams.dashboard.templates.empty')}
    >
      <Stack gap={4}>
        {templates.templates.map((template) => (
          <UnstyledButton
            key={template.id}
            component={PrefetchLink}
            to={paths.rideNew(teamSlug)}
            state={{ template }}
            p="xs"
            style={{ borderRadius: 'var(--mantine-radius-md)' }}
          >
            <Group gap="sm" wrap="nowrap">
              <IconTemplate size={18} color="var(--mantine-color-dimmed)" />
              <Text size="sm" fw={500} style={{ flex: 1, minWidth: 0 }} truncate>
                {template.name}
              </Text>
              {/* No « 0 groupe » (docs/LEDGER_*.md WEB-167, R4). */}
              {template.groupCount > 0 && (
                <Text size="xs" c="dimmed">
                  {t('groups.groupCount', { count: template.groupCount })}
                </Text>
              )}
              <IconChevronRight size={16} color="var(--mantine-color-dimmed)" />
            </Group>
          </UnstyledButton>
        ))}
      </Stack>
    </DashboardSection>
  )
}
