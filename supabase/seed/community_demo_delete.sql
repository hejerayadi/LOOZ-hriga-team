-- =========================================================
-- LOOZ — DELETE all the demo data of the community
--
-- Deletes the fake farmers (profiles with is_demo = true) and their login
-- accounts (…@looz-demo.invalid, also those that lost their profile).
-- Everything that belongs to them goes with them: their posts,
-- their answers, and also the answers real users wrote UNDER a demo post.
-- Real users, their own posts and their other answers are kept.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- (One single statement: all or nothing.)
-- =========================================================

delete from auth.users
where email like 'demo-farmer-%@looz-demo.invalid'
   or id in (select id from public.profiles where is_demo);

-- Should say 0 and 0:
select (select count(*) from auth.users where email like '%@looz-demo.invalid') as demo_accounts_left,
       (select count(*) from public.profiles where is_demo) as demo_people_left;
