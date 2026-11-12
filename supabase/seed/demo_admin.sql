-- =========================================================
-- LOOZ — the DEMO ADMIN of the dashboard ("Connexion démo") and the demo
-- accounts of the presentation (seed, NOT a migration)
--
-- BEFORE: Supabase > Authentication > Users > "Add user" > "Create new user":
--   e-mail  admin-demo@looz-demo.invalid
--   a long password (the SAME one goes ONLY in dashboard/backend/.env,
--   line DEMO_ADMIN_PASSWORD=...), "Auto Confirm User" on.
--
-- This file then:
--   - makes that account an ADMIN named "Démo Admin", a demo account;
--   - marks the demo accounts of the presentation (demo_phones below) and
--     ONLY those (the test numbers +216 50 000 001 ... 005 are not demo
--     accounts). The fake people of the community (is_demo) are demo too.
--     With "Connexion démo", the dashboard shows only demo accounts (no real
--     farmer, no real phone number: screenshots for the repo).
--   - never creates an account (+216 22 999 002 must stay without one).
-- The demo admin acts only on demo things, never on the settings, the
-- price, the gateways or blocking accounts (migration 013).
-- The switch stays OFF: turn it on in the dashboard (Réglages), or
--   update app_settings set demo_admin_login_enabled = true where id;
-- Remove: supabase/seed/demo_admin_delete.sql
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Needs migration 013. ONE statement (do $$ ... $$) + a check.
-- Safe to run again.
-- =========================================================

do $$
declare
  demo_email  constant text   := 'admin-demo@looz-demo.invalid';
  demo_phones constant text[] := array['+21622777001',                    -- IoT demo farmer (Sfax)
                                       '+21622123456',                    -- Premium, demo orchard
                                       '+21622123457',                    -- Free farmer
                                       '+21622123458',                    -- expert
                                       '+21622999001', '+21622999003'];   -- demo login: farmer, expert
  uid uuid;
begin
  select id into uid from auth.users where email = demo_email;
  if uid is null then
    raise exception 'No login account % yet: create it first (Authentication > Users > Add user), then run this file again.', demo_email;
  end if;
  -- The profile is made with the account; if it is missing, make it.
  insert into profiles (id, role, name) values (uid, 'admin', 'Démo Admin') on conflict (id) do nothing;
  update profiles set role = 'admin', first_name = 'Démo', last_name = 'Admin', zone = null, demo_account = true
  where id = uid;
  update profiles set demo_account = true where phone = any (demo_phones) and not demo_account;
  -- Only these numbers (and the demo admin) are demo accounts.
  update profiles set demo_account = false
  where demo_account and id <> uid and not (coalesce(phone, '') = any (demo_phones));
end $$;

-- Check: you should see  admin-demo@looz-demo.invalid | admin | Démo Admin | true | 6 | 0 | false
--   6 = the demo numbers that have an account (fewer if one has no account yet)
--   0 = +216 22 999 002 still has no account
select u.email,
       p.role,
       p.name,
       p.demo_account,
       (select count(*) from profiles x where x.demo_account and x.role <> 'admin')  as demo_accounts,
       (select count(*) from profiles x where x.phone = '+21622999002')              as account_22999002,
       (select demo_admin_login_enabled from app_settings where id)                  as connexion_demo_on
from auth.users u join profiles p on p.id = u.id
where u.email = 'admin-demo@looz-demo.invalid';
