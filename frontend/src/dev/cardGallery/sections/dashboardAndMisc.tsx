import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Route, Routes } from 'react-router-dom'
import { Box, Paper, Stack } from '@mantine/core'
import type { NotificationDto, RideDto } from '@/api/dto'
import { DashboardSection } from '@/components/team/dashboard/DashboardSection'
import { TodoBand } from '@/components/team/dashboard/TodoBand'
import { MyUpcomingList } from '@/components/team/dashboard/MyUpcomingList'
import { UpcomingRideCard } from '@/components/team/dashboard/UpcomingRideCard'
import {
  LatestAdsList,
  LatestPostsList,
  NewRoutesList,
} from '@/components/team/dashboard/ContentLists'
import { NotificationItem } from '@/components/notification/NotificationItem'
import { PairedDevicesManager } from '@/components/profile/PairedDevicesManager'
import { CommentSection } from '@/components/comment/CommentSection'
import { RideTemplateListPage } from '@/pages/ridetemplate/RideTemplateListPage'
import { paths } from '@/config/paths'
import type { GallerySection } from '../galleryLayout'
import { TEMPLATE_TEAM_SLUGS } from '../fakeApi'
import {
  AD_RENTAL,
  AD_SALE,
  AD_WANTED,
  NOTIFICATION_READ,
  NOTIFICATION_UNREAD,
  NOTIFICATION_UPDATED,
  RIDE_SLUG,
  VCM_REF,
  VCM_SLUG,
  day,
  draftRide,
  fullRide,
  hoursFromNow,
  post,
  ride,
  rideWithoutRoute,
  route,
  trip,
} from '../fixtures'

/** The dashboard's sections as `TeamDashboard` frames them: same ids, titles, links, emptiness. */
function MyUpcomingSection() {
  const { t } = useTranslation()
  const publications = [ride({ registered: true }), trip(10, { registered: true })]
  return (
    <DashboardSection
      id="dashboard-my-upcoming"
      title={t('teams.dashboard.myUpcoming.title')}
      seeAllTo={`${paths.teamAgenda(VCM_SLUG)}?w=me`}
      isEmpty={publications.length === 0}
      empty={t('teams.dashboard.myUpcoming.empty')}
    >
      <MyUpcomingList publications={publications} />
    </DashboardSection>
  )
}

/** One card of « Sorties à venir », in that section's own grid. */
function UpcomingRide({ ride: theRide }: { ride: RideDto }) {
  return (
    <Box
      style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))',
        gap: 'var(--mantine-spacing-md)',
      }}
    >
      <UpcomingRideCard ride={theRide} />
    </Box>
  )
}

function PostsSection() {
  const { t } = useTranslation()
  const posts = [
    post(),
    post({
      id: 'p-trevezel',
      slug: 'compte-rendu-roch-trevezel',
      name: 'Compte rendu : montée du Roc’h Trévézel',
      excerpt: 'Vent de face sur la crête, mais le soleil est revenu pour la descente.',
      thumbnailUrl: undefined,
      dateTime: day(-6, '20:10'),
      commentCount: 0,
      createdBy: undefined,
    }),
  ]
  return (
    <DashboardSection
      id="dashboard-posts"
      title={t('teams.dashboard.posts.title')}
      seeAllTo={paths.teamPosts(VCM_SLUG)}
      isEmpty={posts.length === 0}
      empty={t('teams.dashboard.posts.empty')}
    >
      <LatestPostsList posts={posts} />
    </DashboardSection>
  )
}

function RoutesSection() {
  const { t } = useTranslation()
  const routes = [
    route(),
    route({
      id: 'rt-drennec',
      slug: 'tour-du-lac-du-drennec',
      name: 'Tour du lac du Drennec',
      distance: 38_600,
      elevationGain: 410,
      surfaceType: 'GRAVEL',
      tags: [],
    }),
  ]
  return (
    <DashboardSection
      id="dashboard-routes"
      title={t('teams.dashboard.routes.title')}
      framed
      seeAllTo={paths.routes(VCM_SLUG)}
      isEmpty={routes.length === 0}
      empty={t('teams.dashboard.routes.empty')}
    >
      <NewRoutesList routes={routes} />
    </DashboardSection>
  )
}

function AdsSection() {
  const { t } = useTranslation()
  const ads = [AD_SALE, AD_RENTAL, AD_WANTED]
  return (
    <DashboardSection
      id="dashboard-ads"
      title={t('teams.dashboard.ads.title')}
      framed
      seeAllTo={paths.ads(VCM_SLUG)}
      isEmpty={ads.length === 0}
      empty={t('teams.dashboard.ads.empty')}
    >
      <LatestAdsList ads={ads} />
    </DashboardSection>
  )
}

