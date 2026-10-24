import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Stack, Text, Modal } from '@mantine/core'
import { ParticipantList, type ParticipantSource } from './ParticipantList'

export type { ParticipantSource } from './ParticipantList'

interface ParticipantListModalProps {
  isOpen: boolean
  onClose: () => void
  source: ParticipantSource
  groupName: string
  /** The total the detail already knows, shown until the first page arrives. */
  count: number
  /** `RideGroupDto.leader.id`, when the group has a designated leader. */
  leaderId?: string
}

/**
 * {@link ParticipantList} in a modal, for the cards of a ride's groups and a trip. A modal's
 * search is its own and is dropped on close: it is no page of its own to share.
 */
export function ParticipantListModal({
  isOpen,
  onClose,
  source,
  groupName,
  count,
  leaderId,
}: ParticipantListModalProps) {
  const { t } = useTranslation()
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const [debouncedSearch, setDebouncedSearch] = useState('')

  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedSearch(search)
      setPage(0)
    }, 300)
    return () => clearTimeout(timer)
  }, [search])

  const handleClose = () => {
    setSearch('')
    setPage(0)
    onClose()
  }

  return (
    <Modal opened={isOpen} onClose={handleClose} title={groupName} size="xl">
      <Stack>
        <Text size="sm" fw={600} c="primary">
          {t('rides.detail.groups.participantsNoMax', { count })}
        </Text>
        <ParticipantList
          source={source}
          count={count}
          leaderId={leaderId}
          search={debouncedSearch || undefined}
          page={page}
          searchInput={search}
          onSearchInputChange={setSearch}
          onPageChange={setPage}
          enabled={isOpen}
        />
      </Stack>
    </Modal>
  )
}
