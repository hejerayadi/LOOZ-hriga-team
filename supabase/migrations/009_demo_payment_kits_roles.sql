-- =========================================================
-- LOOZ — Migration 009: DEMO payment, LOOZ kit requests, price per sensor,
-- farmer or expert
--
-- What it does:
--   1. app_settings: one row of settings. demo_payments_enabled = true
--      allows the demo payment; only admins change it (Table Editor >
--      app_settings > false = demo payments off, at once).
--   2. plan_prices: Connected is now a price PER SENSOR (8 DT per sensor
--      for 30 days); Essential stays 15 DT for 30 days.
--   3. payments: two more statuses, 'paid_demo' and 'failed_demo', and the
--      number of sensors paid (Connected).
--   4. kit_requests: the farmer asks for the LOOZ sensor kit (Connected).
--      The request copies his governorate, trees, area and phone from his
--      profile. An admin calls him, installs the kit, then writes the
--      number of sensors and "installed".
--   5. profiles: "organisation" (experts, optional), and choose_role():
--      farmer or expert, only during the sign-up. An expert gets the
--      "verified expert" badge only when an admin sets verified = true.
--   6. activate_pack(): the ONE place that gives a pack for N days (used by
--      the demo payment and, later, by a real payment provider).
--   7. demo_payment(): the app "pays" a pack. NO card data: the card
--      typed on the screen never leaves the phone. Works ONLY if
--      demo_payments_enabled = true.
--   8. last check
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 008. Safe to run again (same rules as 008: no
-- begin/commit, each statement can be run again).
-- =========================================================


-- ---------- 1) The settings of the app (one row) ----------
create table if not exists app_settings (
  id                     boolean primary key default true check (id),  -- only one row
  demo_payments_enabled  boolean not null default true,
  updated_at             timestamptz not null default now()
);
insert into app_settings (id) values (true) on conflict (id) do nothing;

alter table app_settings enable row level security;

drop policy if exists "Logged-in users read the settings" on app_settings;
create policy "Logged-in users read the settings"
  on app_settings for select to authenticated using (true);

drop policy if exists "Admins change the settings" on app_settings;
create policy "Admins change the settings"
  on app_settings for update to authenticated using (is_admin()) with check (is_admin());

revoke insert, delete on app_settings from anon, authenticated;


-- ---------- 2) Connected: a price per sensor ----------
-- per_sensor = true: the price is for ONE sensor of the LOOZ kit.
alter table plan_prices add column if not exists per_sensor boolean not null default false;
comment on column plan_prices.per_sensor is
  'true = price for ONE sensor of the LOOZ kit (Connected: 8 DT x number of sensors).';

-- Only the first time (afterwards an admin may change the price).
update plan_prices set price_millimes = 8000, per_sensor = true, updated_at = now()
where plan = 'connected' and not per_sensor;


-- ---------- 3) Payments: demo statuses and sensors ----------
alter table payments drop constraint if exists payments_status_check;
alter table payments add constraint payments_status_check
  check (status in ('pending', 'paid', 'failed', 'expired', 'paid_demo', 'failed_demo'));

alter table payments add column if not exists sensors integer;
alter table payments drop constraint if exists payments_sensors_check;
alter table payments add constraint payments_sensors_check
  check (sensors is null or sensors between 1 and 1000);


-- ---------- 4) The requests of the LOOZ sensor kit ----------
-- status: 'new' (just asked), 'contacted' (an admin called), 'installed'
-- (the kit works: sensors is set), 'cancelled'.
create table if not exists kit_requests (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references profiles(id) on delete cascade,
  phone            text,
  governorate      text,
  almond_trees     integer,
  orchard_area_ha  numeric(8, 2),
  status           text not null default 'new'
                   check (status in ('new', 'contacted', 'installed', 'cancelled')),
  sensors          integer check (sensors is null or sensors between 1 and 1000),
  admin_note       text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  installed_at     timestamptz,
  constraint kit_requests_installed_has_sensors check (status <> 'installed' or sensors is not null)
);
comment on table kit_requests is
  'Requests of the LOOZ sensor kit (Connected). An admin sets status and sensors.';

-- One open request per farmer (new or contacted).
create unique index if not exists kit_requests_one_open
  on kit_requests (user_id) where status in ('new', 'contacted');
create index if not exists kit_requests_status_idx on kit_requests (status, created_at);

create or replace function public.kit_requests_before_update() returns trigger
language plpgsql set search_path = public as $$
begin
  new.updated_at := now();
  if new.status = 'installed' and old.status is distinct from 'installed' then
    new.installed_at := coalesce(new.installed_at, now());
  end if;
  return new;
end;
$$;

drop trigger if exists kit_requests_before_update on kit_requests;
create trigger kit_requests_before_update
  before update on kit_requests
  for each row execute function public.kit_requests_before_update();

alter table kit_requests enable row level security;

