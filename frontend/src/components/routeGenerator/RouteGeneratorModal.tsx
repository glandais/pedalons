import { useReducer } from 'react'
import { useTranslation } from 'react-i18next'
import { ActionIcon, Box, Modal } from '@mantine/core'
import { IconArrowLeft } from '@tabler/icons-react'
import type { GeneratedRouteDto, RouteGeneratorType, TeamDetailDto } from '@/api/dto'
import {
  GENERATOR_DEFAULT_DISCOVERY,
  GENERATOR_DEFAULT_KM,
} from '@/hooks/filters/routeGeneratorFilters'
import { MapFullscreenShell } from '../map/MapFullscreenShell'
import {
  RouteGeneratorPanel,
  type GeneratorParamPatch,
  type RouteGeneratorPanelParams,
} from './RouteGeneratorPanel'

type Action =
  | { kind: 'patch'; patch: GeneratorParamPatch }
  | { kind: 'generate' }
  | { kind: 'more' }
  | { kind: 'select'; index: number }

const INITIAL: RouteGeneratorPanelParams = {
  distanceKm: GENERATOR_DEFAULT_KM,
  discovery: GENERATOR_DEFAULT_DISCOVERY,
  seed: 0,
  selected: 0,
  go: false,
}

/** The same rules as the page's query string (`generatorParamPatch`), over local state. */
function reduce(state: RouteGeneratorPanelParams, action: Action): RouteGeneratorPanelParams {
  switch (action.kind) {
    case 'patch':
      return { ...state, ...action.patch, go: false, seed: 0, selected: 0 }
    case 'generate':
      return state.go ? { ...state, seed: state.seed + 1, selected: 0 } : { ...state, go: true }
    case 'more':
      return { ...state, seed: state.seed + 1, selected: 0, go: true }
    case 'select':
      return { ...state, selected: action.index }
  }
}

interface RouteGeneratorModalProps {
  opened: boolean
  onClose: () => void
  team: TeamDetailDto
  /** A candidate was chosen: the editor loads it into the planner. */
  onUse: (candidate: GeneratedRouteDto, type: RouteGeneratorType) => void
}

/**
 * The generator inside the route editor, for a creation (ledger `WEB-179`): the same panel as the
 * page, in a fullscreen dialog, so that a ride or trip form hosting the editor keeps its unsaved
 * state. The parameters live here, in local state, kept while the editor is open. The query cache
 * is the page's, so a request already made is not sent again.
 */
export function RouteGeneratorModal({ opened, onClose, team, onUse }: RouteGeneratorModalProps) {
  const { t } = useTranslation()
  const [params, dispatch] = useReducer(reduce, INITIAL)
  return (
    <Modal.Root
      opened={opened}
      onClose={onClose}
      fullScreen
      padding={0}
      // Escape never closes it, as for the planner's editor: the back arrow does
      closeOnEscape={false}
      lockScroll={false}
      zIndex={300}
      transitionProps={{ duration: 0 }}
    >
      <Modal.Content h="100dvh">
        <MapFullscreenShell
          leading={
            <ActionIcon variant="subtle" size="lg" onClick={onClose} aria-label={t('actions.back')}>
              <IconArrowLeft size={20} />
            </ActionIcon>
          }
          title={
            <Modal.Title fz="md" fw={600} lh="inherit">
              {t('routeGenerator.title')}
            </Modal.Title>
          }
        >
          <Box h="100%" style={{ overflowY: 'auto' }}>
            <RouteGeneratorPanel
              team={team}
              layout="modal"
              params={params}
              onParamsChange={(patch) => dispatch({ kind: 'patch', patch })}
              onGenerate={() => dispatch({ kind: 'generate' })}
              onMoreProposals={() => dispatch({ kind: 'more' })}
              onSelect={(index) => dispatch({ kind: 'select', index })}
              onOpen={onUse}
            />
          </Box>
        </MapFullscreenShell>
      </Modal.Content>
    </Modal.Root>
  )
}
