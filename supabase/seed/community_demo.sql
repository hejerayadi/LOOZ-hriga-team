-- =========================================================
-- LOOZ — DEMO data for the community (fake farmers, posts, answers)
--
-- 9 fake people (8 farmers + 1 verified expert), 15 posts, 56 answers,
-- spread over the last 6 weeks. Mostly in Arabic, a few in French.
--
-- How the fake farmers are made:
--   A profile must belong to a login account (auth.users), so each fake
--   farmer gets an account WITHOUT phone and WITHOUT password, with a
--   fake e-mail that can't receive anything (…@looz-demo.invalid), and
--   blocked until the year 2999: nobody can log in with it.
--   Their profiles are marked is_demo = true.
--
-- To delete everything later: supabase/seed/community_demo_delete.sql
--
-- Where: Supabase > SQL Editor > New query > paste ALL > Run
-- Run it AFTER migration 006. Safe to run again (nothing is added twice).
--
-- The whole job is ONE statement: the "do $$ ... $$;" block below.
-- So it is all or nothing (an error = nothing saved), and it works however
-- the editor sends the file (all in one go, or one statement at a time).
-- The temporary tables (demo_farmers, ...) exist only inside this block.
-- =========================================================

do $$
declare
  people_count  int;
  posts_count   int;
  answers_count int;
begin

-- ---------- 1) The fake people ----------
create temp table demo_farmers (
  id          uuid primary key,
  n           int,
  first_name  text,
  last_name   text,
  region      text,     -- code, shown in Arabic or French by the app
  role        text,
  language    text,
  verified    boolean
) on commit drop;

insert into demo_farmers values
  ('de000000-0000-4000-8000-000000000001', 1, 'الهادي',     'الطرابلسي', 'sfax',        'farmer', 'ar', false),
  ('de000000-0000-4000-8000-000000000002', 2, 'فاطمة',      'القاسمي',   'kairouan',    'farmer', 'ar', false),
  ('de000000-0000-4000-8000-000000000003', 3, 'منصف',       'الجلاصي',   'sidi_bouzid', 'farmer', 'ar', false),
  ('de000000-0000-4000-8000-000000000004', 4, 'نجيب',       'العياري',   'gafsa',       'farmer', 'ar', false),
  ('de000000-0000-4000-8000-000000000005', 5, 'سنية',       'الزغلامي',  'kasserine',   'farmer', 'ar', false),
  ('de000000-0000-4000-8000-000000000006', 6, 'عبد الكريم', 'الزواري',   'mahdia',      'farmer', 'ar', false),
  ('de000000-0000-4000-8000-000000000007', 7, 'Karim',      'Ben Youssef', 'sfax',      'farmer', 'fr', false),
  ('de000000-0000-4000-8000-000000000008', 8, 'Leila',      'Mansouri',  'zaghouan',    'farmer', 'fr', false),
  ('de000000-0000-4000-8000-000000000009', 9, 'سامي',       'الدريدي',   'sidi_bouzid', 'expert', 'ar', true);

-- Their login accounts (they can't log in: no phone, no password, blocked).
-- The empty '' texts avoid an error in Supabase > Authentication > Users.
insert into auth.users (
  instance_id, id, aud, role, email,
  raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, banned_until,
  confirmation_token, recovery_token, email_change_token_new, email_change)
select '00000000-0000-0000-0000-000000000000', d.id, 'authenticated', 'authenticated',
       'demo-farmer-' || lpad(d.n::text, 2, '0') || '@looz-demo.invalid',
       '{"provider": "email", "providers": ["email"]}'::jsonb,
       jsonb_build_object('name', d.first_name || ' ' || d.last_name,
                          'role', d.role, 'language', d.language, 'demo', true),
       now() - interval '90 days', now(), '2999-12-31'::timestamptz,
       '', '', '', ''
from demo_farmers d
on conflict (id) do nothing;

-- Their profiles are created automatically with the accounts. (If an
-- account is there without its profile, the profile is made here.)
insert into profiles (id, role, name, language)
select d.id, d.role, d.first_name || ' ' || d.last_name, d.language
from demo_farmers d
where exists (select 1 from auth.users u where u.id = d.id)
on conflict (id) do nothing;

-- Names, region, expert badge, demo mark.
update profiles p
set first_name = d.first_name,
    last_name  = d.last_name,
    zone       = d.region,
    verified   = d.verified,
    is_demo    = true,
    created_at = now() - interval '90 days'
from demo_farmers d
where p.id = d.id;


-- ---------- 2) The posts ----------
create temp table demo_posts (
  n       int primary key,
  author  int,          -- number of the fake farmer above
  type    text,
  photo   text,
  ago     interval,     -- how long ago it was posted
  text    text
) on commit drop;

