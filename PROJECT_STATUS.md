# Looz — project status

Last update: 14 November 2026 (photo diagnosis Bêta, Milestone 1 built: migration 016 run, Edge Function "diagnose" to deploy; zone letters أ ب ج د in Arabic).

> **⚠ Before a real launch: turn the DEMO LOGIN off** (section 5). While it is on, anyone who types a
> phone number can open that account: any 6-digit code works. Turn the **demo payment** off too
> (section 9) once a real payment provider is set up.

> **⚠ Supabase Free pauses a project after 1 week without activity — check it before the jury.**
> Open the Supabase dashboard a few days before: if the project says "Paused", click "Restore"
> (it takes a few minutes). The Free plan has no automatic backup: the demo data can be made again
> with the seeds (section 7).

## 1. What works today

| Module | Status | Data |
| --- | --- | --- |
| Design (23 screens of the Figma, Arabic right to left + French) | Done | — |
| Start of the app: start screen, sign in, sign up (who are you → information → pack) | Done | **Real** (Supabase) |
| Login with the phone | Done as a **demo login** (any number, any code, no SMS) | **Real** accounts and sessions (Edge Function `demo-auth`) |
| **Two packs**: Free and Premium (8 DT per zone / 30 days) | Done | **Real** (database rules + app) |
| Payment of Premium: the bill comes from the database (zones of the orchard) | Done as a **demo** (no real money) | **Real** database, demo card |
| **My orchard in 3D** (Premium): the farmer's real orchard, zones, trees, sensor boxes | Done | **Real** (Supabase). Sensor readings not yet: "قريبًا" |
| **Orchard designer** (section 3): draw the orchard on a grid, cut it into zones, the bill, pay, the orchard is built → 3D | Done (grid). Satellite map: "قريبًا" (Phase 5). Editing later: Phase 4 | **Real** (Supabase, migration 011) |
| Profile: name, phone, my pack, its zones and end date, log out | Done | **Real** (Supabase) |
| Community: questions, answers, delete, photos | Done | **Real** (Supabase + Storage) |
| **Alerts** (section 15): the tab "التنبيهات" with the regional alerts of the farmer's governorate, the number on the bell, an alert's screen ("ماذا أفعل؟" in steps, until when, "أنا أيضًا", "تمّ"), the most important alert on Home | Done (Phase 1, 14 Nov 2026). Sensor alerts "بستاني" and voice / push: "قريبًا" | **Real** (Supabase, migration 015) |
| **"إبلاغ / Signaler"** in the community (section 15): on the question and the answers of others, 4 reasons, "✓ أبلغت" | Done (14 Nov 2026) | **Real** (`report_content()` of 013) → Dashboard › Communauté › Signalements |
| **Photo diagnosis (Bêta)** (section 16), paid pack: camera or photo → "جاري النظر…" → "على الأرجح" / "غير متأكد" / "لم نجد هذه الأمراض الثلاثة", the photo with the sick spots marked, 2-3 first steps (drafts), "اسأل خبيرًا" = a community question with the photo | Milestone 1 built (14 Nov 2026). History, zone choice: Milestone 2 | **Real**: Roboflow model through the Edge Function `diagnose` (migration 016) |
| Home (weather), assistant and voice ("قريبًا" at the end, no fake answer), map, journal, tips | Screens done | **Fake** data (`mobile_app/lib/data/fake_data.dart`). A tree on the map says "قريبًا" |
| **Sensor boxes → Supabase** (section 12): Node-RED of the farm (`iot/node-red/`) sends the readings once a minute to the Edge Function `iot-ingest` | Done (Milestone 1) with the **simulated** boxes NODE-01…04 of the IoT demo farmer | **Real** Supabase (migration 012), simulated boxes |
| Admin dashboard (`dashboard/`), **in French** (section 14): login + "Connexion démo", Vue d'ensemble, Agriculteurs (live boxes, 3-day charts, accept / remove), Utilisateurs (expert badge, block), Communauté (hide / show again / delete, reports), Alertes (regional alerts in Arabic + French with the preview, sensor alert log), Vergers (plan), Capteurs, Abonnements (bills, payments, price), Réglages (the switches), Journal des actions | **Phases A–D built** (A: 12 Nov, B–D: 13 Nov 2026). Migration 014 (the database keeps the demo admin on demo data) run on 13 Nov | **Real** (Supabase, admin login; every change through a checked function + admin action log, migrations 013 and 014) |

The list of every screen and how it was checked: `mobile_app/SCREENS_CHECKLIST.md`.

## 2. The two packs (migration 011)

| | Free | Premium |
| --- | --- | --- |
| Price | 0 | **8 DT per zone / 30 days** (1 zone = 1 LOOZ sensor box, installed by us) |
| Community, alerts of the region | ✓ | ✓ |
| My orchard in 3D, smart alerts, predictions, photo diagnosis, assistant and voice | — | ✓ |

- **The bill** = the zones the farmer drew, but at least **1 zone per 2 hectares** (drawing 1 zone on
  10 ha still bills 5). An admin can replace this minimum with the real number of boxes installed
  (section 10). The app never computes the price: it asks the database (`orchard_quote()`).
  - No pack yet, or the pack has ended → a new month: zones × 8 DT.
  - Pack still running and more zones drawn → only the **extra zones**, for the days left.
  - Pack still running, same zones → paying adds **the next month** ("جدّد باقتك").
- **No orchard built yet** (nothing, or a draft) → "★ ابدأ بريميوم" opens **"ارسم بستانك"**:
  the designer (section 3). Its review shows the bill, then pays and builds the orchard.
- **Free users**: the "بستاني ★" tab shows the locked screen ("★ ابدأ بريميوم"). The camera
  button, the assistant bar and "تكلّم" lead there too.
- **The old packs** (Essential 15 DT, Connected 8 DT per sensor) are gone. Their paid subscribers
  became **Premium** with the same end date (Connected kept its number of sensors). Their old
  payments keep the old name (history). Open kit requests of the old Connected flow were cancelled
  with a note.

## 3. The orchard designer (Phase 3)

Files: `mobile_app/lib/features/orchard_designer/` (the maths in `geometry.dart`). The app only
calls the functions of migration 011: `orchard_save_design`, `orchard_quote`, `demo_payment`,
`orchard_apply_design`, `orchard_discard_design`. No new migration was needed.

1. **"ارسم بستانك"**: 3 steps, the price per zone, how to draw: "بإصبعك، على شبكة" (now) or
   "على صورة القمر الصناعي" (**"قريبًا"**, Phase 5). A draft saved before: "★ أكمل الرسم" (it
   opens where the farmer stopped) or "ابدأ من جديد" (after a question, the draft is erased).
