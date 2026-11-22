-- =========================================================
-- LOOZ — the DEMO VIDEO: what is LEFT TODAY of the daily limits (READ ONLY)
--
-- Photo diagnosis and voice assistant are for PAID farmers only, so the
-- rows are the demo accounts with a running paid pack, plus one row for
-- the WHOLE APP (its limit counts every user, real ones too).
-- "Today" = Tunisia time (the counters start again at midnight).
-- The limits of Google / Groq themselves are not in the database.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run. Changes nothing.
-- =========================================================

with s as (select * from app_settings where id),
who as (
  select p.name || ' (' || p.phone || ')' as who, 1 as ord,
         public.diagnosis_count_today(p.id) as photos_used, (select diagnosis_per_day from s) as photos_limit,
         public.voice_seconds_today(p.id) as voice_used, (select voice_minutes_per_day from s) * 60 as voice_limit
  from profiles p
  where (p.is_demo or p.demo_account) and p.role = 'farmer' and public.has_paid_pack(p.id)
  union all
  select 'WHOLE APP (everyone)', 2,
         public.diagnosis_count_today(null), (select diagnosis_app_per_day from s),
         public.voice_seconds_today(null), (select voice_app_minutes_per_day from s) * 60
)
select who,
       photos_used                                   as photos_today,
       photos_limit                                  as photos_per_day,
       greatest(photos_limit - photos_used, 0)       as photos_left,
       round(voice_used / 60.0, 1)                   as voice_minutes_today,
       voice_limit / 60                              as voice_minutes_per_day,
       round(greatest(voice_limit - voice_used, 0) / 60.0, 1) as voice_minutes_left,
       (select voice_session_seconds from s)         as longest_conversation_seconds
from who
order by ord, who;
