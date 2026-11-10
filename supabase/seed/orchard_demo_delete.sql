-- =========================================================
-- LOOZ — removes the DEMO orchard(s) of supabase/seed/orchard_demo.sql
--
-- Its zones, nodes and trees go with it. The pack of the demo account is
-- NOT changed (it keeps its end date and nodes).
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- =========================================================

delete from kit_requests where orchard_id in (select id from orchards where is_demo);
delete from orchards where is_demo;

-- Check: you should see  0
select count(*) as demo_orchards_left from orchards where is_demo;
