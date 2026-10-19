/**
 * Half-open run of unpaved edges [from, to) of a line; edge i joins points i and i + 1
 */
export interface UnpavedSpan {
  /** @minimum 0 */
  from: number
  /** @minimum 1 */
  to: number
}
