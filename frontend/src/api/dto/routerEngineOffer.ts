import type { RouterEngine } from './routerEngine.ts'
import type { RouterProfile } from './routerProfile.ts'

export interface RouterEngineOffer {
  engine: RouterEngine
  profiles: RouterProfile[]
}
