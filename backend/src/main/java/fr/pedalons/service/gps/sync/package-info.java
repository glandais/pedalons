/**
 * The automatic sync of the routes of a member's rides to their GPS services (docs/LEDGER_*.md
 * API-120, plan {@code docs/plans/2026-10-16-gps-route-autosync.md}): a planner that writes the
 * desired state, a leased worker that calls the services outside any transaction, and the service
 * the endpoints use (opt-in, state, manual uploads, disconnection).
 */
@NullMarked
package fr.pedalons.service.gps.sync;

import org.jspecify.annotations.NullMarked;