insert into demo_posts values
  (1,  2, 'question', 'demo:almond_blossoms', '2 hours',
   'شجرة اللوز عندي نوّرت في أكتوبر بعد المطر الأخير. هل هذه الزهرة سليمة؟'),
  (2,  3, 'question', null, '1 day',
   'قداش لازم نسقي اللوز في الخريف؟ الأرض عندي رملية والشجر عمره 4 سنين.'),
  (3,  7, 'question', null, '2 days 3 hours',
   'Quel est le prix des amandes à Sfax cette semaine ? On m''a proposé 9 dinars le kilo en coque.'),
  (4,  4, 'question', null, '3 days 5 hours',
   'لقيت دودة بيضاء كبيرة في جذع شجرة يابسة. هل هي الكابنودس؟ شنوة نعمل؟'),
  (5,  5, 'tip',      null, '4 days 2 hours',
   'نصيحة: بعد الصابة نظّفوا الأرض من اللوز اللي طاح، فيه الحشرات والفطريات اللي ترجع في الربيع.'),
  (6,  1, 'question', null, '6 days',
   'الأوراق فيها ثقوب صغار ونقط بنية، وطاحت بكري هذا العام. شنوة هذا المرض؟'),
  (7,  6, 'question', null, '8 days 4 hours',
   'نحب نغرس 50 شجرة لوز جديدة. وقتاش أحسن وقت للغراسة؟'),
  (8,  8, 'tip',      null, '10 days',
   'Astuce : après la récolte, faites sécher les amandes à l''ombre 3 ou 4 jours avant de les stocker, sinon elles moisissent.'),
  (9,  2, 'question', null, '12 days 6 hours',
   'هل لازم نزبّر شجر اللوز كل عام؟ ووقتاش؟'),
  (10, 3, 'question', null, '15 days',
   'الشتاء ما جاتش والبئر نقص. كيفاش نقسم الماء بين الزيتون واللوز؟'),
  (11, 7, 'question', null, '18 days 2 hours',
   'Mes jeunes arbres ont de la gomme qui coule sur le tronc. C''est grave ?'),
  (12, 5, 'question', null, '21 days',
   'قداش تعطي شجرة اللوز من كيلو في العام؟ هذا أول عام صابة عندي.'),
  (13, 1, 'tip',      null, '25 days',
   'نصيحة لصحاب النحل: في الربيع الجاي حطّوا الجباحة قرب اللوز وقت التنوير، الصابة تزيد برشا.'),
  (14, 6, 'question', null, '30 days',
   'كمّلنا الجني. شنوة أحسن طريقة باش نقشّر اللوز؟ بالآلة ولا باليد؟'),
  (15, 4, 'question', null, '38 days',
   'الشهيلي حرق الأوراق في جويلية. هل الشجرة توا في خطر؟');

insert into posts (id, author_id, type, text, photo, date, updated_at)
select ('de000000-0000-4000-9000-' || lpad(p.n::text, 12, '0'))::uuid,
       f.id, p.type, p.text, p.photo, now() - p.ago, now() - p.ago
from demo_posts p
join demo_farmers f on f.n = p.author
on conflict (id) do nothing;


-- ---------- 3) The answers (a real conversation under each post) ----------
create temp table demo_comments (
  post    int,
  k       int,          -- order under the post
  author  int,
  after   interval,     -- how long after the post
  text    text
) on commit drop;

