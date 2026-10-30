-- =========================================================
-- LOOZ — Migration 006: the COMMUNITY (posts and their answers)
--
-- What it does:
--   1. profiles.is_demo: marks the fake farmers of the demo
--      (supabase/seed/community_demo.sql). Users cannot change it.
--   2. text checks, in the database too: not empty, at most 1000
--      characters, no HTML (no < or >), no invisible control characters
--   3. "comments": the answers written under a post (any farmer can answer)
--   4. the author is ALWAYS the logged-in user (the database sets it,
--      whatever the app sends), and the date is always "now"
--   5. against spam: at most 5 answers per minute and 3 posts per
--      10 minutes for each user
--   6. public_profile(): the ONLY public information about a user:
--      first name, last name, region, "verified expert" badge.
--      Never the phone, the pack, the payment or the role.
--   7. two ready-made lists for the app: "community_posts" (with the
--      author's name and the number of answers) and "community_comments"
--   8. the rules (RLS): every logged-in user reads; each user writes,
--      changes and deletes only his own posts and answers; admins can
--      hide or delete anything
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 005. Safe to run again.
-- ⚠ If you ever re-run 005, run THIS file again afterwards (part 1).
-- (The old "answers" table — answers by verified experts only — is not
--  used by the app and is not changed.)
-- =========================================================

-- All or nothing: if one line fails, nothing is changed.
begin;


-- ---------- 1) Demo farmers ----------
alter table profiles add column if not exists is_demo boolean not null default false;
comment on column profiles.is_demo is
  'Fake farmer of the demo (supabase/seed/community_demo.sql). Cannot log in. '
  'Delete them all with supabase/seed/community_demo_delete.sql.';

-- Same as migration 005, plus is_demo: a user may change his first name,
-- last name, language and region, nothing else.
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
    or new.created_at     is distinct from old.created_at
    or new.is_demo        is distinct from old.is_demo then
      raise exception 'This field cannot be changed from the app' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;


-- ---------- 2) What a text may contain ----------
-- 1 to max_length characters (spaces and line breaks at both ends are not
-- counted), no < or > (so no HTML), no invisible control characters
-- (line breaks are fine) and no characters that turn the text direction.
create or replace function public.community_text_ok(t text, max_length integer) returns boolean
language sql immutable as $$
  select t is not null
     and char_length(btrim(t, E' \n\r')) between 1 and max_length
     and t !~ '[<>]'
     and t !~ '[\x01-\x09\x0b\x0c\x0e-\x1f\x7f\u202a-\u202e\u2066-\u2069]';
$$;


-- ---------- 3) POSTS (the table exists since looz_schema.sql) ----------
-- Columns: author_id, type ('question' or 'tip'), text, photo, voice_note,
-- hidden (by an admin), date. New: updated_at.
alter table posts add column if not exists updated_at timestamptz not null default now();
alter table posts alter column author_id set default auth.uid();
update posts set hidden = false where hidden is null;
alter table posts alter column hidden set default false;
alter table posts alter column hidden set not null;
update posts set date = now() where date is null;
alter table posts alter column date set default now();
alter table posts alter column date set not null;

alter table posts drop constraint if exists posts_text_check;
alter table posts add constraint posts_text_check
  check (public.community_text_ok(text, 1000)) not valid;  -- "not valid": old rows are not checked

-- Photos and voice notes: not uploaded from the app yet (needs Supabase
-- Storage, later). Until then only the demo pictures shipped in the app
-- ("demo:almond_blossoms").
alter table posts drop constraint if exists posts_photo_check;
alter table posts add constraint posts_photo_check
  check (photo is null or photo ~ '^demo:[a-z0-9_]+$') not valid;
alter table posts drop constraint if exists posts_voice_note_check;
alter table posts add constraint posts_voice_note_check
  check (voice_note is null or voice_note ~ '^demo:[a-z0-9_]+$') not valid;

create index if not exists posts_date_idx on posts (date desc);
create index if not exists posts_author_id_idx on posts (author_id, date desc);


-- ---------- 4) COMMENTS: the answers under a post ----------
create table if not exists comments (
  id          uuid primary key default gen_random_uuid(),
  post_id     uuid not null references posts(id) on delete cascade,     -- deleted with its post
  author_id   uuid not null default auth.uid() references profiles(id) on delete cascade,
  text        text not null,
  hidden      boolean not null default false,                            -- hidden by an admin
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table comments drop constraint if exists comments_text_check;
alter table comments add constraint comments_text_check
  check (public.community_text_ok(text, 1000));

create index if not exists comments_post_id_idx on comments (post_id, created_at);
create index if not exists comments_author_id_idx on comments (author_id, created_at desc);


-- ---------- 5) Author, date and spam limit: set by the database ----------
-- Only for the users of the app (SQL Editor, the server and admins are free).
create or replace function public.posts_before_write() returns trigger
language plpgsql set search_path = public as $$
begin
  new.text := btrim(new.text, E' \n\r');
  new.updated_at := now();
  if current_user <> 'authenticated' or public.is_admin() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.author_id := auth.uid();
    new.date      := now();
    new.hidden    := false;
    if (select count(*) from posts
        where author_id = auth.uid() and date > now() - interval '10 minutes') >= 3 then
      raise exception 'Too many posts: wait a few minutes' using errcode = 'PT429';
    end if;
  elsif new.author_id is distinct from old.author_id
     or new.date      is distinct from old.date
     or new.hidden    is distinct from old.hidden then
    raise exception 'This field cannot be changed from the app' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists posts_before_write on posts;
