import type { RouterEngineOffer } from './routerEngineOffer.ts'

export interface RouterEnginesResponse {
  /** The engines the planner can ask for a leg. STADIA is always there, with every profile; PEDALONS only when the service behind it is configured and says it is ready */
  engines: RouterEngineOffer[]
}
