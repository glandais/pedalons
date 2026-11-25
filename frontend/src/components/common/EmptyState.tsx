import { Box, Center, Group, Paper, Stack, Text, Title } from '@mantine/core'
import type { ReactNode } from 'react'
import { useCardHeadingOrder } from '@/components/card/common/cardHeadingOrder'

interface EmptyStateProps {
  /** Domain icon (absolute variant) or IconSearchOff (filtered variant), sized 48. */
  icon: ReactNode
  title: string
  description?: string
  /** Buttons letting the user out of the state — mandatory in practice for `filtered`. */
  actions?: ReactNode
  /**
   * `absolute`: nothing exists yet. `filtered`: things exist, the current
   * filters hide them. The two must never read the same.
   */
  variant?: 'absolute' | 'filtered'
  /**
   * The title's level; its size stays an h3's. By default the level of the cards it stands in for
   * (`CardHeadingOrder`): an h3 under a page's h2, an h2 under a page's h1 (`TeamListPage`,
   * `AllRoutesPage`). 1 only when the state replaces the whole page — a 403 with nothing around it
   * (docs/LEDGER_*.md WEB-210).
   */
  order?: 1 | 2 | 3 | 4
}

/**
 * The single empty-state surface of the site. Uses only `dimmed` tokens so it
 * stays legible in both color schemes (no hard-coded `gray-N`).
 */
export function EmptyState({
  icon,
  title,
  description,
  actions,
  variant = 'absolute',
  order,
}: EmptyStateProps) {
  const listOrder = useCardHeadingOrder()
  return (
    <Paper withBorder py="xl" px="md" radius="md" data-variant={variant}>
      <Center>
        <Stack align="center" gap="md">
          <Box
            p="lg"
            style={{
              backgroundColor: 'var(--mantine-color-default-hover)',
              borderRadius: '50%',
              color: 'var(--mantine-color-dimmed)',
              lineHeight: 0,
            }}
          >
            {icon}
          </Box>
          <Title order={order ?? listOrder} size="h3" ta="center">
            {title}
          </Title>
          {description && (
            <Text c="dimmed" ta="center" maw={400}>
              {description}
            </Text>
          )}
          {actions && (
            <Group justify="center" gap="sm">
              {actions}
            </Group>
          )}
        </Stack>
      </Center>
    </Paper>
  )
}
