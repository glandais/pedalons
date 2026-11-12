import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { keepPreviousData } from '@tanstack/react-query'
import { IconCopy, IconUsers } from '@tabler/icons-react'
import {
  Box,
  Button,
  Center,
  Group,
  Loader,
  Modal,
  Stack,
  Text,
  UnstyledButton,
} from '@mantine/core'
import { useListTemplates } from '@/api/endpoints/ride-templates/ride-templates'
import type { RideTemplateDto } from '@/api/dto'
import { MarkdownDisplay } from '../common/MarkdownDisplay'
import { Pagination } from '../common/Pagination'
import { useScrollToListTopWithinContainer } from '@/hooks/useScrollToListTop'
import { SearchInput } from '../common/SearchInput'
import { TemplateGroupBadge } from './TemplateGroupBadge'

interface RideTemplatePickerModalProps {
  isOpen: boolean
  onClose: () => void
  onSelect: (template: RideTemplateDto) => void
  teamSlug: string
  title?: string
}

export function RideTemplatePickerModal({
  isOpen,
  onClose,
  onSelect,
  teamSlug,
  title,
}: RideTemplatePickerModalProps) {
  const { t } = useTranslation()
  const [page, setPage] = useState(0)
  const { listTopRef, scrollToListTop } = useScrollToListTopWithinContainer()
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')

  // Debounce search input
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedSearch(search)
      setPage(0)
    }, 300)

    return () => clearTimeout(timer)
  }, [search])

  const pageSize = 20

  const {
    data: templatesResponse,
    isPending,
    error,
  } = useListTemplates(
    teamSlug,
    {
      search: debouncedSearch || undefined,
      page,
      size: pageSize,
    },
    // Mounted closed for the whole form session — see `RoutePickerModal` for why this is gated
    // rather than prefetched.
    { query: { placeholderData: keepPreviousData, enabled: isOpen } }
  )

  const totalPages = Math.ceil((templatesResponse?.total ?? 0) / pageSize)

  const handleClose = () => {
    setSearch('')
    setPage(0)
    onClose()
  }

  const handleSelect = (template: RideTemplateDto) => {
    onSelect(template)
    handleClose()
  }

  const templates = templatesResponse?.templates || []

  return (
    <Modal
      opened={isOpen}
      onClose={handleClose}
      title={title || t('rideTemplates.picker.title')}
      size="xl"
    >
      <Box mb="md">
        <SearchInput
          value={search}
          onChange={setSearch}
          placeholder={t('rideTemplates.picker.search')}
          fullWidth
        />
      </Box>
      {isPending ? (
        <Center py="xl">
          <Stack align="center" gap="xs">
            <Loader />
            <Text c="dimmed">{t('loading')}</Text>
          </Stack>
        </Center>
      ) : error ? (
        <Center py="xl">
          <Text c="red">{t('error.loading')}</Text>
        </Center>
      ) : templates.length === 0 ? (
        <Center py="xl">
          <Stack align="center" gap="xs">
            <IconCopy size={48} color="var(--mantine-color-dimmed)" />
            <Text c="dimmed">{t('rideTemplates.list.noResults')}</Text>
          </Stack>
        </Center>
      ) : (
        <>
          <Stack ref={listTopRef} gap="sm">
            {templates.map((template) => (
              <UnstyledButton
                key={template.id}
                onClick={() => handleSelect(template)}
                p="md"
                style={{
                  border: '1px solid var(--mantine-color-default-border)',
                  borderRadius: 'var(--mantine-radius-md)',
                  textAlign: 'left',
                  width: '100%',
                }}
              >
                <Group justify="space-between" align="flex-start" wrap="nowrap">
                  <Box style={{ flex: 1, minWidth: 0 }}>
                    <Text fw={500} truncate>
                      {template.name}
                    </Text>
                    {template.markdown && (
                      <MarkdownDisplay
                        markdown={template.markdown}
                        preview={true}
                        maxLength={120}
                      />
                    )}
                  </Box>
                  <Group gap="xs" ml="md">
                    <IconUsers size={16} color="var(--mantine-color-dimmed)" />
                    <Text size="sm" c="dimmed">
                      {t('groups.groupCount', { count: template.groupCount })}
                    </Text>
                  </Group>
                </Group>
                {template.groups && template.groups.length > 0 && (
                  <Group gap="xs" mt="sm" wrap="wrap">
                    {template.groups.map((group) => (
                      <TemplateGroupBadge key={group.id} group={group} color="gray" />
                    ))}
                  </Group>
                )}
              </UnstyledButton>
            ))}
          </Stack>

          <Pagination
            currentPage={page}
            totalPages={totalPages}
            onPageChange={(nextPage) => {
              setPage(nextPage)
              scrollToListTop()
            }}
            variant="compact"
          />
        </>
      )}
      <Box mt="md">
        <Button variant="default" onClick={handleClose}>
          {t('actions.cancelAction')}
        </Button>
      </Box>
    </Modal>
  )
}
