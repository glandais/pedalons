/**
 * Team-network route generator: a pure, deterministic search over a graph built from the team's own
 * routes (docs/plans/2026-11-13-generateur-boucles-equipe.md, ledger docs/LEDGER_*.md API-198).
 *
 * <p>No database, no CDI, no HTTP: the only input is a list of {@link
 * fr.pedalons.service.route.generator.TrackInput}, so every rule can be unit-tested on a graph
 * built by hand. Geometry maths run in a local equirectangular projection (short-range and angular
 * operations only); lengths always come from the input.
 */
@NullMarked
package fr.pedalons.service.route.generator;

import org.jspecify.annotations.NullMarked;
