import {
  IconCloud,
  IconCloudFog,
  IconCloudRain,
  IconCloudSnow,
  IconCloudStorm,
  IconDroplet,
  IconDroplets,
  IconHaze,
  IconHazeMoon,
  IconMoon,
  IconMoonStars,
  IconSnowflake,
  IconSun,
  IconSunLow,
  IconUmbrella,
} from '@tabler/icons-react'
import { CompassPoint, RelativeWind, WeatherCondition, WeatherStatus } from '@/api/dto'
import type { RideWeatherSummaryDto, WindSegmentDto } from '@/api/dto'
import { RELATIVE_WIND_COLORS } from '@/lib/badgeColors.generated'
import type { BadgeFamily } from '@/lib/badgeColors.generated'

/**
 * How the weather looks: the one table from a forecast's condition to its icon, plus the small
 * decisions every weather component shares (which statuses show anything, which group comes
 * first, how the wind stretches split the route).
 *
 * The API carries the computations — passages, relative wind, exposure, rain alert
 * (docs/plans/archive/2026-10-05-weather.md §1) — and no rendered text: the client only picks icons,
 * words, and units. An enum value this build does not know yet (the contract only grows) never
 * breaks a card: an unknown condition draws a plain cloud, an unknown status draws nothing.
 */

/** What `@tabler/icons-react` actually exports — a forwardRef component, not a plain function. */
type TablerIcon = typeof IconCloud

/**
 * Icons only, no colour: a colour per condition would be a local colour table for a contract enum,
 * which only contracts/brand-colors.yaml may hold (docs/BRANDING.md §3.6) — and the mobile draws
 * them in one neutral tint too. The icon takes the colour of the text around it.
 */
interface ConditionDisplay {
  day: TablerIcon
  night: TablerIcon
}

const CONDITION_DISPLAY: Record<WeatherCondition, ConditionDisplay> = {
  [WeatherCondition.CLEAR]: { day: IconSun, night: IconMoon },
  [WeatherCondition.MOSTLY_CLEAR]: { day: IconSunLow, night: IconMoonStars },
  [WeatherCondition.PARTLY_CLOUDY]: { day: IconHaze, night: IconHazeMoon },
  [WeatherCondition.OVERCAST]: { day: IconCloud, night: IconCloud },
  [WeatherCondition.FOG]: { day: IconCloudFog, night: IconCloudFog },
  [WeatherCondition.DRIZZLE]: { day: IconDroplet, night: IconDroplet },
  [WeatherCondition.RAIN]: { day: IconCloudRain, night: IconCloudRain },
  [WeatherCondition.HEAVY_RAIN]: { day: IconDroplets, night: IconDroplets },
  [WeatherCondition.FREEZING_RAIN]: { day: IconSnowflake, night: IconSnowflake },
  [WeatherCondition.SHOWERS]: { day: IconUmbrella, night: IconUmbrella },
  [WeatherCondition.SNOW]: { day: IconCloudSnow, night: IconCloudSnow },
  [WeatherCondition.THUNDERSTORM]: { day: IconCloudStorm, night: IconCloudStorm },
}

const FALLBACK_DISPLAY: ConditionDisplay = { day: IconCloud, night: IconCloud }

export function isKnownCondition(condition: string | undefined): condition is WeatherCondition {
  return !!condition && Object.prototype.hasOwnProperty.call(CONDITION_DISPLAY, condition)
}

/**
 * The conditions that fall from the sky, the ones a rain alert can be named after. The alert is
 * raised on probability alone (50 % or more), so the hour's condition may well be « Couvert » or
 * one this build does not know: a card then says « Pluie », never « Couvert dès 10:00 ».
 */
const PRECIPITATING_CONDITIONS: ReadonlySet<string> = new Set<WeatherCondition>([
  WeatherCondition.DRIZZLE,
  WeatherCondition.RAIN,
  WeatherCondition.HEAVY_RAIN,
  WeatherCondition.FREEZING_RAIN,
  WeatherCondition.SHOWERS,
  WeatherCondition.SNOW,
  WeatherCondition.THUNDERSTORM,
])

/** The condition a rain alert is worded with: its own when it precipitates, RAIN otherwise. */
export function rainAlertCondition(condition: string | undefined): WeatherCondition {
  return condition && PRECIPITATING_CONDITIONS.has(condition)
    ? (condition as WeatherCondition)
    : WeatherCondition.RAIN
}

