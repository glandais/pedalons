import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { keepPreviousData } from '@tanstack/react-query'
import { IconMap, IconArrowsMaximize, IconArrowUp } from '@tabler/icons-react'
import {
  Stack,
  Group,
  Button,
  Text,
  SimpleGrid,
  Image,
  Center,
  Loader,
  Modal,
  Box,
} from '@mantine/core'
import { useListRoutes } from '@/api/endpoints/routes/routes'
import type { RouteDto } from '@/api/dto'
import { MarkdownDisplay } from '../../components/common/MarkdownDisplay'
import { Pagination } from '../common/Pagination'
import { useScrollToListTopWithinContainer } from '@/hooks/useScrollToListTop'
import { SearchInput } from '../common/SearchInput'
import { useUnits } from '@/hooks/useUnits'
import { useResolvedColorScheme } from '@/hooks/useResolvedColorScheme'

interface RoutePickerModalProps {
  isOpen: boolean
  onClose: () => void
  onSelect: (route: RouteDto | null) => void
  teamSlug: string
  selectedRouteSlug?: string | null
  title?: string
  onCreateNew?: () => void
}

export function RoutePickerModal({
  isOpen,
  onClose,
  onSelect,
  teamSlug,
  selectedRouteSlug,
  title,
  onCreateNew,
}: RoutePickerModalProps) {
  const { t } = useTranslation()
  const { distance, elevation } = useUnits()
  const colorScheme = useResolvedColorScheme()
  const [page, setPage] = useState(0)
  const { listTopRef, scrollToListTop } = useScrollToListTopWithinContainer()
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')

  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedSearch(search)
      setPage(0)
    }, 300)

    return () => clearTimeout(timer)
  }, [search])

  const pageSize = 20

  const {
    data: routesResponse,
    isPending,
    error,
  } = useListRoutes(
    teamSlug,
    { page, size: pageSize, search: debouncedSearch || undefined },
    {
      // The editors mount this modal for the whole edit session, closed. Without `enabled` it
      // queried the team's route list on every ride and trip form load — a list most visitors
      // never open, and the one query the SSR audit kept reporting on `rideNew`/`rideEdit`/
      // `tripNew`/`tripEdit`. Prefetching it would have been the wrong fix: the right one is not
      // to ask at all until the visitor opens the picker.
      query: { placeholderData: keepPreviousData, enabled: isOpen },
    }
  )

  const totalPages = Math.ceil((routesResponse?.total ?? 0) / pageSize)

  const handleClose = () => {
    setSearch('')
    setPage(0)
    onClose()
  }

  const routes = routesResponse?.routes || []

  return (
    <Modal
      opened={isOpen}
      onClose={handleClose}
      title={title || t('routes.picker.title')}
      size="xl"
    >
      <Group mb="md">
        <SearchInput
          value={search}
          onChange={setSearch}
          placeholder={t('routes.picker.search')}
          fullWidth
          style={{ flex: 1 }}
        />
        {onCreateNew && <Button onClick={onCreateNew}>{t('routes.create.title')}</Button>}
      </Group>
      {isPending ? (
        <Center py="xl">
          <Stack align="center">
            <Loader />
            <Text c="dimmed">{t('loading')}</Text>
          </Stack>
        </Center>
      ) : error ? (
        <Center py="xl">
          <Text c="red">{t('error.loading')}</Text>
        </Center>
      ) : routes.length === 0 ? (
        <Center py="xl">
          <Stack align="center">
            <IconMap size={48} color="var(--mantine-color-dimmed)" />
            <Text c="dimmed">{t('routes.picker.noResults')}</Text>
            {selectedRouteSlug && (
              <Button variant="subtle" onClick={() => onSelect(null)}>
                {t('routes.picker.clearSelection')}
              </Button>
            )}
          </Stack>
        </Center>
      ) : (
        <Stack>
          <SimpleGrid ref={listTopRef} cols={{ base: 1, md: 2 }} spacing="md">
            {routes.map((route) => (
              <Button
                key={route.id}
                variant="default"
                h="auto"
                p="md"
                onClick={() => onSelect(route)}
                style={{
                  textAlign: 'left',
                  border:
                    route.slug === selectedRouteSlug
                      ? '2px solid var(--mantine-primary-color-filled)'
                      : undefined,
                  backgroundColor:
                    route.slug === selectedRouteSlug
                      ? 'var(--mantine-primary-color-light)'
                      : undefined,
                }}
              >
                <Stack gap="xs" w="100%">
                  <Image
                    src={(colorScheme === 'dark'
                      ? route.media.assets.thumbnailDark
                      : route.media.assets.thumbnailLight
                    )?.imageUrl?.replace('{size}', '256')}
                    alt={route.name}
                    h={128}
                    fit="cover"
                    radius="sm"
                    loading="lazy"
                  />
                  <Text fw={500} truncate>
                    {route.name}
                  </Text>
                  <MarkdownDisplay markdown={route.media.markdown} preview={true} maxLength={120} />
                  <Group>
                    <Group gap={4}>
                      <IconArrowsMaximize size={14} />
                      <Text size="xs" c="dimmed">
                        {distance(route.distance)}
                      </Text>
                    </Group>
                    <Group gap={4}>
                      <IconArrowUp size={14} />
                      <Text size="xs" c="dimmed">
                        {elevation(route.elevationGain)}
                      </Text>
                    </Group>
                  </Group>
                </Stack>
              </Button>
            ))}
          </SimpleGrid>

          <Pagination
            currentPage={page}
            totalPages={totalPages}
            onPageChange={(nextPage) => {
              setPage(nextPage)
              scrollToListTop()
            }}
            variant="compact"
          />
        </Stack>
      )}
      <Box mt="md">
        {selectedRouteSlug && (
          <Button variant="subtle" color="danger" onClick={() => onSelect(null)}>
            {t('routes.picker.clearSelection')}
          </Button>
        )}
        <Button variant="default" onClick={handleClose}>
          {t('actions.cancelAction')}
        </Button>
      </Box>
    </Modal>
  )
}
