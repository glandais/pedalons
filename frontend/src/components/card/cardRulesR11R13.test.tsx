import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react'
import { MemoryRouter, Route, Routes, useLocation } from 'react-router-dom'
import { MantineProvider } from '@mantine/core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { UserDto } from '@/api/dto'
import { plain } from '@/test/weatherFixtures'
import { useAuthStore } from '@/store/authStore'
import { paths } from '@/config/paths'

const join = vi.hoisted(() => ({ mutate: vi.fn(), isPending: false }))
const report = vi.hoisted(() => ({ mutate: vi.fn(), notify: vi.fn() }))

vi.mock('@/lib/prefetch', () => ({ prefetchUrl: vi.fn() }))
vi.mock('@/config/appConfig', () => ({ isSingleTeam: () => false, getAppConfig: () => null }))
vi.mock('@/api/endpoints/team-members/team-members', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/api/endpoints/team-members/team-members')>()),
  useJoinTeam: () => join,
}))
vi.mock('@/api/endpoints/rides/rides', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/api/endpoints/rides/rides')>()),
  useGetRideParticipants: () => ({
    data: {
      participants: [
        { id: 'u-camille', displayName: 'Camille Durand' },
        { id: 'u-karim', displayName: 'Karim Benali' },
      ],
      total: 2,
      page: 0,
      size: 20,
    },
    isPending: false,
    error: null,
  }),
}))
vi.mock('@/api/endpoints/moderation/moderation', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@/api/endpoints/moderation/moderation')>()),
  useReportContent: () => ({ mutate: report.mutate, isPending: false }),
}))
vi.mock('@mantine/notifications', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@mantine/notifications')>()),
  notifications: { show: report.notify },
}))
vi.mock('react-i18next', async (importOriginal) => {
  const { frenchT } = await import('@/test/frenchT')
  return {
    ...(await importOriginal<typeof import('react-i18next')>()),
    useTranslation: () => ({ t: frenchT, i18n: { language: 'fr' } }),
  }
})

import { TeamCard } from './TeamCard'
import { PublicationCard } from './PublicationCard'
import { AgendaRow } from '../agenda/AgendaRow'
import { MyUpcomingList } from '../team/dashboard/MyUpcomingList'
import { RideTemplateCard } from '../ridetemplate/RideTemplateCard'
import { TeamMemberList } from '../team/TeamMemberList'
import { ParticipantList } from '../ride/ParticipantList'
import { CommentItem } from '../comment/CommentItem'
import { ReportModal } from '../moderation/ReportModal'
import {
  CAMILLE,
  GRAVEL_TEAM,
  MARKDOWN_COMMENTS,
  NOE,
  TEMPLATE,
  TEMPLATE_DRAFT,
  VCM_REF,
  member,
  ride,
} from '@/dev/cardGallery/fixtures'

function Where() {
  const location = useLocation()
  return <div data-testid="where">{location.pathname + location.search}</div>
}

function wrap(node: React.ReactNode) {
  return render(
    <MantineProvider>
      <QueryClientProvider client={new QueryClient()}>
        <MemoryRouter>
          <Routes>
            <Route
              path="*"
              element={
                <>
                  {node}
                  <Where />
                </>
              }
            />
          </Routes>
        </MemoryRouter>
      </QueryClientProvider>
    </MantineProvider>
  )
}

const text = () => plain(document.body.textContent)

function signIn(signedIn = true) {
  useAuthStore.setState({
    isAuthenticated: signedIn,
    user: signedIn ? ({ id: CAMILLE.id, displayName: CAMILLE.displayName } as UserDto) : null,
  })
}

beforeEach(() => {
  join.mutate.mockReset()
  join.isPending = false
  signIn()
})
afterEach(cleanup)

