-- =========================================================
-- LOOZ — the DEMO VIDEO: the story accounts, community posts and the
-- regional alert (seed, NOT a migration)
--
-- What it does (demo accounts and demo content ONLY, never a real user):
--   1. The story accounts (they must exist: demo login, then demo_admin.sql):
--        +216 22 777 001  paid farmer, live sensors  -> "عادل البقلوطي", Sfax
--        +216 22 999 001  FREE farmer                -> "سلمى الشرفي", Sfax
--        +216 22 123 458  VERIFIED expert             -> "ريم العلوي", Sfax, badge ◆
--      (all three stay demo accounts: demo_account = true; +216 22 123 457 is
--      NOT used: it stays the Kairouan farmer of the live tests)
--   2. The demo community looks recent: the posts and answers of the fake
--      people (community_demo.sql) are moved forward so the newest is
--      3 hours old (nothing moves if they are already recent).
--   3. Two story posts with a photo and an answer of the verified expert:
--        - سلمى (free farmer): leaf curl, in Arabic (photo demo:leaf_curl);
--        - Karim Ben Youssef (fake farmer): shot hole, in French (photo demo:leaf_shot_hole);
--      + one answer of سلمى under an older demo question.
--      The two photos are pictures of the APP (mobile_app/assets/images/,
--      CC0 photos from iNaturalist): restart the app once after adding them.
--   4. ONE active DEMO regional alert "موجة سخانة في صفاقس / Vague de chaleur
--      à Sfax" for 3 days. A demo alert reaches DEMO accounts only
--      (migration 014): real farmers of Sfax never see it.
--   5. ONE demo box WAITING for installation, for the dashboard scene: the box
--      DEMO-D of zone D of the demo orchard of +216 22 123 456 (سليم الحمروني),
--      its installation visit "agriculteur contacté". The demo admin clicks
--      "Accepter l'installation" (the code DEMO-D is already filled in).
--      The 4 live boxes of 22 777 001 (NODE-01…04) are never touched.
-- Run it again any time: it puts the same story back (same ids, fresh
-- times, the alert active again). Every row it adds has an id starting
-- with de000000-0000-4000- (the demo ids of community_demo.sql).
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Needs migrations up to 015 + community_demo.sql + demo_admin.sql.
-- ONE statement (do $$ ... $$) + a check.
-- =========================================================

do $$
declare
  iot      uuid;
  free     uuid;
  expert   uuid;
  admin    uuid;
  karim    constant uuid := 'de000000-0000-4000-8000-000000000007';
  hadi     constant uuid := 'de000000-0000-4000-8000-000000000001';
  newest   timestamptz;
  shift    interval;
  box      uuid;
  box_orch uuid;
