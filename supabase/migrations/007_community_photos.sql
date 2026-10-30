-- =========================================================
-- LOOZ — Migration 007: PHOTOS in the community posts (Supabase Storage)
--
-- What it does:
--   1. the name of a photo: <user id>/<random id>.jpg (or .png / .webp),
--      and a limit against spam: at most 5 photos in 10 minutes per user
--   2. the "community" bucket (a folder of files in Supabase Storage):
--      PRIVATE (only logged-in users of the app see the photos),
--      at most 5 MB per photo, only JPEG, PNG or WebP
--   3. the rules of the bucket: every logged-in user sees the photos of
--      the posts (a post hidden by an admin hides its photo too) and their
--      own photos; each user uploads only into their own folder and deletes
--      only their own photos; admins see and delete any photo. Nobody can
--      replace a photo.
--   4. posts.photo: only a photo of this bucket (or, for the demo data
--      written in the SQL Editor, the demo picture "demo:..."). From the
--      app, the photo must be YOUR OWN photo, really uploaded.
--   5. last check: shows what is in place
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 006. Safe to run again.
-- ⚠ If you ever re-run 006, run THIS file again afterwards (parts 4 and 5).
--
-- No begin/commit: the SQL Editor may run the statements one by one
-- (see supabase/seed/community_demo.sql). Each statement can be run
-- again, and the order is safe: if one fails, nothing is left open; fix
-- the problem and run the whole file again.
--
-- Deleting a photo: only with the Storage API (the app does it when you
-- delete your post). Supabase refuses "delete from storage.objects" in SQL,
-- because the file itself would stay.
-- =========================================================


-- ---------- 1) What a photo name may be ----------
-- "<user id>/<random id>.<jpg|jpeg|png|webp>", for example
-- 0c1f...-.../7a2b...-....jpg : the first part is the folder of the user.
create or replace function public.community_photo_name_ok(p_name text) returns boolean
language sql immutable as $$
  select coalesce(p_name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp)$', false);
$$;

-- Against spam: has the logged-in user uploaded fewer than 5 photos in the
-- last 10 minutes? ("security definer": it counts all their photos.)
create or replace function public.community_photo_uploads_ok() returns boolean
language sql stable security definer set search_path = '' as $$
  select count(*) < 5
  from storage.objects o
  where o.bucket_id = 'community'
    and o.name like auth.uid()::text || '/%'
    and o.created_at > now() - interval '10 minutes';
$$;

revoke execute on function public.community_photo_uploads_ok() from public, anon;
grant execute on function public.community_photo_uploads_ok() to authenticated;


-- ---------- 2) The bucket "community" ----------
-- Private: a photo can't be opened with a link by people outside the app.
-- 5 MB = 5 * 1024 * 1024 bytes (the app makes photos much smaller).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('community', 'community', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;


-- ---------- 3) The rules of the bucket (RLS on storage.objects) ----------
-- (RLS is already on for storage.objects in every Supabase project.)
-- See (logged-in users only): the photos of the posts that everybody sees,
-- and your own photos (before the post is published). Admins: all.
drop policy if exists "Community photos: see the photos of the posts" on storage.objects;
create policy "Community photos: see the photos of the posts"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'community'
    and ((storage.foldername(name))[1] = (select auth.uid()::text)
         or exists (select 1 from public.posts p
                    where p.photo = objects.name
                      and p.photo not like 'demo:%'
                      and not p.hidden)
         or public.is_admin())
  );

-- Upload: only into your own folder, with a correct name, not too often.
drop policy if exists "Community photos: upload into your own folder" on storage.objects;
create policy "Community photos: upload into your own folder"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'community'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
    and public.community_photo_name_ok(name)
    and public.community_photo_uploads_ok()
  );

-- Delete: only your own photos. Admins: any photo (moderation).
drop policy if exists "Community photos: delete your own" on storage.objects;
create policy "Community photos: delete your own"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'community'
    and ((storage.foldername(name))[1] = (select auth.uid()::text) or public.is_admin())
  );

-- (No "update" rule: nobody can replace or move a photo.)


-- ---------- 4) posts.photo ----------
-- New rule, added BEFORE the old "demo picture only" rule is removed.
-- "not valid": old rows are not checked (they all follow the old rule).
alter table posts drop constraint if exists posts_photo_in_bucket;
alter table posts add constraint posts_photo_in_bucket
  check (photo is null
         or photo ~ '^demo:[a-z0-9_]+$'
         or public.community_photo_name_ok(photo)) not valid;
alter table posts drop constraint if exists posts_photo_check;

-- One photo = one post (deleting a post deletes its photo).
create unique index if not exists posts_photo_unique on posts (photo)
  where photo is not null and photo not like 'demo:%';

-- Same as migration 006, plus the end: from the app, a photo must be
-- the user's own photo, really uploaded in "community".
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
  if new.photo is not null
     and (tg_op = 'INSERT' or new.photo is distinct from old.photo)
     and not (public.community_photo_name_ok(new.photo)
              and split_part(new.photo, '/', 1) = auth.uid()::text
              and exists (select 1 from storage.objects o
                          where o.bucket_id = 'community' and o.name = new.photo)) then
    raise exception 'The photo must be one of your photos in "community"' using errcode = '22023';
  end if;
  return new;
end;
$$;


-- ---------- 5) Last check (should say: true | true | 3 | true) ----------
select
  exists (select 1 from storage.buckets
          where id = 'community' and public = false and file_size_limit = 5242880
            and allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'])
    as bucket_ready,
  exists (select 1 from pg_constraint where conname = 'posts_photo_in_bucket')
    and not exists (select 1 from pg_constraint where conname = 'posts_photo_check')
    as photo_rule_ready,
  (select count(*) from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname like 'Community photos:%')
    as storage_rules,
  (select prosrc like '%community_photo_name_ok%' from pg_proc
   where oid = 'public.posts_before_write()'::regprocedure)
    as post_photo_check_ready;
