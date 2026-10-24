import { useState } from 'react'
import { invalidateTeamDashboard } from '@/lib/teamDashboardCache'
import { useParams, useNavigate, Navigate } from 'react-router-dom'
import { PrefetchLink } from '@/components/common/PrefetchLink'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { notifications } from '@mantine/notifications'
import i18next from 'i18next'
import {
  IconCalendar,
  IconPencil,
  IconMail,
  IconChevronDown,
  IconMapPin,
  IconCurrencyEuro,
  IconCircleCheck,
  IconUser,
} from '@tabler/icons-react'
import {
  Alert,
  Avatar,
  Box,
  Button,
  Menu,
  Container,
  Divider,
  Paper,
  Group,
  Stack,
  Title,
  Text,
  Badge,
  Loader,
} from '@mantine/core'
import {
  useUpdateAd,
  useDeleteAd,
  useUndeleteAd,
  getListAdsQueryKey,
  getGetAdQueryKey,
} from '../../api/endpoints/ads/ads'
import { QueryStateBoundary } from '../../components/common/QueryStateBoundary'
import { AdContactModal, type AdContactOutcome } from '../../components/ad/AdContactModal'
import { AdGallery } from '../../components/ad/AdGallery'
import { AdLocationMap } from '../../components/ad/AdLocationMap'
import { useAuth } from '../../hooks/useAuth'
import { DetailPageSkeleton } from '../../components/common/DetailPageSkeleton'
import { ConfirmDialog } from '../../components/common/ConfirmDialog'
import { MediaDisplay } from '../../components/common/MediaDisplay'
import { EntityLogo } from '../../components/common/EntityLogo'
import { ContentActionsMenu } from '../../components/moderation/ContentActionsMenu'
import { TeamContextBanner } from '../../components/team/TeamContextBanner'
import { FormattedDateTime } from '../../components/common/FormattedDate'
import { paths } from '@/config/paths'
import { AdType, RentalPeriod, ReportTargetType, Status } from '../../api/dto'
import { useCanonicalPath } from '../../hooks/useCanonicalPath'
import { useAdDetailData } from './adDetailData'
import { AD_TYPE_COLORS, STATUS_COLORS } from '@/lib/badgeColors.generated'
import { TagList } from '@/components/tag'
import { useAuthStore, selectIsPlatformAdmin } from '@/store/authStore'
import { teamAccess } from '@/lib/teamAccess'