function todoOrganizer() {
  const page = (publications: RideDto[]) => ({
    publications,
    total: publications.length,
    page: 0,
    size: 10,
  })
  return {
    drafts: page([draftRide()]),
    ridesWithoutRoute: page([rideWithoutRoute()]),
    ridesWithFullGroup: page([ride()]),
    reports: {
      openCount: 2,
      latestReason: 'SPAM' as const,
      latestTargetType: 'COMMENT' as const,
      latestExcerpt: 'Vends maillots du club à prix cassés, écrivez-moi en privé',
      latestReportedAt: hoursFromNow(-6),
    },
  }
}

export const dashboardSection: GallerySection = {
  id: 'tableau',
  title: 'Tableau de bord d’équipe — TodoBand, MyUpcomingList, UpcomingRideCard, ContentLists',
  entries: [
    {
      id: 'a-traiter',
      label: 'les quatre tuiles : brouillon, sans parcours, groupe complet, signalements',
      layout: 'full',
      render: () => <TodoBand teamSlug={VCM_SLUG} organizer={todoOrganizer()} />,
    },
    {
      id: 'mes-sorties',
      label: '« Vos prochaines sorties » : une sortie, un voyage',
      layout: 'dashMain',
      render: () => <MyUpcomingSection />,
    },
    {
      id: 'sortie-a-venir',
      label: 'non inscrite',
      layout: 'dashMain',
      render: () => <UpcomingRide ride={ride()} />,
    },
    {
      id: 'sortie-a-venir-inscrite',
      label: 'inscrite au groupe B',
      layout: 'dashMain',
      render: () => <UpcomingRide ride={ride({ registered: true })} />,
    },
    {
      id: 'sortie-a-venir-complet',
      label: 'tous les groupes complets',
      layout: 'dashMain',
      render: () => <UpcomingRide ride={fullRide()} />,
    },
    {
      id: 'sortie-a-venir-sans-parcours',
      label: 'aucun parcours',
      layout: 'dashMain',
      render: () => <UpcomingRide ride={rideWithoutRoute()} />,
    },
    {
      id: 'dernieres-publications',
      label: 'deux publications, l’une avec photo',
      layout: 'dashMain',
      render: () => <PostsSection />,
    },
    {
      id: 'nouveaux-parcours',
      label: 'deux parcours',
      layout: 'dashAside',
      render: () => <RoutesSection />,
    },
    {
      id: 'annonces-tableau',
      label: 'vente, location, recherche',
      layout: 'dashAside',
      render: () => <AdsSection />,
    },
  ],
}

/** A notification in the inbox's frame (`NotificationListPage`). */
function Inbox({ notification }: { notification: NotificationDto }) {
  return (
    <Paper withBorder radius="md" p={4}>
      <Stack gap={0}>
        <NotificationItem notification={notification} onOpen={() => undefined} />
      </Stack>
    </Paper>
  )
}

/** `RideTemplateListPage` at its real path, its team answered by the fake API. */
function TemplatePage(): ReactNode {
  return (
    <Routes>
      <Route path={paths.rideTemplates(':teamSlug')} element={<RideTemplateListPage />} />
    </Routes>
  )
}

export const miscSection: GallerySection = {
  id: 'divers',
  title: 'Divers — notifications, modèles, appareils, commentaires',
  entries: [
    {
      id: 'notification-non-lue',
      label: 'nouvelle sortie, non lue',
      layout: 'full',
      render: () => <Inbox notification={NOTIFICATION_UNREAD} />,
    },
    {
      id: 'notification-lue',
      label: 'Karim Benali a rejoint, lue',
      layout: 'full',
      render: () => <Inbox notification={NOTIFICATION_READ} />,
    },
    {
      id: 'notification-modification',
      label: 'sortie modifiée : date et lieu de départ',
      layout: 'full',
      render: () => <Inbox notification={NOTIFICATION_UPDATED} />,
    },
    {
      id: 'modele',
      label:
        'la carte de modèle est écrite dans la page (RideTemplateListPage), montée ici entière — vue d’organisation, seul public de la page',
      layout: 'full',
      url: () => paths.rideTemplates(TEMPLATE_TEAM_SLUGS.modele),
      render: () => <TemplatePage />,
    },
    {
      id: 'modele-brouillon',
      label: 'un modèle en brouillon, même page',
      layout: 'full',
      url: () => paths.rideTemplates(TEMPLATE_TEAM_SLUGS['modele-brouillon']),
      render: () => <TemplatePage />,
    },
    {
      id: 'appareils',
      label: 'un Karoo et une montre Garmin appairés',
      layout: 'full',
      render: () => <PairedDevicesManager />,
    },
    {
      id: 'commentaires',
      label: 'un commentaire, une réponse, un supprimé',
      layout: 'full',
      render: () => (
        <CommentSection
          teamSlug={VCM_SLUG}
          teamName={VCM_REF.name}
          entityType="rides"
          entitySlug={RIDE_SLUG}
          isOrganizer={false}
        />
      ),
    },
  ],
}
