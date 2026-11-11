-- A team's plan (docs/LEDGER_*.md BILL-10): FREE caps the members and the planner saves, UNLOCKED
-- lifts both caps. Set by the platform admin only; tier_note says why (« club pilote », « offert
-- par … »).
--
-- Additive, with a default: the previous release, still running for the minute of a start-first
-- deploy, does not map the columns and omits them from its inserts, where the default applies — a
-- team it creates is born FREE and closed, as it was. No refusal exists yet, so FREE costs nothing
-- in the meantime.
ALTER TABLE teams ADD COLUMN tier VARCHAR(20) NOT NULL DEFAULT 'FREE';
ALTER TABLE teams ADD COLUMN tier_note VARCHAR(500);

-- Every team that exists today is unlocked. Its governance flags are left as they are.
UPDATE teams SET tier = 'UNLOCKED';
