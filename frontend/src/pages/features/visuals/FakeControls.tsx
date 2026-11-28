import { Box, Text } from '@mantine/core'

/** A slider drawn with boxes: not an input, so nothing in the illustration takes focus. */
export function FakeSlider({ percent, marks }: { percent: number; marks?: number }) {
  return (
    <Box pos="relative" h={18}>
      <Box
        pos="absolute"
        top={7}
        left={0}
        right={0}
        h={4}
        bg="light-dark(var(--mantine-color-gray-2), var(--mantine-color-dark-4))"
        style={{ borderRadius: 2 }}
      />
      <Box
        pos="absolute"
        top={7}
        left={0}
        h={4}
        w={`${percent}%`}
        bg="var(--mantine-primary-color-filled)"
        style={{ borderRadius: 2 }}
      />
      {marks && (
        <Box
          pos="absolute"
          top={7}
          left={0}
          right={0}
          h={4}
          style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}
        >
          {Array.from({ length: marks }, (_, i) => (
            <Box
              key={i}
              w={4}
              h={4}
              bg="var(--mantine-color-white)"
              style={{ borderRadius: '50%' }}
            />
          ))}
        </Box>
      )}
      <Box
        pos="absolute"
        top={1}
        w={16}
        h={16}
        bg="var(--mantine-color-white)"
        style={{
          left: `calc(${percent}% - ${(percent / 100) * 16}px)`,
          borderRadius: '50%',
          border: '3px solid var(--mantine-primary-color-filled)',
        }}
      />
    </Box>
  )
}

/** A segmented switch drawn with boxes; `active` is the selected segment. */
export function FakeSegments({
  items,
  active,
  columns,
}: {
  items: string[]
  active: number
  columns?: string
}) {
  return (
    <Box
      p={3}
      bg="light-dark(var(--mantine-color-gray-1), var(--mantine-color-dark-6))"
      style={{
        display: 'grid',
        gridTemplateColumns: columns ?? `repeat(${items.length}, minmax(0, 1fr))`,
        borderRadius: 'var(--mantine-radius-md)',
      }}
    >
      {items.map((item, index) => (
        <Text
          key={index}
          size="xs"
          fw={600}
          ta="center"
          py={5}
          truncate
          c={index === active ? 'var(--mantine-color-bright)' : 'dimmed'}
          bg={
            index === active
              ? 'light-dark(var(--mantine-color-white), var(--mantine-color-dark-5))'
              : undefined
          }
          style={{
            borderRadius: 'var(--mantine-radius-sm)',
            boxShadow: index === active ? 'var(--mantine-shadow-xs)' : undefined,
          }}
        >
          {item}
        </Text>
      ))}
    </Box>
  )
}
