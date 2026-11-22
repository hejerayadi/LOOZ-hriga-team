-- =========================================================
-- LOOZ — the DEMO VIDEO: put the demo back to its STARTING state before a
-- take (seed, NOT a migration). Run demo_recording_setup.sql once before.
--
-- What it does (demo accounts ONLY, never a real user):
--   1. Deletes the account of the live sign-up number +216 22 999 005
--      (like reset_signup.sql).
--   2. Today's PHOTO diagnoses and VOICE conversations of the demo accounts
--      are moved to yesterday: the daily limits are full again (the rows
--      stay: the admin dashboard still shows them, dated yesterday).
--   3. Deletes the in-app notifications of the demo accounts (the ML
--      predictions that are still a problem come back as NEW notifications
--      at the next round of the ML worker, within a minute: that is the live
--      part of the video).
--   4. What the story accounts did during the rehearsal (after the setup):
--      their new posts, answers and reports are deleted. The story posts of
--      the setup stay. A new post with a photo in Storage is NOT deleted
--      (Supabase does not let SQL delete files): the check counts it,
--      delete it in the app (⋮ > حذف).
--   5. Regional alerts: the demo alerts made during the rehearsal (e.g. with
--      "Connexion démo") are deleted; the Sfax demo alert of the setup is
--      active again and NEW again ("جديد", no "تمّ", no "أنا أيضًا") for the
--      demo accounts.
--   6. The demo box DEMO-D (zone D, demo orchard of +216 22 123 456) is
--      WAITING for installation again, its visit "agriculteur contacté"
--      (after "Accepter l'installation" in the dashboard scene).
-- Step 1 deletes EVERYTHING the sign-up made in scene 3 (upgrade, orchard,
-- zones, boxes, trees, pack, installation visit, payments, notifications):
-- all of it hangs on the account (checked on the laptop).
--
-- What it does NOT reset: see the end of this file.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- ONE statement (do $$ ... $$) + a check. Safe to run again.
-- =========================================================

do $$
declare
  signup      constant text := '+21622999005';
  story_alert constant uuid := 'de000000-0000-4000-b000-000000000001';
  uid         uuid;
  demo        uuid[];
  story       uuid[];
  since       timestamptz;
  day0        timestamptz := date_trunc('day', now() at time zone 'Africa/Tunis') at time zone 'Africa/Tunis';
  box         uuid;
  box_orch    uuid;
begin
  select created_at into since from regional_alerts where id = story_alert;
  if since is null then
    raise exception 'Run supabase/seed/demo_recording_setup.sql first (the story is not there).';
  end if;

  -- 1. The live sign-up account
  select id into uid from auth.users where phone in (signup, substr(signup, 2));
  if uid is null then
    select id into uid from profiles where phone = signup;
  end if;
  if uid is not null then
    if exists (select 1 from profiles where id = uid and (role = 'admin' or is_demo or demo_account)) then
      raise exception 'Refused: % is an admin or a demo account. Change the sign-up number.', signup;
    end if;
    delete from payments where user_id = uid;
    delete from auth.users where id = uid;
  end if;

  select coalesce(array_agg(id), '{}') into demo from profiles where is_demo or demo_account;
  select coalesce(array_agg(id), '{}') into story from profiles
  where phone in ('+21622777001', '+21622999001', '+21622123458') and demo_account;

  -- 2. Today's photos and voice of the demo accounts -> yesterday
  update photo_diagnoses
  set created_at = created_at - interval '1 day', finished_at = finished_at - interval '1 day'
  where user_id = any (demo) and created_at >= day0;
  update voice_sessions
  set started_at = started_at - interval '1 day', expires_at = expires_at - interval '1 day',
      ended_at = ended_at - interval '1 day'
  where user_id = any (demo) and started_at >= day0;

  -- 3. In-app notifications of the demo accounts
  delete from ml_notifications where farmer_id = any (demo);

  -- 4. What the story accounts did during the rehearsal
  delete from content_reports where reporter_id = any (story) and created_at > since;
  delete from comments
  where author_id = any (story) and created_at > since and id::text not like 'de000000-0000-4000-%';
  delete from posts
  where author_id = any (story) and date > since and id::text not like 'de000000-0000-4000-%'
    and (photo is null or photo like 'demo:%');

  -- 5. Regional alerts of the demo
  delete from regional_alerts where is_demo and created_at > since and id <> story_alert;
  update regional_alerts
  set starts_at = now() - interval '1 hour', ends_at = now() + interval '3 days',
      ended_at = null, ended_by = null, updated_at = now()
  where id = story_alert;
  delete from regional_alert_reads
  where user_id = any (demo) and alert_id in (select id from regional_alerts where is_demo);
  delete from regional_alert_reports
  where user_id = any (demo) and alert_id in (select id from regional_alerts where is_demo);

  -- 6. The demo box of the dashboard scene: waiting again (same lines as demo_recording_setup.sql)
  select n.id, z.orchard_id into box, box_orch
  from nodes n join zones z on z.id = n.zone_id join orchards o on o.id = z.orchard_id
  join profiles p on p.id = o.farmer_id
  where p.phone = '+21622123456' and p.demo_account and o.is_demo and z.letter = 'D' and z.archived_at is null
  limit 1;
  if box is not null then
    update nodes set hardware_id = 'DEMO-D', installed_at = null, installed_by = null where id = box;
    update kit_requests set status = 'contacted' where orchard_id = box_orch and status in ('new', 'installed');
  end if;
