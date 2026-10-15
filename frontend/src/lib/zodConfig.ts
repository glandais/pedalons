import { z } from 'zod'

/**
 * Zod 4 compiles object parsers with `new Function` when eval is allowed, and probes for it with a
 * `Function("")` it catches. The site's CSP has no 'unsafe-eval' (docs/LEDGER_*.md SEC-31), so the
 * probe fails anyway — but a browser still reports the caught attempt as a violation on every page
 * that builds a schema. Jitless skips the probe; the interpreted parsers are the ones a strict CSP
 * gets regardless. Imported first by entry-client.tsx: an object schema reads the setting when it is
 * built, at module load.
 */
z.config({ jitless: true })