insert into demo_comments values
  (1, 1, 1, '10 minutes', 'صارت عندي زادة العام الفارط. بعد العطش والمطر الشجرة تتغلط وتنوّر قبل وقتها.'),
  (1, 2, 9, '25 minutes', 'الزهرة سليمة، لكن التنوير في الخريف يضعف الشجرة ولا يعطي غلة. إذا كانت الأزهار قليلة نحّيها، ولا تسقي بكثرة توا.'),
  (1, 3, 2, '40 minutes', 'يعطيك الصحة يا سي سامي. نزيد نسمّد ولا نستنى؟'),
  (1, 4, 9, '55 minutes', 'استنّي للشهر الجاي، وحطّي الغبار (السماد العضوي) في نوفمبر.'),
  (1, 5, 7, '70 minutes', 'Même chose chez moi à Sfax, une dizaine d''arbres ont fleuri.'),
  (1, 6, 3, '90 minutes', 'الحمد لله ما صارتش عندي، أما باش نرد بالي.'),

  (2, 1, 9, '2 hours',  'بعد الصابة الشجرة تحتاج الماء باش تحضّر عيون العام الجاي. في الأرض الرملية: مرة كل 10 أيام حتى يجي المطر.'),
  (2, 2, 4, '3 hours',  'أنا نسقي بالقطرة، ساعتين لكل شجرة، ونوقف كي تطيح الشتاء.'),
  (2, 3, 3, '5 hours',  'باهي، يعطيكم الصحة.'),
  (2, 4, 5, '7 hours',  'ما تنساش تفقّد القطّارات، الطين يسدّهم.'),

  (3, 1, 8, '1 hour',   'À Zaghouan c''est entre 9 et 11 dinars pour la bonne qualité.'),
  (3, 2, 1, '3 hours',  'في سوق صفاقس السوم يتبدل حسب النوع والنظافة. استنى شوية، ساعات يطلع في ديسمبر.'),
  (3, 3, 7, '5 hours',  'Merci, je vais attendre un peu alors.'),

  (4, 1, 9, '1 hour',   'على الأغلب يرقة الكابنودس. اقلع الشجرة اليابسة وحرقها باش ما ينتقلش للشجر الآخر.'),
  (4, 2, 6, '4 hours',  'عندنا في المهدية برشا منه العام هذا، خاصة في الشجر العطشان.'),
  (4, 3, 9, '6 hours',  'صحيح، الكابنودس يحب الشجر الضعيف. السقي المنتظم أحسن وقاية.'),
  (4, 4, 4, '9 hours',  'باهي، توا نقلعها.'),

  (5, 1, 2, '2 hours',  'نصيحة باهية، يعطيك الصحة.'),
  (5, 2, 3, '6 hours',  'وأنا نزيد نحرث خفيف تحت الشجر.'),
  (5, 3, 9, '1 day',    'صحيح، وهذا ينقص زادة من مرض المونيليا في الربيع.'),

  (6, 1, 9, '3 hours',  'هذا مرض تثقّب الأوراق. يكثر مع الرطوبة. رشّ بمبيد نحاسي بعد ما تطيح الأوراق وقبل التنوير.'),
  (6, 2, 7, '5 hours',  'J''ai eu le même problème l''an dernier, le cuivre a bien marché.'),
  (6, 3, 1, '8 hours',  'المبيد النحاسي نلقاه عند بائع الأدوية الفلاحية؟'),
  (6, 4, 9, '10 hours', 'إيه، واتبع الكمية المكتوبة على العلبة بالضبط.'),

  (7, 1, 9, '2 hours',  'من نوفمبر حتى فيفري، والشجرة راقدة. اختار شتلات سليمة ومطعّمة.'),
  (7, 2, 2, '5 hours',  'أنا غرست في ديسمبر وجات باهية.'),
  (7, 3, 3, '9 hours',  'خلّي بين الشجرة والشجرة 6 أمتار على الأقل.'),
  (7, 4, 6, '1 day',    'وشنوة أحسن نوع للمهدية؟'),
  (7, 5, 1, '1 day 3 hours', 'اسأل في المندوبية الجهوية للفلاحة، يعطيوك الأنواع اللي تنجح في جهتك.'),

  (8, 1, 7, '3 hours',  'Bon conseil. Moi je les mets sur des bâches dans le hangar.'),
  (8, 2, 5, '1 day',    'صحيح، الرطوبة تخسّر اللوز. وأنا نحطّهم في شكاير خيش.'),
  (8, 3, 8, '1 day 2 hours', 'Oui, les sacs en jute, c''est parfait.'),

  (9, 1, 9, '2 hours',  'التزبير الخفيف كل عام في الشتاء، بعد ما تطيح الأوراق. نحّي الفروع اليابسة والمتشابكة في الوسط باش يدخل الضوء.'),
  (9, 2, 1, '6 hours',  'ما تزبّرش برشا، اللوز ما يحبش التزبير القوي.'),
  (9, 3, 4, '1 day',    'ونظّف المقص بالجافال بين شجرة وشجرة.'),
  (9, 4, 2, '1 day 4 hours', 'فهمت، يعطيكم الصحة.'),

  (10, 1, 9, '4 hours', 'في الخريف اللوز يستحمل العطش أكثر من الربيع. خلّي الماء للزيتون توا، ورجّع للوز قبل التنوير.'),
  (10, 2, 5, '1 day',   'أنا غطّيت الأرض تحت الشجر بالتبن باش ما تنشفش بالزربة.'),
  (10, 3, 3, '1 day 5 hours', 'فكرة باهية التبن، نجرّبها.'),

  (11, 1, 9, '3 hours', 'La gomme vient souvent d''une blessure, d''un excès d''eau ou d''un champignon. Nettoyez la plaie et n''arrosez pas contre le tronc.'),
  (11, 2, 8, '6 hours', 'Chez moi c''était le goutteur, trop près du tronc.'),
  (11, 3, 7, '9 hours', 'Effectivement, le goutteur touche le tronc. Merci !'),
  (11, 4, 1, '1 day',   'الصمغ يجي زادة كي تجرح الشجرة بالمحراث. ردّ بالك.'),

  (12, 1, 4, '5 hours', 'تبدا تعطي من العام الثالث، والشجرة الكبيرة المسقية تعطي بين 8 و15 كيلو بالقشرة.'),
  (12, 2, 1, '9 hours', 'في البعلي أقل برشا، حسب الشتاء.'),
  (12, 3, 9, '1 day',   'التسميد والسقي في وقت التنوير يفرقوا برشا في الصابة.'),
  (12, 4, 5, '2 days',  'إن شاء الله العام الجاي خير.'),

  (13, 1, 2, '4 hours', 'صحيح، جاري حط النحل والصابة عنده خير منّا.'),
  (13, 2, 6, '1 day',   'وما ترشّوش المبيدات وقت التنوير باش ما تقتلوش النحل.'),

  (14, 1, 7, '6 hours', 'Il y a une machine à la coopérative de mon village, ils prennent 300 millimes le kilo.'),
  (14, 2, 3, '1 day',   'عندنا نقشّروا مع العايلة، ياخذ وقت أما اللوز يبقى سالم.'),
  (14, 3, 6, '1 day 6 hours', 'باهي، نسأل على الآلة في التعاضدية.'),

  (15, 1, 9, '5 hours', 'إذا كانت العيون خضراء تحت القشرة، الشجرة لاباس. اسقِ بانتظام حتى يجي المطر.'),
  (15, 2, 5, '1 day',   'عندي نفس المشكل في القصرين، الشجر رجع ورّق بعد السقي.'),
  (15, 3, 4, '2 days',  'شفت العيون خضراء، الحمد لله.'),
  (15, 4, 2, '2 days 3 hours', 'الحمد لله، ربي يبارك.');

