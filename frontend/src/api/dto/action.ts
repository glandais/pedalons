export type Action = (typeof Action)[keyof typeof Action]

export const Action = {
  DEPOSIT: 'DEPOSIT',
  DELETE: 'DELETE',
  KEEP: 'KEEP',
} as const
