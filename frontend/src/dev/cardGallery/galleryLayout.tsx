/**
 * The gallery's frame: a case is a caption carrying its identifier above one card, in the width the
 * card has on the site. Consecutive cases of the same layout share one container, so three grid
 * cards sit side by side exactly as in a list.
 */
import { Component, type CSSProperties, type ErrorInfo, type ReactNode } from 'react'
import { MemoryRouter } from 'react-router-dom'
import { Box, Flex, Grid, SimpleGrid, Stack, Text } from '@mantine/core'

/**
 * Where a card lives on the site, and so how wide it is:
 * - `grid`: a list's three-column grid (`SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }}`);
 * - `homeMain` / `homeAside`: the member home's two columns (`Grid.Col` 8 / 4 at lg, 7 / 5 at md);
 * - `side`: a detail page's side column (`.detail-layout > .detail-side`, 380 to 440 px);
 * - `dashMain` / `dashAside`: the team dashboard's two columns (`flex: 999 1 560px` / `1 1 300px`);
 * - `full`: the page's whole width (`Container size="lg"`).
 */
export type CaseLayout =
  'grid' | 'homeMain' | 'homeAside' | 'side' | 'dashMain' | 'dashAside' | 'full'

export interface GalleryCase {
  /** The brief's identifier, e.g. `fil-sortie-inscrite`. */
  id: string
  /** What the case shows, after the identifier. */
  label: string
  layout: CaseLayout
  /** The router location the case is mounted at (a case that mounts a whole page). */
  url?: () => string
  render: () => ReactNode
}

/** A case of the brief the site has no card for: listed, with the reason, never replaced. */
export interface OmittedCase {
  id: string
  label: string
  omitted: string
}

export type GalleryEntry = GalleryCase | OmittedCase

export interface GallerySection {
  id: string
  title: string
  entries: GalleryEntry[]
}

export const isOmitted = (entry: GalleryEntry): entry is OmittedCase => 'omitted' in entry

class CaseErrorBoundary extends Component<{ id: string; children: ReactNode }, { error?: Error }> {
  state: { error?: Error } = {}

  static getDerivedStateFromError(error: Error) {
    return { error }
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error(`[galerie] ${this.props.id} :`, error, info.componentStack)
  }

  render() {
    if (this.state.error) {
      return (
        <Text c="red" size="sm" data-gallery-error={this.props.id}>
          Erreur de rendu : {this.state.error.message}
        </Text>
      )
    }
    return this.props.children
  }
}

function Caption({ id, label }: { id: string; label: string }) {
  return (
    <Text size="xs" c="dimmed" mb={6} ff="monospace">
      {id}
      <Text span size="xs" c="dimmed" ff="inherit">
        {' '}
        — {label}
      </Text>
    </Text>
  )
}

function CaseView({ entry }: { entry: GalleryCase }) {
  return (
    <Box data-gallery-case={entry.id}>
      <Caption id={entry.id} label={entry.label} />
      <CaseErrorBoundary id={entry.id}>
        {/* One router per case: a case that mounts a page needs its own location. */}
        <MemoryRouter initialEntries={[entry.url?.() ?? '/']}>{entry.render()}</MemoryRouter>
      </CaseErrorBoundary>
    </Box>
  )
}

function OmittedView({ entry }: { entry: OmittedCase }) {
  return (
    <Box
      data-gallery-omitted={entry.id}
      p="sm"
      style={{ border: '1px dashed var(--mantine-color-default-border)', borderRadius: 8 }}
    >
      <Caption id={entry.id} label={entry.label} />
      <Text size="sm" c="dimmed">
        Omis sur le site : {entry.omitted}
      </Text>
    </Box>
  )
}

/** An empty column beside the cases, holding the width the other column takes on the page. */
function Neighbour(props: { style?: CSSProperties; visibleFrom?: 'md' }) {
  return <Box aria-hidden {...props} />
}

function Run({ layout, cases }: { layout: CaseLayout; cases: GalleryCase[] }) {
  const views = cases.map((entry) => <CaseView key={entry.id} entry={entry} />)
  switch (layout) {
    case 'grid':
      return (
        <SimpleGrid cols={{ base: 1, sm: 2, lg: 3 }} spacing="lg">
          {views}
        </SimpleGrid>
      )
    case 'homeMain':
      return (
        <Stack gap="xl">
          {views.map((view, i) => (
            <Grid key={i} gap="lg">
              <Grid.Col span={{ base: 12, md: 7, lg: 8 }}>{view}</Grid.Col>
              <Grid.Col span={{ base: 12, md: 5, lg: 4 }} visibleFrom="md" />
            </Grid>
          ))}
        </Stack>
      )
    case 'homeAside':
      return (
        <Grid gap="lg">
          {views.map((view, i) => (
            <Grid.Col key={i} span={{ base: 12, md: 5, lg: 4 }}>
              {view}
            </Grid.Col>
          ))}
        </Grid>
      )
    case 'side':
      return (
        <Flex gap="lg" wrap="wrap" align="flex-start">
          {views.map((view, i) => (
            <Box key={i} w="100%" maw={440}>
              {view}
            </Box>
          ))}
        </Flex>
      )
    case 'dashMain':
      return (
        <Flex gap="xl" wrap="wrap" align="flex-start">
          <Stack gap="xl" style={{ flex: '999 1 560px', minWidth: 0 }}>
            {views}
          </Stack>
          <Neighbour style={{ flex: '1 1 300px' }} />
        </Flex>
      )
    case 'dashAside':
      return (
        <Flex gap="xl" wrap="wrap" align="flex-start">
          <Neighbour style={{ flex: '999 1 560px' }} />
          <Stack gap="xl" style={{ flex: '1 1 300px', minWidth: 0 }}>
            {views}
          </Stack>
        </Flex>
      )
    case 'full':
      return <Stack gap="xl">{views}</Stack>
  }
}

/** A section: its cases in the brief's order, grouped into runs of one layout. */
export function SectionView({ section }: { section: GallerySection }) {
  const blocks: ReactNode[] = []
  let run: GalleryCase[] = []
  const flush = () => {
    if (run.length > 0) {
      blocks.push(<Run key={run[0].id} layout={run[0].layout} cases={run} />)
      run = []
    }
  }
  for (const entry of section.entries) {
    if (isOmitted(entry)) {
      flush()
      blocks.push(<OmittedView key={entry.id} entry={entry} />)
    } else {
      if (run.length > 0 && run[0].layout !== entry.layout) flush()
      run.push(entry)
    }
  }
  flush()

  return (
    <Box component="section" data-gallery-section={section.id}>
      <Text component="h2" fw={700} size="xl" mb="md">
        {section.title}
      </Text>
      <Stack gap="xl">{blocks}</Stack>
    </Box>
  )
}