2. **Step 1, the outline** (a grid, north at the top):
   - "قلم": the finger (or the mouse) goes around the orchard; the app straightens the sides
     and closes the shape. "نقاط": a tap on each corner, a tap on the first one closes it.
   - Drag a corner to move it. "تراجع", "إعادة", "امسح" (erase; it can be undone).
   - "العرض" / "الطول": the size in metres (5 to 3000), typed in a sheet; the drawing takes it.
     The area is shown in hectares.
   - Crossing sides: "خطّان يتقاطعان. حرّك نقطة." and no "التالي". Too small: a message.
3. **Step 2, the zones** (one sensor each, 20 at most):
   - "أعطي عدد المناطق والأشجار": how many zones (2 at first, or 1 per 2 ha) and the trees of
     each → straight strips, their areas proportional to the trees (west or north first).
   - "أرسم خطوط التقسيم بنفسي": drag a line across; it cuts the zones it goes over. "تراجع",
     "امسح". A line that misses: "الخط لم يقسم أي منطقة.".
   - Then each zone: its trees (at least 1), type (أشجار صغيرة، أشجار كبيرة، تربة رملية، مسقية،
     بعلية، أخرى), name (optional, 30 letters) and colour (10).
4. **Step 3, the review**: area, zones, trees, sensors and the price, from the database. When
   the area minimum applies, one sentence: "بستانك 10 هكتار: يلزمه 5 حسّاسات على الأقل." with
   a tip: "قسّمه إلى 5 مناطق بنفس السعر.". Then "★ ادفع وابنِ بستاني" → the demo payment →
   "جاري بناء بستانك…" → (sign-up) the welcome → "بستاني ★" in 3D. The pack already covers
   it: "★ ابنِ بستاني" (no payment). More than 100 sensors: "اتصل بنا" (one pack has 100 at most).
