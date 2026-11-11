-- Whether a private team may publish content readable by link (docs/LEDGER_*.md API-176): set by
-- the platform admin only, off for every existing team.
--
-- Additive, with a default: the previous release, still running for the minute of a start-first
-- deploy, does not map the column and omits it from its inserts, where the default applies.
ALTER TABLE teams ADD COLUMN public_content_allowed BOOLEAN NOT NULL DEFAULT FALSE;

-- From this release on, a detail is read by link whatever its team's visibility. Content that a
-- team switched to private before TeamService.makeContentTeamOnly existed (2026-09-28) kept its
-- PUBLIC or PUBLIC_UNLISTED visibility, hidden only by the team clause this release drops: closed
-- here, so that a private team holds non-TEAM content only once the platform admin allowed it.
-- Safe during the rolling deploy: the previous release already hides that content from outsiders
-- and refuses any non-TEAM visibility in a private team.
UPDATE team_entities SET visibility = 'TEAM'
WHERE visibility <> 'TEAM'
  AND team_id IN (SELECT id FROM teams WHERE visibility = 'TEAM');

UPDATE ride_templates SET visibility = 'TEAM'
WHERE visibility <> 'TEAM'
  AND team_id IN (SELECT id FROM teams WHERE visibility = 'TEAM');