/** The icon of a condition, by day or by night; a plain cloud for a condition not known here. */
export function weatherIcon(condition: string | undefined, daylight = true): TablerIcon {
  const display = isKnownCondition(condition) ? CONDITION_DISPLAY[condition] : FALLBACK_DISPLAY
  return daylight ? display.day : display.night
}

/** OK and STALE carry a forecast; STALE is shown, flagged as old. */
export function hasForecast(status: string | undefined): boolean {
  return status === WeatherStatus.OK || status === WeatherStatus.STALE
}

/**
 * Whether the ride page shows a weather block for this status at all. OUT_OF_RANGE (finished,
 * cancelled) and any status unknown to this build show nothing; NO_LOCATION is only worth a word
 * to whoever can fix it — the organisers.
 */
export function showsDetailBlock(status: string | undefined, canEdit: boolean): boolean {
  switch (status) {
    case WeatherStatus.OK:
    case WeatherStatus.STALE:
    case WeatherStatus.NOT_YET_AVAILABLE:
    case WeatherStatus.UNAVAILABLE:
      return true
    case WeatherStatus.NO_LOCATION:
      return canEdit
    default:
      return false
  }
}

/** Whether a card's summary line has anything to say: the API only sends these three. */
export function showsSummary(summary: RideWeatherSummaryDto | undefined): boolean {
  if (!summary) return false
  if (summary.status === WeatherStatus.NOT_YET_AVAILABLE) return !!summary.availableFrom
  return hasForecast(summary.status)
}

/**
 * The range a card shows, min → max over the window from departure to the last arrival. Falls
 * back to the departure temperature when the window gives no range; a single value when both ends
 * round to the same degree is the caller's business (units decide the rounding).
 */
export function temperatureRange(
  summary: RideWeatherSummaryDto
): { min: number; max: number } | undefined {
  const min = summary.temperatureMin ?? summary.temperature
  const max = summary.temperatureMax ?? summary.temperature
  if (min === undefined || max === undefined) return undefined
  return { min: Math.min(min, max), max: Math.max(min, max) }
}

export function isKnownRelativeWind(value: string | undefined): value is RelativeWind {
  return !!value && Object.prototype.hasOwnProperty.call(RELATIVE_WIND_COLORS, value)
}

/** The generated family of a relative wind (contracts/brand-colors.yaml), gray when unknown. */
export function relativeWindColor(value: string | undefined): BadgeFamily {
  return isKnownRelativeWind(value) ? RELATIVE_WIND_COLORS[value] : 'gray'
}

export function isKnownCompassPoint(value: string | undefined): value is CompassPoint {
  return !!value && Object.prototype.hasOwnProperty.call(CompassPoint, value)
}

/**
 * The rotation of the relative-wind arrow, in degrees clockwise. The arrow is drawn pointing
 * forward (up: the direction of travel) and turned by `relativeWindAngle`, which is where the wind
 * blows *towards*: 0 points ahead (pushing), 180 points back at the rider (in the face).
 */
export function windArrowRotation(relativeWindAngle: number): number {
  const angle = relativeWindAngle % 360
  return Math.round(angle < 0 ? angle + 360 : angle)
}

export interface ExposureSection {
  relativeWind: RelativeWind
  fromDistance: number
  toDistance: number
  /** Share of the route, 0–100. */
  percent: number
}

/**
 * The wind stretches in route order, as shares of the leg's length — the bar under the strip
 * reads « face here, tail there » rather than only the totals. A stretch of an unknown kind is
 * dropped (it leaves a gap rather than a wrong colour), and so is an empty one.
 */
export function exposureSections(segments: WindSegmentDto[], distance: number): ExposureSection[] {
  const total =
    distance > 0
      ? distance
      : segments.reduce((sum, segment) => sum + (segment.toDistance - segment.fromDistance), 0)
  if (total <= 0) return []
  return segments
    .filter(
      (segment) =>
        isKnownRelativeWind(segment.relativeWind) && segment.toDistance > segment.fromDistance
    )
    .map((segment) => ({
      relativeWind: segment.relativeWind,
      fromDistance: segment.fromDistance,
      toDistance: segment.toDistance,
      percent: ((segment.toDistance - segment.fromDistance) / total) * 100,
    }))
}
