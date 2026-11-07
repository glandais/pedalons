import { useTranslation } from 'react-i18next'
import { NumberInput, SimpleGrid } from '@mantine/core'
import { WallDateTimePicker } from '@/components/common/WallDateTimePicker'
import { useUnits } from '@/hooks/useUnits'
import { useEffectiveTimezone } from '@/utils/dateFormat'
import { addDaysToWallTime, instantToWallTime } from '@/utils/wallTime'
import { MAX_AVERAGE_SPEED_KMH, MIN_AVERAGE_SPEED_KMH, type DepartureValue } from './departure'

/** A preview is purged after this many days: a departure later than that is lost with it. */
const RETENTION_DAYS = 30

interface DepartureFieldsProps {
  value: DepartureValue
  onChange: (value: DepartureValue) => void
  /** The zone known for the track (`preview.departureTimezone`); unknown before the first save. */
  zone?: string
  /** For the purge bound: the preview's `createdAt`, now at creation. */
  createdAt?: string
  /** Replaces the default hint under the date. */
  description?: string
}

/**
 * The departure of a GPX preview: the date and time at the track's start, and an optional average
 * speed. The clock is the one of the first point of the track, not the device's: nothing is
 * converted here, the value is a wall time without zone and the server reads it in the zone it finds.
 * The speed follows the person's units; the state stays in km/h and is only rewritten when the
 * field is touched, so a round trip through miles never passes for a modification.
 */
export function DepartureFields({
  value,
  onChange,
  zone,
  createdAt,
  description,
}: DepartureFieldsProps) {
  const { t } = useTranslation()
  const { config, speedToDisplay, speedFromDisplay } = useUnits()
  const { timezone: readerZone } = useEffectiveTimezone()
  const shownZone = zone ?? readerZone
  const maxDate = addDaysToWallTime(
    instantToWallTime(createdAt ?? new Date(), shownZone),
    RETENTION_DAYS
  )

  return (
    <SimpleGrid cols={{ base: 1, sm: 2 }}>
      <WallDateTimePicker
        label={t('gpxTools.departure.label')}
        description={description ?? t('gpxTools.departure.hint')}
        value={value.departure}
        onChange={(departure) => onChange({ ...value, departure })}
        zone={shownZone}
        maxDate={maxDate}
        clearable
      />
      <NumberInput
        label={t('gpxTools.departure.speedLabel')}
        description={t('gpxTools.departure.speedHint')}
        // Rounded inwards: the conversion back rounds to the hundredth, and 62.14 mph would come
        // back as 100.01 km/h, which the server refuses.
        min={Math.ceil(speedToDisplay(MIN_AVERAGE_SPEED_KMH) ?? MIN_AVERAGE_SPEED_KMH)}
        max={Math.floor(speedToDisplay(MAX_AVERAGE_SPEED_KMH) ?? MAX_AVERAGE_SPEED_KMH)}
        suffix={` ${config.speedUnit}`}
        value={speedToDisplay(value.averageSpeed) ?? ''}
        onChange={(val) => onChange({ ...value, averageSpeed: speedFromDisplay(val) })}
      />
    </SimpleGrid>
  )
}
