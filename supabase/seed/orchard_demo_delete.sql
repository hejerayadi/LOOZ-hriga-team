-- =========================================================
-- LOOZ — removes the DEMO orchard(s) of supabase/seed/orchard_demo.sql
--
-- Its zones, nodes and trees go with it. The pack of the demo account is
-- NOT changed (it keeps its end date and nodes).
-- Only the demo orchard of +216 22 123 456: the IoT demo farmer
-- (+216 22 777 001) has its own delete file (iot_demo_farmer_delete.sql).
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- =========================================================

delete from kit_requests
where orchard_id in (select o.id from orchards o join profiles p on p.id = o.farmer_id
                     where o.is_demo and p.phone = '+21622123456');
delete from orchards o
using profiles p
where p.id = o.farmer_id and o.is_demo and p.phone = '+21622123456';

-- Check: you should see  0
select count(*) as demo_orchards_left
from orchards o join profiles p on p.id = o.farmer_id
where o.is_demo and p.phone = '+21622123456';
