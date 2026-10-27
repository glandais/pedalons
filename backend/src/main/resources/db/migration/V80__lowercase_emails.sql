-- Addresses are now normalised (trimmed, lower-cased) by every request that carries one, and looked
-- up by exact match: an account stored with a capital could no longer sign in nor get a reset code
-- (docs/LEDGER_*.md API-146). An address whose lower-cased form is already taken on its domain is
-- left alone rather than breaking uk_users_domain_email; there was none on 27 October 2026.

update users u
set email = lower(trim(u.email)), updated_at = now()
where u.email <> lower(trim(u.email))
  and not exists (
    select 1 from users o
    where o.domain_id = u.domain_id and o.id <> u.id and o.email = lower(trim(u.email))
  );

update auth_tokens
set email = lower(trim(email))
where email <> lower(trim(email));