insert into comments (id, post_id, author_id, text, created_at, updated_at)
select ('de000000-0000-4000-a000-' || lpad((c.post * 10 + c.k)::text, 12, '0'))::uuid,
       ('de000000-0000-4000-9000-' || lpad(c.post::text, 12, '0'))::uuid,
       f.id, c.text,
       least(now() - p.ago + c.after, now() - interval '1 minute'),
       least(now() - p.ago + c.after, now() - interval '1 minute')
from demo_comments c
join demo_posts p on p.n = c.post
join demo_farmers f on f.n = c.author
on conflict (id) do nothing;


-- ---------- 4) Last check: everything is there, or nothing is saved ----------
select count(*) into people_count
from profiles p join demo_farmers d on d.id = p.id where p.is_demo;
select count(*) into posts_count
from posts where author_id in (select id from demo_farmers);
select count(*) into answers_count
from comments where author_id in (select id from demo_farmers);

if people_count <> 9 or posts_count <> 15 or answers_count <> 56 then
  raise exception 'Demo data not complete: % people, % posts, % answers (expected 9, 15, 56). Nothing was saved.',
    people_count, posts_count, answers_count;
end if;

end
$$;

-- What is in the database now (should say 9, 15, 56):
select (select count(*) from profiles where is_demo) as demo_people,
       (select count(*) from posts p join profiles a on a.id = p.author_id where a.is_demo) as demo_posts,
       (select count(*) from comments c join profiles a on a.id = c.author_id where a.is_demo) as demo_answers;
