/**
 * The list gallery: the site's real list pages, mounted with fixed answers from the brief shared
 * with the app's gallery (`docs/plans/2026-11-10-etat-des-lieux-affichage/audit-listes/galerie.md`).
 * A development tool: served by `pnpm dev` at `/dev/lists.html`, never part of the production
 * build — see `main.tsx`.
 *
 * One case per address, `?section=<id>&case=<id>`, so a capture takes one picture per case: the
 * whole application — its layout, header and breadcrumb included — in a memory router opened at
 * the case's address, from the route table the site itself uses (`buildRoutes`). Without a case,
 * the table of contents.
 */
import { Suspense, useState, type ReactNode } from 'react'
import { createMemoryRouter, RouterProvider, type RouteObject } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { Anchor, Box, Container, List, Stack, Text, Title } from '@mantine/core'
import { buildRoutes } from '@/config/RouteGenerator'
import {
  LIST_SECTIONS,
  findCase,
  isOmittedCase,
  type ListCase,
  type OmittedListCase,
} from './cases'

export const caseUrl = (sectionId: string, caseId: string) => `?section=${sectionId}&case=${caseId}`

/**
 * The route table without its loaders: a loader awaits the route's prefetch before the page
 * renders, so a case whose answer never comes (`-chargement`) would show nothing at all. The page
 * fetches its own data through its hooks either way — what a client navigation does once the
 * cache is cold.
 */
function withoutLoaders(routes: RouteObject[]): RouteObject[] {
  return routes.map((route) => {
    const copy = { ...route } as RouteObject & { loader?: unknown }
    delete copy.loader
    if (copy.children) copy.children = withoutLoaders(copy.children)
    return copy as RouteObject
  })
}

function CaseApp({ entry }: { entry: ListCase }) {
  const queryClient = useQueryClient()
  const [router] = useState(() =>
    createMemoryRouter(withoutLoaders(buildRoutes(queryClient)), {
      initialEntries: [entry.url()],
    })
  )
  return (
    <Suspense fallback={null}>
      <RouterProvider router={router} />
    </Suspense>
  )
}

function Caption({ children }: { children: ReactNode }) {
  return (
    <Box
      px="sm"
      py={4}
      // Above the application: its skip link, hidden above the app's box, would cover the caption.
      style={{
        position: 'relative',
        zIndex: 1000,
        borderBottom: '1px solid var(--mantine-color-default-border)',
        background: 'var(--mantine-color-gray-0)',
      }}
    >
      <Text size="xs" c="dimmed" ff="monospace" truncate>
        {children}
      </Text>
    </Box>
  )
}

/**
 * A case: its caption, then the application. The application's box is transformed so that the
 * fixed header of `AppShell` sits under the caption instead of over it.
 */
export function CaseView({ entry }: { entry: ListCase }) {
  return (
    <Box
      data-gallery-case={entry.id}
      data-gallery-scroll={entry.scrollTo}
      data-gallery-clicks={entry.clicks ? JSON.stringify(entry.clicks) : undefined}
    >
      <Caption>
        {entry.id} — {entry.label}
      </Caption>
      <Box style={{ transform: 'translateZ(0)', minHeight: '100vh' }}>
        <CaseApp entry={entry} />
      </Box>
    </Box>
  )
}

function OmittedView({ entry }: { entry: OmittedListCase }) {
  return (
    <Box data-gallery-omitted={entry.id} p="md">
      <Caption>
        {entry.id} — {entry.label}
      </Caption>
      <Text size="sm" c="dimmed" mt="sm">
        Omis sur le site : {entry.omitted}
      </Text>
    </Box>
  )
}

function TableOfContents() {
  return (
    <Box component="nav" aria-label="Sommaire">
      <List size="sm" spacing="sm">
        {LIST_SECTIONS.map((section) => (
          <List.Item key={section.id}>
            <Text span fw={600} size="sm">
              {section.id}
            </Text>
            <Text span size="sm" c="dimmed">
              {' '}
              — {section.title}
            </Text>
            <List size="sm" withPadding>
              {section.entries.map((entry) => (
                <List.Item key={entry.id}>
                  {isOmittedCase(entry) ? (
                    <Text span size="sm" c="dimmed">
                      {entry.id} (omis : {entry.omitted})
                    </Text>
                  ) : (
                    <Anchor
                      href={caseUrl(section.id, entry.id)}
                      data-section={section.id}
                      data-case={entry.id}
                      ff="monospace"
                      size="sm"
                    >
                      {entry.id}
                    </Anchor>
                  )}
                </List.Item>
              ))}
            </List>
          </List.Item>
        ))}
      </List>
    </Box>
  )
}

export function ListGallery({
  sectionId,
  caseId,
}: {
  sectionId?: string | null
  caseId?: string | null
}) {
  const { entry } = findCase(sectionId ?? null, caseId ?? null)
  if (entry) {
    return isOmittedCase(entry) ? <OmittedView entry={entry} /> : <CaseView entry={entry} />
  }
  return (
    <Box py="lg" px="md">
      <Container size="lg" px={0}>
        <Stack gap="md">
          <Title order={1} size="h3">
            Galerie des listes — site
          </Title>
          <Text size="sm" c="dimmed">
            Outil de développement : les vraies pages de liste, des réponses fixes, lues par Camille
            Durand (organisatrice du Vélo Club des Monts, français, métrique, Europe/Paris). Un cas
            par adresse.
          </Text>
          {(sectionId || caseId) && (
            <Text c="red">
              Cas inconnu : {sectionId} / {caseId}
            </Text>
          )}
          <TableOfContents />
        </Stack>
      </Container>
    </Box>
  )
}
