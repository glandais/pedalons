package fr.pedalons.enums;

/**
 * Which route planner quota a save or a calculation drew on (docs/LEDGER_*.md BILL-10): the team's,
 * for a route of a team, or the user's own, in the GPX tools.
 */
public enum PlannerQuotaScope {
  TEAM,
  PERSONAL
}