begin
  select id into iot    from profiles where phone = '+21622777001';
  select id into free   from profiles where phone = '+21622999001';
  select id into expert from profiles where phone = '+21622123458';
  select p.id into admin from profiles p join auth.users u on u.id = p.id
  where u.email = 'admin-demo@looz-demo.invalid';
  if iot is null or free is null or expert is null then
    raise exception 'A story account is missing (22 777 001, 22 999 001 or 22 123 458): log in once with it in the app (demo login), then run demo_admin.sql, then this file again.';
  end if;
  if admin is null then
    raise exception 'The demo admin is missing: run supabase/seed/demo_admin.sql first.';
  end if;
  if not exists (select 1 from profiles where id = karim and is_demo) then
    raise exception 'The demo community is missing: run supabase/seed/community_demo.sql first.';
  end if;

  -- ---------- 1) The story accounts ----------
  update profiles set first_name = 'عادل', last_name = 'البقلوطي', zone = 'sfax', demo_account = true
  where id = iot;
  update profiles set first_name = 'سلمى', last_name = 'الشرفي', zone = 'sfax', role = 'farmer',
                      demo_account = true
  where id = free;
  update profiles set first_name = 'ريم', last_name = 'العلوي', zone = 'sfax', role = 'expert',
                      verified = true, organisation = 'مهندسة فلاحية', demo_account = true
  where id = expert;

  -- ---------- 2) The demo community looks recent ----------
  select max(p.date) into newest
  from posts p join profiles a on a.id = p.author_id
  where a.is_demo and p.id::text like 'de000000-0000-4000-9000-0000000000%';   -- the 15 posts of community_demo.sql
  shift := (now() - interval '3 hours') - newest;
  if newest is not null and shift > interval '1 hour' then
    update posts p set date = p.date + shift, updated_at = p.updated_at + shift
    from profiles a
    where a.id = p.author_id and a.is_demo and p.id::text like 'de000000-0000-4000-9000-0000000000%';
    update comments c set created_at = c.created_at + shift, updated_at = c.updated_at + shift
    from profiles a
    where a.id = c.author_id and a.is_demo and c.id::text like 'de000000-0000-4000-a000-%';
  end if;

  -- ---------- 3) The story posts (fixed ids: run again = refreshed) ----------
  insert into posts (id, author_id, type, text, photo, hidden, date, updated_at) values
    ('de000000-0000-4000-9000-000000000101', free, 'question',
     'أوراق اللوز عندي تكمّشت وولّات حمراء ومنفوخة بعد المطر. شنوة هذا المرض وشنوة نعمل؟',
     'demo:leaf_curl', false, now() - interval '5 hours', now() - interval '5 hours'),
    ('de000000-0000-4000-9000-000000000102', karim, 'question',
     'Des petits trous sont apparus sur les feuilles de mes amandiers après les pluies. C''est une maladie ?',
     'demo:leaf_shot_hole', false, now() - interval '1 day 2 hours', now() - interval '1 day 2 hours')
  on conflict (id) do update
    set author_id = excluded.author_id, type = excluded.type, text = excluded.text, photo = excluded.photo,
        hidden = false, date = excluded.date, updated_at = excluded.updated_at;

  insert into comments (id, post_id, author_id, text, hidden, created_at, updated_at) values
    ('de000000-0000-4000-a000-000000001011', 'de000000-0000-4000-9000-000000000101', expert,
     'هذا مرض تجعّد الأوراق. يجي مع البرد والمطر في الربيع. نحّي الأوراق المريضة وابعدها على البستان. العلاج يتعمل في آخر الشتاء قبل ما الشجرة تفتّح: اسأل المرشد الفلاحي في منطقتك.',
     false, now() - interval '4 hours', now() - interval '4 hours'),
    ('de000000-0000-4000-a000-000000001012', 'de000000-0000-4000-9000-000000000101', hadi,
     'صارتلي نفس الحكاية العام اللي فات، والشجرة رجعت لاباس في الصيف.',
     false, now() - interval '3 hours 30 minutes', now() - interval '3 hours 30 minutes'),
    ('de000000-0000-4000-a000-000000001013', 'de000000-0000-4000-9000-000000000101', free,
     'يعيشك يا مهندسة، توا نعمل هكا.',
     false, now() - interval '3 hours', now() - interval '3 hours'),
    ('de000000-0000-4000-a000-000000001021', 'de000000-0000-4000-9000-000000000102', expert,
     'Oui, c''est sûrement la criblure, une maladie due à un champignon. Ramassez les feuilles tombées et éloignez-les du verger. Arrosez au pied, pas sur les feuilles. Pour un traitement, demandez conseil au CRDA de votre région.',
     false, now() - interval '1 day', now() - interval '1 day'),
    ('de000000-0000-4000-a000-000000001022', 'de000000-0000-4000-9000-000000000102', karim,
     'Merci beaucoup, je vais faire ça dès demain.',
     false, now() - interval '23 hours', now() - interval '23 hours'),
    ('de000000-0000-4000-a000-000000001031', 'de000000-0000-4000-9000-000000000002', free,
     'أنا نسقي مرة في الجمعة في الخريف خاطر الأرض رملية، ونزيد مرة كي تطلع السخانة.',
     false, now() - interval '6 hours', now() - interval '6 hours')
  on conflict (id) do update
    set post_id = excluded.post_id, author_id = excluded.author_id, text = excluded.text, hidden = false,
        created_at = excluded.created_at, updated_at = excluded.updated_at;

  -- ---------- 4) The DEMO regional alert for Sfax (active for 3 days) ----------
  insert into regional_alerts (id, kind, severity, governorates, title_ar, title_fr, body_ar, body_fr,
                               advice_ar, advice_fr, starts_at, ends_at, ended_at, ended_by,
                               created_by, updated_by, updated_at, is_demo)
  values ('de000000-0000-4000-b000-000000000001', 'heat', 'warning', array['sfax'],
          'موجة سخانة في صفاقس',
          'Vague de chaleur à Sfax',
          'السخانة باش توصل 40 درجة في الأيام الثلاثة الجاية. الشجر الصغير والأرض الرملية يتعبو أكثر.',
          'Il va faire jusqu''à 40 °C pendant les 3 prochains jours. Les jeunes arbres et les sols sableux souffrent le plus.',
          E'اسقي في الصباح بكري ولا في العشية، موش في القايلة.\nشوف الشجر الصغير كل يوم.\nغطّي الأرض حول الساق بالتبن باش تحافظ على الرطوبة.',
          E'Arrosez tôt le matin ou le soir, pas à midi.\nRegardez les jeunes arbres chaque jour.\nCouvrez le sol autour du tronc avec de la paille pour garder l''humidité.',
          now() - interval '1 hour', now() + interval '3 days', null, null,
          admin, admin, now(), true)
  on conflict (id) do update
    set kind = excluded.kind, severity = excluded.severity, governorates = excluded.governorates,
        title_ar = excluded.title_ar, title_fr = excluded.title_fr, body_ar = excluded.body_ar,
        body_fr = excluded.body_fr, advice_ar = excluded.advice_ar, advice_fr = excluded.advice_fr,
        starts_at = excluded.starts_at, ends_at = excluded.ends_at, ended_at = null, ended_by = null,
        updated_by = excluded.updated_by, updated_at = excluded.updated_at, is_demo = true;

  -- ---------- 5) One demo box WAITING for installation (the same lines are in reset_demo_recording.sql) ----------
  select n.id, z.orchard_id into box, box_orch
  from nodes n join zones z on z.id = n.zone_id join orchards o on o.id = z.orchard_id
  join profiles p on p.id = o.farmer_id
  where p.phone = '+21622123456' and p.demo_account and o.is_demo and z.letter = 'D' and z.archived_at is null
  limit 1;
  if box is null then
    raise exception 'The demo orchard of +216 22 123 456 (zone D) is missing: run supabase/seed/orchard_demo.sql, then this file again.';
  end if;
  update nodes set hardware_id = 'DEMO-D', installed_at = null, installed_by = null where id = box;
  update kit_requests set status = 'contacted' where orchard_id = box_orch and status in ('new', 'installed');
