/**
 * Audience measurement settings for the site
 */
export interface AnalyticsConfigDto {
  /** Same-origin path the site sends a page view to (for example /count), without the query string. */
  countPath: string
}
