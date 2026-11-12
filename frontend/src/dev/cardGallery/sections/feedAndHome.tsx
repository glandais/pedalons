import { PublicationCard } from '@/components/card'
import { NextRideCard } from '@/components/home/NextRideCard'
import { WeekAgenda } from '@/components/home/WeekAgenda'
import { MyTeamsCard } from '@/components/home/MyTeamsCard'
import { AgendaRow } from '@/components/agenda/AgendaRow'
import { MemberHome } from '@/pages/home/MemberHome'
import { hourAlignedNowIso } from '@/utils/nowIso'
import type { GallerySection } from '../galleryLayout'
import {
  CAMILLE,
  GRAVEL_REF,
  GRAVEL_TEAM,
  VCM_TEAM,
  WEEK_EVENTS,
  day,
  draftPost,
  media,
  post,
  ride,
  rideUnderWay,
  rideWithoutGroups,
  trip,
} from '../fixtures'
import { PHOTO_URL } from '../images'

const cancelled = { status: 'CANCELLED' as const, weather: undefined }

/** A content with a photo: its first picture is the card's banner (R10), as the app's gallery. */
const photoMedia = media({
  images: [
    {
      id: 'as-photo',
      fileName: 'photo.png',
      contentType: 'image/svg+xml',
      url: PHOTO_URL,
      imageUrl: PHOTO_URL,
    },
  ],
})

/** « Traversée du Morvan » over: J−16 → J−14, its last stage at J−14 09:00 (the app's). */
function tripOver() {
  return trip(-16, { endDate: day(-14, '09:00'), endDateTime: day(-14, '16:00'), finished: true })
}

/** The same trip in a public team, read by someone outside it: the count, never a name (R4). */
function tripOutsider() {
  const base = trip()
  return trip(10, {
    team: GRAVEL_REF,
    visibility: 'PUBLIC',
    participants: [],
    commentCount: undefined,
    permissions: {
      ...base.permissions,
      canRegister: false,
      canComment: false,
      canSeeParticipants: false,
    },
  })
}

export const feedSection: GallerySection = {
  id: 'fil',
  title: 'Fil — PublicationCard',
  entries: [
    {
      id: 'fil-sortie',
      label: 'nominale, non inscrite',
      layout: 'grid',
      render: () => <PublicationCard publication={ride()} showTeam={false} />,
    },
    {
      id: 'fil-sortie-inscrite',
      label: 'inscrite au groupe B, 09:30',
      layout: 'grid',
      render: () => <PublicationCard publication={ride({ registered: true })} showTeam={false} />,
    },
    {
      id: 'fil-sortie-demain',
      label: 'J+1',
      layout: 'grid',
      render: () => <PublicationCard publication={ride({ offset: 1 })} showTeam={false} />,
    },
    {
      id: 'fil-sortie-en-cours',
      label: 'partie il y a 1 h',
      layout: 'grid',
      render: () => <PublicationCard publication={rideUnderWay()} showTeam={false} />,
    },
    {
      id: 'fil-sortie-terminee',
      label: 'J−2',
      layout: 'grid',
      render: () => <PublicationCard publication={ride({ offset: -2 })} showTeam={false} />,
    },
    {
      id: 'fil-sortie-annulee',
      label: 'annulée',
      layout: 'grid',
      render: () => (
        <PublicationCard
          publication={ride(
            {},
            {
              ...cancelled,
              permissions: { ...ride().permissions, canRegister: false },
            }
          )}
          showTeam={false}
        />
      ),
    },
    {
      id: 'fil-sortie-brouillon',
      label: 'brouillon',
      layout: 'grid',
      render: () => (
        <PublicationCard
          publication={ride({}, { status: 'DRAFT', weather: undefined })}
          showTeam={false}
        />
      ),
    },
    {
      id: 'fil-sortie-sans-groupe',
      label: 'ni groupe ni parcours',
      layout: 'grid',
      render: () => <PublicationCard publication={rideWithoutGroups()} showTeam={false} />,
    },
    {
      id: 'fil-sortie-alerte-pluie',
      label: 'pluie 60 % vers 11:00',
      layout: 'grid',
      render: () => <PublicationCard publication={ride({ rainAlert: true })} showTeam={false} />,
    },
    {
      id: 'fil-sortie-meteo-a-venir',
      label: 'J+10, la prévision ouvre à J+3',
      layout: 'grid',
      render: () => (
        <PublicationCard
          publication={ride(
            { offset: 10 },
            {
              slug: 'boucle-meteo-a-venir',
              weather: { status: 'NOT_YET_AVAILABLE', availableFrom: day(3, '00:00') },
            }
          )}
          showTeam={false}
        />
      ),
    },
    {
      id: 'fil-sortie-photo',
      label: 'une photo : en bandeau, la carte du tracé en vignette',
      layout: 'grid',
      render: () => (
        <PublicationCard
          publication={ride({}, { slug: 'boucle-photo', media: photoMedia })}
          showTeam={false}
        />
      ),
    },
    {
      id: 'fil-sortie-lien',
      label: 'lisible par lien (Public) dans l’équipe privée',
      layout: 'grid',
      render: () => (
        <PublicationCard
          publication={ride({}, { slug: 'boucle-lien', visibility: 'PUBLIC' })}
          showTeam={false}
        />
      ),
    },
    {
      id: 'fil-voyage',
      label: 'J+10 → J+12',
      layout: 'grid',
      render: () => <PublicationCard publication={trip()} showTeam={false} />,
    },
    {
      id: 'fil-voyage-termine',
      label: 'J−16 → J−14',
      layout: 'grid',
      render: () => <PublicationCard publication={tripOver()} showTeam={false} />,
    },
    {
      id: 'fil-voyage-non-membre',
      label: 'Gravel Bretagne (publique), vu d’une personne non membre',
      layout: 'grid',
      render: () => <PublicationCard publication={tripOutsider()} showTeam={false} />,
    },
    {
      id: 'fil-voyage-inscrit-en-cours',
      label: 'inscrite, commencé hier',
      layout: 'grid',
      render: () => (
        <PublicationCard
          publication={trip(-1, {
            registered: true,
            participants: [CAMILLE, ...trip().participants],
          })}
          showTeam={false}
        />
      ),
    },
    {
      id: 'fil-voyage-annule',
      label: 'annulé',
      layout: 'grid',
      render: () => <PublicationCard publication={trip(10, cancelled)} showTeam={false} />,
    },
    {
      id: 'fil-publication',
      label: 'avec photo',
      layout: 'grid',
      render: () => <PublicationCard publication={post()} showTeam={false} />,
    },
    {
      id: 'fil-publication-brouillon',
      label: 'brouillon, sans photo',
      layout: 'grid',
      render: () => <PublicationCard publication={draftPost()} showTeam={false} />,
    },
    {
      id: 'fil-supprime',
      label: 'sortie supprimée (vue d’un administrateur)',
      layout: 'grid',
      render: () => <PublicationCard publication={ride({}, { deleted: true })} showTeam={false} />,
    },
  ],
}

