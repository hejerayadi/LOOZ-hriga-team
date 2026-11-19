-- =========================================================
-- LOOZ — Migration 017: the voice assistant "لوز" (Gemini Live) for the paid pack
--
-- A paid farmer taps "تكلّم". The app asks the Edge Function "voice-token",
-- which (with the service_role key):
--   1. voice_begin(user): checks the switch, the paid pack, the farmer's
--      "yes" to the voice message (consent) and the minutes left today
--      (his own and the whole app's), and opens a conversation with its
--      length (3 minutes at most);
--   2. asks Google for a short-lived, single-use token LOCKED to the model,
--      the instructions of "لوز" and its tools, valid only for that length;
--   3. gives the token to the app. The app talks DIRECTLY to Google
--      (the voice never goes through LOOZ).
-- At the end, the app calls voice_end(): the time is measured by the
-- DATABASE clock (start -> end), never by the app.
--
-- Nothing of the voice or of the words is saved: only how long, how many
-- questions and how many tool calls (to see the use and the cost).
--
-- What this file adds:
--   1. Settings (admin): on / off, the model, the voice, minutes per farmer
--      per day (5), minutes per day for the whole app (60: protects the
--      Gemini money), longest conversation (180 seconds), and "Google free
--      tier" (true: the first-time message says Google may use the voice to
--      improve its products; set it to false after switching to the paid
--      tier, PROJECT_STATUS.md "before launch").
--   2. Table voice_consents: the farmer said "yes" to "your voice goes to
--      Google" (asked once, can be taken back).
--   3. Table voice_sessions: one row per conversation (times and counts).
--   4. voice_begin / voice_begin_failed (service_role only),
--      my_voice_quota(), voice_set_consent(), voice_end() for the app.
--   5. The rules (RLS) and the rights.
--   6. Last check.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 016. Safe to run again.
-- (If you run 014 again after this file, its 2nd number is 30, not 28: the
--  2 reading rules of this file use admin_sees_all() too.)
-- =========================================================


-- ---------- 1) Settings (admin) ----------
alter table app_settings add column if not exists voice_enabled            boolean not null default true;
alter table app_settings add column if not exists voice_model              text    not null default 'gemini-3.8-live';
alter table app_settings add column if not exists voice_speaker            text    not null default 'Kore';
alter table app_settings add column if not exists voice_minutes_per_day    integer not null default 5;
alter table app_settings add column if not exists voice_app_minutes_per_day integer not null default 60;
alter table app_settings add column if not exists voice_session_seconds    integer not null default 180;
alter table app_settings add column if not exists voice_google_free_tier   boolean not null default true;
alter table app_settings drop constraint if exists app_settings_voice_check;
alter table app_settings add constraint app_settings_voice_check check (
  voice_model ~ '^[a-z0-9][a-z0-9.-]{1,60}$'
  and voice_speaker ~ '^[A-Z][a-z]{2,20}$'
  and voice_minutes_per_day between 1 and 60
  and voice_app_minutes_per_day between 1 and 100000
  and voice_session_seconds between 60 and 540);
comment on column app_settings.voice_enabled is 'false = the voice assistant is off (the app says so).';
comment on column app_settings.voice_model is 'The Gemini Live model, e.g. gemini-3.8-live (no "models/").';
comment on column app_settings.voice_speaker is 'The Gemini voice of "لوز", e.g. Kore, Puck, Charon (listen in Google AI Studio).';
comment on column app_settings.voice_minutes_per_day is 'Minutes one farmer may talk per day (Tunisia time).';
comment on column app_settings.voice_app_minutes_per_day is 'Minutes the whole app may talk per day: protects the Gemini money.';
comment on column app_settings.voice_session_seconds is 'Longest conversation (seconds, 60 to 540: a Google connection lasts about 10 minutes).';
comment on column app_settings.voice_google_free_tier is
  'true = the Gemini API key is on Google''s FREE tier (Google may use the voice to improve its products): the app says so in the first-time message. Set false after switching to the paid tier.';


-- ---------- 2) The consent ("your voice goes to Google") ----------
create table if not exists voice_consents (
  user_id      uuid primary key references profiles(id) on delete cascade,
  accepted_at  timestamptz not null default now()
);
comment on table voice_consents is
  'The farmer said yes to "your voice is sent to Google, LOOZ records nothing" (asked once). No row = not asked yet or taken back.';


