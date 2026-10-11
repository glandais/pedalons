-- The lease FeedbackGithubWorker takes on a row before calling GitHub, so that the second backend of
-- a rolling deploy does not open the same issue twice (docs/LEDGER_*.md ISSUE-8). Nullable and
-- unused by the previous release, which keeps working beside this one.
alter table error_signatures add column github_claimed_until timestamp(6) with time zone;
alter table feedback_reports add column github_claimed_until timestamp(6) with time zone;
