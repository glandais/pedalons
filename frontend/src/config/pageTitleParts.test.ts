import { beforeAll, describe, expect, it } from 'vitest'
import { QueryClient } from '@tanstack/react-query'
import type { TFunction } from 'i18next'
import { createServerI18n } from '@/i18n'
import { formatPageTitle } from '@/lib/pageTitle'
import { getGetRideQueryKey } from '@/api/endpoints/rides/rides'
import { pageTitleParts } from './pageTitleParts'
import { entityNames, entityNamesFromCache, type BreadcrumbEntities } from './breadcrumbNames'
import type { RouteParams } from './routes.types'

let t: TFunction
beforeAll(async () => {
  t = (await createServerI18n('fr')).t as TFunction
})

const team = { name: 'N Peloton' }
const ride = {
  name: 'Sortie du samedi',
  team: { name: 'N Peloton', accessible: true },
  groups: [{ id: 'g1', name: 'A' }],
}
const trip = {
  name: 'Voyage',
  team: { name: 'N Peloton', accessible: true },
  stages: [{ slug: 's1', name: 'Étape 1' }],
}

function title(
  routeId: string | undefined,
  entities: BreadcrumbEntities,
  params: RouteParams = {}
) {
  const parts = pageTitleParts(routeId, params, entityNames(entities, params, t), t)
  return formatPageTitle(parts.label, parts.context, 'Pédalons')
}
const tp = { teamSlug: 'np' }

describe('pageTitleParts', () => {
  it.each([
    ['team-agenda', { team }, tp, 'Agenda · N Peloton — Pédalons'],
    ['team-detail', { team }, tp, 'N Peloton — Pédalons'],
    ['team-calendar', { team }, tp, 'Agenda · N Peloton — Pédalons'],
    ['team-about', { team }, tp, 'À propos · N Peloton — Pédalons'],
    [
      'ride-detail',
      { ride, team },
      { ...tp, rideSlug: 'r' },
      'Sortie du samedi · N Peloton — Pédalons',
    ],
    ['ride-detail', { team }, { ...tp, rideSlug: 'r' }, 'Sortie · N Peloton — Pédalons'],
    [
      'ride-edit',
      { ride, team },
      { ...tp, rideSlug: 'r' },
      'Modifier · Sortie du samedi · N Peloton — Pédalons',
    ],
    ['route-new', { team }, tp, 'Créer un parcours · N Peloton — Pédalons'],
    [
      'ride-group',
      { ride },
      { ...tp, rideSlug: 'r', groupId: 'g1' },
      'Groupe A · Sortie du samedi · N Peloton — Pédalons',
    ],
    [
      'ride-group-map',
      { ride },
      { ...tp, rideSlug: 'r', groupId: 'g1' },
      'Groupe A · Sortie du samedi · N Peloton — Pédalons',
    ],
    [
      'stage-map',
      { trip },
      { ...tp, tripSlug: 't', stageSlug: 's1' },
      'Étape 1 · Voyage · N Peloton — Pédalons',
    ],
    ['gpx-tools-view', { gpxPreview: { name: 'Boucle' } }, { previewId: 'p' }, 'Boucle — Pédalons'],
    ['gpx-tools-view', {}, {}, 'Fichier GPX — Pédalons'],
    [
      'gpx-tools-edit',
      { gpxPreview: { name: 'Boucle' } },
      { previewId: 'p' },
      'Modifier · Boucle — Pédalons',
    ],
    ['admin', {}, {}, 'Administration de la plateforme — Pédalons'],
    ['admin-users', {}, {}, 'Comptes · Administration — Pédalons'],
    ['profile-preferences', {}, {}, 'Préférences — Pédalons'],
    ['routes-map', { team }, tp, 'Carte des parcours · N Peloton — Pédalons'],
    ['home', {}, {}, 'Accueil — Pédalons'],
    ['not-found', {}, {}, 'Page introuvable — Pédalons'],
    [undefined, {}, {}, 'Page introuvable — Pédalons'],
  ] as [string | undefined, BreadcrumbEntities, RouteParams, string][])(
    '%s -> %s',
    (routeId, entities, params, expected) => {
      expect(title(routeId, entities, params)).toBe(expected)
    }
  )
})

describe('entityNamesFromCache', () => {
  it("takes the team's name from the ride when GET team is not cached", () => {
    const queryClient = new QueryClient()
    queryClient.setQueryData(getGetRideQueryKey('np', 'r'), ride)
    const names = entityNamesFromCache(queryClient, { teamSlug: 'np', rideSlug: 'r' }, t)
    expect(names.team).toBe('N Peloton')
    expect(names.ride).toBe('Sortie du samedi')
  })
})