drop policy if exists "Users see their own kit requests" on kit_requests;
create policy "Users see their own kit requests"
  on kit_requests for select to authenticated using (user_id = auth.uid());

drop policy if exists "Admins manage kit requests" on kit_requests;
create policy "Admins manage kit requests"
  on kit_requests for all to authenticated using (is_admin()) with check (is_admin());

-- Users never write directly: request_kit() below.
revoke insert, update, delete on kit_requests from anon;

-- The farmer asks for the kit: his governorate, trees, area and phone are
-- copied from his profile (not sent by the app). Asked twice: the same
-- open request is given back.
create or replace function public.request_kit() returns kit_requests
language plpgsql security definer set search_path = public as $$
declare
  me     profiles;
  result kit_requests;
begin
  select * into me from profiles where id = auth.uid();
  if not found then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  if me.zone is null then
    raise exception 'Choose your governorate first' using errcode = '22023';
  end if;
  select * into result from kit_requests
  where user_id = me.id and status in ('new', 'contacted');
  if found then
    return result;
  end if;
  insert into kit_requests (user_id, phone, governorate, almond_trees, orchard_area_ha)
  values (me.id, me.phone, me.zone, me.almond_trees, me.orchard_area_ha)
  returning * into result;
  return result;
end;
$$;

revoke execute on function public.request_kit() from public, anon;
grant execute on function public.request_kit() to authenticated;


-- ---------- 5) Farmer or expert ----------
alter table profiles add column if not exists organisation text;
alter table profiles drop constraint if exists profiles_organisation_check;
alter table profiles add constraint profiles_organisation_check
  check (organisation is null or public.community_text_ok(organisation, 100));

-- During the sign-up only (before the pack is chosen): 'farmer' or
-- 'expert' (never 'admin'), with the organisation of an expert. "verified"
-- is never changed here: only an admin gives the "verified expert" badge.
create or replace function public.choose_role(p_role text, p_organisation text default null)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  if p_role is null or p_role not in ('farmer', 'expert') then
    raise exception 'Unknown role: %', p_role using errcode = '22023';
  end if;
  update profiles set
    role = p_role,
    organisation = case when p_role = 'expert'
                        then nullif(btrim(p_organisation), '') end
  where id = auth.uid() and plan_chosen_at is null and role in ('farmer', 'expert');
  if not found then
    raise exception 'The role is chosen during the sign-up only' using errcode = '42501';
  end if;
end;
$$;

revoke execute on function public.choose_role(text, text) from public, anon;
grant execute on function public.choose_role(text, text) to authenticated;


-- ---------- 6) Give a pack for N days (the ONE place) ----------
-- Same pack still running: the days are added after its end. Otherwise:
-- from now. Returns the new end. Called by demo_payment() and
-- confirm_payment(), never by the app directly.
create or replace function public.activate_pack(p_user uuid, p_plan text, p_days integer)
returns timestamptz
language plpgsql security definer set search_path = public as $$
declare
  sub      subscriptions;
  new_end  timestamptz;
begin
  select * into sub from subscriptions where user_id = p_user for update;
  if sub.plan = p_plan and sub.status = 'active' and sub.ends_at > now() then
    new_end := sub.ends_at + make_interval(days => p_days);
  else
    new_end := now() + make_interval(days => p_days);
  end if;
  -- The profile first (its "paid" trigger of migration 005 would give the
  -- pack forever), then the subscription with its real end.
  update profiles set chosen_plan = p_plan, payment_status = 'paid',
                      plan_chosen_at = coalesce(plan_chosen_at, now())
  where id = p_user;
  insert into subscriptions (user_id, plan, status, started_at, ends_at)
  values (p_user, p_plan, 'active', now(), new_end)
  on conflict (user_id) do update
    set plan = excluded.plan,
        status = 'active',
        started_at = case when subscriptions.plan = excluded.plan
                           and subscriptions.ends_at > now()
                          then subscriptions.started_at else now() end,
        ends_at = excluded.ends_at;
  return new_end;
end;
$$;

revoke execute on function public.activate_pack(uuid, text, integer) from public, anon, authenticated;
grant execute on function public.activate_pack(uuid, text, integer) to service_role;

-- How many units a payment of [p_plan] counts for [p_user]: 1, or the
-- sensors of his installed kit (null = no kit installed yet).
create or replace function public.pack_units(p_user uuid, p_plan text) returns integer
language sql stable security definer set search_path = public as $$
  select case
    when not coalesce((select per_sensor from plan_prices where plan = p_plan), false) then 1
    else (select sensors from kit_requests
          where user_id = p_user and status = 'installed'
          order by installed_at desc nulls last limit 1)
  end;
$$;

revoke execute on function public.pack_units(uuid, text) from public, anon, authenticated;
grant execute on function public.pack_units(uuid, text) to service_role;

