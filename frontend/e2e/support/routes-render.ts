import type {
  AdDto,
  AssetDto,
  AssetTypeRequest,
  CommentDto,
  CommentRequest,
  GpxPreviewDto,
  MediaDto,
  PlaceDetailDto,
  PlaceRequest,
  PostDto,
  RideDto,
  RideTemplateDto,
  RideTemplateRequest,
  RouteDto,
  TagCreateRequest,
  TagDto,
  TagTarget,
  TeamDetailDto,
  TeamPageDto,
  TripDto,
} from '../../src/api/dto'
import { newAd, solidPng, uploadImage } from './ads'
import { contractEnglishPaths, fillPath } from './contract'
import { apiPost, apiPut, expectOk, withApi, type AuthResponse } from './api'
import { addMember, newTeam, newTeamPage, newUser, roleSession, teamRequest } from './data'
import { setPlatformRole } from './platform-admin'
import { newPost } from './posts'
import { joinGroup, newRide } from './rides'
import { gpxOf, newRoute, newTrip, windingTrack } from './routes'

/**
 * The dataset of routes-render.e2e.ts: one real value for every `{param}` of contracts/routes.yaml
 * (see contract.ts), and a session for every role the route table names.
 */

/**
 * Who opens a screen: an anonymous visitor, a signed-in user who belongs to no team of the dataset
 * (`outsider`), the dataset team's member, organizer and admin, and the platform admin.
 */
export type RenderRole =
  'anonymous' | 'outsider' | 'member' | 'organizer' | 'teamAdmin' | 'platformAdmin'

/** Every role, in the order the tests are declared. */
export const RENDER_ROLES: readonly RenderRole[] = [
  'anonymous',
  'outsider',
  'member',
  'organizer',
  'teamAdmin',
  'platformAdmin',
]

export interface Dataset {
  team: TeamDetailDto
  sessions: Record<Exclude<RenderRole, 'anonymous'>, AuthResponse>
  ride: RideDto
  /** A ride of a single group on `route`: what a solo ride's fullscreen map draws (WEB-118). */
  soloRide: RideDto
  /** Its route, the first stage's, and the one route the screens name. */
  route: RouteDto
  /** The route of the ride's first group, and of the trip's second stage. */
  otherRoute: RouteDto
  trip: TripDto
  post: PostDto
  ad: AdDto
  page: TeamPageDto
  template: RideTemplateDto
  place: PlaceDetailDto
  preview: GpxPreviewDto
  /** Every `{param}` of the contract, filled from the entities above. */
  params: Record<string, string>
}

/**
 * A public team — so an anonymous visitor may read its public screens — owned by a user of its own,
 * with a plain member, an organizer and an admin, and one public entity of every kind a route
 * names. The platform admin adds the members (a team is born with addMemberAllowed=false) and is
 * not a member itself. The outsider is a plain signed-in account that joins nothing.
 *
 * Every entity is filled the way a team's real one is, not left at its minimum: a screen only
 * fires the queries its data calls for — a group's route, the places a ride form has selected, a
 * stage's route — and a query that never fires is a prefetch nobody audits. So the team has a
 * logo, a location and a picture; the ride its own route, a start and an end place, a group with a
 * route of its own, a leader and a rider, and a group with none of them; the trip two stages with a
 * route each, the first with its places, and a rider; the ad a picture and a location; the post and
 * the page a picture; the template two groups; the rides, trips, posts, routes and ads a tag each;
 * every commentable entity a comment.
 *
 * The platform admin is a fresh account promoted for the run ({@link releaseDataset} takes the role
 * back), not the bootstrap `admin@e2e.test`: that one owns a team per spec that creates one as it,
 * run after run, and its screens grow with them. `/calendrier` lists every outing of its teams over
 * eight months, unpaginated — after a few runs on the same database, thousands on the same week,
 * which `@mantine/schedule` lays out in quadratic time: a 20 s server render, and a timeout.
 */
