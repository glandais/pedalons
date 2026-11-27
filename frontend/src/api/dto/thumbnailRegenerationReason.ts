export type ThumbnailRegenerationReason =
  (typeof ThumbnailRegenerationReason)[keyof typeof ThumbnailRegenerationReason]

export const ThumbnailRegenerationReason = {
  RENDERED_IN_WINDOW: 'RENDERED_IN_WINDOW',
  SMALL_FILE: 'SMALL_FILE',
  MISSING: 'MISSING',
  OUTDATED: 'OUTDATED',
  GIVEN_UP: 'GIVEN_UP',
} as const
