-- =========================================================
-- LOOZ — the DEMO VIDEO, step 1: LIST what is in the database (READ ONLY:
-- it changes nothing, it deletes nothing)
--
-- One table, one line per thing, sorted by section:
--   1 ACCOUNTS    every account except the admins and the 9 fake people of
--                 the community (one summary line for them)
--   2 COMMUNITY   every post, answer and report NOT written by the fake people
--   3 ALERTS      every regional alert (active or ended, demo or real)
--   4 DIAGNOSES   photo diagnoses, one line per user (how many, what was found)
--   5 VOICE       voice conversations, one line per user
--   6 PAYMENTS    demo payments left without an account (deleted test accounts)
--   7 SIGN-UP     the number of the live sign-up (+216 22 999 005) must have no account;
--                 +216 22 999 002 must never have one
--   8 STORAGE     photo files that belong to no account any more
-- Column "kind":
--   TEST (designer) = +216 22 98x xxx · TEST (Supabase test number) = +216 50 000 00x ·
--   TEST? (odd name) = a name like "test", "user", "aaa" or empty · demo account = the
--   demo numbers + the demo admin · REAL user = everything else: never delete or hide
--   it without the owner's OK. Real users' numbers are shown masked.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run. Copy the result
-- (or "Export > CSV") and give it to Claude.
-- =========================================================

