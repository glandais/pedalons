package fr.pedalons.enums;

/**
 * How much of the road to ride off pavement, for a gravel or mountain-bike ride of the team route
 * generator (docs/LEDGER_*.md API-207, lot 5). The shares each level stands for live in the
 * backend, not in the contract.
 */
public enum RouteGeneratorUnpaved {
  LOW,
  USUAL,
  HIGH
}
