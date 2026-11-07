-- =========================================================
-- LOOZ — Migration 008: the sign-up profile and the PAYMENTS of the packs
--
-- What it does:
--   1. profiles: the governorate (column "zone", one of the 24) and 3
--      optional orchard fields: number of almond trees, area in hectares,
--      irrigated or rain-fed. Each user can change his own.
--   2. plan_prices: the price of each paid pack (the ONE place for the
--      prices: the app shows them, the payment server charges them).
--   3. payments: one row per payment of a pack. NEVER card data: the card
--      is typed only on the page of the payment provider (Konnect).
--   4. the rules: a user reads only his own payments, and can NEVER write
--      one, nor mark himself "paid" (no rule allows it).
--   5. the functions of the payment server only (Edge Functions, with the
--      service_role key): start_payment, set_payment_ref, confirm_payment
--      (the provider said "paid": the user gets the pack for 30 days),
--      close_payment (failed or expired).
--   6. last check
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 007. Safe to run again.
-- No begin/commit: the SQL Editor may run the statements one by one (see
-- supabase/seed/community_demo.sql). Each statement can be run again, in a
-- safe order: if one fails, fix the problem and run the whole file again.
-- =========================================================


-- ---------- 1) The sign-up profile ----------
-- "zone" already exists (the community shows it as the region): it is the
-- governorate, as a code that the app shows in Arabic or French.
-- "not valid": old rows are not checked.
alter table profiles drop constraint if exists profiles_zone_check;
alter table profiles add constraint profiles_zone_check check (zone is null or zone in (
  'tunis', 'ariana', 'ben_arous', 'manouba', 'nabeul', 'zaghouan', 'bizerte', 'beja',
  'jendouba', 'kef', 'siliana', 'sousse', 'monastir', 'mahdia', 'sfax', 'kairouan',
  'kasserine', 'sidi_bouzid', 'gabes', 'medenine', 'tataouine', 'gafsa', 'tozeur', 'kebili'))
  not valid;
comment on column profiles.zone is
  'Governorate of the farmer (code: tunis, sfax, sidi_bouzid... 24 codes).';

-- The orchard, all optional: number of almond trees, area in hectares,
-- watering ('irrigated' or 'rainfed').
alter table profiles add column if not exists almond_trees    integer;
alter table profiles add column if not exists orchard_area_ha numeric(8, 2);
alter table profiles add column if not exists irrigation      text;

alter table profiles drop constraint if exists profiles_almond_trees_check;
alter table profiles add constraint profiles_almond_trees_check
  check (almond_trees is null or almond_trees between 1 and 100000);
alter table profiles drop constraint if exists profiles_orchard_area_check;
alter table profiles add constraint profiles_orchard_area_check
  check (orchard_area_ha is null or (orchard_area_ha > 0 and orchard_area_ha <= 10000));
alter table profiles drop constraint if exists profiles_irrigation_check;
alter table profiles add constraint profiles_irrigation_check
  check (irrigation is null or irrigation in ('irrigated', 'rainfed'));


-- ---------- 2) The prices of the paid packs ----------
-- In millimes (1 DT = 1000 millimes). One payment = the pack for
-- period_days days. Change a price: Table Editor > plan_prices.
create table if not exists plan_prices (
  plan            text primary key check (plan in ('essential', 'connected')),
  price_millimes  integer not null check (price_millimes between 1000 and 10000000),
  period_days     integer not null default 30 check (period_days between 1 and 366),
  updated_at      timestamptz not null default now()
);

-- First prices (only if there are none yet): change them in Table Editor.
insert into plan_prices (plan, price_millimes) values
  ('essential', 15000),
  ('connected', 30000)
on conflict (plan) do nothing;

alter table plan_prices enable row level security;

drop policy if exists "Everyone reads the prices" on plan_prices;
create policy "Everyone reads the prices"
  on plan_prices for select to anon, authenticated using (true);

drop policy if exists "Admins change the prices" on plan_prices;
create policy "Admins change the prices"
  on plan_prices for all to authenticated using (is_admin()) with check (is_admin());


-- ---------- 3) The payments ----------
-- status: 'pending' (waiting for the provider), 'paid' (confirmed by the
-- provider to our server), 'failed', 'expired' (never paid).
-- user_id: kept empty if the account is deleted (the payment stays).
create table if not exists payments (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid references profiles(id) on delete set null,
  plan             text not null check (plan in ('essential', 'connected')),
  amount_millimes  integer not null check (amount_millimes > 0),
  period_days      integer not null check (period_days between 1 and 366),
  provider         text not null default 'konnect',
  provider_ref     text unique,
  status           text not null default 'pending'
                   check (status in ('pending', 'paid', 'failed', 'expired')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  paid_at          timestamptz
);
comment on table payments is
  'One row per payment of a pack. NEVER card data (number, expiry, CVV): '
  'the card is typed only on the page of the payment provider.';

create index if not exists payments_user_id_idx on payments (user_id, created_at desc);


-- ---------- 4) The rules: read your own, never write ----------
alter table payments enable row level security;

drop policy if exists "Users see their own payments" on payments;
create policy "Users see their own payments"
  on payments for select to authenticated using (user_id = auth.uid());

