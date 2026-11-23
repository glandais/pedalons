import type { RouterEngine } from './routerEngine.ts'
import type { RouterEngineOption } from './routerEngineOption.ts'
import type { RouterProfile } from './routerProfile.ts'

export interface RouterEngineOffer {
  engine: RouterEngine
  profiles: RouterProfile[]
  /** What the engine really accepts beyond the profiles, from its capabilities: the screen shows a control only when its option is listed. Empty for STADIA. */
  options: RouterEngineOption[]
}