describe('R11 — lieu et groupe (docs/LEDGER_*.md WEB-167)', () => {
  it('feed card: « Groupe B · Place de la Mairie » under the departure, for a registered reader', () => {
    wrap(<PublicationCard publication={ride({ registered: true })} showTeam={false} />)
    expect(screen.getByTestId('group-place-line').textContent).toBe('Groupe B · Place de la Mairie')
    cleanup()
    wrap(<PublicationCard publication={ride()} showTeam={false} />)
    expect(screen.queryByTestId('group-place-line')).toBeNull()
  })

  it('team agenda row: the group once registered, the place alone otherwise', () => {
    wrap(<AgendaRow publication={ride({ registered: true })} />)
    expect(screen.getByTestId('group-place-line').textContent).toBe('Groupe B · Place de la Mairie')
    cleanup()
    wrap(<AgendaRow publication={ride()} />)
    expect(screen.getByTestId('group-place-line').textContent).toBe('Place de la Mairie')
    cleanup()
    wrap(<AgendaRow publication={ride({}, { startPlace: undefined })} />)
    expect(screen.queryByTestId('group-place-line')).toBeNull()
  })

  it('« Vos prochaines sorties »: the group and the place, then the server’s distance (R3)', () => {
    wrap(<MyUpcomingList publications={[ride({ registered: true })]} />)
    expect(screen.getByTestId('group-place-line').textContent).toBe('Groupe B · Place de la Mairie')
    expect(text()).toContain('78,0 km')
    expect(text()).toContain('980 m')
    expect(text()).not.toContain('25 km/h')
  })
})

describe('R12 — modèle de sortie', () => {
  it('says the name, « 3 groupes · prochaine sortie #12 », the paces in text, the description', () => {
    wrap(<RideTemplateCard template={TEMPLATE} canManage onDelete={vi.fn()} />)
    const card = screen.getByTestId('ride-template-card')
    expect(plain(card.textContent)).toContain('3 groupes · prochaine sortie #12')
    expect(plain(screen.getByTestId('ride-template-paces').textContent)).toBe(
      'A 28 km/h · B 25 km/h · C 22 km/h'
    )
    // The description, its Markdown stripped; never « Publié », nor the visibility.
    expect(card.textContent).toContain('place de la Mairie')
    expect(card.textContent).not.toContain('**')
    expect(card.textContent).not.toContain('Publié')
    expect(card.textContent).not.toContain('Équipe uniquement')
  })

  it('says « Brouillon » and « sans numéro » on a draft that numbers nothing', () => {
    wrap(<RideTemplateCard template={TEMPLATE_DRAFT} canManage onDelete={vi.fn()} />)
    expect(text()).toContain('Brouillon')
    expect(text()).toContain('1 groupe · sans numéro')
  })

  it('keeps a comment as typed: no Markdown rendered, its line breaks kept', () => {
    const [comment] = MARKDOWN_COMMENTS
    wrap(
      <CommentItem
        comment={{ ...comment, content: `${comment.content}\nÀ dimanche` }}
        canDeleteComment={() => false}
        onDeleteComment={vi.fn()}
        replyingTo={null}
        isDeleting={false}
        isReplying={false}
      />
    )
    const body = screen.getByText(/avant le départ/)
    expect(body.textContent).toContain('**avant le départ**')
    expect(body.querySelector('strong')).toBeNull()
    expect(body.style.whiteSpace).toBe('pre-wrap')
  })
})

