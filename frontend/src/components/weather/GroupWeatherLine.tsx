import type { WeatherLegDto } from '@/api/dto'
import { RideWeatherSummaryLine } from './RideWeatherSummaryLine'

interface GroupWeatherLineProps {
  /** The group's leg of the ride's forecast; nothing is drawn without one. */
  leg: WeatherLegDto | undefined
  /** The ride's zone: the rain's time is a passage, read in it (docs/LEDGER_*.md API-60). */
  timezone?: string
}

/**
 * A group's weather in one line, on its card of the ride page — not a link, the group's page holds
 * the detail. The card's weather line (`RideWeatherSummaryLine`, KIT §8 and §9, docs/LEDGER_*.md
 * WEB-167 R2) read on the summary of the group's own leg (`WeatherLegDto.summary`): its range, its
 * wind at departure, its rain or its alert — as the app's `RideGroupWeatherLine`. No sky in words,
 * no Face / Dos badge on a card any more: the group page's weather section carries them.
 */
export function GroupWeatherLine({ leg, timezone }: GroupWeatherLineProps) {
  return <RideWeatherSummaryLine summary={leg?.summary} timezone={timezone} />
}
