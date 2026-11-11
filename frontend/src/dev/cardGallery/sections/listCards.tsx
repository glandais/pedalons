import { AdCard, RouteCard, TeamCard } from '@/components/card'
import { RouteRow } from '@/components/route/RouteRow'
import { RouteUsages } from '@/components/route/RouteUsages'
import { PendingInvitationsBanner } from '@/components/team/PendingInvitationsBanner'
import { TeamMemberList } from '@/components/team/TeamMemberList'
import { ParticipantsSection } from '@/components/publication/ParticipantsSection'
import type { GallerySection } from '../galleryLayout'
import {
  AD_DRAFT,
  AD_RENTAL,
  AD_SALE,
  AD_WANTED,
  CAMILLE,
  GRAVEL_TEAM,
  LEA,
  NOE,
  PEOPLE,
  RIDE_SLUG,
  ROUTE_SLUG,
  VCM_SLUG,
  VCM_TEAM,
  day,
  media,
  member,
  route,
} from '../fixtures'

export const routesSection: GallerySection = {
  id: 'parcours',
  title: 'Parcours — RouteCard, RouteRow, RouteUsages',
  entries: [
    {
      id: 'parcours',
      label: 'vignette, tags',
      layout: 'grid',
      render: () => <RouteCard route={route()} showTeam={false} />,
    },
    {
      id: 'parcours-sans-vignette',
      label: 'pas encore de vignette',
      layout: 'grid',
      render: () => (
        <RouteCard route={route({ thumbnailUrl: undefined, media: media() })} showTeam={false} />
      ),
    },
    {
      id: 'parcours-supprime',
      label: 'supprimé (vue d’un administrateur)',
      layout: 'grid',
      render: () => <RouteCard route={route({ deleted: true })} showTeam={false} />,
    },
    {
      id: 'parcours-ligne',
      label: 'densité compacte : la ligne de la liste (vue « Lignes »)',
      layout: 'full',
      render: () => <RouteRow route={route()} />,
    },
    {
      id: 'usages',
      label: '« Utilisé dans » : une sortie, un voyage (via une étape)',
      layout: 'full',
      render: () => <RouteUsages teamSlug={VCM_SLUG} routeSlug={ROUTE_SLUG} />,
    },
  ],
}

export const adsSection: GallerySection = {
  id: 'annonces',
  title: 'Annonces — AdCard',
  entries: [
    {
      id: 'annonce-vente',
      label: 'vente, 1 200 €, Brest',
      layout: 'grid',
      render: () => <AdCard ad={AD_SALE} />,
    },
    {
      id: 'annonce-location',
      label: 'location, 15 € par jour',
      layout: 'grid',
      render: () => <AdCard ad={AD_RENTAL} />,
    },
    {
      id: 'annonce-recherche',
      label: 'recherche, prix à négocier',
      layout: 'grid',
      render: () => <AdCard ad={AD_WANTED} />,
    },
    {
      id: 'annonce-brouillon',
      label: 'la vente, en brouillon',
      layout: 'grid',
      render: () => <AdCard ad={AD_DRAFT} />,
    },
  ],
}

export const teamsSection: GallerySection = {
  id: 'equipes',
  title: 'Équipes et personnes — TeamCard, invitations, TeamMemberList, ParticipantsSection',
  entries: [
    {
      id: 'equipe',
      label: 'Vélo Club des Monts, Camille membre',
      layout: 'grid',
      render: () => <TeamCard team={VCM_TEAM} showRole />,
    },
    {
      id: 'equipe-admin',
      label: 'Gravel Bretagne, Camille administratrice',
      layout: 'grid',
      render: () => <TeamCard team={GRAVEL_TEAM} showRole />,
    },
    {
      id: 'equipe-decouverte',
      label: 'Gravel Bretagne vue d’une personne non membre (même TeamCard, sans rôle)',
      layout: 'grid',
      render: () => <TeamCard team={{ ...GRAVEL_TEAM, role: undefined }} showRole />,
    },
    {
      id: 'invitations',
      label: 'une invitation en attente (bandeau de la liste des équipes)',
      layout: 'full',
      render: () => <PendingInvitationsBanner />,
    },
    {
      id: 'membre',
      label: 'annuaire vu d’un membre : Noé Perrin, membre',
      layout: 'full',
      render: () => (
        <TeamMemberList
          members={[member(NOE, 'MEMBER', day(-300))]}
          currentUserRole={null}
          currentUserId={CAMILLE.id}
        />
      ),
    },
    {
      id: 'membre-admin',
      label: 'annuaire vu d’un membre : Léa Martin, administratrice',
      layout: 'full',
      render: () => (
        <TeamMemberList
          members={[member(LEA, 'ADMIN', day(-800))]}
          currentUserRole={null}
          currentUserId={CAMILLE.id}
        />
      ),
    },
    {
      id: 'inscrits',
      label: `${PEOPLE.length} personnes du groupe A, Léa Martin capitaine`,
      layout: 'side',
      render: () => (
        <ParticipantsSection
          source={{ kind: 'ride', teamSlug: VCM_SLUG, rideSlug: RIDE_SLUG, groupId: 'g-a' }}
          count={PEOPLE.length}
          leaderId={LEA.id}
          titleId="gallery-participants"
        />
      ),
    },
  ],
}