5. **What the database builds**: the outline and area, the zones, one sensor per zone ("في
   انتظار التركيب" in the 3D), the trees in rows, and one installation visit (`kit_requests`).
6. **The draft** is saved after every step ("التالي"), so the farmer goes on where he stopped,
   even on another phone. Paid but not built (no internet): "★ ابنِ بستاني" on the review.

## 4. The start of the app (how it works now)

- **Start screen**: the almond-blossom photo, "عربي | FR" (remembered on the phone),
  "إنشاء حساب" (sign up) and "تسجيل الدخول" (sign in).
- **Sign in**: phone → code → Home. A number with no account gets
  "لا يوجد حساب بهذا الرقم." and a button "إنشاء حساب" (nothing is created).
- **Sign up**: phone → code → **"من أنت؟"** ("فلاح" or "مهندس فلاحي أو مرشد") → **"معلوماتك"**:
  - first name, last name, governorate (24), all required;
  - farmers, optional: almond trees, area in hectares, irrigated / rain-fed;
  - experts, optional: only their organisation (no orchard boxes).
- **Farmer, then the pack**:
  - Free → welcome → Home.
  - Premium → **"ارسم بستانك"** → the designer (section 3) → pay at the review → the orchard
    is built → welcome → "بستاني ★" in 3D. Or "متابعة مجانًا" → welcome → Home on Free (the
    drawing stays saved).
- **Expert**: no pack, no payment → welcome → Home. The "◆ خبير موثّق" badge appears only after an
  admin verifies them (section 10).
- **A number that already has an account**: "هذا الرقم لديه حساب بالفعل." + "تسجيل الدخول".
- **Stopped in the middle** (no information, no pack, or Premium chosen and not paid): the next
  login opens the missing step ("ارسم بستانك" for Premium, with "★ أكمل الرسم" if he drew).
- **Errors** (no internet, wrong code...) show a neutral warning icon (▲!).

## 5. Demo login (any number, any code) — TURN IT OFF BEFORE A REAL LAUNCH

**What it does.** While `app_settings.demo_login_enabled` is `true`:

- any Tunisian number (+216 and 8 digits) and **any 6 digits** log in, for sign in and sign up;
- **no SMS** is sent; the phone and code screens look exactly the same;
- a new number + "إنشاء حساب" gets a real account (phone confirmed) and a normal session.

**How it works.** The app asks the Edge Function **`demo-auth`** (`supabase/functions/demo-auth/index.ts`).
Only the function has the `service_role` key (Supabase gives it to the function; it is never in the
app). The function checks the switch, makes the account if needed and returns a normal Supabase
session. Its limits:

- admins can never be opened this way (they use their e-mail on the dashboard);
- at most 60 new demo accounts per hour for the whole app;
- every account it makes is marked `demo_login: true` (in its app metadata).

**Why it must be off for a real launch.** While it is on, **anyone who types a phone number can open
that account** (and see that person's profile, pack, orchard and posts). It is only for demos and
tests.

**How to turn it off** (takes effect at once, no new app needed):

1. Supabase › Table Editor › `app_settings` (one row).
2. Set `demo_login_enabled` to `false` and save.

Then the app uses the normal Supabase SMS code again. **Before that**, set up a real SMS provider in
Supabase › Authentication › Sign In / Providers › Phone; otherwise only the 5 test numbers of
section 6 can log in. To turn the demo back on: `true`.

**The demo accounts.** To list them (read only, in the SQL Editor):

```sql
select phone, created_at from auth.users
where raw_app_meta_data->>'demo_login' = 'true' order by created_at;
```

Delete the ones you don't need in Supabase › Authentication › Users (their profile goes with them).

**If you deploy `demo-auth` again** (Edge Functions › `demo-auth` › edit › Deploy): check in its
settings that **"Verify JWT" is still off**. If the function is missing, the app quietly uses the
normal SMS code.

## 6. Run the app

Put the Supabase URL and the **publishable** key in `mobile_app/.env` (see `mobile_app/.env.example`).
Never put the `service_role` key in the app.

```powershell
cd mobile_app
flutter pub get
flutter run -d chrome --dart-define-from-file=.env
```

With the demo login on, **any number works** (type only the 8 digits: "+216" is already there) with
**any 6 digits** as the code.

**Numbers already used** (they have accounts):

| Number | Used for |
| --- | --- |
| +216 50 000 001 ... 005 | Supabase test numbers (code `123456`, also without the demo login): auth, community, sign-up and payment live tests. 04 = Premium, 1 zone, no orchard. 05 = Free (its kit request was cancelled by 011) |
| +216 22 999 001 / 003 | Demo login live test: farmer / expert |
| +216 22 999 002 | Demo login live test: must **never** get an account ("no account" check) |
| +216 22 123 456 | **Premium with the demo orchard** (seed): 4 zones, until 3/12/2026. Use it to see "بستاني ★" in 3D |
| +216 22 123 457 | **Free** farmer: the locked screens |
| +216 22 123 458 | Expert |
| +216 22 98x xxx | **Designer tests** (live test and Chrome): each run makes a NEW account with its orchard. Delete them (section 10) |
| +216 22 777 001 | **IoT demo farmer "Demo IoT"** (Sfax, Premium 90 days, until 9/2/2027): the orchard of the Node-RED simulation (seed `iot_demo_farmer.sql`, section 12). Its 3D shows the trees #12…#92 like Node-RED |

## 7. Database and Edge Function (Supabase)

Run the files in **Supabase > SQL Editor**, in this order. Every file can be run again safely.

1. `supabase/looz_schema.sql`
2. `supabase/looz_policies.sql`
3. `supabase/migrations/002_zones_and_nodes.sql`
4. `supabase/migrations/003_node_sensors_and_tree_photos.sql`
5. `supabase/migrations/004_subscription_plans.sql`
6. `supabase/migrations/005_phone_auth_profiles.sql`
7. `supabase/migrations/006_community.sql`
8. `supabase/migrations/007_community_photos.sql`
9. `supabase/migrations/008_signup_profile_payment.sql`
10. `supabase/migrations/009_demo_payment_kits_roles.sql`
11. `supabase/migrations/010_demo_login.sql`
12. `supabase/migrations/011_two_packs_orchard_designer.sql`
13. `supabase/migrations/012_iot_link.sql` (check line: `true | 30 | false | false | true | true | true`)
14. Optional, the demo orchard of +216 22 123 456: `supabase/seed/orchard_demo.sql`
    (to remove it: `supabase/seed/orchard_demo_delete.sql`, it only touches 22 123 456).
15. Optional, the IoT demo farmer +216 22 777 001: make the account in the app first (demo login,
    "فلاح", Sfax, free pack), then `supabase/seed/iot_demo_farmer.sql`. The last column of its
    check line is the **gateway key**: paste it in `iot/node-red/.env` (section 12), never anywhere
    else. Every run makes a NEW key and a fresh orchard. To remove it:
    `supabase/seed/iot_demo_farmer_delete.sql` (`0 | 0`).
16. Optional, demo questions for the community: `supabase/seed/community_demo.sql`
    (to remove them: `supabase/seed/community_demo_delete.sql`).
17. `supabase/migrations/013_admin_dashboard.sql` (check line: `0 | true | false | true | false | 0 | 0`).
    ⚠ If you ever run `looz_policies.sql` or a migration 002–012 again, run 013 again afterwards
    (they bring back the old "Admins manage …" rules).
18. Optional, the demo admin of "Connexion démo" (section 14): first Authentication › Users › Add
    user `admin-demo@looz-demo.invalid`, then `supabase/seed/demo_admin.sql`
    (`admin-demo@looz-demo.invalid | admin | Démo Admin | true | 6 | 0 | false`). To remove it:
    `supabase/seed/demo_admin_delete.sql` (`false | 0 | 0`).
19. `supabase/migrations/014_demo_admin_database.sql` (check line: `0 | 26 | true | 16 | false`; the
    16 = the demo people: the 6 demo numbers, the demo admin and the 9 fake people of the community).
    ⚠ If you ever run 012 or 013 again, run 014 again afterwards (they bring back the old "Admins
    see …" rules).
20. `supabase/migrations/015_app_alerts.sql` (check line: `true | false | false | true | true`): the
    alerts tab of the app (section 15). Run it after 014. Running 013 or 014 again does not undo it.
21. `supabase/migrations/016_photo_diagnosis.sql` (check line: `true | false | false | true | 10 | 1000 | 0.65 | 0.4`):
    the photo diagnosis (section 16). If you run 014 again after it, 014's second number is 28 (not 26).

Then the **Edge Functions** (Edge Functions › Deploy a new function › Via Editor › paste the file ›
name › Deploy function; then in its settings turn **"Verify JWT" off**; no secret to add):

| Name | File | Why Verify JWT is off |
| --- | --- | --- |
| `demo-auth` | `supabase/functions/demo-auth/index.ts` | the app calls it before the login |
| `iot-ingest` | `supabase/functions/iot-ingest/index.ts` | Node-RED has no Supabase login: the function checks the gateway key itself |

And ONE function with **"Verify JWT" ON** (only logged-in users):

| Name | File | Secret (Edge Functions › Secrets) |
| --- | --- | --- |
| `diagnose` | `supabase/functions/diagnose/index.ts` | `ROBOFLOW_API_KEY` = the **Private API Key** of the Roboflow workspace (never in the app, never in git). Optional: `ROBOFLOW_MODEL` (default `almond-diseases-detection-l7tfx/2`). Never add `ROBOFLOW_URL` (tests only) |

All 12 SQL files and the demo orchard are in the real database, and `demo-auth` answers (checked on
9 November 2026 by `test_live/database_check_test.dart`, `orchard_live_test.dart` and
`demo_login_live_test.dart`). 012 and the IoT demo farmer were run by you on 11 November 2026;
013, `demo_admin.sql` and the "Connexion démo" switch on 12 November 2026. 014 on 13 November 2026.
015 on 14 November 2026 (its 5 functions answer: checked the same day).

## 8. Tests

From `mobile_app/`:

| Command | What it checks | Last result |
| --- | --- | --- |
| `flutter analyze` | The code | No issues |
| `flutter test` | All the screens and flows, with a fake login (also in demo mode), fake payment, fake orchard and fake community; the real login code with a fake web server (no internet). The designer: `test/geometry_test.dart` (area, clean-up of the drawing, crossing sides, automatic split, dividing lines) and `test/designer_test.dart` (every step, finger and mouse, resume, errors, French, a 360 x 640 phone). Tree numbers from the codes ("12", "TREE-012"): `test/orchard_3d_data_test.dart`. The alerts: `test/alerts_test.dart` (order, bell, "جديد", steps, "أنا أيضًا", "تمّ", ended while open, no alert, no internet, pull down, every minute, back to the app, French, Home). "إبلاغ": `test/report_test.dart`. The photo diagnosis: `test/diagnosis_test.dart` (camera, "جاري النظر…", the 3 results, the marks, "اسأل خبيرًا" → the question with the photo, every failure, the limits, Free = locked, French, the plurals, the assistant says "قريبًا", the zone letters أ ب ج د) | 246 / 246 pass |
| `python tool/find_hardcoded_texts.py` | No text written in the code (all texts in `lib/l10n/*.arb`) | 0 |

**Live tests**: against the real Supabase. They need internet and `mobile_app/.env`.
Run each one with `--dart-define-from-file=.env`.

| File | What it does | Last result |
| --- | --- | --- |
| `test_live/database_check_test.dart` | Are all the SQL files in the database? (read only) | 12 / 12 |
| `test_live/designer_live_test.dart` | A NEW number: sign up → Premium → draw (5 corners, 150 x 100 m) → 2 automatic zones → the review (16 DT) → pay → built → "بستاني ★" in 3D; then the database (orchard, 2 zones, 2 waiting sensors, ~300 trees, pack, payment, installation visit) and its rules | 2 / 2 |
| `test_live/orchard_live_test.dart` | The demo orchard of 22 123 456; the app reads it and builds the 3D; in the app "بستاني ★" shows it; Premium → bill 32 DT for 4 zones, refused test card changes nothing; a Free account sees no orchard | 5 / 5 |
| `test_live/signup_payment_live_test.dart` | 04 (old Essential) is Premium now, 1 zone, same end date, "ارسم بستانك"; 05's kit request cancelled, Free, locked → "ارسم بستانك"; 20 database rules (no free pack, no price change, no orchard written by hand...) | 4 / 4 |
| `test_live/demo_login_live_test.dart` | `demo-auth` answers; sign up with a new number and any code (farmer, expert), sign in with another code, "no account", the rules | 6 / 6 |
| `test_live/auth_live_test.dart` | Sign in 01 and 02, the security rules of the profiles | 5 / 5 |
| `test_live/community_live_test.dart` | Questions, answers, rules (01, 02, 03) | 6 / 6 |
| `test_live/community_photo_live_test.dart` | Photos in Storage (01, 02) | 3 / 3 |

Example:

```powershell
flutter test test_live/orchard_live_test.dart --dart-define-from-file=.env
```

The numbers of the live tests have accounts now: the sign-up tests then check "account exists"
instead. To test them as new users again, delete them in Supabase > Authentication > Users.

**Admin dashboard API** (from `dashboard/backend`, venv active; first time `pip install -r requirements-dev.txt`):

| Command | What it checks | Last result |
| --- | --- | --- |
| `pytest` | No internet, fake tables and fake database functions (also "ouverte par / fait par" of the alerts, and the page without migration 015): only admins (401 / 403), the farmers list and page, the demo admin sees demo accounts only (and never a real admin's name), "Vue d'ensemble", the 3 days (window on the latest measure, alert log, sensor problems grouped, actions), Capteurs (waiting first, visits, gateways without key, log), every action calls its checked function and every refusal of the database becomes a French message (reason, device code, demo admin...), "Connexion démo" (switch, password only in `.env`, 127.0.0.1 only, other websites refused, not an admin → refused, one login per 3 s), CORS localhost + 127.0.0.1, a value the box flags as wrong is not drawn. **Phase B**: accounts (e-mail of admins only, "New user" never shown), expert badge, block, posts newest first with every answer, private photo link (5 min), hide / show again / delete (the photo removed from Storage), reports. **Phase C**: regional alerts (states, "Moi aussi", create / change / end, every check of the database in French), sensor alert log (filters). **Phase D**: orchards and their plan (drafts too), the bill (same rule as the app), subscriptions, payments, price, settings, the action log 100 lines at a time | 115 / 115 pass |
| `pytest tests_live -v` | **Real Supabase, Node-RED running**: needs `LIVE_ADMIN_EMAIL` and `LIVE_ADMIN_PASSWORD` in `dashboard/backend/.env` (skipped otherwise). Phase 1 and **Phase A** (Milestone A: NODE-04 "Retirer" → refused → "Accepter" → received again). **Milestone B**: the demo expert 22 123 458 verified → the app shows "◆ خبير موثّق" (and next to an answer she writes, then deletes; she STAYS verified), a demo post hidden → gone from the app → shown again. **Milestone C**: a heat alert for Sfax → 22 777 001 reads it, 22 123 457 (Kairouan) does not → changed → ended. **Milestone D**: the price 8 → 9 DT → the app's bill and the dashboard's bill change, the log says 8 → 9 DT → back to 8 DT. **App module** (`test_live_app_alerts.py`): the jury scenario (section 15) with Connexion démo. `test_live_014.py` (after 014): the demo admin's own token reads demo rows only through the Supabase API, and "Vue d'ensemble" counts what its lists show | 39 / 39 pass (13 Nov 2026, Node-RED running): IoT 8, A 9, B 6, C 5, D 6, 014 5. 14 Nov 2026: app module 3 pass + 1 skipped (22 777 001 has no post of his own), C 5 and 014 5 again; photo diagnosis `test_live_diagnosis.py` 4 / 4 (with `LIVE_LEAF_PHOTO` / `LIVE_OTHER_PHOTO` paths, each photo = 1 of the 10 of the day of 22 777 001) |

**Frontend** (from `dashboard/frontend`): `npx tsc --noEmit`, `npm run lint`, `npm run build`: no error.

**The SQL on the laptop** (no Supabase): 013 + `demo_admin.sql` (99 checks) and 014 (64 checks:
real admins and the app read exactly what they read before, the demo admin only demo rows in every
table, view and photo, its overview counts its lists, a demo alert never reaches a real farmer)
were tested on a local PostgreSQL 17, run the 3 ways of the SQL Editor and again. 015: 89 checks (the
list = exactly what the rules of 014 show, for 10 kinds of users; order; new after a change; done;
"Moi aussi" once; every refusal; reports; the jury scenario; 013 + 014 + 015 run again). 016: 73 checks
(the app writes nothing; paid pack, switch, zone; the verdict from the thresholds; every wrong result
refused; the limits of the day, two photos at once; 30 photos kept; who reads what; 013-016 again).
The Edge Function `diagnose`: 33 checks under Deno with a fake Roboflow and a stand-in of Supabase
(login, bad photos, Free farmer, a sick leaf with its boxes, nothing, a weak guess, no credits (402),
busy once (503), down, nonsense, the photo not saved, switch off, limits, old photos deleted, 25 s
timeout, the key never in the logs). The IoT part: the
SQL of 012 and the seeds (91 checks), the Edge Function under Deno with a local stand-in of Supabase (14
checks), and the real Node-RED flow sending to it (all readings accepted, the clock continues after
a restart).

## 9. What is demo or fake

- **Login = DEMO** (section 5): any number, any code, no SMS. Turn it off before a real launch.
- **Payment = DEMO.** No money moves, there is no payment provider.
  - The card boxes only *look* real: the app checks the format (16 digits, a date, 3 digits,
    a name), then clears them.
  - The card is never saved, never sent (not to Supabase, not anywhere), never in a log or a test.
  - The database only records "paid_demo" or "failed_demo", with the amount and the zones.
  - The test card **4000 0000 0000 0002** is always refused, to show the "not paid" screen.
    Any other well-formed card is accepted.
  - The payment screen shows a small "وضع تجريبي / Mode démo" label.
  - The code is ready for a real provider: only `DemoPaymentService` in
    `mobile_app/lib/data/payment_service.dart` would change.
- **The demo orchard** of +216 22 123 456 comes from `supabase/seed/orchard_demo.sql`
  (`orchards.is_demo = true`). Its sensor boxes have no readings yet: the 3D shows "قريبًا" for
  soil moisture and temperature.
- **The designer is real** (it saves in Supabase). Only its satellite map is "قريبًا" (Phase 5).
- **Fake data**: Home (weather), assistant, map, journal and tips use
  `lib/data/fake_data.dart`.
- **"Mode test : changer d'offre"** in Profile (debug builds only): switches Free / Premium in the
  app only (not in the database), to see the locked screens.

## 10. Admin how-tos

Prefer the **dashboard**: each change there needs a reason and is written in the action log. The
Table Editor still works (it is not logged).

| To do | Where | How |
| --- | --- | --- |
| **Turn the demo login off** | **Dashboard › Réglages** › "Connexion de démonstration de l'application" › Désactiver (or `app_settings.demo_login_enabled`) | Only after a real SMS provider (section 5): the window asks you to confirm it. |
| Turn the demo payment off | **Dashboard › Réglages** › "Paiement de démonstration" | The app then says "payment not available". |
| Change the price | **Dashboard › Abonnements › Prix › Changer le prix** (shows the effect on the paid packs, asks to confirm) | The price of **one box** for 30 days (8 DT). New payments and renewals use it. |
| Change the minimum per area | **Dashboard › Abonnements › Prix** › Hectares par boîtier | 2 = at least 1 box billed per 2 ha. Empty = bill only the zones drawn. |
| Bill the real number of boxes | `orchards` | `confirmed_nodes` = the boxes really installed (1 to 100). It replaces the area minimum. |
| Installation visits | **Dashboard › Capteurs › Visites d'installation › Modifier** (logged) | Made **by the database** when a paid orchard is built (the designer), with the number of boxes to install. "à planifier" → "agriculteur contacté", or "annulée", plus a note. "Installation faite" comes **by itself** when every box of the orchard is accepted. |
| Verify an expert | **Dashboard › Utilisateurs** › Vérifier (reason to remove it) | The "◆ خبير موثّق" badge appears at once next to their name and answers in the app. |
| Make an admin (dashboard) | `profiles` | `role` = `admin`. |
| **Delete the test accounts** of the designer | Authentication › Users | Search **2298**, then "Delete user" on each (+216 22 98x xxx). Their profile, orchard, zones, sensors, trees and installation visit go with them; their demo payments stay, without the user. |
| Block / unblock an account | **Dashboard › Utilisateurs** › Bloquer (reason required; never an admin) | The account cannot log in; its session ends within an hour. Real deletion: Authentication › Users. |
| Hide, show again or delete a post / answer | **Dashboard › Communauté** › open the post › Masquer / Afficher de nouveau / Supprimer (asks twice) | Hidden: gone from the app at once. Deleted: the log keeps a copy of the text; the photo is removed. |
| A regional alert (frost, heat…) | **Dashboard › Alertes › Nouvelle alerte** (Arabic + French, governorates, dates, the advice **one step per line**, the preview = the app's screen) › Terminer to end it | The farmers (and experts) of those governorates see it in the app's tab "التنبيهات" within a minute (or when they pull the list down), and on Home. Terminer: gone at the next refresh. Each alert shows "N « Moi aussi » · ouverte par N · fait par N". |
| A post or an answer reported by a farmer | **Dashboard › Communauté › Signalements** | Masquer the text (the report becomes "Traité"), or Classer the report if nothing is wrong. |
| **Stop all sensor data** (emergency) | `app_settings` (one row) | `iot_ingest_enabled` = `false`: every gateway is refused (Node-RED keeps its readings and sends them when it is `true` again, up to 5000). |
| **A new key for a gateway** (key lost or seen by someone) | **Dashboard › Capteurs › Passerelles › Nouvelle clé** (or the farmer's page). SQL Editor: `select public.iot_gateway_new_key('GW-01');` | The key is shown **once**: paste it in `iot/node-red/.env` (`LOOZ_GATEWAY_KEY=`), restart Node-RED. The old key stops at once. The log keeps "Nouvelle clé", never the key. |
| Switch a gateway off / on | **Dashboard › Capteurs › Passerelles › Désactiver / Activer** (reason required) | Every reading of that gateway is refused while it is off. |
| Accept / remove a sensor box | **Dashboard**: farmer's page or Capteurs › "Accepter l'installation" (the code printed on the box) / "Retirer" (reason required). SQL Editor: `select public.iot_accept_node(id) from nodes where hardware_id = 'NODE-04';` / `select public.iot_unaccept_node(id, 'the reason') from nodes where hardware_id = 'NODE-04';` | A box not accepted: its readings are refused ("installation non acceptée"). |
| Who did what | **Dashboard › Journal des actions** (every line, filter by kind), and on each page ("Actions des administrateurs") | Table `admin_actions` (read only; written by the functions of 013). Actions in the SQL Editor are logged as "SQL Editor"; the **Table Editor is not logged**: prefer the dashboard. |
| Keep more or less history | **Dashboard › Réglages** › Conservation de l'historique des capteurs | 30 = days of **measured** time per box (readings, sensor alerts and problems; older ones are deleted). |

Users can't do any of these themselves: the database rules refuse it (checked by the live tests).

## 11. Next steps

1. **Orchard designer**
   - Phase 3 (done): draw the outline on a grid, the zones (automatic or by hand), the bill,
     pay, and the orchard is built (zones, one box per zone, trees in rows).
   - Phase 4: edit the orchard later (history kept, extra zones billed for the days left).
   - Phase 5: draw on a satellite map (after choosing a map provider).
2. **Real SMS** (an SMS provider in Supabase Auth), then **turn the demo login off**.
3. **Real payment**: choose the provider (Konnect was compared), add an Edge Function and its
   secret key in Supabase secrets (never in the app), and replace `DemoPaymentService`.
4. **Admin dashboard** (section 14): all pages built (Phases A–D). Next: CRDA admins limited to
   their governorates (a separate step); fix what you find when you test it.
5. **App alerts, Phase 2** (Phase 1 done, section 15): the sensor alerts of a paid farmer in the tab
   ("بستاني / Mon verger": zone, level, simple advice, texts from the codes in the ARB files; a tap
   opens the zone in the 3D) and the real readings in the 3D zone panel. A small migration **017**
   (the state of the farmer's own boxes with the gateway's offline time; 016 is the diagnosis).
6. **Photo diagnosis, Milestone 2** (section 16): "صوري السابقة" (history, on the camera screen and in
   Profile), the zone of the photo (optional), the dashboard page "Diagnostics" (Bientôt). Later: our
   own model trained on Roboflow (dataset v11 + Tunisian photos confirmed by experts, healthy and
   olive leaves as "nothing" examples, RF-DETR = Apache 2.0), only with photos farmers said "yes" to. Zone names in Arabic with Arabic
   letters ("المنطقة ب"), never "المنطقة B". Later: push notifications and reading aloud.
6. **Real sensor readings in the app** (the farmer's view): the 3D and alerts read
   `iot_node_status` / `node_alert_events` (the database rules already allow it), in place of
   "قريبًا" and `fake_data.dart`; then photo diagnosis.
7. Remind farmers before their pack ends (the end date is in `subscriptions.ends_at`).

## 12. IoT: sensor boxes → Supabase → admin dashboard (migration 012)

```
Node-RED (iot/node-red, this laptop)          Supabase                          Admin dashboard
simulated boxes NODE-01…04 → gateway checks   Edge Function iot-ingest          backend (admin's token, RLS)
→ stress indices + level (rules-v1)     ──►   → iot_ingest() checks and saves ──►  → farmers list, farmer page
→ codes, 1 batch per minute (+ key)            node_latest / node_readings /       (French, every 15 s)
                                               node_alert_events / node_fault_days
```

- **The demo farmer** "Demo IoT" (+216 22 777 001, Sfax) has exactly the orchard of the Node-RED
  simulation: zones **A to D** (Node-RED uses the same names now), boxes NODE-01…04, 18 trees
  TREE-012…TREE-092, Nonpareil / Nonpareil / Tuono / Ferraduel, 8 / 10 / 12 / 4 years. NODE-02:
  the irrigation line leaks (its soil dries, the level climbs to "Critique"). NODE-03: hot zone.
  NODE-04: faulty soil probe ("Problème de capteur").
- **Who may send**: a reading is accepted only for a box (by its device code) of the gateway's
  own orchard, **accepted by an admin**, of a farmer with a **running paid pack**. The rest is
  refused and counted (the dashboard says why, e.g. "installation non acceptée").
- **The key** of the gateway: `lgw_` + 64 letters/digits, only in `iot/node-red/.env`
  (`LOOZ_GATEWAY_KEY=`). Supabase keeps only its hash. Never in git, never in a message.
  New key: section 10.
- **Codes only** in Supabase (levels ok / info / watch / warning / critical / sensor, reasons,
  fault codes): the dashboard writes the French texts, the app will write Arabic / French.
- **Time**: "Dernière donnée il y a 40 s" = when Supabase received it (real time). "mesure 16/06
  13:30 · heure simulée" = the Node-RED clock (5 s = 15 min, from 15 June 2026 05:00, Tunisia
  time). The clock is saved on disk: a restart of Node-RED continues it. To start the simulation
  again from 15 June: stop Node-RED, delete `iot/node-red/context`, start it again (Supabase
  starts the history of the 4 boxes again by itself).
- **Volume** (Free plan: 500 MB database, 500,000 Edge Function calls a month): 1 call a minute
  = 43,200 a month; history = 1 point per simulated hour per box, the last 30 days of measured
  time (about 1 MB for the demo, it never grows more).
- **States of a box** on the dashboard: En attente d'installation · Installé, aucune donnée ·
  En ligne · Hors ligne (nothing for 5 min in demo, 35 min for real boxes) · Problème de capteur.
- **Node-RED's own dashboard** (http://127.0.0.1:1881/dashboard) shows the line "Envoi à
  Supabase : ✓ 10:21:05 · 48 acceptée(s)" (or why it failed); the readings wait in memory (up
  to 5000) when Supabase does not answer.

## 13. Run everything on the laptop (4 PowerShell windows, in this order)

```powershell
# 1. Mosquitto (MQTT, localhost:1883). Skip if it already runs (Task Manager: mosquitto.exe).
& "D:\Exec\Mosquitto\mosquitto.exe" -v

# 2. LOOZ Node-RED (only this laptop can open it). First time: npm install (and .env, section 12).
cd "D:\IEEE\aotn chalenge\AOTN-TSYP-chalenge\iot\node-red"
node-red -u .
#    editor http://127.0.0.1:1881 · its dashboard http://127.0.0.1:1881/dashboard

# 3. Admin backend (FastAPI), this laptop only
cd "D:\IEEE\aotn chalenge\AOTN-TSYP-chalenge\dashboard\backend"
.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --host 127.0.0.1 --port 8000

# 4. Admin frontend (Next.js) → http://127.0.0.1:3000, log in with the admin e-mail (or "Connexion démo")
cd "D:\IEEE\aotn chalenge\AOTN-TSYP-chalenge\dashboard\frontend"
npm run dev
```

**Don't run the default Node-RED (`C:\Users\hejer\.node-red`, port 1880) at the same time**: it
has its own copy of the simulation and would publish the same MQTT messages (it never sends to
Supabase: it has no key). If you start it again, make it reachable from this laptop only: in
`C:\Users\hejer\.node-red\settings.js`, remove the `//` in front of `uiHost: "127.0.0.1",`, save,
restart it.

For a demo in front of a jury: `LOOZ_BATCH_SECONDS=20` in `iot/node-red/.env` (the dashboard then
moves every 20 s) — and check that the Supabase project is not paused (top of this file).

**Every page of the dashboard takes about 40 s?** The network's IPv6 is broken (seen on 11
November 2026: IPv4 answered in 0.1 s, IPv6 never). Python then waits for IPv6 before trying IPv4.
`SUPABASE_IPV4_ONLY=true` in `dashboard/backend/.env` (it is there now) makes the backend use IPv4
only; harmless when IPv6 works. Node-RED and the browser are not affected.

## 14. Admin dashboard (migrations 013 and 014)

**The rule**: admins READ everything (database rules), but every CHANGE goes through one checked
database function, called with the admin's own login (never the `service_role` key). The function
checks the rules (reason required, demo admin limits...) and writes a line in the **admin action
log** `admin_actions` (who, what, when, on what, why). Nobody can change or delete that log.
Roles, the expert badge and packs can no longer be changed through the API, admins included:
a role stays SQL only (section 10).

**Pages** (all in French; "Bientôt" = not ready yet):

| Page | Phase | What it does |
| --- | --- | --- |
| Connexion | A | E-mail + password; "Connexion démo" when its switch is on |
| Vue d'ensemble | A | Numbers (farmers, boxes by state, experts, orchards, regional alerts, community, demo payments of the month, visits) + "À faire" with links. With "Connexion démo": demo data only (after 014) |
| Agriculteurs | A | List; a farmer's page: plan, gateway (Nouvelle clé, Désactiver), boxes live (Accepter l'installation / Retirer), visit (Modifier), charts of the last 3 days (5 measures, one line per box, the values table), alert log, sensor problems (14 days), admin actions |
| Capteurs | A | Every box (waiting first), En attente, Visites d'installation, Passerelles, Journal |
| Utilisateurs | B | Every account: search (name, phone, e-mail), filters (role, governorate, pack, state); an account's page (pack, login, posts, answers, actions); "Vérifier / Retirer la vérification" (the app's "◆ خبير موثّق"), "Bloquer / Débloquer" (not with the demo account). A role changes only in SQL |
| Communauté | B | Every post newest first (hidden ones too), filters, search; a post's page: text, photo (private: a link valid 5 min; the app's demo picture), every answer; Masquer / Afficher de nouveau / Supprimer (2nd confirmation) on the post and each answer, with a reason; Signalements (from the app's "إبلاغ / Signaler"); Journal |
| Alertes | C | Regional alerts: create, change, end; type, gravity, governorates (one, several, all 24), title / text / advice in Arabic AND French (the same checks as the database), start / end, and the **preview** of the app's screen in both languages. Sensor alerts of every orchard (level, governorate, farmer, period; 50 lines at a time) |
| Vergers | D | Every orchard (owner, governorate, area, zones, trees, boxes, built or draft); an orchard's page: the plan (zones, trees, boxes), its zones, the bill of one period. Read only |
| Abonnements | D | Every farmer's pack with the bill of one period at the current price (same rule as the app), the payments (demo ones marked), the price of a box and "hectares par boîtier" (reason + confirmation), their log |
| Réglages | D | The switches (demo login of the app, demo payment, sensor data, "Connexion démo") and the history days, each with a warning and a confirmation; turning the app's demo login off asks "a real SMS provider is connected" |
| Journal des actions | D | Every admin action (who, what, when, on what, why, before → after), filter by kind, 100 lines at a time |

Screenshots (French, "Connexion démo", demo accounts only): `docs/screenshots/admin-dashboard-phase-a/`,
`-phase-b/` (with the badge in the app, Arabic and French), `-phase-c/`, `-phase-d/`.

**"Connexion démo"** (for the jury and the screenshots of the repo):

- The login `admin-demo@looz-demo.invalid` (made in Authentication › Users, then
  `supabase/seed/demo_admin.sql`). Its password is ONLY in `dashboard/backend/.env`
  (`DEMO_ADMIN_PASSWORD=`): the **backend** logs in and gives the browser only the session.
- Only from this laptop (127.0.0.1) and only while the switch is on:
  `select demo_admin_login_enabled from public.admin_set_setting('demo_admin_login_enabled', 'true', 'Démo du jury');`
  Turn it OFF after the demo: same line with `'false'` and a reason (e.g. `'Fin de la démo'`).
- It sees **only the demo accounts**: +216 22 777 001, 22 123 456, 22 123 457, 22 123 458,
  22 999 001, 22 999 003 and the fake people of the community (not 50 000 001–005). The names of
  real admins are shown as "Administrateur". A violet tag "Compte de démonstration" is at the top.
- Its regional alerts are marked "démo" and (after 014) reach **demo accounts only**.
- It acts **only on demo things** (the database checks it) and **never** on the settings, the
  price, the gateways (new key, on / off) or blocking accounts.
- To remove it completely: `supabase/seed/demo_admin_delete.sql`, delete the login in
  Authentication › Users, remove `DEMO_ADMIN_PASSWORD` from `dashboard/backend/.env`.
- **Migration 014**: the database itself keeps it on demo data. With its own login, even straight
  through the Supabase API, it reads only the demo accounts, their orchards, boxes, readings,
  payments, posts, answers and photos, the demo regional alerts, and its own lines of the log;
  "Vue d'ensemble" counts demo data only. Before 014 this was done by the backend only: run 014
  before showing the dashboard to anyone. It still works only from this laptop and only while its
  switch is on.

## 15. Alerts in the app and "إبلاغ / Signaler" (migration 015, Phase 1)

**The tab "التنبيهات / Alertes"** (`mobile_app/lib/features/alerts/`):

- The **regional alerts** of the farmer's governorate (free farmers, paid farmers and experts):
  active only; a demo alert (written with "Connexion démo") reaches demo accounts only. The database
  decides (`my_regional_alerts()`); the app never writes an alert.
- Order: not done first, then the most serious (خطر, then انتباه, then معلومة), then the newest.
  Colour and face by severity (the design's dark / medium green, blue for an information), the icon
  of the kind (❄ frost, thermometer, sun, leaf, bug, wind, rain). "جديد" on an alert not opened yet
  (or changed by an admin since). The **number on the bell** = new alerts not done.
- Loaded when the app opens, **every 60 s** while it is open, when the farmer comes back to the app,
  when he opens the tab, and when he **pulls the list down**. Nothing in the background.
- An alert's screen: what is happening, "ماذا أفعل؟" (one numbered step per line of the advice; 🔊
  says "قريبًا"), "صالح حتى 15/11 على الساعة 08:00" or "صالح حتى إشعار آخر", the count ("فلاح واحد
  قال: أنا أيضًا"), **"أنا أيضًا"** (once per person, "تراجع" takes it back) and **"تمّ"** (only
  with advice: "أحسنت!" with the petals, "تراجع"; a done alert goes to the end and leaves the
  bell). Ended by an admin while open: "انتهى هذا التنبيه." + "رجوع إلى التنبيهات".
- **Home** shows the most important alert not done (and "انتبه: تنبيه في منطقتك" under the title), or
  the green "كل شيء بخير" card. The fake tree alert is gone (the map's trees say "قريبًا").
- Paid farmers: a section "بستاني" with "تنبيهات حسّاسات بستانك — قريبًا" (Phase 2). For everyone:
  "الإشعارات على الهاتف — قريبًا".

**"إبلاغ / Signaler"** (community, on a question's own screen): on the question and the answers of
other people (never your own, never in the list). "لماذا تبلّغ؟": "إعلان أو إزعاج", "كلام مسيء",
"نصيحة خاطئة أو خطيرة", "سبب آخر" (+ "إلغاء"). Then "شكرًا. سيراجعه فريق لوز." and "✓ أبلغت"; the
text stays visible, the Looz team decides (Dashboard › Communauté › Signalements). Once per person and
text, 10 a day ("بلغت الحد اليوم. حاول غدًا."), never a text already hidden.

**Migration 015**: `regional_alert_reads` (opened / done, per person and alert: own rows only, written
only by the functions), `my_regional_alerts()`, `regional_alert_mark(id, 'read' | 'done' |
'undone')`, `regional_alert_me_too(id, on)` (returns the new count), `regional_alert_reach(ids)` (the
dashboard's "ouverte par / fait par", admins only). Tested on the laptop (89 checks) and live.

**The jury scenario** (tested live on 14 Nov 2026, `dashboard/backend/tests_live/test_live_app_alerts.py`):

1. Dashboard (Connexion démo) › Alertes › Nouvelle alerte: gel, Danger, Sfax, the texts, the advice
   one step per line › Publier.
2. On 22 777 001's phone (within a minute, or pull down): the bell shows 1, the frost card is at the
   top, Home shows it; in Arabic and (switch عربي | FR) in French.
3. He opens it and taps "أنا أيضًا" → the dashboard shows "1 « Moi aussi » · ouverte par 1" by itself.
4. The admin taps Terminer → the alert leaves the app at the next refresh (or pull down).
5. He opens a demo question › "إبلاغ" › a reason → "✓ أبلغت" → Dashboard › Communauté ›
   Signalements shows it → Masquer → gone from the app. (Afficher de nouveau puts it back.)

Each person reports a text **once, forever**: 22 777 001 already reported two demo questions in the
tests ("الشهيلي حرق الأوراق في جويلية…" and "نحب نغرس 50 شجرة لوز جديدة…"): use another one in front
of the jury.

Screenshots (real Supabase, 22 777 001, Arabic and French, and the dashboard):
`docs/screenshots/app-alerts/`.

## 16. Photo diagnosis (Bêta, paid pack — migration 016 + Edge Function `diagnose`)

**What the farmer does** (camera button of the assistant bar, or Ask › "صورة"; Free: the locked screen):

1. "صوّر الورقة" + "تجريبي": the tips (ورقة لوز واحدة · من قريب · في الضوء), "يمكنك إرسال 7 صور اليوم",
   "تُرسل الصورة للفحص، وتُحفظ في حسابك فقط.". The round button = the camera (web: the photos);
   "اختر من الصور" under it. The photo is made small (1600 px, JPEG) and its GPS removed.
2. "جاري النظر…" (the photo is sent; a few seconds).
3. The result: "ثقوب في الأوراق" / "تجعّد الأوراق" / "بقع على الأوراق" with **"على الأرجح"** or **"غير
   متأكد"** (never "متأكد"), the photo with the sick spots framed in red, "ماذا أفعل؟" with 3 steps,
   "هذا ليس تشخيصًا نهائيًا. اطلب رأي خبير.", 🔊 = "قريبًا".
   Nothing found (or a weak guess, or not an almond leaf): **"لم نجد هذه الأمراض الثلاثة."** + "صوّر
   الورقة من قريب، في الضوء." + "هذا لا يعني أن الشجرة سليمة." (never "your tree is healthy").
4. **"اسأل خبيرًا"**: the question screen opens with the photo and a ready question ("صوّرت ورقة لوز.
   التطبيق يقول: ثقوب في الأوراق (على الأرجح). هل هذا صحيح؟"), the farmer can change it, "انشر" → the
   community; the question is linked to the diagnosis. A verified expert ("◆ خبير موثّق") answers.
5. Messages: "تحتاج إلى الإنترنت" (+ "حاول مرة أخرى"), "أرسلت اليوم 10 صور. هذا هو الحد. عُد غدًا.", "الفحص
   مشغول اليوم…" (the app's limit, or no Roboflow credits), "الفحص غير متوفر الآن. اسأل خبيرًا.", "لم
   نستطع قراءة الصورة. صوّر من جديد.".

**How it works**: the app → Edge Function `diagnose` (checks the login) → `diagnosis_begin()` (paid
pack, switch, limits) → the photo in the private bucket `diagnoses` (folder = the farmer; the 30
newest are kept) → Roboflow `almond-diseases-detection-l7tfx/2` (the key only in the secret
`ROBOFLOW_API_KEY`; `disable_active_learning=true`) → `diagnosis_finish()` saves the codes and decides
the verdict. The app gets codes only and writes the texts (ARB). The screens only know
`DiagnosisService` (`mobile_app/lib/data/diagnosis_service.dart`): another model later = another class.

**Settings** (Table Editor › `app_settings`, no new app needed): `diagnosis_enabled` (on/off),
`diagnosis_per_day` 10 (per farmer), `diagnosis_app_per_day` 1000 (whole app: the Roboflow credits),
`diagnosis_keep_photos` 30, `diagnosis_likely` 0.65 ("على الأرجح" from), `diagnosis_unsure` 0.40
("غير متأكد" from; below: "لم نجد"). The thresholds must be checked with real photos.

**Roboflow (checked 14 Nov 2026 on roboflow.com)**: Free Tier = 10 credits a month, no card: the API
just stops when they are used (no bill). Object detection costs 0.125 to 0.3125 credits per 1,000
photos: about 32,000 to 80,000 photos a month for free. "All Roboflow-hosted models come with a
commercial license". In the workspace, "Data Licensing and Model Training" is turned OFF. Still to
check on the Universe page: the dataset licence, the model's metrics, what version 11 adds.

**First steps shown to farmers: DRAFTS — TO VALIDATE BY AN AGRONOMIST** before a real launch (no
pesticide names, no doses; in the ARB files, keys `adviceShotHole1..3`, `adviceLeafCurl1..3`,
`adviceLeafSpot1..3`):

| Disease | Arabic | French |
| --- | --- | --- |
| ثقوب في الأوراق (shot hole) | اجمع الأوراق المريضة والساقطة، وأبعدها عن البستان. · اسقِ عند الجذع، لا فوق الأوراق. · اسأل خبيرًا عن العلاج قبل المطر القادم. | Ramassez les feuilles malades et tombées, loin du verger. · Arrosez au pied, pas sur les feuilles. · Demandez à un expert le traitement avant la prochaine pluie. |
| تجعّد الأوراق (leaf curl) | انزع الأوراق المجعّدة وأبعدها عن البستان. · راقب الأوراق الجديدة: الحرّ يوقف المرض غالبًا. · اسأل خبيرًا: الوقاية تكون في الشتاء، قبل تفتّح البراعم. | Enlevez les feuilles frisées, loin du verger. · Surveillez les nouvelles feuilles : la chaleur arrête souvent la maladie. · Demandez à un expert : la prévention se fait en hiver, avant le débourrement. |
| بقع على الأوراق (leaf spot) | اجمع الأوراق المصابة والساقطة تحت الشجرة. · في الشتاء، قلّم ليدخل الهواء والشمس. · اسأل خبيرًا ليعرف نوع البقع. | Ramassez les feuilles touchées et tombées sous l'arbre. · En hiver, taillez pour faire entrer l'air et le soleil. · Demandez à un expert quel type de taches c'est. |

**Zone letters**: in Arabic the zones are أ ب ج د ه و ز ح ط ي ك ل م ن س ع ف ص ق ر (the abjad order, 20
zones) everywhere (designer, 3D, and later the alerts and the diagnosis): "المنطقة ب", never "المنطقة
B". The database keeps A to T. One place: `mobile_app/lib/core/zone_letters.dart` + the ARB text
`zoneLetters`.

**Live (14 Nov 2026, `diagnose` deployed with Verify JWT ON)**: `dashboard/backend/tests_live/test_live_diagnosis.py`
4 / 4 (no login → 401 from Supabase; the public key alone → refused by the function itself; Free
farmer → `not_paid`; a picture without a leaf → "nothing", saved, readable only by its owner, his
photo in his private folder). The real app in Chrome, Arabic and French (22 123 456): camera, "جاري
النظر…", result with the box, steps, "اسأل خبيرًا" → the question with the photo in the community,
"لم نجد", no internet: `docs/screenshots/photo-diagnosis/` (photo credits: `CREDITS.md` there). The
test questions were deleted afterwards.

**⚠ What the public model said on 8 real photos (Wikimedia)**: shot-hole leaf → nothing; 2 shot-hole
close-ups → nothing; leaf curl → nothing; autumn almond leaves → nothing (right); healthy almond twig
→ nothing (right); green picture → nothing (right); **olive leaf → "غير متأكد: ثقوب في الأوراق" (0.49,
a false alarm)**. The app works (the olive answer proves the photo reaches the model); the model
`almond-diseases-detection-l7tfx/2` misses diseased leaves unlike its training photos. Before the
jury: check the same photos on the model's Universe page ("browser test"), and use our own trained
version (dataset v11 + Tunisian photos + healthy / olive leaves as "nothing" examples) or show the
honest path ("لم نجد" → "اسأل خبيرًا").
