export type MemberSortBy = (typeof MemberSortBy)[keyof typeof MemberSortBy]

export const MemberSortBy = {
  NAME: 'NAME',
  JOINED_AT: 'JOINED_AT',
} as const