-- ---------- 3) The conversations (no voice, no words) ----------
create or replace function public.voice_end_reasons() returns text[]
language sql immutable as $$
  -- farmer: the stop button or the screen closed / time_up: the length was reached /
  -- error: the connection broke / replaced: a new conversation started /
  -- lost: never ended (app closed), found later / token_error: Google gave no token.
  select array['farmer', 'time_up', 'error', 'replaced', 'lost', 'token_error'];
$$;

create table if not exists voice_sessions (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references profiles(id) on delete cascade,
  model             text not null check (model ~ '^[a-z0-9][a-z0-9.-]{1,60}$'),
  started_at        timestamptz not null default now(),
  reserved_seconds  integer not null check (reserved_seconds between 1 and 540),
  expires_at        timestamptz not null,
  ended_at          timestamptz,
  charged_seconds   integer check (charged_seconds is null or charged_seconds between 0 and 540),
  end_reason        text check (end_reason is null or end_reason = any (public.voice_end_reasons())),
  questions         integer not null default 0 check (questions between 0 and 500),
  tool_calls        integer not null default 0 check (tool_calls between 0 and 500),
  community_posts   integer not null default 0 check (community_posts between 0 and 20),
  tokens_in         integer check (tokens_in is null or tokens_in between 0 and 100000000),
  tokens_out        integer check (tokens_out is null or tokens_out between 0 and 100000000),
  constraint voice_sessions_state check (
    (ended_at is null and charged_seconds is null and end_reason is null)
    or (ended_at is not null and charged_seconds is not null and end_reason is not null))
);
create index if not exists voice_sessions_user_idx on voice_sessions (user_id, started_at desc);
create index if not exists voice_sessions_day_idx on voice_sessions (started_at);
comment on table voice_sessions is
  'One row per voice conversation: times and counts only (no voice, no words). Opened by the Edge Function "voice-token", ended by the app (voice_end).';
comment on column voice_sessions.charged_seconds is
  'Seconds counted for the limits: database clock start -> end, at least 20, at most reserved_seconds. While open: reserved_seconds counts.';
comment on column voice_sessions.tokens_in is 'Tokens Google counted (usageMetadata, told by the app): to check the real cost.';

-- Seconds of the day (Tunisia time) of one farmer, or of the whole app (null):
-- ended conversations count their measured time, open ones their full length.
create or replace function public.voice_seconds_today(p_user uuid default null) returns integer
language sql stable security definer set search_path = public as $$
  select coalesce(sum(coalesce(charged_seconds, reserved_seconds)), 0)::integer from voice_sessions
  where started_at >= (date_trunc('day', now() at time zone 'Africa/Tunis') at time zone 'Africa/Tunis')
    and (p_user is null or user_id = p_user);
$$;