end $$;

-- Check: you should see  0 | 0 | 0 | 0 | 1 | true | 0 | DEMO-D waiting
--   sign-up account | photos of the demo accounts today | voice seconds of the demo accounts today |
--   in-app notifications of the demo accounts (may be 1-2 a minute later: live problems come back) |
--   active demo alerts | the Sfax demo alert is active | rehearsal posts with a photo left (delete in the app) |
--   the demo box of the dashboard scene
select (select count(*) from auth.users where phone in ('21622999005', '+21622999005'))           as signup_account,
       (select coalesce(sum(public.diagnosis_count_today(id)), 0) from profiles
        where is_demo or demo_account)                                                            as demo_photos_today,
       (select coalesce(sum(public.voice_seconds_today(id)), 0) from profiles
        where is_demo or demo_account)                                                            as demo_voice_seconds_today,
       (select count(*) from ml_notifications n join profiles p on p.id = n.farmer_id
        where p.is_demo or p.demo_account)                                                        as demo_notifications,
       (select count(*) from regional_alerts a where a.is_demo and public.regional_alert_is_active(a)) as active_demo_alerts,
       (select public.regional_alert_is_active(a) from regional_alerts a
        where a.id = 'de000000-0000-4000-b000-000000000001')                                     as sfax_alert_active,
       (select count(*) from posts p join profiles a on a.id = p.author_id
        where a.demo_account and a.phone in ('+21622777001', '+21622999001', '+21622123458')
          and p.id::text not like 'de000000-0000-4000-%'
          and p.date > (select created_at from regional_alerts where id = 'de000000-0000-4000-b000-000000000001')
          and p.photo is not null and p.photo not like 'demo:%')                                 as rehearsal_posts_with_photo,
       (select n.hardware_id || case when n.installed_at is null then ' waiting' else ' ACCEPTED' end
        from nodes n where n.hardware_id = 'DEMO-D')                                            as dashboard_box;

-- What this file does NOT reset:
--   - Node-RED's simulated clock: after the frost-night scenario it stays in February (it only goes
--     forward). To start from 15 June again: stop Node-RED, delete iot/node-red/context, start it.
--   - The ML predictions themselves (ml_latest, ml_history): they follow Node-RED.
--   - The daily limits of Google and Groq (not in the database): Gemini photos (free tier 20 a day
--     per Google project, 5 a minute), Gemini Live, Groq (1,000 texts a day per model).
--   - The voice consent of a demo account ("أوافق" is asked only once).
--   - The app on the phone / in Chrome: the language chosen, the login, the screen it was on.
--   - The admin action log (it can't be changed: lines of the rehearsal stay, marked "démo").
--   - Old photo diagnoses and voice conversations (only today's are moved to yesterday).
--   - Posts of the demo community hidden or deleted during the rehearsal: run
--     demo_recording_setup.sql again (it puts the story posts back) or "Afficher de nouveau".
--   - A badge or a name of a story account changed during the rehearsal: run
--     demo_recording_setup.sql again.
