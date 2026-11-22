-- =========================================================
-- LOOZ — the DEMO VIDEO: delete the TEST leftovers (seed, NOT a migration)
-- Made from the result of demo_recording_list.sql (22 Nov 2026).
--
-- DELETED (test only):
--   1. The designer test accounts +216 22 98x xxx ("test user" +216 22 989 101)
--      with everything of them, and their demo payments.
--   2. The 6 demo payments left without an account (deleted test accounts).
--   3. What the Supabase test numbers +216 50 000 001…005 wrote in the
--      community (the answer "walahi bravo"). Their ACCOUNTS STAY: the live
--      tests log in with them (auth, community, photo, sign-up + payment).
--   4. The reports written by demo accounts (2 by 22 777 001, from the
--      live tests), and the posts / answers of the 9 fake people that a test
--      hid are shown again.
--   5. The ENDED demo alerts (9 test alerts "Gel cette nuit", "Fortes
--      pluies demain", "Vague de chaleur à Sfax et Sidi Bouzid", "Test : …").
--      The story alert of demo_recording_setup.sql is never touched.
--   6. The test photo diagnoses of the demo accounts (22 777 001: 8,
--      22 123 456: 19) and the test voice conversations (22 777 001: 2).
--      Their photo FILES stay in Storage (SQL cannot delete files): the
--      check gives their folders, delete them in Storage > diagnoses.
--
-- NOT TOUCHED:
--   - every REAL user (the 8 "REAL user" accounts of the list), their posts,
--     photos, diagnoses and payments;
--   - the 3 ended alerts "Jalon C : vague de chaleur à Sfax" (written by an
--     admin, visible to all farmers when they were active): marked REAL in
--     the list, so they stay. They are ended: the app and "Connexion démo"
--     never show them;
--   - the demo accounts themselves (22 999 001 / 003, 22 123 456 / 457 / 458,
--     22 777 001) and the 9 fake people: the live tests and the video use them;
--   - the 5 Supabase test numbers (see 3).
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- ONE statement (do $$ ... $$) + a check. Safe to run again.
-- =========================================================

do $$
declare
  story_alert constant uuid := 'de000000-0000-4000-b000-000000000001';
  designer    uuid[];
  testers     uuid[];
  demo        uuid[];
begin
  select coalesce(array_agg(id), '{}') into designer from profiles
  where phone like '+2162298%' and role <> 'admin' and not is_demo and not demo_account;
  select coalesce(array_agg(id), '{}') into testers from profiles
  where phone like '+2165000000_' and role <> 'admin' and not is_demo and not demo_account;
  select coalesce(array_agg(id), '{}') into demo from profiles
  where (is_demo or demo_account) and role <> 'admin';

  -- 1. Designer test accounts (+ their payments, which would stay without a user)
  delete from payments where user_id = any (designer);
  delete from auth.users where id = any (designer);

  -- 2. Demo payments without an account
  delete from payments where user_id is null and status in ('paid_demo', 'failed_demo');

  -- 3. Community leftovers of the Supabase test numbers (accounts kept)
  delete from content_reports where reporter_id = any (testers);
  delete from comments where author_id = any (testers);
  delete from posts where author_id = any (testers) and (photo is null or photo like 'demo:%');

  -- 4. Reports written by demo accounts; fake people's posts / answers visible again
  delete from content_reports where reporter_id = any (demo);
  update posts    set hidden = false where hidden and author_id in (select id from profiles where is_demo);
  update comments set hidden = false where hidden and author_id in (select id from profiles where is_demo);

  -- 5. Ended demo alerts (never the story alert)
  delete from regional_alerts a
  where a.is_demo and a.id <> story_alert and not public.regional_alert_is_active(a);

  -- 6. Test photo diagnoses and voice conversations of the demo accounts
  delete from photo_diagnoses where user_id = any (demo);
  delete from voice_sessions where user_id = any (demo) and ended_at is not null;
end $$;

-- Check: you should see  0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 5 | 8 | 1 | 1 | 3 | <folders>
--   designer test accounts | payments without account | posts + answers of the test numbers |
--   reports by demo accounts | hidden posts + answers of the fake people | ended demo alerts |
--   photo diagnoses of demo accounts | voice of demo accounts | test numbers kept (5) |
--   REAL users kept: accounts (8) | their posts (1) | their photo diagnoses (1) | ended "Jalon C" alerts kept (3) |
--   the Storage folders (diagnoses) with photo files that have no diagnosis any more: open
--   Storage > diagnoses > each folder named here and delete its files (empty = nothing to do)
-- (REAL users = the same rule as demo_recording_list.sql: not admin, not demo, not a test number,
--  not an odd name.)
with real_users as (
  select id from profiles p
  where p.role <> 'admin' and not p.is_demo and not p.demo_account
    and coalesce(p.phone, '') not like '+2162298%' and coalesce(p.phone, '') not like '+2165000000_'
    and coalesce(p.phone, '') <> '+21622999002'
    and coalesce(btrim(p.name), '') <> ''
    and p.name !~* '(test|essai|dummy|fake|^user|^demo|asdf|azer|qwer)'
    and replace(p.name, ' ', '') !~ '^(.)\1*$' and p.name !~ 'تجرب'
)
select (select count(*) from profiles where phone like '+2162298%' and not (is_demo or demo_account)) as designer_accounts,
       (select count(*) from payments where user_id is null)                                          as payments_without_account,
       (select count(*) from posts p join profiles a on a.id = p.author_id where a.phone like '+2165000000_')
         + (select count(*) from comments c join profiles a on a.id = c.author_id where a.phone like '+2165000000_')
                                                                                                    as test_number_posts_answers,
       (select count(*) from content_reports r join profiles a on a.id = r.reporter_id
        where a.is_demo or a.demo_account)                                                         as demo_reports,
       (select count(*) from posts p join profiles a on a.id = p.author_id where a.is_demo and p.hidden)
         + (select count(*) from comments c join profiles a on a.id = c.author_id where a.is_demo and c.hidden)
                                                                                                    as hidden_fake_content,
       (select count(*) from regional_alerts a
        where a.is_demo and a.id <> 'de000000-0000-4000-b000-000000000001'
          and not public.regional_alert_is_active(a))                                              as ended_demo_alerts,
       (select count(*) from photo_diagnoses d join profiles a on a.id = d.user_id
        where a.is_demo or a.demo_account)                                                         as demo_diagnoses,
       (select count(*) from voice_sessions v join profiles a on a.id = v.user_id
        where (a.is_demo or a.demo_account) and v.ended_at is not null)                            as demo_voice,
       (select count(*) from profiles where phone like '+2165000000_')                               as test_numbers_kept,
       (select count(*) from real_users)                                                            as real_accounts,
       (select count(*) from posts where author_id in (select id from real_users))                   as real_posts,
       (select count(*) from photo_diagnoses where user_id in (select id from real_users))           as real_diagnoses,
       (select count(*) from regional_alerts where title_fr like 'Jalon C%')                         as jalon_c_alerts_kept,
       coalesce((select string_agg(distinct (storage.foldername(o.name))[1], ', ')
                 from storage.objects o
                 where o.bucket_id = 'diagnoses'
                   and not exists (select 1 from photo_diagnoses d where d.photo_path = o.name)
                   and exists (select 1 from profiles p
                               where p.id::text = (storage.foldername(o.name))[1]
                                 and (p.is_demo or p.demo_account))), '')                          as storage_folders_to_empty;
