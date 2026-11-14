package fr.pedalons.service.route.generator;

/**
 * Why no route was produced. Lot 3 maps these to the {@code GENERATOR_*} error codes of plan §6
 * (docs/plans/2026-11-13-generateur-boucles-equipe.md, ledger docs/LEDGER_*.md API-198).
 */
public enum GeneratorFailure {
  START_TOO_FAR,
  END_TOO_FAR,
  DISTANCE_TOO_SHORT,
  NETWORK_TOO_SMALL,
  NO_ROUTE
}