/** « Ma prochaine sortie » in group B, whose maximum has been lifted. */
function rideWithoutMaximum() {
  const base = ride({ registered: true })
  const group = base.registeredGroup && {
    ...base.registeredGroup,
    maxParticipants: undefined,
    full: false,
  }
  return { ...base, registeredGroup: group }
}

export const homeSection: GallerySection = {
  id: 'accueil',
  title: 'Accueil — NextRideCard, WeekAgenda, MyTeamsCard',
  entries: [
    {
      id: 'prochaine-sortie',
      label: 'inscrite au groupe B',
      layout: 'homeMain',
      render: () => <NextRideCard ride={ride({ registered: true })} headingId="next-ride-1" />,
    },
    {
      id: 'prochaine-sortie-sans-maximum',
      label: 'groupe sans nombre maximum',
      layout: 'homeMain',
      render: () => <NextRideCard ride={rideWithoutMaximum()} headingId="next-ride-2" />,
    },
    {
      id: 'prochaine-sortie-vide',
      label:
        'rien de réservé — l’état vide est rendu par la page (MemberHome), montée ici en entier avec des listes vides',
      layout: 'full',
      render: () => <MemberHome />,
    },
    {
      id: 'semaine',
      label: '5 lignes : sortie, inscrite, étape d’un voyage d’une étape, annulée, brouillon',
      layout: 'homeAside',
      render: () => (
        <WeekAgenda nowIso={hourAlignedNowIso()} events={WEEK_EVENTS} isLoading={false} />
      ),
    },
    {
      id: 'semaine-vide',
      label: 'rien dans les 7 jours',
      layout: 'homeAside',
      render: () => <WeekAgenda nowIso={hourAlignedNowIso()} events={[]} isLoading={false} />,
    },
    {
      id: 'mes-equipes',
      label: 'deux équipes, rôles différents',
      layout: 'homeAside',
      render: () => <MyTeamsCard teams={[VCM_TEAM, GRAVEL_TEAM]} total={2} isLoading={false} />,
    },
    {
      id: 'mes-equipes-vide',
      label: 'aucune équipe',
      layout: 'homeAside',
      render: () => <MyTeamsCard teams={[]} total={0} isLoading={false} />,
    },
  ],
}

export const agendaSection: GallerySection = {
  id: 'agenda',
  title: 'Agenda — AgendaRow (vue « Lignes »)',
  entries: [
    {
      id: 'agenda-sortie',
      label: 'sortie à venir',
      layout: 'full',
      render: () => <AgendaRow publication={ride()} />,
    },
    {
      id: 'agenda-inscrite',
      label: 'inscrite au groupe B',
      layout: 'full',
      render: () => <AgendaRow publication={ride({ registered: true })} />,
    },
    {
      id: 'agenda-annulee',
      label: 'annulée',
      layout: 'full',
      render: () => (
        <AgendaRow
          publication={ride(
            { offset: 5 },
            {
              ...cancelled,
              id: 'r-drennec',
              slug: 'tour-du-lac-du-drennec',
              name: 'Tour du lac du Drennec',
              distance: 54_000,
              elevationGain: 610,
              displayDistance: 54_000,
              displayElevationGain: 610,
            }
          )}
        />
      ),
    },
    {
      id: 'agenda-etape',
      label: 'étape d’un voyage',
      omitted:
        'la vue « Lignes » de l’agenda liste le voyage entier (AgendaRow prend une sortie ou un voyage) ; une étape n’apparaît que dans la grille du calendrier (CalendarView).',
    },
    {
      id: 'agenda-passee',
      label: 'J−2, terminée',
      layout: 'full',
      render: () => <AgendaRow publication={ride({ offset: -2 })} />,
    },
  ],
}
