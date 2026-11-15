/**
 * Stands in for `@/lib/push/webPush` in the embedded planner's bundle
 * (`vite.mobile-planner.config.ts` aliases it). `authStore` imports the real one lazily on sign
 * out, and a single-file build inlines a lazy import, Firebase with it. The page has no session
 * to sign out of.
 */
export async function disableWebPush(): Promise<void> {}
