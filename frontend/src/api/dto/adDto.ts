import type { AdDtoLocationGeometry } from './adDtoLocationGeometry.ts'
import type { AdType } from './adType.ts'
import type { Instant } from './instant.ts'
import type { MediaDto } from './mediaDto.ts'
import type { RentalPeriod } from './rentalPeriod.ts'
import type { Status } from './status.ts'
import type { TagDto } from './tagDto.ts'
import type { TeamPublicationDto } from './teamPublicationDto.ts'
import type { Visibility } from './visibility.ts'

/**
 * Ad data
 */
export interface AdDto {
  /** Team */
  team: TeamPublicationDto
  /** Ad ID (TSID) */
  id: string
  /** Ad URL slug */
  slug: string
  /** Ad name */
  name: string
  /** Ad media */
  media: MediaDto
  /** Plain-text opening of the description, flattened (links become their label) and cut on a word boundary at about 200 characters. Null when the description holds no text. Lets a list row render its two lines without the description being sent at all — see the 'view' parameter. */
  excerpt?: string
  /** URL template of the ad's first picture, the one a card shows. Saves a compact row from carrying media.assets just to find it. Opaque URL: may carry a query string; substitute {size} only. */
  thumbnailUrl?: string
  /** URL templates of every picture on the ad, in editor order — the gallery. Present whatever the 'view', so a compact row can show a carousel without pulling media.assets. The first entry is the same picture as 'thumbnailUrl'. */
  images: string[]
  /** Ad status */
  status: Status
  /** Visibility level */
  visibility: Visibility
  /** Ad type */
  adType: AdType
  /** Price */
  price?: number
  /** Period the price applies to, for a rental — render as 'price / period'. Null for a sale, and for a rental whose period has not been set. */
  rentalPeriod?: RentalPeriod
  /** Location description */
  locationDescription?: string
  /** Approximate location of the ad, deliberately blurred: the point is the centre of a fixed cell about 1 km across, not the seller's address. Enough to tell a nearby ad from a distant one, and the same value on every read so repeated calls cannot be averaged back to the exact position. Null when the ad has no location. The exact point stays on AdEditDto, and only for the seller: the team's admins get this blurred point there too. Proximity filters measure from this blurred point too, never from the exact one. */
  locationGeometry?: AdDtoLocationGeometry
  /** Creation timestamp */
  createdAt: Instant
  /** Creation timestamp */
  updatedAt: Instant
  /** Creator ID (TSID) */
  createdById: string
  /** Display name of the member who posted the ad. The only thing about them this DTO carries: there is no contact channel on an Ad, and inventing one (an email, a phone number) is a product decision, not a serialisation one. */
  createdByDisplayName: string
  /** Whether the ad is soft-deleted */
  deleted: boolean
  /** The team's AD tags the ad carries, sorted by label. Empty when it carries none. */
  tags: TagDto[]
}
