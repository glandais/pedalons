import type { TagTarget } from './tagTarget.ts'

export type ListTeamTagsParams = {
  /** Only the tags of this kind of content; all kinds when absent */
  type?: TagTarget
}
