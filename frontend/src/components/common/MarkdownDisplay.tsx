import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import remarkDirective from 'remark-directive'
import removeMd from 'remove-markdown'
import type { TitleOrder, TitleSize } from '@mantine/core'
import {
  Text,
  Box,
  Title,
  Anchor,
  Table,
  Divider,
  Code,
  Blockquote,
  List,
  Image,
} from '@mantine/core'
import type { ReactNode } from 'react'
import type { AssetDto } from '@/api/dto'
import { type ImageSize, ASSET_DIRECTIVE_REGEX } from '../../lib/assetMarkdown'
import { remarkAssetDirective } from '../../lib/remarkAssetDirective'
import { remarkHeadingLevels, type HeadingDepth } from '../../lib/remarkHeadingLevels'
import { AssetImage } from './AssetImage'

export interface MarkdownDisplayProps {
  markdown: string
  preview?: boolean
  maxLength?: number
  images?: AssetDto[]
  /** Passed to each asset picture (`AssetImage`'s `sizes`). */
  imageSizes?: string
  /**
   * The level the content's highest heading takes (docs/LEDGER_*.md WEB-207): the page has its own
   * h1 (the post's, the team's), so the content starts at h2 — h3 under a section that is itself an
   * h2 (a team page or « À propos » under TeamLayout). The others keep their distance to it; each
   * heading keeps the size of the level it was written at.
   */
  topHeadingLevel?: 2 | 3
}

export function MarkdownDisplay({
  markdown,
  preview = false,
  maxLength = 150,
  images = [],
  imageSizes,
  topHeadingLevel = 2,
}: MarkdownDisplayProps) {
  if (!markdown) {
    return null
  }

  // Preview mode: strip markdown and truncate
  if (preview) {
    // Remove asset directives before stripping markdown (removeMd doesn't handle them)
    const withoutDirectives = markdown.replace(ASSET_DIRECTIVE_REGEX, '')
    const plainText = removeMd(withoutDirectives)
    const truncated =
      plainText.length > maxLength ? plainText.slice(0, maxLength) + '...' : plainText
    return (
      <Text size="sm" c="dimmed">
        {truncated}
      </Text>
    )
  }

  // The level a heading was written at (`data-written`, remarkHeadingLevels) sets its look; the
  // level it was moved to, its tag.
  const heading =
    (order: TitleOrder) =>
    ({ children, 'data-written': written }: { children?: ReactNode; 'data-written'?: string }) => {
      const look = (Number(written) || order) as HeadingDepth
      return (
        <Title
          order={order}
          size={`h${look}` as TitleSize}
          mb={look === 1 ? 'md' : look === 2 ? 'sm' : 'xs'}
          mt={look <= 2 ? 'lg' : 'md'}
          style={look <= 3 ? { letterSpacing: '-0.025em' } : undefined}
        >
          {children}
        </Title>
      )
    }

  // Full markdown rendering - asset URLs handled at render time via AssetImage
  return (
    <Box fz="md" lh={1.75}>
      <ReactMarkdown
        remarkPlugins={[
          remarkGfm,
          remarkDirective,
          remarkAssetDirective,
          [remarkHeadingLevels, { top: topHeadingLevel }],
        ]}
        components={{
          // Asset directive - handles ::asset{id="..." size="..." alt="..."}
          // @ts-expect-error - custom component from remark-directive
          'asset-image': ({ id, size, alt }: { id?: string; size?: string; alt?: string }) => {
            if (!id) return null
            return (
              <Box my="md">
                <AssetImage
                  assetId={id}
                  images={images}
                  size={size as ImageSize}
                  altText={alt}
                  sizes={imageSizes}
                />
              </Box>
            )
          },
          // Regular image URLs
          img: ({ src, alt, ...props }) => (
            <Image
              src={src}
              alt={alt}
              maw="100%"
              h="auto"
              radius="md"
              my="md"
              loading="lazy"
              {...props}
            />
          ),
          // Headings
          h1: heading(1),
          h2: heading(2),
          h3: heading(3),
          h4: heading(4),
          h5: heading(5),
          h6: heading(6),
          // Paragraphs
          p: ({ children }) => (
            <Text component="p" mb="xs" lh={1.625}>
              {children}
            </Text>
          ),
          // Lists
          ul: ({ children }) => (
            <List type="unordered" mb="xs">
              {children}
            </List>
          ),
          ol: ({ children }) => (
            <List type="ordered" mb="xs">
              {children}
            </List>
          ),
          li: ({ children }) => <List.Item mb={4}>{children}</List.Item>,
          // Links
          a: ({ href, children }) => (
            <Anchor
              href={href}
              target="_blank"
              rel="noopener noreferrer"
              c="var(--mantine-color-anchor)"
            >
              {children}
            </Anchor>
          ),
          // Code
          code: ({ className, children }) => {
            const isInline = !className
            if (isInline) {
              return (
                <Code
                  bg="var(--mantine-color-default-hover)"
                  c="var(--mantine-color-pink-text)"
                  px={6}
                  py={2}
                  fz="sm"
                >
                  {children}
                </Code>
              )
            }
            return (
              <Code
                block
                bg="var(--mantine-color-dark-filled)"
                c="var(--mantine-color-text)"
                p="md"
                fz="sm"
                my="md"
                style={{ overflowX: 'auto' }}
              >
                {children}
              </Code>
            )
          },
          // Blockquotes
          blockquote: ({ children }) => (
            <Blockquote color="cyan" my="md" fs="italic">
              {children}
            </Blockquote>
          ),
          // Tables (from remark-gfm)
          table: ({ children }) => (
            <Box style={{ overflowX: 'auto' }} my="md">
              <Table striped highlightOnHover withTableBorder>
                {children}
              </Table>
            </Box>
          ),
          thead: ({ children }) => (
            <Table.Thead bg="var(--mantine-color-body)">{children}</Table.Thead>
          ),
          tbody: ({ children }) => <Table.Tbody>{children}</Table.Tbody>,
          tr: ({ children }) => <Table.Tr>{children}</Table.Tr>,
          th: ({ children }) => (
            <Table.Th
              px="sm"
              py="xs"
              fz="xs"
              fw={500}
              c="dimmed"
              tt="uppercase"
              style={{ letterSpacing: '0.05em' }}
            >
              {children}
            </Table.Th>
          ),
          td: ({ children }) => (
            <Table.Td px="sm" py="xs" fz="sm">
              {children}
            </Table.Td>
          ),
          // Horizontal rule
          hr: () => <Divider my="md" color="var(--mantine-color-default-border)" />,
          // Strong/bold
          strong: ({ children }) => (
            <Text component="strong" fw={700}>
              {children}
            </Text>
          ),
          // Emphasis/italic
          em: ({ children }) => (
            <Text component="em" fs="italic">
              {children}
            </Text>
          ),
        }}
      >
        {markdown}
      </ReactMarkdown>
    </Box>
  )
}
