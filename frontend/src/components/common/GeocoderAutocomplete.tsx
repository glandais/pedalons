import { useState, useEffect, useCallback, useMemo, useRef } from 'react'
import { Paper, Text, Box, Group, ActionIcon, Loader } from '@mantine/core'
import { IconMapPin, IconX } from '@tabler/icons-react'
import { useTranslation } from 'react-i18next'
import { resolvePlace, useSearchPlaces } from '@/api/endpoints/geocode/geocode'
import { ErrorCode } from '@/api/dto'
import { ApiClientError } from '@/lib/apiError'
import { Autocomplete } from './Autocomplete'
import type { GeocodeResultDto, GeoJsonPoint } from '@/api/dto'

/**
 * Address lookup in forms, via `GET /api/geocode/search` — the backend's proxy to Stadia Maps'
 * geocoder (docs/LEDGER_*.md OPS-49).
 *
 * The proxy is kept on purpose: it caches, it keeps the provider key on the server, and it is the
 * server's IP the provider sees, never the member's. The place search on the free-navigation maps
 * (`components/map/MapSearchControl`) is the opposite choice — it calls Stadia Maps from the
 * browser, as a basemap does — and the privacy policy describes both. What is left for this
 * component is the credit under the results, which the provider's terms want visible.
 *
 * A suggestion usually comes without a position (docs/LEDGER_*.md API-129): the search costs the
 * provider's cheap autocomplete, and the position is a billed lookup, `GET /api/geocode/place`,
 * made here once — for the suggestion picked, never for the list. If it fails the field stays
 * usable, with a message: the user can search and pick again, or leave the position empty (no form
 * takes a position typed by hand). While it runs the form holds no position yet, so a form passes
 * `onResolvingChange` and keeps its submit disabled until the lookup is over — saving in between
 * would save no position, or erase the one the form had.
 */
const NO_RESULTS: GeocodeResultDto[] = []

export interface GeocoderAutocompleteProps {
  value?: GeoJsonPoint | null
  onChange: (point: GeoJsonPoint | null) => void
  label?: string
  description?: string
  placeholder?: string
  error?: string
  required?: boolean
  disabled?: boolean
  /** Told `true` when a picked suggestion's position starts resolving, `false` once it is over. */
  onResolvingChange?: (resolving: boolean) => void
}