export function AdDetailPage() {
  const { t } = useTranslation()
  const isPlatformAdmin = useAuthStore(selectIsPlatformAdmin)
  const { teamSlug, adSlug } = useParams<{ teamSlug: string; adSlug: string }>()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const [showUnpublishConfirm, setShowUnpublishConfirm] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [contactOpen, setContactOpen] = useState(false)
  /**
   * What came of writing to the author. `sent` and `optedOut` are *states of the page*, not
   * notifications: a confirmation that vanishes before it is read is no confirmation, and an
   * author who opted out cannot be reached by trying again.
   */
  const [contactOutcome, setContactOutcome] = useState<AdContactOutcome | null>(null)
  const { user } = useAuth()

  const { team: teamQuery, ad: adQuery } = useAdDetailData(teamSlug, adSlug)
  const { data: team, isLoading: isLoadingTeam } = teamQuery
  const { data: ad, isLoading: isLoadingAd, error, refetch } = adQuery

  useCanonicalPath(team && ad ? paths.ad(team.slug, ad.slug) : undefined)

  const updateMutation = useUpdateAd()
  const deleteMutation = useDeleteAd()
  const undeleteMutation = useUndeleteAd()

  if (!isLoadingTeam && !team) {
    return <Navigate to={paths.teams()} replace />
  }

  // The module is off for this team: the API refuses every ad, so there is nothing to show here.
  if (team && !team.enableAds) {
    return <Navigate to={paths.team(team.slug)} replace />
  }

  // Ads are for the team's members (and a platform admin, who moderates them): the API refuses the
  // ad to anyone else, and that refusal is not a load failure to retry. Same destination as
  // CreateAdPage and EditAdPage.
  if (team && !team.role && !isPlatformAdmin) {
    return <Navigate to={paths.ads(team.slug)} replace />
  }

  if (isLoadingTeam || isLoadingAd || error || !ad) {
    return (
      <Container size="xl" py="xl">
        <QueryStateBoundary
          isLoading={isLoadingTeam || isLoadingAd}
          isError={!!error}
          error={error}
          isNotFound={!ad}
          onRetry={() => void refetch()}
          skeleton={<DetailPageSkeleton withMap={false} />}
          notFound={{
            title: t('ads.detail.notFound.title'),
            message: t('ads.detail.notFound.message'),
            backTo: paths.ads(teamSlug!),
            backLabel: t('ads.title'),
          }}
        >
          {null}
        </QueryStateBoundary>
      </Container>
    )
  }

  const isAdmin = teamAccess(team, isPlatformAdmin).isAdmin
  // The relay is open to anyone who may read the ad, i.e. a team member — except its author,
  // who has no one to write to. `AD_CONTACT_SELF` therefore never needs a rendering.
  const canContactAuthor = !!team?.role && ad.createdById !== user?.id
  // The author or a team admin, as AdAccessChecker enforces — an organizer who did not write the
  // ad may not edit it either.
  const canEdit = isAdmin || (!!user && ad.createdById === user.id)

  const formattedDate = <FormattedDateTime date={ad.createdAt} />

  const formatPrice = (price: number | undefined, adType: AdType, rentalPeriod?: RentalPeriod) => {
    if (price === undefined || price === null) {
      return t('ads.detail.priceNegotiable')
    }
    const formattedPrice = new Intl.NumberFormat('fr-FR', {
      style: 'currency',
      currency: 'EUR',
    }).format(price)

    if (adType === AdType.RENTAL && rentalPeriod) {
      return `${formattedPrice} / ${t(`ads.rentalPeriod.${rentalPeriod satisfies 'DAY' | 'WEEK' | 'MONTH'}`).toLowerCase()}`
    }
    return formattedPrice
  }

  const invalidateAds = () => {
    queryClient.invalidateQueries({ queryKey: getListAdsQueryKey(teamSlug!) })
    invalidateTeamDashboard(queryClient, teamSlug!)
    queryClient.invalidateQueries({ queryKey: getGetAdQueryKey(teamSlug!, adSlug!) })
  }

  const handlePublish = () => {
    updateMutation.mutate(
      { teamSlug: teamSlug!, slug: adSlug!, data: { ...ad, status: Status.PUBLISHED } },
      {
        onSuccess: () => {
          invalidateAds()
          notifications.show({ message: i18next.t('ads.notifications.updated'), color: 'green' })
        },
      }
    )
  }

  const handleUnpublish = () => {
    updateMutation.mutate(
      { teamSlug: teamSlug!, slug: adSlug!, data: { ...ad, status: Status.DRAFT } },
      {
        onSuccess: () => {
          invalidateAds()
          notifications.show({ message: i18next.t('ads.notifications.updated'), color: 'green' })
          setShowUnpublishConfirm(false)
        },
      }
    )
  }

  const handleDelete = () => {
    deleteMutation.mutate(
      { teamSlug: teamSlug!, slug: adSlug! },
      {
        onSuccess: () => {
          queryClient.invalidateQueries({ queryKey: getListAdsQueryKey(teamSlug!) })
          invalidateTeamDashboard(queryClient, teamSlug!)
          notifications.show({ message: i18next.t('ads.notifications.deleted'), color: 'green' })
          setShowDeleteConfirm(false)
          navigate(paths.ads(teamSlug!))
        },
      }
    )
  }

  const handleRestore = () => {
    undeleteMutation.mutate(
      { teamSlug: teamSlug!, slug: adSlug! },
      {
        onSuccess: () => {
          invalidateAds()
          notifications.show({ message: i18next.t('ads.notifications.restored'), color: 'green' })
        },
      }
    )
  }

  return (
    <Container size="md" py="xl">
      {/* Way back to the team: this page is not mounted inside TeamLayout */}
      {team && <TeamContextBanner team={team} />}

      {/* The pictures, straight from `images[]` so a trimmed `media` changes nothing here.
          Renders nothing at all when the ad has none. */}
      <AdGallery images={ad.images} name={ad.name} />

      {/* Header */}
      <Paper withBorder p="lg" mb="lg">
        <Group justify="space-between" align="flex-start" wrap="wrap">
          <Group style={{ minWidth: 0 }}>
            <EntityLogo logo={ad.media.assets.logo} alt={ad.name} size="lg" />
            <Stack gap={4} style={{ minWidth: 0 }}>
              <Title order={2} lineClamp={1}>
                {ad.name}
              </Title>
              <Group gap="xs">
                <Badge color={AD_TYPE_COLORS[ad.adType]}>
                  {t(`ads.adType.${ad.adType satisfies 'SALE' | 'RENTAL' | 'WANTED'}`)}
                </Badge>
                <Badge color={STATUS_COLORS[ad.status]}>
                  {t(`status.${ad.status satisfies 'DRAFT' | 'PUBLISHED' | 'CANCELLED'}`)}
                </Badge>
              </Group>
              <TagList tags={ad.tags} />
            </Stack>
          </Group>

          <Group gap="xs" wrap="nowrap">
            {canEdit && (
              <Button.Group>
                <Button
                  component={PrefetchLink}
                  to={paths.adEdit(teamSlug!, adSlug!)}
                  variant="default"
                  leftSection={<IconPencil size={16} />}
                >
                  {t('actions.edit')}
                </Button>
                <Menu position="bottom-end">
                  <Menu.Target>
                    <Button variant="default" px="xs" aria-label={t('aria.manageActions')}>
                      <IconChevronDown size={16} />
                    </Button>
                  </Menu.Target>
                  <Menu.Dropdown>
                    {ad.status === Status.DRAFT && (
                      <Menu.Item
                        onClick={handlePublish}
                        disabled={updateMutation.isPending}
                        color="success"
                        leftSection={updateMutation.isPending ? <Loader size="sm" /> : undefined}
                      >
                        {t('actions.publish')}
                      </Menu.Item>
                    )}
                    {ad.status === Status.PUBLISHED && (
                      <Menu.Item onClick={() => setShowUnpublishConfirm(true)} color="warning">
                        {t('actions.unpublish')}
                      </Menu.Item>
                    )}
                    {ad.deleted && (
                      <Menu.Item
                        onClick={handleRestore}
                        color="green"
                        disabled={undeleteMutation.isPending}
                      >
                        {t('actions.restore')}
                      </Menu.Item>
                    )}
                    <Menu.Divider />
                    <Menu.Item onClick={() => setShowDeleteConfirm(true)} color="danger">
                      {t('actions.delete')}
                    </Menu.Item>
                  </Menu.Dropdown>
                </Menu>
              </Button.Group>
            )}
            <ContentActionsMenu
              teamSlug={ad.team.slug}
              teamName={ad.team.name}
              targetType={ReportTargetType.AD}
              targetId={ad.id}
              author={{ id: ad.createdById, displayName: ad.createdByDisplayName }}
              onReported={() => navigate(paths.ads(ad.team.slug))}
            />
          </Group>
        </Group>

        {/* Price */}
        <Box
          mt="lg"
          p="md"
          bg="var(--mantine-color-body)"
          style={{ borderRadius: 'var(--mantine-radius-md)' }}
        >
          <Group gap="xs">
            <IconCurrencyEuro size={24} />
            <Text size="xl" fw={700}>
              {formatPrice(ad.price, ad.adType, ad.rentalPeriod)}
            </Text>
          </Group>
        </Box>

        {/* Publication date: on its own, right under the price, as on mobile */}
        <Group gap="xs" mt="md">
          <IconCalendar size={16} />
          <Text size="sm" c="dimmed">
            {formattedDate}
          </Text>
        </Group>

        {/* Description. `MediaDisplay` also lists the attachments, so the section stays for an ad
            whose body is empty but which carries a file. */}
        {(ad.media.markdown.length > 0 || ad.media.assets.attachments.length > 0) && (
          <Box mt="lg">
            <Title order={4} mb="xs">
              {t('ads.detail.description')}
            </Title>
            <MediaDisplay media={ad.media} />
          </Box>
        )}

        {/* Location. The written place stands on its own — no map when the geometry is missing,
            since a map centred on a fallback would lie. */}
        {(ad.locationDescription || ad.locationGeometry) && (
          <Box mt="lg">
            <Title order={4} mb="xs">
              {t('ads.detail.location')}
            </Title>
            <Stack gap="xs">
              {ad.locationDescription && (
                <Group gap="xs">
                  <IconMapPin size={16} />
                  <Text size="sm">{ad.locationDescription}</Text>
                </Group>
              )}
              {ad.locationGeometry && <AdLocationMap geometry={ad.locationGeometry} />}
            </Stack>
          </Box>
        )}

        <Divider my="lg" />

        {/* The author. `createdByDisplayName` is all the DTO carries about them — there is no
            contact channel on an ad, only the relay below. */}
        <Title order={4} mb="xs">
          {t('ads.detail.seller')}
        </Title>
        <Group gap="sm">
          <Avatar radius="xl" color="primary">
            <IconUser size={18} />
          </Avatar>
          <Text fw={500}>{ad.createdByDisplayName}</Text>
        </Group>

        {contactOutcome === 'sent' ? (
          <Alert mt="md" color="green" icon={<IconCircleCheck size={16} />}>
            {t('ads.contact.sent')}
          </Alert>
        ) : contactOutcome === 'optedOut' ? (
          <Alert mt="md" color="orange">
            {t('ads.contact.error.optedOut')}
          </Alert>
        ) : (
          // The button does not exist on one's own ad: relaying a message to oneself is not an
          // action.
          canContactAuthor && (
            <Button
              mt="md"
              leftSection={<IconMail size={16} />}
              onClick={() => setContactOpen(true)}
            >
              {t('ads.contact.button')}
            </Button>
          )
        )}
      </Paper>

      {/* Confirmation Dialogs */}
      <ConfirmDialog
        isOpen={showUnpublishConfirm}
        onClose={() => setShowUnpublishConfirm(false)}
        onConfirm={handleUnpublish}
        title={t('actions.unpublish')}
        message={t('ads.detail.confirmations.unpublish')}
        confirmText={t('actions.unpublish')}
        variant="warning"
        isLoading={updateMutation.isPending}
      />
      <AdContactModal
        opened={contactOpen}
        onClose={() => setContactOpen(false)}
        teamSlug={teamSlug!}
        adSlug={adSlug!}
        sellerName={ad.createdByDisplayName}
        onOutcome={setContactOutcome}
      />

      <ConfirmDialog
        isOpen={showDeleteConfirm}
        onClose={() => setShowDeleteConfirm(false)}
        onConfirm={handleDelete}
        title={t('actions.delete')}
        message={t('ads.detail.confirmations.delete')}
        confirmText={t('actions.delete')}
        variant="danger"
        isLoading={deleteMutation.isPending}
      />
    </Container>
  )
}
