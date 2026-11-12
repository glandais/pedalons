import { useTranslation } from 'react-i18next'
import { ActionIcon, Button, Group, Paper, Stack, Text } from '@mantine/core'
import { IconPencil, IconPlus, IconTrash } from '@tabler/icons-react'
import type { RideTemplateDto } from '@/api/dto'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { StateBadge } from '@/components/card/common'
import { paths } from '@/config/paths'
import { useUnits } from '@/hooks/useUnits'
import { stripMarkdown } from '@/lib/seo'
import { cardState } from '@/utils/cardState'

interface RideTemplateCardProps {
  template: RideTemplateDto
  /** An organiser of the team: « Créer une sortie », the pencil and the bin. */
  canManage: boolean
  onDelete: (template: RideTemplateDto) => void
}

/**
 * A template in its list, the app's card (docs/LEDGER_*.md WEB-167, R12 and R13): its name and the
 * one state of the rides it creates — « Brouillon » or « Annulé », never « Publié » (R1) —,
 * « 3 groupes · prochaine sortie #12 » (« sans numéro »), its groups with their pace in text, and
 * its description on two lines when it has one. Its visibility and tags are the editor's, not the
 * card's. « Créer une sortie » opens the ride form filled from it (`?template=`, CreateRidePage).
 */
export function RideTemplateCard({ template, canManage, onDelete }: RideTemplateCardProps) {
  const { t } = useTranslation()
  const { speed } = useUnits()

  const groups = [...template.groups].sort((a, b) => a.sortOrder - b.sortOrder)
  // No « 0 groupe » (R4): the summary may then be the number alone.
  const summary = [
    template.groupCount > 0 ? t('groups.groupCount', { count: template.groupCount }) : null,
    template.nextNumber != null
      ? t('rideTemplates.card.nextNumber', { number: template.nextNumber })
      : t('rideTemplates.card.unnumbered'),
  ]
    .filter(Boolean)
    .join(' · ')
  const paces = groups
    .map((group) =>
      group.averageSpeed ? `${group.name} ${speed(group.averageSpeed)}` : group.name
    )
    .join(' · ')
  const description = template.markdown ? stripMarkdown(template.markdown) : ''

  return (
    <Paper withBorder p="md" data-testid="ride-template-card">
      <Group justify="space-between" align="flex-start" wrap="nowrap">
        <Stack gap={4} style={{ flex: 1, minWidth: 0 }}>
          <Group gap="xs" wrap="wrap">
            <Text size="lg" fw={500}>
              {template.name}
            </Text>
            <StateBadge state={cardState({ status: template.status })} />
          </Group>
          {summary && (
            <Text size="sm" c="dimmed">
              {summary}
            </Text>
          )}
          {paces && (
            <Text size="sm" c="dimmed" data-testid="ride-template-paces">
              {paces}
            </Text>
          )}
          {description && (
            <Text size="sm" c="dimmed" lineClamp={2}>
              {description}
            </Text>
          )}
          {canManage && (
            <Group mt="xs">
              <Button
                component={PrefetchLink}
                to={`${paths.rideNew(template.team.slug)}?template=${encodeURIComponent(template.slug)}`}
                variant="outline"
                size="xs"
                leftSection={<IconPlus size={14} />}
              >
                {t('rideTemplates.card.createRide')}
              </Button>
            </Group>
          )}
        </Stack>
        {canManage && (
          <Group gap="xs" ml="md" wrap="nowrap">
            <ActionIcon
              component={PrefetchLink}
              to={paths.rideTemplateEdit(template.team.slug, template.slug)}
              variant="subtle"
              color="gray"
              title={t('actions.edit')}
              aria-label={t('actions.edit')}
            >
              <IconPencil size={20} />
            </ActionIcon>
            <ActionIcon
              variant="subtle"
              color="danger"
              onClick={() => onDelete(template)}
              title={t('actions.delete')}
              aria-label={t('actions.delete')}
            >
              <IconTrash size={20} />
            </ActionIcon>
          </Group>
        )}
      </Group>
    </Paper>
  )
}