create trigger posts_before_write
  before insert or update on posts
  for each row execute function public.posts_before_write();

create or replace function public.comments_before_write() returns trigger
language plpgsql set search_path = public as $$
begin
  new.text := btrim(new.text, E' \n\r');
  new.updated_at := now();
  if current_user <> 'authenticated' or public.is_admin() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.author_id  := auth.uid();
    new.created_at := now();
    new.hidden     := false;
    if (select count(*) from comments
        where author_id = auth.uid() and created_at > now() - interval '1 minute') >= 5 then
      raise exception 'Too many answers: wait a minute' using errcode = 'PT429';
    end if;
  elsif new.author_id  is distinct from old.author_id
     or new.post_id    is distinct from old.post_id
     or new.created_at is distinct from old.created_at
     or new.hidden     is distinct from old.hidden then
    raise exception 'This field cannot be changed from the app' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists comments_before_write on comments;
create trigger comments_before_write
  before insert or update on comments
  for each row execute function public.comments_before_write();


-- ---------- 6) The public information about a user ----------
-- Profiles are private (migration 005): each user reads only his own row.
-- This function is the ONLY way to read something about another user, and
-- it returns only these 4 things. Logged-in users only.
create or replace function public.public_profile(p_user uuid)
returns table (first_name text, last_name text, region text, verified_expert boolean)
language sql stable security definer set search_path = public as $$
  select p.first_name,
         p.last_name,
         p.zone,
         (p.role = 'expert' and coalesce(p.verified, false))
  from profiles p
  where p.id = p_user and auth.uid() is not null;
$$;

revoke execute on function public.public_profile(uuid) from public, anon;
grant execute on function public.public_profile(uuid) to authenticated;


-- ---------- 7) The lists read by the app ----------
-- "security_invoker": the rules of part 8 apply to the user who reads.
-- Hidden posts and answers are not in the lists.
create or replace view public.community_posts with (security_invoker = true) as
select p.id,
       p.type,
       p.text,
       p.photo,
       p.voice_note,
       p.date       as created_at,
       p.author_id,
       a.first_name as author_first_name,
       a.last_name  as author_last_name,
       a.region     as author_region,
       coalesce(a.verified_expert, false) as author_verified_expert,
       (select count(*)::int from comments c
        where c.post_id = p.id and not c.hidden) as comment_count,
       exists (select 1 from comments c
               cross join lateral public.public_profile(c.author_id) e
               where c.post_id = p.id and not c.hidden and e.verified_expert) as has_expert_answer
from posts p
left join lateral public.public_profile(p.author_id) a on true
where not p.hidden;

create or replace view public.community_comments with (security_invoker = true) as
select c.id,
       c.post_id,
       c.text,
       c.created_at,
       c.author_id,
       a.first_name as author_first_name,
       a.last_name  as author_last_name,
       a.region     as author_region,
       coalesce(a.verified_expert, false) as author_verified_expert
from comments c
left join lateral public.public_profile(c.author_id) a on true
where not c.hidden;

revoke all on public.community_posts, public.community_comments from public, anon;
grant select on public.community_posts, public.community_comments to authenticated;


-- ---------- 8) The rules (RLS) ----------
alter table posts enable row level security;
alter table comments enable row level security;
revoke all on posts, comments from anon;   -- not logged in: nothing at all

-- POSTS (same rules as looz_policies.sql, written again here)
drop policy if exists "Everyone logged in reads visible posts" on posts;
create policy "Everyone logged in reads visible posts"
  on posts for select to authenticated
  using (hidden = false or author_id = auth.uid() or is_admin());

drop policy if exists "Users write their own posts" on posts;
create policy "Users write their own posts"
  on posts for insert to authenticated
  with check (author_id = auth.uid() and hidden = false);

drop policy if exists "Users edit their own visible posts" on posts;
create policy "Users edit their own visible posts"
  on posts for update to authenticated
  using (author_id = auth.uid() and hidden = false)
  with check (author_id = auth.uid() and hidden = false);

drop policy if exists "Users delete their own posts" on posts;
create policy "Users delete their own posts"
  on posts for delete to authenticated using (author_id = auth.uid());

drop policy if exists "Admins moderate posts" on posts;
create policy "Admins moderate posts"
  on posts for all to authenticated using (is_admin()) with check (is_admin());

-- COMMENTS
-- Read: the answers of the posts you can see.
drop policy if exists "Everyone logged in reads comments" on comments;
create policy "Everyone logged in reads comments"
  on comments for select to authenticated
  using ((hidden = false or author_id = auth.uid() or is_admin())
         and exists (select 1 from posts where posts.id = comments.post_id));

-- Write: as yourself, under a visible post.
drop policy if exists "Users write their own comments" on comments;
create policy "Users write their own comments"
  on comments for insert to authenticated
  with check (author_id = auth.uid() and hidden = false
              and exists (select 1 from posts
                          where posts.id = comments.post_id and posts.hidden = false));

drop policy if exists "Users edit their own comments" on comments;
create policy "Users edit their own comments"
  on comments for update to authenticated
  using (author_id = auth.uid() and hidden = false)
  with check (author_id = auth.uid() and hidden = false);

drop policy if exists "Users delete their own comments" on comments;
create policy "Users delete their own comments"
  on comments for delete to authenticated using (author_id = auth.uid());

drop policy if exists "Admins manage comments" on comments;
create policy "Admins manage comments"
  on comments for all to authenticated using (is_admin()) with check (is_admin());


commit;
