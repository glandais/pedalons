/**
 * A count per key (a tier, a role, a client kind…) — counts only
 */
export interface AdminKeyCountDto {
  /** What is counted */
  key: string
  /** How many */
  count: number
}
