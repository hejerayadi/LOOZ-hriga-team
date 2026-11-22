-- =========================================================
-- LOOZ — the DEMO VIDEO: delete the account of the LIVE SIGN-UP number
-- +216 22 999 005, so the sign-up can be done again (seed, NOT a migration)
--
-- Deletes ONLY the account of +216 22 999 005: its login, its profile and
-- everything of it (orchard drawn, zones, boxes, pack, installation visit,
-- posts, answers, photos rows, voice, notifications...) and its demo
-- payments. It refuses to delete an admin or a demo account (safety).
-- Nothing else is touched. Nothing to do if the number has no account.
--
-- Photos the sign-up uploaded (community or diagnosis) stay in Storage:
-- Supabase does not let SQL delete files. The check counts them; delete
-- them in Storage > community / diagnoses > the folder with no account
-- (they are never shown in the app: no post points to them any more).
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- ONE statement (do $$ ... $$) + a check. Safe to run again.
-- =========================================================

do $$
declare
  signup constant text := '+21622999005';
  uid uuid;
begin
  select id into uid from auth.users where phone in (signup, substr(signup, 2));
  if uid is null then
    select id into uid from profiles where phone = signup;
  end if;
  if uid is null then
    return;                                            -- no account: nothing to do
  end if;
  if exists (select 1 from profiles where id = uid and (role = 'admin' or is_demo or demo_account)) then
    raise exception 'Refused: % is an admin or a demo account. Change the sign-up number.', signup;
  end if;
  delete from payments where user_id = uid;            -- demo payments (they would stay without a user)
  delete from auth.users where id = uid;               -- the profile and everything of it go with it
end $$;

-- Check: you should see  +216 22 999 005 | 0 | 0 | N
--   the number | accounts | profiles | files in Storage that belong to no account any more
--   (N: old test accounts count too; if N went UP, the sign-up uploaded photos: delete them
--   in Storage > community / diagnoses, the folders whose name is no user id)
select '+216 22 999 005'                                                                     as number,
       (select count(*) from auth.users where phone in ('21622999005', '+21622999005'))      as accounts,
       (select count(*) from profiles where phone = '+21622999005')                          as profiles,
       (select count(*) from storage.objects o
        where o.bucket_id in ('community', 'diagnoses')
          and not exists (select 1 from profiles p
                          where p.id::text = (storage.foldername(o.name))[1]))               as files_without_account;
