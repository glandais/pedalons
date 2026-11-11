package fr.pedalons.enums;

/**
 * A team's plan, set by the platform admin only (docs/LEDGER_*.md BILL-10). {@code FREE} caps the
 * members and the planner saves, {@code UNLOCKED} lifts both caps; the numbers live in {@code
 * PlanLimits}, never here. The governance flags still close a team whatever its tier.
 */
public enum TeamTier {
  FREE,
  UNLOCKED
}
