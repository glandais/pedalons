# Pédalons Roadmap

This is the **product** roadmap: ideas not yet built and not yet turned into engineering tasks.
Everything else lives in the ledger and is not repeated here:

- what was delivered, with its date, contract version, tests and the decisions not to undo —
  [LEDGER_DONE.md](LEDGER_DONE.md);
- what is left to do once an idea has a task (`PREFIX-n`), and what was deliberately ruled out —
  [LEDGER_NEXT.md](LEDGER_NEXT.md);
- what the product does today — [PRODUCT_SHEET.md](PRODUCT_SHEET.md).

An idea that gets a ledger entry leaves this file. Two former lines went that way:
open: weather on Karoo and Garmin (ledger `API-77`); global full-text search (ledger `API-19`) was ruled out.

## P0 — Launch polish

- [ ] Responsive website — remaining issues on small screens
- [ ] Cards — remaining polish (icons, route previews)

## P2 — Growth

Features that differentiate and deepen engagement.

### Discovery
- [ ] User favorite routes + dedicated tab

### Route features
- [ ] Route basket (collect routes, display on a single map)
- [ ] Team/global route heatmap — the routes maps (`/parcours/carte`, per team or `?role=all`)
      already draw every route one may read; what is missing is weighting by how often a road is
      ridden

### Trips
- [ ] Trip stage alternative routes
- [ ] Trip progress indicator inside the trip view (current stage, "stage 3/7") — today only the
      agenda and card badges say a trip is under way

## P3 — Platform

### Administration
- [ ] Configure legal pages from the admin panel
- [ ] Manage system images from the admin panel

## Icebox — Needs discovery

Validated interest required before prioritization.

- [ ] Dedicated mobile/Garmin/Karoo app for a team with its own domain (one store listing per
      customer — the web side is covered by domain aliases)
- [ ] User dedicated team (personal workspace)
