import type { ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Alert, Badge, Box, Button, Group, Loader, Menu, Paper, Text, Title } from '@mantine/core'
import { IconCalendar, IconChevronDown, IconPencil } from '@tabler/icons-react'
import { Status, type MediaDto, type ReportTargetType, type TagDto } from '@/api/dto'
import { EntityLogo } from '@/components/common/EntityLogo'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { Rendezvous } from '@/components/common/Rendezvous'
import { ShareButton } from '@/components/common/ShareButton'
import { ContentActionsMenu } from '@/components/moderation/ContentActionsMenu'
import { TagList } from '@/components/tag'
import { paths } from '@/config/paths'
import { STATUS_COLORS } from '@/lib/badgeColors.generated'
import { KIND_LABELS, type PublicationKind } from './publicationKind'
import type { PublicationStatusActions } from './usePublicationStatusActions'

interface PublicationHeaderProps {
  kind: PublicationKind
  /** What the header shows of the ride or the trip. */
  publication: {
    id: string
    name: string
    media: MediaDto
    status: Status
    finished: boolean
    timezone: string
    publishAt?: string
    tags: TagDto[]
    team: { slug: string; name: string }
  }
  reportTargetType: ReportTargetType
  /** The organiser's menu; null for a reader who may not edit. */
  statusActions: PublicationStatusActions | null
  editPath: string
  /** « Rejoindre le voyage » / « Quitter le voyage »: a trip is joined from its header. */
  joinActions?: ReactNode
  /** Why the last join or leave failed, under the title. */
  error?: string | null
  /** Under the title: the departure, the places, the facts. */
  children?: ReactNode
}

/**
 * The header of a ride's or a trip's page (docs/LEDGER_*.md WEB-155): its logo, name and badges,
 * what the reader can do, then the departure (docs/BRANDING.md §7.8, WEB-137) and whatever the page
 * puts under it, the scheduled publication and the team tags — every one of them (cards show the
 * first three). The organiser's text is not here: it is the « Consignes » block (WEB-134).
 */
export function PublicationHeader({
  kind,
  publication,
  reportTargetType,
  statusActions,
  editPath,
  joinActions,
  error,
  children,
}: PublicationHeaderProps) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const labels = KIND_LABELS[kind]

  return (
    <Paper shadow="xs" p="lg" mb="lg" withBorder component="header">
      <Group justify="space-between" align="flex-start" wrap="wrap">
        <Group gap="sm" style={{ minWidth: 0 }}>
          <EntityLogo logo={publication.media.assets.logo} alt={publication.name} size="lg" />
          <Title
            order={2}
            style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
          >
            {publication.name}
          </Title>
          <Badge color={STATUS_COLORS[publication.status]} variant="light">
            {t(`status.${publication.status satisfies 'DRAFT' | 'PUBLISHED' | 'CANCELLED'}`)}
          </Badge>
          {publication.finished && (
            <Badge color="gray" variant="light">
              {t(labels.finished)}
            </Badge>
          )}
        </Group>

        <Group gap="xs" wrap="wrap">
          {joinActions}
          {statusActions && (
            <Button.Group>
              <Button
                component={PrefetchLink}
                to={editPath}
                variant="outline"
                leftSection={<IconPencil size={16} />}
              >
                {t('actions.edit')}
              </Button>
              <Menu position="bottom-end">
                <Menu.Target>
                  <Button variant="outline" px="xs" aria-label={t('aria.manageActions')}>
                    <IconChevronDown size={16} />
                  </Button>
                </Menu.Target>
                <Menu.Dropdown>
                  {statusActions.status === Status.DRAFT && (
                    <Menu.Item
                      onClick={statusActions.publish}
                      disabled={statusActions.isUpdating}
                      color="success"
                      leftSection={statusActions.isUpdating ? <Loader size="sm" /> : undefined}
                    >
                      {t('actions.publish')}
                    </Menu.Item>
                  )}
                  {statusActions.status === Status.PUBLISHED && (
                    <>
                      <Menu.Item onClick={() => statusActions.confirm('unpublish')} color="warning">
                        {t('actions.unpublish')}
                      </Menu.Item>
                      <Menu.Item onClick={() => statusActions.confirm('cancel')} color="warning">
                        {t(labels.cancelAction)}
                      </Menu.Item>
                    </>
                  )}
                  {statusActions.status === Status.CANCELLED && (
                    <Menu.Item onClick={() => statusActions.confirm('uncancel')} color="green">
                      {t(labels.uncancelAction)}
                    </Menu.Item>
                  )}
                  {statusActions.deleted && (
                    <Menu.Item
                      onClick={statusActions.restore}
                      color="green"
                      disabled={statusActions.isRestoring}
                    >
                      {t('actions.restore')}
                    </Menu.Item>
                  )}
                  <Menu.Divider />
                  <Menu.Item onClick={() => statusActions.confirm('delete')} color="danger">
                    {t('actions.delete')}
                  </Menu.Item>
                </Menu.Dropdown>
              </Menu>
            </Button.Group>
          )}
          <ShareButton title={publication.name} />
          <ContentActionsMenu
            teamSlug={publication.team.slug}
            teamName={publication.team.name}
            targetType={reportTargetType}
            targetId={publication.id}
            onReported={() => navigate(paths.team(publication.team.slug))}
          />
        </Group>
      </Group>

      {error && (
        <Alert color="red" variant="light" mt="md">
          {error}
        </Alert>
      )}

      {children && <Box mt="md">{children}</Box>}

      {publication.status === Status.DRAFT && publication.publishAt && (
        <Group mt="xs" gap="xs">
          <IconCalendar size={16} color="var(--mantine-color-yellow-text)" />
          <Text size="sm" c="var(--mantine-color-yellow-text)">
            <Rendezvous
              date={publication.publishAt}
              zone={publication.timezone}
              variant="detail"
              template={(date) => t(labels.scheduledPublish, { date })}
            />
          </Text>
        </Group>
      )}

      <TagList tags={publication.tags} mt="md" />
    </Paper>
  )
}