-- The time counted for a conversation that ends now: the database clock,
-- at least 20 seconds (a hacked app can't open many 1-second conversations),
-- at most its length.
create or replace function public.voice_charge(s voice_sessions) returns integer
language sql stable as $$
  select least(s.reserved_seconds,
               greatest(20, ceil(extract(epoch from least(now(), s.expires_at) - s.started_at))::integer));
$$;


-- ---------- 4) The functions ----------
-- The Edge Function "voice-token", BEFORE asking Google for a token.
-- Returns {"id", "model", "speaker", "seconds" (length of this conversation),
--          "expires_at", "language", "governorate", "per_day_seconds", "left_seconds"}.
-- Errors: P0002 unknown user, PT403 no paid pack, PT412 no consent yet,
-- PT503 off / app limit of the day, PT429 the farmer's limit of the day.
create or replace function public.voice_begin(p_user uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  s        app_settings;
  p        profiles;
  v        voice_sessions;
  mine     integer;
  app      integer;
  seconds  integer;
begin
  select * into s from app_settings where id;
  select * into p from profiles where id = p_user;
  if p.id is null then
    raise exception 'Unknown user' using errcode = 'P0002';
  end if;
  if not s.voice_enabled then
    raise exception 'The voice assistant is off' using errcode = 'PT503';
  end if;
  if not public.has_paid_pack(p_user) then
    raise exception 'Paid pack only' using errcode = 'PT403';
  end if;
  if not exists (select 1 from voice_consents where user_id = p_user) then
    raise exception 'Consent needed' using errcode = 'PT412';
  end if;

  -- One start at a time for the whole app: two farmers starting together
  -- can't pass the app limit, one farmer can't pass his own.
  perform pg_advisory_xact_lock(hashtext('voice_begin'));

  -- The farmer's conversations still open: past their end = 'lost' (full
  -- length counted); still running = 'replaced' (measured time counted).
  update voice_sessions x set
    ended_at        = least(now(), x.expires_at),
    charged_seconds = case when x.expires_at <= now() then x.reserved_seconds else public.voice_charge(x) end,
    end_reason      = case when x.expires_at <= now() then 'lost' else 'replaced' end
  where x.user_id = p_user and x.ended_at is null;

  mine := s.voice_minutes_per_day * 60 - public.voice_seconds_today(p_user);
  if mine < 30 then
    raise exception 'No minutes left today' using errcode = 'PT429';
  end if;
  app := s.voice_app_minutes_per_day * 60 - public.voice_seconds_today(null);
  if app < 30 then
    raise exception 'App limit of the day reached' using errcode = 'PT503';
  end if;
  seconds := least(s.voice_session_seconds, mine, app);

  -- +15 s: time to open the connection (the token itself stops at expires_at).
  insert into voice_sessions (user_id, model, reserved_seconds, expires_at)
  values (p_user, s.voice_model, seconds, now() + make_interval(secs => seconds + 15))
  returning * into v;

  return jsonb_build_object(
    'id', v.id, 'model', v.model, 'speaker', s.voice_speaker, 'seconds', seconds,
    'expires_at', v.expires_at, 'language', coalesce(p.language, 'ar'), 'governorate', p.zone,
    'per_day_seconds', s.voice_minutes_per_day * 60, 'left_seconds', mine - seconds);
end;
$$;

-- The Edge Function, when Google gave NO token: nothing is counted.
create or replace function public.voice_begin_failed(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update voice_sessions set ended_at = now(), charged_seconds = 0, end_reason = 'token_error'
  where id = p_id and ended_at is null;
  if not found then
    raise exception 'Unknown or finished conversation' using errcode = 'P0002';
  end if;
end;
$$;

-- The app, at the end of a conversation (stop, time up, connection lost).
-- The counts are only for the statistics; the time is the database clock.
-- Returns {"charged_seconds", "used_seconds", "left_seconds"}.
create or replace function public.voice_end(p_id uuid, p_reason text, p_questions integer default 0,
                                            p_tool_calls integer default 0, p_posts integer default 0,
                                            p_tokens_in integer default null, p_tokens_out integer default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v     voice_sessions;
  s     app_settings;
  used  integer;
begin
  if auth.uid() is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  if p_reason is null or p_reason not in ('farmer', 'time_up', 'error') then
    raise exception 'Reason: farmer, time_up or error' using errcode = '22023';
  end if;
  select * into v from voice_sessions where id = p_id and user_id = auth.uid() for update;
  if v.id is null then
    raise exception 'Not your conversation' using errcode = 'P0002';
  end if;
  if v.ended_at is null then
    update voice_sessions set
      ended_at        = least(now(), expires_at),
      charged_seconds = public.voice_charge(v),
      end_reason      = p_reason,
      questions       = least(greatest(coalesce(p_questions, 0), 0), 500),
      tool_calls      = least(greatest(coalesce(p_tool_calls, 0), 0), 500),
      community_posts = least(greatest(coalesce(p_posts, 0), 0), 20),
      tokens_in       = least(greatest(p_tokens_in, 0), 100000000),
      tokens_out      = least(greatest(p_tokens_out, 0), 100000000)
    where id = p_id returning * into v;
  end if;
  -- Already ended (twice, or 'replaced' / 'lost'): nothing changes, the
  -- answer is the same.
  select * into s from app_settings where id;
  used := public.voice_seconds_today(auth.uid());
  return jsonb_build_object('charged_seconds', v.charged_seconds, 'used_seconds', used,
                            'left_seconds', greatest(s.voice_minutes_per_day * 60 - used, 0));
end;
$$;

-- The app, before the microphone: is it on, does he pay, did he say yes,
-- how many seconds are left today, is the whole app still open today?
create or replace function public.my_voice_quota() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'enabled', s.voice_enabled,
    'paid', public.has_paid_pack(auth.uid()),
    'consent', exists (select 1 from voice_consents where user_id = auth.uid()),
    'per_day_seconds', s.voice_minutes_per_day * 60,
    'used_seconds', public.voice_seconds_today(auth.uid()),
    'left_seconds', greatest(s.voice_minutes_per_day * 60 - public.voice_seconds_today(auth.uid()), 0),
    'session_seconds', s.voice_session_seconds,
    'app_open', s.voice_app_minutes_per_day * 60 - public.voice_seconds_today(null) >= 30,
    'google_free_tier', s.voice_google_free_tier)
  from app_settings s where s.id and auth.uid() is not null;
$$;

-- The app: "موافق" (true) on the first-time message, or take it back (false).
create or replace function public.voice_set_consent(p_on boolean) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  if p_on then
    insert into voice_consents (user_id) values (auth.uid())
    on conflict (user_id) do update set accepted_at = now();
  else
    delete from voice_consents where user_id = auth.uid();
  end if;
  return coalesce(p_on, false);
end;
$$;


-- ---------- 5) The rules (RLS) and the rights ----------
alter table voice_sessions enable row level security;
drop policy if exists "Farmers see their own conversations" on voice_sessions;
create policy "Farmers see their own conversations" on voice_sessions for select to authenticated
  using (user_id = (select auth.uid()) or (select public.admin_sees_all())
         or ((select public.is_demo_admin()) and user_id = any ((select public.demo_person_ids())::uuid[])));

