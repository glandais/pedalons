/**
 * The card gallery (ledger `WEB-167`): the site's real card components, mounted with fixed data
 * from the brief shared with the app's gallery
 * (`docs/plans/2026-11-10-etat-des-lieux-affichage/audit-cartes/galerie.md`). A development tool:
 * served by `pnpm dev` at `/dev/cards.html`, never part of the production build — see `main.tsx`.
 *
 * One URL per section, `?section=<id>`; without one, the table of contents.
 */
import { Anchor, Box, Container, List, Stack, Text, Title } from '@mantine/core'
import { SectionView, isOmitted, type GallerySection } from './galleryLayout'
import { agendaSection, feedSection, homeSection } from './sections/feedAndHome'
import { groupsSection, stagesSection } from './sections/detailCards'
import { adsSection, routesSection, teamsSection } from './sections/listCards'
import { dashboardSection, miscSection } from './sections/dashboardAndMisc'

/** The brief's sections, in its order. */
export const GALLERY_SECTIONS: GallerySection[] = [
  feedSection,
  homeSection,
  agendaSection,
  groupsSection,
  stagesSection,
  routesSection,
  adsSection,
  teamsSection,
  dashboardSection,
  miscSection,
]

export const sectionUrl = (id: string) => `?section=${id}`

function TableOfContents() {
  return (
    <Box component="nav" aria-label="Sommaire">
      <List size="sm" spacing={4}>
        {GALLERY_SECTIONS.map((section) => {
          const shown = section.entries.filter((e) => !isOmitted(e)).length
          return (
            <List.Item key={section.id}>
              <Anchor href={sectionUrl(section.id)}>{section.id}</Anchor>
              <Text span size="sm" c="dimmed">
                {' '}
                — {section.title} ({shown}/{section.entries.length})
              </Text>
            </List.Item>
          )
        })}
      </List>
    </Box>
  )
}

export function CardGallery({ sectionId }: { sectionId?: string | null }) {
  const section = GALLERY_SECTIONS.find((s) => s.id === sectionId)
  return (
    <Box py="lg" px="md">
      {/* The layout's width (`Layout.tsx`: `Container size="lg"`), so a grid card is a third of it. */}
      <Container size="lg" px={0}>
        <Stack gap="xl">
          <Stack gap="xs">
            <Title order={1} size="h3">
              Galerie des cartes — site
            </Title>
            <Text size="sm" c="dimmed">
              Outil de développement (ledger WEB-167) : les vrais composants, des données fixes,
              lues par Camille Durand (membre, français, métrique, Europe/Paris). J = aujourd’hui.
            </Text>
            {section ? (
              <Anchor href="?" size="sm">
                ← Sommaire
              </Anchor>
            ) : (
              <TableOfContents />
            )}
          </Stack>
          {section && <SectionView section={section} />}
          {sectionId && !section && <Text c="red">Section inconnue : {sectionId}</Text>}
        </Stack>
      </Container>
    </Box>
  )
}
