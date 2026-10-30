-- =========================================================
-- LOOZ — Migration 005: sign up / sign in with the PHONE NUMBER
--
-- What it does:
--   1. adds first name, last name, chosen pack, payment status to "profiles"
--   2. checks the data in the database too (phone format, names, ...)
--   3. keeps the old "name" column filled (the admin dashboard uses it)
--   4. stops users from changing protected fields (phone, pack, payment...)
--   5. "choose_plan": the ONLY way for a user to save the pack he chose
--   6. when an admin marks a payment "paid", the user gets the pack's plan
--   7. copies the phone number of the login account into the profile
--   8. each user can only READ and UPDATE his own profile
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 004. Safe to run again.
-- ⚠ If you ever re-run looz_policies.sql, run THIS file again afterwards:
--   it recreates the old "everyone sees all profiles" rule and the old
--   "create a profile" function.
-- =========================================================

-- All or nothing: if one line fails, nothing is changed.
begin;


-- ---------- 1) New columns ----------
-- first_name / last_name : asked after the code (both required in the app).
-- chosen_plan            : the pack chosen at sign-up ('free', 'essential', 'connected').
-- payment_status         : 'free' (free pack), 'pending' (paid pack, not paid yet),
--                          'paid' (set ONLY by an admin or, later, the payment server).
-- plan_chosen_at         : when the pack was chosen (empty = sign-up not finished).
-- updated_at             : last change of the profile.
-- (phone, language and created_at already exist.)
alter table profiles add column if not exists first_name     text;
alter table profiles add column if not exists last_name      text;
alter table profiles add column if not exists chosen_plan    text not null default 'free';
alter table profiles add column if not exists payment_status text not null default 'free';
alter table profiles add column if not exists plan_chosen_at timestamptz;
alter table profiles add column if not exists updated_at     timestamptz not null default now();


-- ---------- 2) Checks: the database refuses wrong data ----------
-- Phone: Tunisian number in international format, "+216" then 8 digits.
-- Supabase saves the login phone WITHOUT the "+": old rows get it added.
update profiles set phone = '+' || phone where phone ~ '^[0-9]+$';

alter table profiles drop constraint if exists profiles_phone_format;
alter table profiles add constraint profiles_phone_format
  check (phone is null or phone ~ '^\+216[0-9]{8}$') not valid;  -- "not valid": old rows are not checked

-- One profile per phone number.
create unique index if not exists profiles_phone_unique on profiles (phone) where phone is not null;

-- Names: 1 to 50 characters, no digits, no symbols, no line breaks.
-- (Letters of any language, spaces, apostrophes and hyphens are fine.)
alter table profiles drop constraint if exists profiles_first_name_check;
alter table profiles add constraint profiles_first_name_check check (
  first_name is null or (
    char_length(btrim(first_name)) between 1 and 50
    and first_name !~ '[0-9<>{}()@#$%^&*_+=|/;:"!?~\\\[\]]'
    and first_name !~ '[[:cntrl:]]'));

alter table profiles drop constraint if exists profiles_last_name_check;
alter table profiles add constraint profiles_last_name_check check (
  last_name is null or (
    char_length(btrim(last_name)) between 1 and 50
    and last_name !~ '[0-9<>{}()@#$%^&*_+=|/;:"!?~\\\[\]]'
    and last_name !~ '[[:cntrl:]]'));

alter table profiles drop constraint if exists profiles_language_check;
alter table profiles add constraint profiles_language_check
  check (language in ('ar', 'fr')) not valid;

alter table profiles drop constraint if exists profiles_chosen_plan_check;
alter table profiles add constraint profiles_chosen_plan_check
  check (chosen_plan in ('free', 'essential', 'connected'));

alter table profiles drop constraint if exists profiles_payment_status_check;
alter table profiles add constraint profiles_payment_status_check
  check (payment_status in ('free', 'pending', 'paid'));


-- ---------- 3) Keep "name" = first name + last name ----------
-- The admin dashboard shows "name": it is now filled automatically.
create or replace function public.profiles_fill_name() returns trigger
language plpgsql set search_path = public as $$
begin
  new.first_name := nullif(btrim(new.first_name), '');
  new.last_name  := nullif(btrim(new.last_name), '');
  if new.first_name is not null or new.last_name is not null then
    new.name := btrim(coalesce(new.first_name, '') || ' ' || coalesce(new.last_name, ''));
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_fill_name on profiles;
create trigger profiles_fill_name
  before insert or update on profiles
  for each row execute function public.profiles_fill_name();


