-- The number the next ride created from a template takes, « Sortie du jeudi #42 », then raised by
-- one (docs/LEDGER_*.md API-108, biketeam's ride_template.increment). Null: the template numbers
-- nothing. Nullable and unused by the previous release, which keeps working beside this one.
alter table ride_templates add column next_number integer;
alter table ride_templates add constraint ck_ride_template_next_number
  check (next_number is null or next_number >= 0);