export async function buildDataset(label: string): Promise<Dataset> {
  const [owner, outsider, member, organizer, teamAdmin, platformAdmin] = await Promise.all([
    newUser(`Fondatrice ${label}`),
    newUser(`Passante ${label}`),
    newUser(`Membre ${label}`),
    newUser(`Organisatrice ${label}`),
    newUser(`Admin équipe ${label}`),
    newUser(`Admin plateforme ${label}`),
  ])
  await setPlatformRole(platformAdmin.user.id, 'PLATFORM_ADMIN')
  const created = await newTeam(owner, `Écrans ${label}`, { visibility: 'PUBLIC' })
  await addMember(platformAdmin, created.slug, member, 'MEMBER')
  await addMember(platformAdmin, created.slug, organizer, 'ORGANIZER')
  await addMember(platformAdmin, created.slug, teamAdmin, 'ADMIN')
  const slug = created.slug

  // What the entities point at: places, tags, pictures.
  const [place, tags, logo, teamPicture, adPicture, postPicture, pagePicture] = await Promise.all([
    apiPost<PlaceDetailDto>(teamAdmin, `/api/teams/${slug}/places`, {
      name: `Lieu ${label}`,
      address: '1 place des Halles, Chartres',
      startPlace: true,
      endPlace: true,
      geometry: { type: 'Point', coordinates: [1.4875, 48.4469] },
    } satisfies PlaceRequest),
    newTags(teamAdmin, slug, label),
    uploadAsset(teamAdmin, slug, 'LOGO', 'logo.png', solidPng(64, 64, [30, 90, 200])),
    uploadImage(teamAdmin, slug, 'equipe.png', solidPng(64, 48, [40, 160, 80])),
    uploadImage(member, slug, 'annonce.png', solidPng(64, 48, [200, 60, 40])),
    uploadImage(organizer, slug, 'article.png', solidPng(64, 48, [220, 180, 40])),
    uploadImage(teamAdmin, slug, 'page.png', solidPng(64, 48, [120, 60, 160])),
  ])
  // A logo, a location and a picture in its description. Its visibility stays PUBLIC: the platform
  // admin sends it, as newTeam does — the owner may not touch a visibility the team cannot edit.
  const team = await apiPut<TeamDetailDto>(
    await roleSession('admin'),
    `/api/teams/${slug}`,
    teamRequest(created.name, {
      visibility: 'PUBLIC',
      media: withImages('Une équipe pour vérifier les écrans.', [teamPicture], logo),
      geometry: { type: 'Point', coordinates: [1.4875, 48.4469] },
    })
  )

  const track = windingTrack(120)
  const [route, otherRoute] = await Promise.all([
    newRoute(organizer, slug, `Parcours ${label}`, track, {
      visibility: 'PUBLIC',
      tagIds: [tags.ROUTE.id],
    }),
    newRoute(organizer, slug, `Boucle ${label}`, windingTrack(80), { visibility: 'PUBLIC' }),
  ])
  const [ride, soloRide, trip, publication, ad, page, template, preview] = await Promise.all([
    newRide(organizer, slug, `Sortie ${label}`, {
      visibility: 'PUBLIC',
      routeSlug: route.slug,
      startPlaceId: place.id,
      endPlaceId: place.id,
      tagIds: [tags.RIDE.id],
      groups: [
        {
          name: 'Groupe A',
          time: '08:30:00',
          averageSpeed: 25,
          maxParticipants: 12,
          routeSlug: otherRoute.slug,
          leaderId: organizer.user.id,
        },
        { name: 'Groupe B' },
      ],
    }),
    // Its one default group rides the ride's route
    newRide(organizer, slug, `Sortie solo ${label}`, {
      visibility: 'PUBLIC',
      routeSlug: route.slug,
    }),
    newTrip(
      organizer,
      slug,
      `Voyage ${label}`,
      [
        {
          name: `Étape ${label}`,
          routeSlug: route.slug,
          startPlaceId: place.id,
          endPlaceId: place.id,
        },
        { name: `Seconde étape ${label}`, routeSlug: otherRoute.slug },
      ],
      { visibility: 'PUBLIC', tagIds: [tags.TRIP.id] }
    ),
    newPost(organizer, slug, `Article ${label}`, {
      media: withImages('Un article pour vérifier les écrans.', [postPicture]),
      visibility: 'PUBLIC',
      tagIds: [tags.POST.id],
    }),
    newAd(member, slug, {
      name: `Annonce ${label}`,
      body: 'Un vélo à vendre.',
      price: 100,
      images: [adPicture],
      locationDescription: 'Chartres',
      locationGeometry: { type: 'Point', coordinates: [1.4875, 48.4469] },
      tagIds: [tags.AD.id],
    }),
    newTeamPage(teamAdmin, slug, `Page ${label}`, '', {
      visibility: 'PUBLIC',
      media: withImages('Une page pour vérifier les écrans.', [pagePicture]),
    }),
    apiPost<RideTemplateDto>(teamAdmin, `/api/teams/${slug}/ride-templates`, {
      name: `Modèle ${label}`,
      markdown: 'Le rendez-vous du samedi.',
      visibility: 'TEAM',
      status: 'PUBLISHED',
      groups: [
        { name: 'Groupe A', time: '08:30:00', averageSpeed: 25, maxParticipants: 12 },
        { name: 'Groupe B', time: '09:00:00', averageSpeed: 20 },
      ],
      tagIds: [tags.RIDE.id],
    } satisfies RideTemplateRequest),
    uploadPreview(member, `Trace ${label}`, gpxOf(`Trace ${label}`, track)),
  ])

  // Riders and comments: the participant counts, the comment threads.
  const comment = (path: string) =>
    apiPost<CommentDto>(member, `/api/teams/${slug}/${path}/comments`, {
      content: 'Un commentaire pour vérifier les écrans.',
    } satisfies CommentRequest)
  await Promise.all([
    joinGroup(member, slug, ride, 'Groupe A'),
    apiPost(member, `/api/teams/${slug}/trips/${trip.slug}/join`),
    comment(`rides/${ride.slug}`),
    comment(`trips/${trip.slug}`),
    comment(`stages/${trip.stages[0].slug}`),
    comment(`posts/${publication.slug}`),
    comment(`routes/${route.slug}`),
  ])

  return {
    team,
    sessions: { outsider, member, organizer, teamAdmin, platformAdmin },
    ride,
    soloRide,
    route,
    otherRoute,
    trip,
    post: publication,
    ad,
    page,
    template,
    place,
    preview,
    params: {
      teamSlug: slug,
      rideSlug: ride.slug,
      // Groupe A: a leader, a pace, a max, its own route and a rider.
      groupId: ride.groups.find((g) => g.name === 'Groupe A')!.id,
      routeSlug: route.slug,
      tripSlug: trip.slug,
      stageSlug: trip.stages[0].slug,
      postSlug: publication.slug,
      adSlug: ad.slug,
      pageSlug: page.slug,
      templateSlug: template.slug,
      previewId: preview.id,
    },
  }
}