end $$;

-- Check: you should see
--   عادل البقلوطي | سلمى الشرفي | sfax | false | ريم العلوي | true | 2 | 6 | true | 0 | DEMO-D waiting | contacted
--   paid farmer | free farmer | her governorate | free farmer has a paid pack (must be false) |
--   expert | expert verified | story posts | story answers | the Sfax demo alert is active | account on
--   the sign-up number +216 22 999 005 (must be 0) | the demo box of the dashboard scene | its visit
select (select name from profiles where phone = '+21622777001')                                 as paid_farmer,
       (select name from profiles where phone = '+21622999001')                                 as free_farmer,
       (select zone from profiles where phone = '+21622999001')                                 as free_governorate,
       (select public.has_paid_pack(id) from profiles where phone = '+21622999001')             as free_has_paid_pack,
       (select name from profiles where phone = '+21622123458')                                 as expert,
       (select verified from profiles where phone = '+21622123458')                             as expert_verified,
       (select count(*) from posts where id in ('de000000-0000-4000-9000-000000000101',
                                                'de000000-0000-4000-9000-000000000102') and not hidden) as story_posts,
       (select count(*) from comments where id::text like 'de000000-0000-4000-a000-00000000102%'
                                         or id::text like 'de000000-0000-4000-a000-00000000101%'
                                         or id::text like 'de000000-0000-4000-a000-00000000103%') as story_answers,
       (select public.regional_alert_is_active(a) from regional_alerts a
        where a.id = 'de000000-0000-4000-b000-000000000001')                                   as sfax_alert_active,
       (select count(*) from auth.users where phone in ('21622999005', '+21622999005'))         as signup_number_accounts,
       (select n.hardware_id || case when n.installed_at is null then ' waiting' else ' ACCEPTED' end
        from nodes n where n.hardware_id = 'DEMO-D')                                            as dashboard_box,
       (select string_agg(distinct k.status, ', ') from kit_requests k
        join nodes n on n.hardware_id = 'DEMO-D' join zones z on z.id = n.zone_id
        where k.orchard_id = z.orchard_id)                                                       as its_visit;
