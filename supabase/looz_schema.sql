-- =========================================================
-- LOOZ — Database schema (from the Lucid class diagram)
-- Paste this whole file in Supabase > SQL Editor > Run
-- =========================================================

-- 1) USERS  (User + Farmer + Expert + Admin in one table)
-- "auth.users" is Supabase's built-in login table.
-- Each profile is linked to one login account.
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        text not null check (role in ('farmer', 'expert', 'admin')),
  name        text not null,
  phone       text,
  language    text default 'ar',
  zone        text,
  -- Farmer only
  farm_name   text,
  -- Expert only
  speciality  text,
  verified    boolean default false,
  created_at  timestamptz default now()
);

-- 2) COMMUNITY
create table posts (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid not null references profiles(id) on delete cascade,  -- User writes Post
  type        text not null check (type in ('question', 'tip')),
  text        text not null,
  photo       text,          -- link to the image in Supabase Storage
  voice_note  text,          -- link to the audio file
  hidden      boolean default false,
  date        timestamptz default now()
);

create table answers (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references posts(id) on delete cascade,     -- Post 1 ◆ 0..* Answer
  expert_id    uuid not null references profiles(id) on delete cascade,  -- Expert answers
  text         text not null,
  is_verified  boolean default false,
  date         timestamptz default now()
);

-- 3) ORCHARD
create table subscriptions (
  id          uuid primary key default gen_random_uuid(),
  farmer_id   uuid not null unique references profiles(id) on delete cascade,  -- Farmer 1 has 0..1
  start_date  date not null,
  end_date    date,
  status      text not null default 'active' check (status in ('active', 'paused', 'ended'))
);

create table orchard_plans (
  id          uuid primary key default gen_random_uuid(),
  farmer_id   uuid not null references profiles(id) on delete cascade,  -- Farmer designs
  area        real,
  spacing     real,
  layout      jsonb,         -- tree positions for the 3D view
  created_at  timestamptz default now()
);

create table orchards (
  id          uuid primary key default gen_random_uuid(),
  farmer_id   uuid not null references profiles(id) on delete cascade,  -- Farmer owns
  name        text not null,
  location    text,
  area        real
);

create table trees (
  id            uuid primary key default gen_random_uuid(),
  orchard_id    uuid not null references orchards(id) on delete cascade,  -- Orchard 1 ◆ 0..* Tree
  code          text not null,
  variety       text,
  growth_stage  text,
  health        text default 'fine' check (health in ('fine', 'care', 'problem')),
  pos_x         real,          -- position in the 3D orchard (meters)
  pos_z         real
);

-- Sensor identity only. The readings live in the NoSQL database (linked by sensor id).
create table sensors (
  id          uuid primary key default gen_random_uuid(),
  tree_id     uuid not null references trees(id) on delete cascade,  -- Tree has Sensor
  type        text not null check (type in ('soil', 'air', 'leaf')),
  last_value  real,
  battery     integer,
  last_seen   timestamptz
);

create table advice (
  id          uuid primary key default gen_random_uuid(),
  tree_id     uuid not null references trees(id) on delete cascade,  -- Tree gets Advice
  text        text not null,
  reason      text,
  confidence  real,
  status      text default 'new' check (status in ('new', 'accepted', 'ignored')),
  created_at  timestamptz default now()
);

create table field_actions (
  id          uuid primary key default gen_random_uuid(),
  orchard_id  uuid not null references orchards(id) on delete cascade,  -- Orchard 1 ◆ 0..* FieldAction
  advice_id   uuid unique references advice(id) on delete set null,     -- Advice leads to (0..1)
  type        text not null check (type in ('watering', 'treatment', 'pruning', 'harvest')),
  date        date not null default current_date,
  notes       text
);

-- 4) ALERTS
create table alerts (
  id          uuid primary key default gen_random_uuid(),
  admin_id    uuid references profiles(id) on delete set null,  -- Admin sends (regional alert)
  sensor_id   uuid references sensors(id) on delete set null,   -- Sensor triggers (tree alert)
  type        text not null check (type in ('regional', 'tree')),
  level       text not null check (level in ('info', 'warning', 'danger')),
  message     text not null,
  zone        text,
  date        timestamptz default now()
);

-- Farmer 0..* confirms 0..* Alert  →  link table
create table alert_confirmations (
  farmer_id     uuid references profiles(id) on delete cascade,
  alert_id      uuid references alerts(id) on delete cascade,
  confirmed_at  timestamptz default now(),
  primary key (farmer_id, alert_id)
);