-- 008's functions for a real provider, now with the price per sensor and
-- activate_pack() (same behaviour as before for Essential).
create or replace function public.start_payment(p_user uuid, p_plan text)
returns payments
language plpgsql security definer set search_path = public as $$
declare
  price  plan_prices;
  units  integer;
  result payments;
begin
  select * into price from plan_prices where plan = p_plan;
  if not found then
    raise exception 'Unknown paid pack: %', p_plan using errcode = '22023';
  end if;
  if not exists (select 1 from profiles where id = p_user) then
    raise exception 'Unknown user' using errcode = '22023';
  end if;
  units := public.pack_units(p_user, p_plan);
  if units is null then
    raise exception 'The LOOZ kit is not installed yet' using errcode = '22023';
  end if;
  if (select count(*) from payments
      where user_id = p_user and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'Too many payments: wait an hour' using errcode = 'PT429';
  end if;
  insert into payments (user_id, plan, amount_millimes, period_days, sensors)
  values (p_user, p_plan, price.price_millimes * units, price.period_days,
          case when price.per_sensor then units end)
  returning * into result;
  return result;
end;
$$;

create or replace function public.confirm_payment(p_ref text, p_amount integer)
returns payments
language plpgsql security definer set search_path = public as $$
declare
  pay payments;
begin
  select * into pay from payments where provider_ref = p_ref for update;
  if not found then
    raise exception 'Unknown payment reference' using errcode = '22023';
  end if;
  if pay.status = 'paid' then
    return pay;
  end if;
  if p_amount is distinct from pay.amount_millimes then
    raise exception 'Wrong amount: % instead of %', p_amount, pay.amount_millimes
      using errcode = '22023';
  end if;
  if pay.user_id is null then
    raise exception 'The account of this payment was deleted' using errcode = '22023';
  end if;
  update payments set status = 'paid', paid_at = now(), updated_at = now()
  where id = pay.id
  returning * into pay;
  perform public.activate_pack(pay.user_id, pay.plan, pay.period_days);
  return pay;
end;
$$;

revoke execute on function public.start_payment(uuid, text)     from public, anon, authenticated;
revoke execute on function public.confirm_payment(text, integer) from public, anon, authenticated;


-- ---------- 7) The DEMO payment ----------
-- The app "pays" [p_plan]: p_success = false is the demo's "not paid"
-- (the test card that always fails). NO card data is sent: the card typed
-- on the screen never leaves the phone.
-- Works ONLY if app_settings.demo_payments_enabled = true. Connected: only
-- once the LOOZ kit is installed (8 DT x its sensors). At most 10 tries
-- per hour.
create or replace function public.demo_payment(p_plan text, p_success boolean default true)
returns payments
language plpgsql security definer set search_path = public as $$
declare
  uid    uuid := auth.uid();
  price  plan_prices;
  units  integer;
  result payments;
begin
  if uid is null then
    raise exception 'Not logged in' using errcode = '42501';
  end if;
  if not coalesce((select demo_payments_enabled from app_settings where id), false) then
    -- PT403 = refused (HTTP 403): the app says "payment not available".
    raise exception 'Demo payments are turned off' using errcode = 'PT403';
  end if;
  select * into price from plan_prices where plan = p_plan;
  if not found then
    raise exception 'Unknown paid pack: %', p_plan using errcode = '22023';
  end if;
  units := public.pack_units(uid, p_plan);
  if units is null then
    -- PT409 = conflict (HTTP 409): the app says "the kit is not installed yet".
    raise exception 'The LOOZ kit is not installed yet' using errcode = 'PT409';
  end if;
  if (select count(*) from payments
      where user_id = uid and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'Too many payments: wait an hour' using errcode = 'PT429';
  end if;
  insert into payments (user_id, plan, amount_millimes, period_days, provider, status,
                        sensors, paid_at)
  values (uid, p_plan, price.price_millimes * units, price.period_days, 'demo',
          case when p_success then 'paid_demo' else 'failed_demo' end,
          case when price.per_sensor then units end,
          case when p_success then now() end)
  returning * into result;
  if p_success then
    perform public.activate_pack(uid, p_plan, price.period_days);
  end if;
  return result;
end;
$$;

revoke execute on function public.demo_payment(text, boolean) from public, anon;
grant execute on function public.demo_payment(text, boolean) to authenticated;


-- ---------- 8) Last check (should say: true | 8000 | true | true | true) ----------
select
  (select demo_payments_enabled from app_settings where id) as demo_payments_on,
  (select price_millimes from plan_prices where plan = 'connected' and per_sensor) as connected_per_sensor,
  exists (select 1 from pg_class where relname = 'kit_requests' and relrowsecurity) as kit_requests_locked,
  has_function_privilege('authenticated', 'public.demo_payment(text, boolean)', 'execute')
    and not has_function_privilege('authenticated', 'public.activate_pack(uuid, text, integer)', 'execute')
    as app_can_only_use_the_demo,
  exists (select 1 from information_schema.columns
          where table_name = 'profiles' and column_name = 'organisation') as expert_ready;
