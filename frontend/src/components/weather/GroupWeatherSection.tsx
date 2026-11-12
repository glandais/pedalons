import type { RideDto, RideWeatherDto, WeatherLegDto } from '@/api/dto'
import { Status } from '@/api/dto'
import type { RouteWeatherSelection } from './RouteWeather'
import { RouteWeatherSection } from './RouteWeatherSection'

interface GroupWeatherSectionProps {
  ride: RideDto
  /** `GET …/rides/{rideSlug}/weather`, the ride page's own read (shared cache). */
  weather: RideWeatherDto | undefined
  /** This group's leg (`leg.groupId === group.id`), undefined when the forecast has none. */
  leg: WeatherLegDto | undefined
  isLoading: boolean
  isFetching: boolean
  onRetry: () => void
  /** Organisers alone hear about a ride without a place (NO_LOCATION): they can fix it. */
  canEdit: boolean
  /** The point selected in « Heure par heure », when the page shares it with its map (WEB-117). */
  selection?: RouteWeatherSelection
  onSelectionChange?: (selection: RouteWeatherSelection) => void
}

/**
 * The whole weather of one group, full width on the group's page: the shared `RouteWeatherSection`
 * (docs/LEDGER_*.md WEB-155) fed by the ride's forecast. A group whose leg has no forecast keeps the
 * meeting point at departure — at the ride's time, not the group's: the server forecasts the
 * meeting point at the ride's departure (RideWeatherPlans) — and a word why. The ride page keeps
 * only the departure (`RideWeatherSection`).
 */
export function GroupWeatherSection({
  ride,
  weather,
  leg,
  isLoading,
  isFetching,
  onRetry,
  canEdit,
  selection,
  onSelectionChange,
}: GroupWeatherSectionProps) {
  return (
    <RouteWeatherSection
      subject="group"
      // No date rule here: until when the weather shows is the server's call, told by `status`
      // (OUT_OF_RANGE past the day the ride ends — API-170, API-183).
      offered={ride.status !== Status.CANCELLED}
      status={weather?.status}
      availableFrom={weather?.availableFrom}
      attribution={weather?.attribution}
      fetchedAt={weather?.fetchedAt}
      departure={weather?.departure}
      departureTime={ride.dateTime}
      // No forecast read: the departure fallback has nothing to show either.
      leg={weather ? leg : undefined}
      timezone={ride.timezone}
      isLoading={isLoading}
      isFetching={isFetching}
      onRetry={onRetry}
      canEdit={canEdit}
      selection={selection}
      onSelectionChange={onSelectionChange}
      titleId="group-weather-title"
    />
  )
}
