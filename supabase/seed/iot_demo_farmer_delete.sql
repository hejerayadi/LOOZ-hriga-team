-- =========================================================
-- LOOZ — removes the orchard of the IoT DEMO FARMER (+216 22 777 001)
-- made by supabase/seed/iot_demo_farmer.sql
--
-- Its zones, boxes, trees, readings, alert log and gateway (GW-01) go with
-- it. The account and its pack are NOT changed (delete the account in
-- Authentication > Users if you want). Other orchards are never touched.
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- =========================================================

delete from kit_requests
where orchard_id in (select o.id from orchards o join profiles p on p.id = o.farmer_id
                     where o.is_demo and p.phone = '+21622777001');
delete from orchards o
using profiles p
where p.id = o.farmer_id and o.is_demo and p.phone = '+21622777001';

-- Check: you should see  0 | 0
select (select count(*) from orchards o join profiles p on p.id = o.farmer_id
         where o.is_demo and p.phone = '+21622777001')        as iot_demo_orchards_left,
       (select count(*) from gateways where code = 'GW-01')     as gateway_left;