-- ---------- 4) Protected fields ----------
-- A user may change his first name, last name and language, nothing else.
-- Admins, the database itself and the server (service_role, for the real
-- payment later) may change everything.
create or replace function public.profiles_protect_columns() returns trigger
language plpgsql set search_path = public as $$
begin
  if current_user = 'authenticated' and not public.is_admin() then
    if new.id             is distinct from old.id
    or new.phone          is distinct from old.phone
    or new.role           is distinct from old.role
    or new.verified       is distinct from old.verified
    or new.chosen_plan    is distinct from old.chosen_plan
    or new.payment_status is distinct from old.payment_status
    or new.plan_chosen_at is distinct from old.plan_chosen_at
    or new.created_at     is distinct from old.created_at then
      raise exception 'This field cannot be changed from the app' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_columns on profiles;
create trigger profiles_protect_columns
  before update on profiles
  for each row execute function public.profiles_protect_columns();


-- ---------- 5) choose_plan: the user saves the pack he chose ----------
-- Free pack            -> payment_status 'free'.
-- Paid pack            -> 'pending' ("pay now" and "pay later" for now:
--                         no real payment yet). The plan itself does NOT
--                         change: it stays 'free' until the payment is done.
-- Same pack, already paid -> stays 'paid'.
create or replace function public.choose_plan(p_plan text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  if p_plan is null or p_plan not in ('free', 'essential', 'connected') then
    raise exception 'Unknown plan' using errcode = '22023';
  end if;
  update profiles set
    payment_status = case
      when p_plan = 'free' then 'free'
      when payment_status = 'paid' and chosen_plan = p_plan then 'paid'
      else 'pending' end,
    chosen_plan    = p_plan,
    plan_chosen_at = now()
  where id = auth.uid();
end;
$$;

revoke execute on function public.choose_plan(text) from public, anon;
grant execute on function public.choose_plan(text) to authenticated;


-- ---------- 6) Payment done -> the user gets the plan ----------
-- When an admin (Table Editor / dashboard) or, later, the payment server sets
-- payment_status = 'paid', the subscription gets the chosen plan.
create or replace function public.apply_paid_plan() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.payment_status = 'paid' and old.payment_status is distinct from 'paid'
     and new.chosen_plan <> 'free' then
    insert into subscriptions (user_id, plan, status, started_at)
    values (new.id, new.chosen_plan, 'active', now())
    on conflict (user_id) do update
      set plan = excluded.plan, status = 'active', started_at = now(), ends_at = null;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_apply_paid_plan on profiles;
create trigger profiles_apply_paid_plan
  after update of payment_status on profiles
  for each row execute function public.apply_paid_plan();


-- ---------- 7) Phone number from the login account ----------
-- Supabase creates the login account (auth.users) when the code is asked.
-- This creates the profile at the same time: phone with "+", language chosen
-- on the first screen, role 'farmer'. (Admins still log in with an e-mail on
-- the dashboard: their phone stays empty.)
create or replace function public.normalize_phone(p text) returns text
language sql immutable as $$
  select case when p is null or btrim(p) = '' then null
              when left(p, 1) = '+' then p
              else '+' || p end;
$$;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, role, name, phone, language)
  values (
    new.id,
    case when new.raw_user_meta_data->>'role' = 'expert' then 'expert' else 'farmer' end,
    coalesce(nullif(btrim(new.raw_user_meta_data->>'name'), ''), 'New user'),
    public.normalize_phone(new.phone),
    case when new.raw_user_meta_data->>'language' = 'fr' then 'fr' else 'ar' end
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- If the login phone ever changes, the profile follows.
create or replace function public.handle_user_phone_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update profiles set phone = public.normalize_phone(new.phone) where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_phone_changed on auth.users;
create trigger on_auth_user_phone_changed
  after update of phone on auth.users
  for each row when (old.phone is distinct from new.phone)
  execute function public.handle_user_phone_change();


-- ---------- 8) Read and update: only your own profile ----------
-- Before: every logged-in user could read ALL profiles (with phone numbers).
-- Now: a user reads only his own. Admins still see everyone (rule
-- "Admins manage all profiles" from looz_policies.sql is unchanged).
drop policy if exists "Logged-in users can see profiles" on profiles;
drop policy if exists "Users see their own profile" on profiles;
create policy "Users see their own profile"
  on profiles for select to authenticated using (id = auth.uid());

-- (Same as before: a user updates only his own row. The trigger of part 4
-- decides which fields he may change.)
drop policy if exists "Users edit their own profile" on profiles;
create policy "Users edit their own profile"
  on profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and role = my_role() and verified = my_verified());

alter table profiles enable row level security;


commit;