export function GeocoderAutocomplete({
  value,
  onChange,
  label,
  description,
  placeholder,
  error,
  required,
  disabled,
  onResolvingChange,
}: GeocoderAutocompleteProps) {
  const { t } = useTranslation()
  const [query, setQuery] = useState('')
  const [debouncedQuery, setDebouncedQuery] = useState('')
  const [selectedName, setSelectedName] = useState<string | null>(null)
  // The suggestion whose position is being fetched, and why the last fetch failed.
  const [resolving, setResolvingState] = useState<GeocodeResultDto | null>(null)
  const [resolveError, setResolveError] = useState<string | null>(null)
  // Only the latest pick may emit: a clear or another pick while a lookup runs discards it.
  const resolveRequest = useRef<AbortController | null>(null)

  useEffect(() => () => resolveRequest.current?.abort(), [])

  // Set from the handlers, not from an effect on `resolving`: the parent learns it in the same
  // event, so its submit is disabled before anything else can be clicked.
  const setResolving = useCallback(
    (result: GeocodeResultDto | null) => {
      setResolvingState(result)
      onResolvingChange?.(result != null)
    },
    [onResolvingChange]
  )

  // Debounce query (300ms)
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedQuery(query)
    }, 300)
    return () => clearTimeout(timer)
  }, [query])

  const { data: results = NO_RESULTS, isFetching: isLoading } = useSearchPlaces(
    { q: debouncedQuery },
    {
      query: {
        enabled: debouncedQuery.length >= 3,
        staleTime: 5 * 60 * 1000, // Cache for 5 minutes
      },
    }
  )

  // Filter results based on query length
  const filteredResults = useMemo(
    () => (debouncedQuery.length < 3 ? [] : results),
    [debouncedQuery, results]
  )

  const handleQueryChange = useCallback((newQuery: string) => {
    setQuery(newQuery)
  }, [])

  const emit = useCallback(
    (displayName: string, lat: number, lon: number) => {
      onChange({ type: 'Point', coordinates: [lon, lat] })
      setSelectedName(displayName)
    },
    [onChange]
  )

  const handleSelect = useCallback(
    (result: GeocodeResultDto) => {
      setQuery('')
      setResolveError(null)
      resolveRequest.current?.abort()
      resolveRequest.current = null
      if (result.lat != null && result.lon != null) {
        emit(result.displayName, result.lat, result.lon)
        return
      }
      const controller = new AbortController()
      resolveRequest.current = controller
      setResolving(result)
      // The field shows its own message: no toast on top of it.
      resolvePlace({ id: result.id }, { skipErrorToast: true }, controller.signal)
        .then((place) => {
          if (controller.signal.aborted) return
          if (place.lat == null || place.lon == null) {
            setResolveError(t('geocoder.resolveFailed'))
          } else {
            // The suggestion's name, the one the user read and picked.
            emit(result.displayName, place.lat, place.lon)
          }
        })
        .catch((e: unknown) => {
          if (controller.signal.aborted) return
          setResolveError(
            e instanceof ApiClientError && e.error.code === ErrorCode.GEOCODING_UNAVAILABLE
              ? t('errors.api.GEOCODING_UNAVAILABLE')
              : t('geocoder.resolveFailed')
          )
        })
        .finally(() => {
          if (resolveRequest.current !== controller) return
          resolveRequest.current = null
          setResolving(null)
        })
    },
    [emit, setResolving, t]
  )

  const handleClear = useCallback(() => {
    resolveRequest.current?.abort()
    resolveRequest.current = null
    setResolving(null)
    setResolveError(null)
    onChange(null)
    setQuery('')
    setSelectedName(null)
  }, [onChange, setResolving])

  const renderItem = useCallback(
    (result: GeocodeResultDto) => (
      <Group gap="xs" wrap="nowrap">
        <IconMapPin size={14} style={{ flexShrink: 0 }} />
        <Text size="sm" ta="left" truncate style={{ flex: 1 }}>
          {result.displayName}
        </Text>
      </Group>
    ),
    []
  )

  const hasValue = value && value.coordinates && value.coordinates.length === 2
  const displayName =
    selectedName ??
    (hasValue ? `${value!.coordinates[1].toFixed(6)}, ${value!.coordinates[0].toFixed(6)}` : null)

  if (hasValue && displayName) {
    return (
      <Box>
        {label && (
          <Text size="sm" fw={500} mb={4}>
            {label}
            {required && (
              <Text component="span" c="red">
                {' '}
                *
              </Text>
            )}
          </Text>
        )}
        {description && (
          <Text size="xs" c="dimmed" mb={4}>
            {description}
          </Text>
        )}
        <Paper p="sm" withBorder>
          <Group justify="space-between" wrap="nowrap">
            <Group gap="xs" wrap="nowrap" style={{ flex: 1, minWidth: 0 }}>
              <IconMapPin size={16} style={{ flexShrink: 0 }} />
              <Text size="sm" truncate style={{ flex: 1 }}>
                {displayName}
              </Text>
            </Group>
            <ActionIcon
              variant="subtle"
              size="sm"
              onClick={handleClear}
              disabled={disabled}
              aria-label={t('geocoder.clear')}
            >
              <IconX size={14} />
            </ActionIcon>
          </Group>
        </Paper>
        {error && (
          <Text size="xs" c="red" mt={4}>
            {error}
          </Text>
        )}
      </Box>
    )
  }

  if (resolving) {
    return (
      <Box aria-busy="true">
        {label && (
          <Text size="sm" fw={500} mb={4}>
            {label}
            {required && (
              <Text component="span" c="red">
                {' '}
                *
              </Text>
            )}
          </Text>
        )}
        {description && (
          <Text size="xs" c="dimmed" mb={4}>
            {description}
          </Text>
        )}
        <Paper p="sm" withBorder>
          <Group justify="space-between" wrap="nowrap">
            <Group gap="xs" wrap="nowrap" style={{ flex: 1, minWidth: 0 }}>
              <Loader size="xs" aria-label={t('geocoder.resolving')} />
              <Text size="sm" truncate style={{ flex: 1 }}>
                {resolving.displayName}
              </Text>
            </Group>
            <ActionIcon
              variant="subtle"
              size="sm"
              onClick={handleClear}
              disabled={disabled}
              aria-label={t('geocoder.clear')}
            >
              <IconX size={14} />
            </ActionIcon>
          </Group>
        </Paper>
        {error && (
          <Text size="xs" c="red" mt={4}>
            {error}
          </Text>
        )}
      </Box>
    )
  }

  return (
    <Box>
      <Autocomplete<GeocodeResultDto>
        items={filteredResults}
        isLoading={isLoading}
        onQueryChange={handleQueryChange}
        onSelect={handleSelect}
        renderItem={renderItem}
        getItemKey={(result) => result.id}
        placeholder={placeholder ?? t('geocoder.placeholder')}
        noResultsMessage={t('geocoder.noResults')}
        minChars={3}
        clearOnSelect={true}
        label={label}
        description={description}
        error={error ?? resolveError ?? undefined}
        required={required}
        disabled={disabled}
        leftSection={<IconMapPin size={16} />}
      />
      {/* The credit Stadia Maps' terms want next to its results — a proxy cannot show it for us. */}
      <Text size="xs" c="dimmed" mt={4}>
        {t('geocoder.attribution')}
      </Text>
    </Box>
  )
}
