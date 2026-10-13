import { useTranslation } from 'react-i18next'
import { IconShieldCheck } from '@tabler/icons-react'
import { Badge, Group, Paper, Text } from '@mantine/core'
import type { RideGroupDto } from '@/api/dto'
import { UserAvatar } from '@/components/common/UserAvatar'

/**
 * The group's leader — only when one is designated (`RideGroupDto.leader`, null in the common
 * case), **never** the ride's creator. `framed` draws it in its own Paper (the group's page);
 * without, it is a line inside a block that already has one (a solo ride's group panel).
 */
export function GroupLeader({ group, framed = true }: { group: RideGroupDto; framed?: boolean }) {
  const { t } = useTranslation()
  if (!group.leader) return null
  const line = (
    <Group gap="sm" wrap="nowrap" data-testid={framed ? undefined : 'group-leader'}>
      <UserAvatar user={group.leader} size={framed ? 'md' : 'sm'} />
      <Text fw={500} truncate size={framed ? undefined : 'sm'}>
        {group.leader.displayName}
      </Text>
      <Badge
        variant="light"
        leftSection={<IconShieldCheck size={12} aria-hidden />}
        style={{ flexShrink: 0 }}
      >
        {t('rides.detail.groups.leader')}
      </Badge>
    </Group>
  )
  if (!framed) return line
  return (
    <Paper withBorder p="md" data-testid="group-leader">
      {line}
    </Paper>
  )
}