drop policy if exists "Admins see all payments" on payments;
create policy "Admins see all payments"
  on payments for select to authenticated using (is_admin());

-- No insert / update / delete rule: only the payment server (service_role,
-- which skips the rules) writes payments. Even the rights are removed:
revoke insert, update, delete on payments from anon, authenticated;


-- ---------- 5) The functions of the payment server (service_role only) ----------

-- A new payment of [p_plan] for [p_user], at the price of plan_prices
-- (never a price sent by the app). At most 5 tries per hour.
create or replace function public.start_payment(p_user uuid, p_plan text)
returns payments
language plpgsql security definer set search_path = public as $$
declare
  price  plan_prices;
  result payments;
begin
  select * into price from plan_prices where plan = p_plan;
  if not found then
    raise exception 'Unknown paid pack: %', p_plan using errcode = '22023';
  end if;
  if not exists (select 1 from profiles where id = p_user) then
    raise exception 'Unknown user' using errcode = '22023';
  end if;
  if (select count(*) from payments
      where user_id = p_user and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'Too many payments: wait an hour' using errcode = 'PT429';
  end if;
  insert into payments (user_id, plan, amount_millimes, period_days)
  values (p_user, p_plan, price.price_millimes, price.period_days)
  returning * into result;
  return result;
end;
$$;

-- The reference given by the provider (Konnect's paymentRef), once.
create or replace function public.set_payment_ref(p_payment uuid, p_ref text)
returns payments
language plpgsql security definer set search_path = public as $$
declare
  result payments;
begin
  update payments set provider_ref = p_ref, updated_at = now()
  where id = p_payment and provider_ref is null and status = 'pending'
  returning * into result;
  if result.id is null then
    raise exception 'Payment not found, or it has its reference already' using errcode = '22023';
  end if;
  return result;
end;
$$;

-- The provider confirmed to our server that this payment is paid, with
-- this reference and this amount. The user gets the pack for period_days
-- (added to the days left, if the same pack is still running). Called
-- twice (the same confirmation twice): nothing more happens.
create or replace function public.confirm_payment(p_ref text, p_amount integer)
returns payments
language plpgsql security definer set search_path = public as $$
declare
  pay      payments;
  sub      subscriptions;
  new_end  timestamptz;
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

  -- The end of the pack: same pack still running = after its end; else from now.
  select * into sub from subscriptions where user_id = pay.user_id for update;
  if sub.plan = pay.plan and sub.status = 'active' and sub.ends_at > now() then
    new_end := sub.ends_at + make_interval(days => pay.period_days);
  else
    new_end := now() + make_interval(days => pay.period_days);
  end if;

  update payments set status = 'paid', paid_at = now(), updated_at = now()
  where id = pay.id
  returning * into pay;

  -- The profile first (its "paid" trigger of migration 005 would give the
  -- pack forever), then the subscription with its real end.
  update profiles set chosen_plan = pay.plan, payment_status = 'paid',
                      plan_chosen_at = coalesce(plan_chosen_at, now())
  where id = pay.user_id;
  insert into subscriptions (user_id, plan, status, started_at, ends_at)
  values (pay.user_id, pay.plan, 'active', now(), new_end)
  on conflict (user_id) do update
    set plan = excluded.plan,
        status = 'active',
        started_at = case when subscriptions.plan = excluded.plan
                           and subscriptions.ends_at > now()
                          then subscriptions.started_at else now() end,
        ends_at = excluded.ends_at;
  return pay;
end;
$$;

-- Not paid: 'failed' or 'expired'. A paid payment never changes.
create or replace function public.close_payment(p_ref text, p_status text)
returns payments
language plpgsql security definer set search_path = public as $$
declare
  result payments;
begin
  if p_status not in ('failed', 'expired') then
    raise exception 'Unknown status: %', p_status using errcode = '22023';
  end if;
  update payments set status = p_status, updated_at = now()
  where provider_ref = p_ref and status = 'pending'
  returning * into result;
  if result.id is null then
    select * into result from payments where provider_ref = p_ref;
  end if;
  return result;
end;
$$;

-- Only the payment server may call them (not the app, not logged-out users).
revoke execute on function public.start_payment(uuid, text)    from public, anon, authenticated;
revoke execute on function public.set_payment_ref(uuid, text)  from public, anon, authenticated;
revoke execute on function public.confirm_payment(text, integer) from public, anon, authenticated;
revoke execute on function public.close_payment(text, text)    from public, anon, authenticated;
grant execute on function public.start_payment(uuid, text)     to service_role;
grant execute on function public.set_payment_ref(uuid, text)   to service_role;
grant execute on function public.confirm_payment(text, integer) to service_role;
grant execute on function public.close_payment(text, text)     to service_role;


-- ---------- 6) Last check (should say: true | 2 | true | true) ----------
select
  exists (select 1 from information_schema.columns
          where table_schema = 'public' and table_name = 'profiles'
            and column_name = 'almond_trees') as profile_ready,
  (select count(*) from plan_prices) as paid_packs_with_price,
  (select relrowsecurity from pg_class where oid = 'public.payments'::regclass) as payments_locked,
  not has_function_privilege('authenticated', 'public.confirm_payment(text, integer)', 'execute')
    as app_cannot_confirm;
