-- =========================================================
-- LOOZ — undoes supabase/seed/demo_admin.sql
--
-- "Connexion démo" off, the demo admin is no longer an admin, no account is
-- a demo account any more. Then delete the login itself in
-- Authentication > Users (admin-demo@looz-demo.invalid) and remove
-- DEMO_ADMIN_PASSWORD from dashboard/backend/.env.
-- The admin action log keeps its lines (marked "démo").
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- =========================================================

update app_settings set demo_admin_login_enabled = false where id;
update profiles set role = 'farmer'
where id in (select id from auth.users where email = 'admin-demo@looz-demo.invalid');
update profiles set demo_account = false where demo_account;

-- Check: you should see  false | 0 | 0
select (select demo_admin_login_enabled from app_settings where id)                   as connexion_demo_on,
       (select count(*) from profiles where demo_account)                              as demo_accounts_left,
       (select count(*) from profiles p join auth.users u on u.id = p.id
         where u.email = 'admin-demo@looz-demo.invalid' and p.role = 'admin')          as demo_admins_left;
