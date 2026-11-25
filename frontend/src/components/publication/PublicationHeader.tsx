import type { ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Badge, Group, Loader, Menu, Text } from '@mantine/core'
import { IconCalendar } from '@tabler/icons-react'
import { Status, type MediaDto, type ReportTargetType, type TagDto } from '@/api/dto'
import { EntityLogo } from '@/components/common/EntityLogo'
import { Rendezvous } from '@/components/common/Rendezvous'
import { ContentActionsMenu } from '@/components/moderation/ContentActionsMenu'
import { TagList } from '@/components/tag'
import { paths } from '@/config/paths'
import { STATUS_COLORS } from '@/lib/badgeColors.generated'
import { DetailHeader } from './DetailHeader'
import { EditMenuButton } from './EditMenuButton'
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
  primary?: ReactNode
  /** « GPS »: the reader's group's route on a ride, the trip's own route on a trip without stages. */
  gps?: ReactNode
  /** Why the last join or leave failed, under the title. */
  error?: string | null
  /** Under the title: the departure, the places, the facts. */
  children?: ReactNode
}

/**
 * The header of a ride's or a trip's page (docs/LEDGER_*.md WEB-155): its logo, name and badges,
 * what the reader can do, then the departure (docs/BRANDING.md §7.8, WEB-137) and whatever the page
 * puts under it, the scheduled publication and the team tags — every one of them (cards show the
 * first three). It is a `DetailHeader` (WEB-206): the title is the page's `h1`, the actions in its fixed order. The organiser's text is not here: it is the « Consignes » block (WEB-134).
 */
export function PublicationHeader({
  kind,
  publication,
  reportTargetType,
  statusActions,
  editPath,
  primary,
  gps,
  error,
  children,
}: PublicationHeaderProps) {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const labels = KIND_LABELS[kind]

  return (
    <DetailHeader
      logo={<EntityLogo logo={publication.media.assets.logo} alt={publication.name} size="lg" />}
      title={publication.name}
      badges={
        <>
          <Badge color={STATUS_COLORS[publication.status]} variant="light">
            {t(`status.${publication.status satisfies 'DRAFT' | 'PUBLISHED' | 'CANCELLED'}`)}
          </Badge>
          {publication.finished && (
            <Badge color="gray" variant="light">
              {t(labels.finished)}
            </Badge>
          )}
        </>
      }
      primary={primary}
      gps={gps}
      edit={
        statusActions && (
          <EditMenuButton to={editPath}>
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
          </EditMenuButton>
        )
      }
      shareTitle={publication.name}
      more={
        <ContentActionsMenu
          teamSlug={publication.team.slug}
          teamName={publication.team.name}
          targetType={reportTargetType}
          targetId={publication.id}
          onReported={() => navigate(paths.team(publication.team.slug))}
        />
      }
      error={error}
    >
      {children}

      {publication.status === Status.DRAFT && publication.publishAt && (
        <Group gap="xs">
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

      <TagList tags={publication.tags} />
    </DetailHeader>
  )
}