alter table voice_consents enable row level security;
drop policy if exists "Farmers see their own consent" on voice_consents;
create policy "Farmers see their own consent" on voice_consents for select to authenticated
  using (user_id = (select auth.uid()) or (select public.admin_sees_all())
         or ((select public.is_demo_admin()) and user_id = any ((select public.demo_person_ids())::uuid[])));

revoke all on voice_sessions, voice_consents from anon, authenticated;
grant select on voice_sessions, voice_consents to authenticated;
grant all on voice_sessions, voice_consents to service_role;

revoke all on function public.voice_end_reasons()                   from public, anon;
revoke all on function public.voice_seconds_today(uuid)             from public, anon, authenticated;
revoke all on function public.voice_charge(voice_sessions)          from public, anon, authenticated;
revoke all on function public.voice_begin(uuid)                     from public, anon, authenticated;
revoke all on function public.voice_begin_failed(uuid)              from public, anon, authenticated;
revoke all on function public.voice_end(uuid, text, integer, integer, integer, integer, integer) from public, anon;
revoke all on function public.my_voice_quota()                      from public, anon;
revoke all on function public.voice_set_consent(boolean)            from public, anon;
grant execute on function public.voice_end_reasons(), public.my_voice_quota(), public.voice_set_consent(boolean),
  public.voice_end(uuid, text, integer, integer, integer, integer, integer) to authenticated, service_role;
grant execute on function public.voice_seconds_today(uuid), public.voice_charge(voice_sessions),
  public.voice_begin(uuid), public.voice_begin_failed(uuid) to service_role;


-- ---------- 6) Last check: you should see  true | false | false | 5 | 60 | 180 | gemini-3.8-live ----------
--   rules_on        true  = the 2 tables have their rules (RLS)
--   app_can_write   false = the app writes no conversation and no consent by itself
--   app_can_begin   false = the app can't open a conversation (only the Edge Function)
--   then the settings: minutes per farmer per day, minutes per day for the app,
--   longest conversation (seconds), the model
select
  (select bool_and(relrowsecurity) from pg_class
   where oid in ('public.voice_sessions'::regclass, 'public.voice_consents'::regclass))             as rules_on,
  has_table_privilege('authenticated', 'public.voice_sessions', 'insert')
    or has_table_privilege('authenticated', 'public.voice_sessions', 'update')
    or has_table_privilege('authenticated', 'public.voice_consents', 'insert')                     as app_can_write,
  has_function_privilege('authenticated', 'public.voice_begin(uuid)', 'execute')                    as app_can_begin,
  s.voice_minutes_per_day, s.voice_app_minutes_per_day, s.voice_session_seconds, s.voice_model
from app_settings s where s.id;
