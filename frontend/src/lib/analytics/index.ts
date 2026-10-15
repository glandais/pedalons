// Audience measurement of the site (docs/plans/2026-10-15-web-analytics.md, docs/LEDGER_*.md WEB-90).
// Importing this module has no effect: no browser global is read before a function is called.
export { installPageViewCounter } from './pageViewCounter'
export { isAnalyticsOptedOut, setAnalyticsOptedOut, subscribeAnalyticsOptOut } from './optOut'
export { browserSignalsOptOut } from './sender'