/** One tag of every kind the team's content takes, created by its admin. */
async function newTags(
  admin: AuthResponse,
  teamSlug: string,
  label: string
): Promise<Record<TagTarget, TagDto>> {
  const targets: TagTarget[] = ['RIDE', 'TRIP', 'POST', 'ROUTE', 'AD']
  const tags = await Promise.all(
    targets.map((type) =>
      apiPost<TagDto>(admin, `/api/teams/${teamSlug}/tags`, {
        type,
        label: `${type.toLowerCase()} ${label}`.slice(0, 40),
        color: 'TEAL',
      } satisfies TagCreateRequest)
    )
  )
  return Object.fromEntries(targets.map((type, i) => [type, tags[i]])) as Record<TagTarget, TagDto>
}

/**
 * The `media` of a request whose markdown shows `images` — the backend keeps only the pictures a
 * `::asset{id="…"}` directive points at — and, for a team, its `logo`.
 */
function withImages(markdown: string, images: AssetDto[], logo?: AssetDto): MediaDto {
  return {
    markdown: [markdown, ...images.map((image) => `::asset{id="${image.id}"}`)].join('\n\n'),
    assets: { logo, images, attachments: [] },
  }
}

/** Uploads a picture of `type` to the team's asset store, as the editors do. */
const uploadAsset = (
  as: AuthResponse,
  teamSlug: string,
  type: AssetTypeRequest,
  name: string,
  png: Buffer
) =>
  withApi(as, async (api) =>
    expectOk<AssetDto>(
      await api.post(`/api/teams/${teamSlug}/assets?assetType=${type}`, {
        multipart: { file: { name, mimeType: 'image/png', buffer: png } },
      })
    )
  )

/** Takes back the platform role {@link buildDataset} granted: never leave a stray platform admin. */
export async function releaseDataset(dataset: Dataset) {
  await setPlatformRole(dataset.sessions.platformAdmin.user.id, undefined)
}

/** A GPX preview (the « Outils GPX » upload), owned by `as`. */
const uploadPreview = (as: AuthResponse, name: string, gpx: string) =>
  withApi(as, async (api) =>
    expectOk<GpxPreviewDto>(
      await api.post('/api/gpx-previews', {
        multipart: {
          gpxFile: {
            name: `${name}.gpx`,
            mimeType: 'application/gpx+xml',
            buffer: Buffer.from(gpx),
          },
        },
      })
    )
  )

const englishTemplates = contractEnglishPaths()

/** The English path of the contract's route `id`, every `{param}` filled from `params`. */
export function englishPath(id: string, params: Record<string, string>): string {
  const path = englishTemplates.get(id)
  if (!path) throw new Error(`no web route ${id} in the contract`)
  return fillPath({ id, path, params: [] }, params)
}
