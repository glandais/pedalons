import { forwardRef, type AnchorHTMLAttributes } from 'react'

/**
 * Stands in for `@/components/common/PrefetchLink` in the embedded planner's bundle
 * (`vite.mobile-planner.config.ts` aliases it). The real one reaches the router and, through the
 * route table, every page of the site, which a single-file build inlines whole. The planner
 * renders no link: `MapControlButton` imports it for the maps that have one.
 */
export const PrefetchLink = forwardRef<
  HTMLAnchorElement,
  AnchorHTMLAttributes<HTMLAnchorElement> & { to: string; prefetch?: string }
>(function PrefetchLink({ to, prefetch: _prefetch, ...rest }, ref) {
  return <a ref={ref} href={to} {...rest} />
})