describe('R13 — actions', () => {
  it('team card: « Rejoindre l’équipe » joins, outside the card’s link', () => {
    wrap(<TeamCard team={{ ...GRAVEL_TEAM, role: undefined }} showRole />)
    const button = screen.getByRole('button', { name: "Rejoindre l'équipe" })
    expect(button.closest('a')).toBeNull()
    fireEvent.click(button)
    expect(join.mutate).toHaveBeenCalledWith({ teamSlug: GRAVEL_TEAM.slug }, expect.anything())
    // The card did not open.
    expect(screen.getByTestId('where').textContent).toBe('/')
  })

  it('team card: « Adhésion… » while the call runs', () => {
    join.isPending = true
    wrap(<TeamCard team={{ ...GRAVEL_TEAM, role: undefined }} showRole />)
    const button = screen.getByRole('button', { name: 'Adhésion…' })
    expect((button as HTMLButtonElement).disabled).toBe(true)
  })

  it('team card: an anonymous visitor goes to the sign-in page, back to the team after', () => {
    signIn(false)
    wrap(<TeamCard team={{ ...GRAVEL_TEAM, role: undefined }} showRole />)
    const link = screen.getByRole('link', { name: "Rejoindre l'équipe" })
    expect(link.getAttribute('href')).toBe(paths.login())
    fireEvent.click(link)
    expect(screen.getByTestId('where').textContent).toBe(paths.login())
    expect(join.mutate).not.toHaveBeenCalled()
  })

  it('team card: « Sur invitation » disabled when the team does not open, nothing for a member', () => {
    wrap(<TeamCard team={{ ...GRAVEL_TEAM, role: undefined, joinable: false }} showRole />)
    const button = screen.getByRole('button', { name: 'Sur invitation' })
    expect((button as HTMLButtonElement).disabled).toBe(true)
    cleanup()
    wrap(<TeamCard team={GRAVEL_TEAM} showRole />)
    expect(screen.queryByRole('button')).toBeNull()
    expect(text()).toContain('Organisateur')
  })

  it('template card: « Créer une sortie » opens the ride form with the template', () => {
    wrap(<RideTemplateCard template={TEMPLATE} canManage onDelete={vi.fn()} />)
    const link = screen.getByRole('link', { name: 'Créer une sortie' })
    expect(link.getAttribute('href')).toBe(
      `${paths.rideNew(VCM_REF.slug)}?template=${TEMPLATE.slug}`
    )
    // The pencil and the bin stay.
    expect(screen.getByRole('link', { name: 'Modifier' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Supprimer' })).toBeTruthy()
  })

  it('member row: a ⋯ menu « Signaler » and « Bloquer {nom} », none on one’s own row', async () => {
    wrap(
      <TeamMemberList
        members={[
          member(CAMILLE, 'MEMBER', '2024-03-03T10:00:00Z'),
          member(NOE, 'MEMBER', '2024-03-03T10:00:00Z'),
        ]}
        currentUserRole={null}
        currentUserId={CAMILLE.id}
      />
    )
    const menus = screen.getAllByRole('button', { name: "Plus d'actions" })
    expect(menus).toHaveLength(1)
    fireEvent.click(menus[0])
    const dropdown = await screen.findByRole('menu')
    expect(within(dropdown).getByText('Signaler')).toBeTruthy()
    expect(within(dropdown).getByText('Bloquer Noé Perrin')).toBeTruthy()
  })

  it('member row: « Modifier » and « Retirer » stay for an administrator, beside the menu', () => {
    wrap(
      <TeamMemberList
        members={[member(NOE, 'MEMBER', '2024-03-03T10:00:00Z')]}
        currentUserRole="ADMIN"
        currentUserId={CAMILLE.id}
        onUpdateRole={vi.fn()}
        onRemoveMember={vi.fn()}
      />
    )
    expect(screen.getByRole('button', { name: 'Modifier' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Retirer' })).toBeTruthy()
    expect(screen.getByRole('button', { name: "Plus d'actions" })).toBeTruthy()
  })

  it('registered person’s row: the same menu, not on one’s own row', () => {
    wrap(
      <ParticipantList
        source={{ kind: 'ride', teamSlug: 'vcm', rideSlug: 'boucle', teamName: 'VCM' }}
        count={2}
        search={undefined}
        page={0}
        searchInput=""
        onSearchInputChange={vi.fn()}
        onPageChange={vi.fn()}
      />
    )
    expect(screen.getAllByRole('button', { name: "Plus d'actions" })).toHaveLength(1)
  })

  it('reporting a member thanks without saying a content is hidden', () => {
    report.mutate.mockImplementation((_vars, { onSuccess }) => onSuccess())
    wrap(
      <ReportModal
        opened
        onClose={vi.fn()}
        teamSlug="vcm"
        teamName="VCM"
        targetType="MEMBER"
        targetId={NOE.id}
      />
    )
    expect(screen.getByText('Signaler ce membre')).toBeTruthy()
    fireEvent.click(screen.getByLabelText('Spam ou publicité'))
    fireEvent.click(screen.getByRole('button', { name: 'Envoyer' }))
    expect(report.mutate.mock.calls[0][0].data).toMatchObject({
      targetType: 'MEMBER',
      targetId: NOE.id,
    })
    expect(report.notify).toHaveBeenCalledWith(
      expect.objectContaining({ message: 'Merci. Votre signalement a été transmis.' })
    )
  })
})
