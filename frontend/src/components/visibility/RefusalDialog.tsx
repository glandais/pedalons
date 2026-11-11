import { useTranslation } from 'react-i18next'
import { Button, Group, List, Modal, Stack, Text } from '@mantine/core'
import { PrefetchLink } from '@/components/common/PrefetchLink'

/** A dialog that explains a refusal and lists links, with a single way out. */
export function RefusalDialog({
  opened,
  onClose,
  title,
  message,
  links,
  testId,
}: {
  opened: boolean
  onClose: () => void
  title: string
  message: string
  links: { key: string; label: string; to: string }[]
  testId: string
}) {
  const { t } = useTranslation()
  return (
    <Modal opened={opened} onClose={onClose} title={title} centered>
      <Stack data-testid={testId}>
        <Text size="sm" c="dimmed">
          {message}
        </Text>
        <List size="sm" spacing={4}>
          {links.map((link) => (
            <List.Item key={link.key}>
              <Text component={PrefetchLink} to={link.to} size="sm" c="primary" td="underline">
                {link.label}
              </Text>
            </List.Item>
          ))}
        </List>
        <Group justify="flex-end">
          <Button variant="default" onClick={onClose}>
            {t('actions.close')}
          </Button>
        </Group>
      </Stack>
    </Modal>
  )
}