with people as (
  select p.id, p.name, p.phone, p.role, p.zone, p.verified, p.is_demo, p.demo_account, p.created_at,
         u.last_sign_in_at,
         case
           when p.role = 'admin'                                   then 'admin'
           when p.is_demo                                          then 'demo (fake person)'
           when p.demo_account                                     then 'demo account'
           when p.phone like '+2162298%'                           then 'TEST (designer)'
           when p.phone like '+2165000000_'                        then 'TEST (Supabase test number)'
           when p.phone = '+21622999002'                           then 'TEST (must have NO account!)'
           when coalesce(btrim(p.name), '') = ''
             or p.name ~* '(test|essai|dummy|fake|^user|^demo|asdf|azer|qwer)'
             or replace(p.name, ' ', '') ~ '^(.)\1*$'                                -- "aaa", "x x x"
             or p.name ~ 'تجرب'                                     then 'TEST? (odd name)'
           else 'REAL user'
         end as kind
  from profiles p left join auth.users u on u.id = p.id
),
shown as (   -- the phone as the list shows it (real users: masked)
  select pe.*, case when pe.kind = 'REAL user' and pe.phone is not null
                    then left(pe.phone, 4) || ' ** *** ' || right(pe.phone, 3)
                    else coalesce(pe.phone, '') end as phone_shown
  from people pe
),
rows as (
  -- 1 ACCOUNTS
  select '1 ACCOUNTS' as section, s.kind, coalesce(s.name, '(no name)') as who, s.phone_shown as phone,
         s.role || ' · ' || coalesce(s.zone, 'no governorate')
           || case when public.has_paid_pack(s.id) then ' · PAID pack' else ' · free' end
           || case when s.verified then ' · verified expert' else '' end
           || ' · last login ' || coalesce(to_char(s.last_sign_in_at at time zone 'Africa/Tunis', 'YYYY-MM-DD'), 'never')
           as detail,
         s.created_at as at
  from shown s where s.kind not in ('admin', 'demo (fake person)')
  union all
  select '1 ACCOUNTS', 'demo (fake person)', count(*) || ' fake people of the community (community_demo.sql)', '',
         'they cannot log in', max(created_at)
  from shown where kind = 'demo (fake person)'
  union all
  -- 2 COMMUNITY: posts
  select '2 COMMUNITY', s.kind, coalesce(s.name, '(no name)'), s.phone_shown,
         'POST ' || p.type || case when p.hidden then ' (hidden)' else '' end
           || case when p.photo like 'demo:%' then ' · demo photo' when p.photo is not null then ' · photo' else '' end
           || ' · ' || (select count(*) from comments c where c.post_id = p.id) || ' answers · '
           || left(regexp_replace(p.text, '\s+', ' ', 'g'), 90),
         p.date
  from posts p join shown s on s.id = p.author_id where s.kind <> 'demo (fake person)'
  union all
  -- 2 COMMUNITY: answers
  select '2 COMMUNITY', s.kind, coalesce(s.name, '(no name)'), s.phone_shown,
         'ANSWER' || case when c.hidden then ' (hidden)' else '' end || ' under "'
           || left(regexp_replace(p.text, '\s+', ' ', 'g'), 35) || '…": '
           || left(regexp_replace(c.text, '\s+', ' ', 'g'), 80),
         c.created_at
  from comments c join posts p on p.id = c.post_id join shown s on s.id = c.author_id
  where s.kind <> 'demo (fake person)'
  union all
  -- 2 COMMUNITY: reports
  select '2 COMMUNITY', 'REPORT by ' || s.kind, coalesce(s.name, '(no name)'), s.phone_shown,
         'REPORT ' || r.status || ' · ' || r.reason || ' · on '
           || coalesce('post "' || left(p.text, 40) || '…"', 'answer "' || left(c.text, 40) || '…"'),
         r.created_at
  from content_reports r join shown s on s.id = r.reporter_id
  left join posts p on p.id = r.post_id left join comments c on c.id = r.comment_id
  union all
  -- 3 ALERTS
  select '3 ALERTS',
         case when public.regional_alert_is_active(a) then 'ACTIVE' else 'ended' end
           || case when a.is_demo then ' · demo (demo accounts only)' else ' · REAL (all farmers)' end,
         coalesce((select name from profiles where id = a.created_by), '(unknown)'), '',
         a.kind || ' · ' || a.severity || ' · ' || array_to_string(a.governorates, ', ') || ' · ' || a.title_fr
           || ' / ' || a.title_ar,
         a.created_at
  from regional_alerts a
  union all
  -- 4 DIAGNOSES (per user)
  select '4 DIAGNOSES', s.kind, coalesce(s.name, '(no name)'), s.phone_shown,
         count(*) || ' photos (' || count(*) filter (where d.created_at >= now() - interval '1 day') || ' in 24 h) · '
           || coalesce(string_agg(distinct coalesce(d.top_class, d.verdict, d.status), ', '), ''),
         max(d.created_at)
  from photo_diagnoses d join shown s on s.id = d.user_id
  group by s.kind, s.name, s.phone_shown
  union all
  -- 5 VOICE (per user)
  select '5 VOICE', s.kind, coalesce(s.name, '(no name)'), s.phone_shown,
         count(*) || ' conversations · '
           || round(sum(coalesce(v.charged_seconds, v.reserved_seconds)) / 60.0, 1) || ' minutes',
         max(v.started_at)
  from voice_sessions v join shown s on s.id = v.user_id
  group by s.kind, s.name, s.phone_shown
  union all
  -- 6 PAYMENTS without an account
  select '6 PAYMENTS', 'without account', count(*) || ' demo payments', '',
         'their account was deleted · ' || coalesce(sum(amount_millimes) / 1000, 0) || ' DT in all',
         max(created_at)
  from payments where user_id is null
  having count(*) > 0
  union all
  -- 7 SIGN-UP numbers
  select '7 SIGN-UP', case when exists (select 1 from profiles where phone = n.phone)
                           then 'HAS AN ACCOUNT ✗' else 'no account ✓' end,
         n.label, n.phone, '', null
  from (values ('+21622999005', 'live sign-up of the video'),
               ('+21622999002', 'must NEVER have an account')) n(phone, label)
  union all
  -- 8 STORAGE
  select '8 STORAGE', 'files without account', o.bucket_id, '',
         count(*) || ' files (delete them in Storage > ' || o.bucket_id || ')', max(o.created_at)
  from storage.objects o
  where o.bucket_id in ('community', 'diagnoses')
    and not exists (select 1 from profiles p where p.id::text = (storage.foldername(o.name))[1])
  group by o.bucket_id
)
select section, kind, who, phone, detail,
       to_char(at at time zone 'Africa/Tunis', 'YYYY-MM-DD HH24:MI') as at_tunisia
from rows
order by section,
         case when kind like 'TEST%' then 0 when kind like 'REAL%' or kind like 'REPORT by REAL%' then 1 else 2 end,
         at desc nulls last;
