export type GetRoutesBulkParams = {
  /** Whether to include each route's track geometry. False answers metadata only — name, distances, media, asset links — with an empty 'tracks' array and no 'extent', for the screens that name routes without drawing them. */
  geometry?: boolean
  /** Route slug to include, repeatable. Capped at 50; unknown slugs and slugs the caller may not read are silently omitted from the response rather than erroring. Unlike GET /{routeSlug}, a slug that was renamed is also omitted rather than followed to the route's current slug: the single-route endpoint falls back to the rename history, this one does not. Same 'omit, never fail' contract as an unknown or unreadable slug, just for a different reason. */
  slug?: string[]
}
