import { z } from 'zod'
import { COMMON_ALIAS, pageField, searchField, sizeField } from './common'

export const ADMIN_PAGE_SIZE = 20

const domainIdField = z.string().optional().catch(undefined)

export const adminUserFiltersSchema = z.object({
  search: searchField,
  domainId: domainIdField,
  // Never `z.coerce.boolean()`: `Boolean('false')` is true.
  adminOnly: z.stringbool().default(false).catch(false),
  page: pageField,
  size: sizeField(ADMIN_PAGE_SIZE),
})

export const adminUserFiltersAlias = {
  ...COMMON_ALIAS,
  domainId: 'domain',
  adminOnly: 'admin',
} as const

export const adminTeamFiltersSchema = z.object({
  domainId: domainIdField,
  page: pageField,
  size: sizeField(ADMIN_PAGE_SIZE),
})

export const adminTeamFiltersAlias = { ...COMMON_ALIAS, domainId: 'domain' } as const

export const adminDomainFiltersSchema = z.object({
  page: pageField,
  size: sizeField(ADMIN_PAGE_SIZE),
})

export const adminDomainFiltersAlias = COMMON_ALIAS
