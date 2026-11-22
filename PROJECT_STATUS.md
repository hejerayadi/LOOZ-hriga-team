# Looz — project status

Last update: 21 November 2026 (the two **ML models** in the app — frost tonight + stress of the trees, with SHAP reasons, Groq explanations in Derja + French, in-app notifications, live data: migration **019** to run + the ML worker to start, section 18; the **admin dashboard redesigned**, section 19). Before: 19 November (photo diagnosis with Gemini, section 16; voice assistant, section 17).

> **⚠ Before a real launch: turn the DEMO LOGIN off** (section 5). While it is on, anyone who types a
> phone number can open that account: any 6-digit code works. Turn the **demo payment** off too
> (section 9) once a real payment provider is set up.

> **⚠ Before real farmers use the voice assistant "لوز": switch the Gemini API to the PAID tier**
> (section 17). On the Free tier, Google may use the farmers' voices and the answers to improve its
> products. Steps: aistudio.google.com › Billing › set up Cloud billing on the project of the key
> `GEMINI_API_KEY` (Prepay, $5 minimum) and add the Google AI Pro monthly credits ($10, Google
> Developer Program › My benefits, on the SAME billing account); check that the project says
> "Paid" on aistudio.google.com/api-keys; set a monthly spend cap (aistudio.google.com/spend, e.g.
> $20); then Table Editor › `app_settings` › `voice_google_free_tier` = **false** (the first-time
> message then stops saying "وقد تستعمله غوغل لتحسين خدماتها"). Until then: demo accounts only.
>
> **The same for the PHOTO diagnosis (Gemini, section 16)**: its key `GEMINI_VISION_API_KEY` is in
> ANOTHER Google project ("looz-vision"): set up billing on THAT project too, then
> `app_settings.diagnosis_google_free_tier` = **false** (the camera screen then stops saying "وقد
> تستعملها غوغل لتحسين خدماتها") and raise `diagnosis_app_per_day` (15 now: the free tier allows
> only 20 photos a day and 5 a minute).

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
| **My orchard in 3D** (Premium): the farmer's real orchard, zones, trees, sensor boxes; each zone coloured by its **ML state** (colour + icon + words), a tap opens the **zone panel** (prediction, how sure, reasons, explanation, ONE action, readings) | Done (21 Nov 2026) | **Real** (Supabase + Realtime, migration 019) |
| **ML predictions** (section 18), paid pack: frost tonight + stress of the trees for every box at every 15-minute step, SHAP reasons, Groq texts (Derja + French), in-app banner + "بستاني" in the alerts tab | Built 21 Nov 2026, tested on the laptop end to end; **to do: run 019 + start the ML worker** | Real models (AI_modules_time_series), Node-RED simulated boxes |
| **Orchard designer** (section 3): draw the orchard on a grid (or **from a photo of a sketch**, section 21), cut it into zones, the bill, pay, the orchard is built → 3D | Done (grid). Satellite map: "قريبًا" (Phase 5). Editing later: Phase 4 | **Real** (Supabase, migration 011) |
| Profile: name, phone, my pack, its zones and end date, log out | Done | **Real** (Supabase) |
| Community: questions, answers, delete, photos | Done | **Real** (Supabase + Storage) |
| **Alerts** (section 15): the tab "التنبيهات" with the regional alerts of the farmer's governorate, the number on the bell, an alert's screen ("ماذا أفعل؟" in steps, until when, "أنا أيضًا", "تمّ"), the most important alert on Home | Done (Phase 1, 14 Nov 2026). Sensor alerts "بستاني" and voice / push: "قريبًا" | **Real** (Supabase, migration 015) |
| **"إبلاغ / Signaler"** in the community (section 15): on the question and the answers of others, 4 reasons, "✓ أبلغت" | Done (14 Nov 2026) | **Real** (`report_content()` of 013) → Dashboard › Communauté › Signalements |
| **Photo diagnosis (Bêta)** (section 16), paid pack: camera or photo → "جاري النظر…" → "على الأرجح" / "غير متأكد" / "لم نجد هذه الأمراض الثلاثة", the photo with the sick spots marked, 2-3 first steps (drafts), "اسأل خبيرًا" = a community question with the photo | Milestone 1 built (14 Nov 2026); **Gemini** vision built 19 Nov 2026, to deploy. History, zone choice: Milestone 2 | **Real**: Gemini (`gemini-3.6-flash`, Google project "looz-vision") or Roboflow, chosen by `app_settings.diagnosis_model`, through the Edge Function `diagnose` (migrations 016 + 018) |
| **Voice assistant "لوز" (Bêta)** (section 17), paid pack: "تكلّم" / the assistant bar → the farmer speaks (Derja or French), "لوز" answers with its voice, the texts on the screen; it reads his orchard (zones + last sensor readings) | Milestone 1 built (15 Nov 2026), to deploy. Alerts, photos, community question: Milestone 2 | **Real**: Gemini Live (`gemini-3.8-live`) with a short-lived locked token from the Edge Function `voice-token` (migration 017) |
| Home (weather), map, journal, tips; 🔊 buttons ("قريبًا") | Screens done | **Fake** data (`mobile_app/lib/data/fake_data.dart`). A tree on the map says "قريبًا" |
| **Sensor boxes → Supabase** (section 12): Node-RED of the farm (`iot/node-red/`) sends the readings once a minute to the Edge Function `iot-ingest` | Done (Milestone 1) with the **simulated** boxes NODE-01…04 of the IoT demo farmer | **Real** Supabase (migration 012), simulated boxes |
| Admin dashboard (`dashboard/`), **in French** (section 14; **redesigned** 21 Nov 2026, section 19: app colours + logo, grouped menu, charts, new pages Prédictions IA / Assistant vocal / Diagnostics photo, a farmer's whole activity): login + "Connexion démo", Vue d'ensemble, Agriculteurs (live boxes, 3-day charts, accept / remove), Utilisateurs (expert badge, block), Communauté (hide / show again / delete, reports), Alertes (regional alerts in Arabic + French with the preview, sensor alert log), Vergers (plan), Capteurs, Abonnements (bills, payments, price), Réglages (the switches), Journal des actions | **Phases A–D built** (A: 12 Nov, B–D: 13 Nov 2026). Migration 014 (the database keeps the demo admin on demo data) run on 13 Nov | **Real** (Supabase, admin login; every change through a checked function + admin action log, migrations 013 and 014) |

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
22. `supabase/migrations/017_voice_assistant.sql` (check line: `true | false | false | 5 | 60 | 180 | gemini-3.8-live`):
    the voice assistant "لوز" (section 17). If you run 014 again after it, 014's second number is 30.
23. `supabase/migrations/018_photo_diagnosis_gemini.sql` (check line: `true | false | roboflow | true | 10 | 15 | 0.9 | 0.7 | qwen/qwen3.8-27b`):
    the photo diagnosis can use Gemini (section 16). The model stays Roboflow until you switch it
    (section 16, "Switch to Gemini"). Safe to run again: your settings are kept (15 a day only over the
    old 1000); 014 stays at 30.
24. `supabase/migrations/019_ml_predictions.sql` (check line: `true | qwen/qwen3.8-27b | 3 | true | false | false | 4`;
    the last number is 0 if the IoT demo farmer 22 777 001 is not there): the ML predictions (section 18).
    Then make the worker's key: `select public.ml_worker_new_key('ML-01');` → paste the `lml_…` value after
    `ML_WORKER_KEY=` in `dashboard/backend/.env` (never anywhere else). If you run 014 again after 019, its
    second number is **34** (not 30). **No Edge Function to deploy**: `iot-ingest` passes the new channels
    through unchanged.

Then the **Edge Functions** (Edge Functions › Deploy a new function › Via Editor › paste the file ›
name › Deploy function; then in its settings turn **"Verify JWT" off**; no secret to add):

| Name | File | Why Verify JWT is off |
| --- | --- | --- |
| `demo-auth` | `supabase/functions/demo-auth/index.ts` | the app calls it before the login |
| `iot-ingest` | `supabase/functions/iot-ingest/index.ts` | Node-RED has no Supabase login: the function checks the gateway key itself |

And ONE function with **"Verify JWT" ON** (only logged-in users):

| Name | File | Secret (Edge Functions › Secrets) |
| --- | --- | --- |
| `diagnose` | `supabase/functions/diagnose/index.ts` | `GEMINI_VISION_API_KEY` = the key of the Google project **"looz-vision"** (Gemini, photos only). Optional: `GEMINI_API_KEY2` = a **backup** Gemini key (from ANOTHER Google project: the limits are per project), tried once when the first is refused. Optional: `GROQ_API_KEY` = the key of Groq (console.groq.com), the 3rd step (the model: setting `diagnosis_groq_model`). `ROBOFLOW_API_KEY` = the **Private API Key** of the Roboflow workspace (the fallback). Optional: `ROBOFLOW_MODEL` (default `almond-diseases-detection-l7tfx/2`). Never in the app, never in git. Never add `ROBOFLOW_URL`, `GEMINI_VISION_URL` nor `GROQ_URL` (tests only) |
| `voice-token` | `supabase/functions/voice-token/index.ts` | `GEMINI_API_KEY` = the Gemini API key (never in the app, never in git). Never add `GEMINI_URL` (tests only) |

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
| `flutter test` | **286 / 286 pass (21 Nov 2026)**, incl. `test/ml_test.dart` (11: the "بستاني" cards and the bell, a card → the zone panel in 3D, Groq text and the template without Groq, "غير متأكد", Realtime → the banner once, free farmers, French, 360 × 640, the states of a zone, the 3D data). All the screens and flows, with a fake login (also in demo mode), fake payment, fake orchard and fake community; the real login code with a fake web server (no internet). The designer: `test/geometry_test.dart` (area, clean-up of the drawing, crossing sides, automatic split, dividing lines) and `test/designer_test.dart` (every step, finger and mouse, resume, errors, French, a 360 x 640 phone). Tree numbers from the codes ("12", "TREE-012"): `test/orchard_3d_data_test.dart`. The alerts: `test/alerts_test.dart` (order, bell, "جديد", steps, "أنا أيضًا", "تمّ", ended while open, no alert, no internet, pull down, every minute, back to the app, French, Home). "إبلاغ": `test/report_test.dart`. The photo diagnosis: `test/diagnosis_test.dart` (camera, "جاري النظر…", the 3 results, the marks, "اسأل خبيرًا" → the question with the photo, every failure, the limits, Free = locked, French, the plurals, the zone letters أ ب ج د, "sent to Google" + the free-tier sentence with Gemini, "not a final diagnosis" on every result). The voice assistant: `test/voice_test.dart` (section 17) | 275 / 275 pass |
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
| `pytest` (21 Nov 2026: **168 passed, 2 skipped**) | ML: `tests/test_ml_models.py` (the bundles load with the pinned versions, the notebooks' own functions = our service, exact SHAP, every feature has a farmer word), `test_ml_features.py` (formulas vs the 5 notebook rows, hourly grid, 24-h window, frost night, stages), `test_ml_explain_worker.py` (Groq checks: no number, no Latin letter in the Arabic, no pesticide word, cache, budget, 429 → template; the worker with a fake Supabase: sensor problem, not enough data, leak → water deficit, hot zone → heat, frost night → zone D frost risk, problems get Groq first, its own key, never the service_role), `test_insights.py` (the new dashboard pages; the demo admin: demo data only). The 2 skipped = cross-checks with the optional `shap` package (they pass when it is installed). Before: No internet, fake tables and fake database functions (also "ouverte par / fait par" of the alerts, and the page without migration 015): only admins (401 / 403), the farmers list and page, the demo admin sees demo accounts only (and never a real admin's name), "Vue d'ensemble", the 3 days (window on the latest measure, alert log, sensor problems grouped, actions), Capteurs (waiting first, visits, gateways without key, log), every action calls its checked function and every refusal of the database becomes a French message (reason, device code, demo admin...), "Connexion démo" (switch, password only in `.env`, 127.0.0.1 only, other websites refused, not an admin → refused, one login per 3 s), CORS localhost + 127.0.0.1, a value the box flags as wrong is not drawn. **Phase B**: accounts (e-mail of admins only, "New user" never shown), expert badge, block, posts newest first with every answer, private photo link (5 min), hide / show again / delete (the photo removed from Storage), reports. **Phase C**: regional alerts (states, "Moi aussi", create / change / end, every check of the database in French), sensor alert log (filters). **Phase D**: orchards and their plan (drafts too), the bill (same rule as the app), subscriptions, payments, price, settings, the action log 100 lines at a time | 115 / 115 pass |
| `pytest tests_live -v` | **Real Supabase, Node-RED running**: needs `LIVE_ADMIN_EMAIL` and `LIVE_ADMIN_PASSWORD` in `dashboard/backend/.env` (skipped otherwise). Phase 1 and **Phase A** (Milestone A: NODE-04 "Retirer" → refused → "Accepter" → received again). **Milestone B**: the demo expert 22 123 458 verified → the app shows "◆ خبير موثّق" (and next to an answer she writes, then deletes; she STAYS verified), a demo post hidden → gone from the app → shown again. **Milestone C**: a heat alert for Sfax → 22 777 001 reads it, 22 123 457 (Kairouan) does not → changed → ended. **Milestone D**: the price 8 → 9 DT → the app's bill and the dashboard's bill change, the log says 8 → 9 DT → back to 8 DT. **App module** (`test_live_app_alerts.py`): the jury scenario (section 15) with Connexion démo. `test_live_014.py` (after 014): the demo admin's own token reads demo rows only through the Supabase API, and "Vue d'ensemble" counts what its lists show | 39 / 39 pass (13 Nov 2026, Node-RED running): IoT 8, A 9, B 6, C 5, D 6, 014 5. 14 Nov 2026: app module 3 pass + 1 skipped (22 777 001 has no post of his own), C 5 and 014 5 again; photo diagnosis `test_live_diagnosis.py` 4 / 4 (with `LIVE_LEAF_PHOTO` / `LIVE_OTHER_PHOTO` paths, each photo = 1 of the 10 of the day of 22 777 001) |

**Frontend** (from `dashboard/frontend`): `npx tsc --noEmit`, `npm run lint`, `npm run build`: no error (21 Nov 2026).

**Node-RED** (from `iot/node-red`): `node test/flow_test.js` runs the flow's code (src/*.js = flows.json)
outside Node-RED: 17 / 17 (raw channels, DHT11 / DS18B20 / 12-bit light, the 4 scenarios, the frost night,
the clock only goes forward, an old memory, pause). After changing `src/*.js`: `python tools/build_flows.py`.

**019 on the laptop** (local PostgreSQL 17, the 3 ways of the SQL Editor and again): 81 / 81 checks (settings
kept, the context and its defaults, the 3 new channels through `iot_ingest`, the worker key (none / wrong →
PT401), jobs = paid farmers' boxes only, the save refuses wrong codes / old predictions / texts with hidden
direction marks, who reads what (farmer, another farmer, free, visitor, real admin, demo admin), one
notification per problem (no repeat; back within 12 h = the same; later = a new one), read / read all,
the Realtime publication, a Node-RED restart).
**End to end on the laptop** (21 Nov 2026): Node-RED (a copy, port 1882) → the real `iot-ingest` under Deno →
local Postgres with 019 → `python -m ml.worker --once` (real Groq): summer → zone B water deficit, zone C heat,
zone D sensor problem, 2 notifications, Derja + French texts; frost scenario → at 22:30 frost risk in A, B, D
(D 0.99), C no frost, 3 "danger" notifications, the summer ones resolved.

**The SQL on the laptop** (no Supabase): 013 + `demo_admin.sql` (99 checks) and 014 (64 checks:
real admins and the app read exactly what they read before, the demo admin only demo rows in every
table, view and photo, its overview counts its lists, a demo alert never reaches a real farmer)
were tested on a local PostgreSQL 17, run the 3 ways of the SQL Editor and again. 015: 89 checks (the
list = exactly what the rules of 014 show, for 10 kinds of users; order; new after a change; done;
"Moi aussi" once; every refusal; reports; the jury scenario; 013 + 014 + 015 run again). 016: 73 checks
(the app writes nothing; paid pack, switch, zone; the verdict from the thresholds; every wrong result
refused; the limits of the day, two photos at once; 30 photos kept; who reads what; 013-016 again).
018: 48 checks (the 3 ways and again, the model setting kept; allowed / refused model names; where
the photo goes for the app; Gemini's conservative verdict: box, plant, thresholds, none / not a leaf;
every wrong answer refused; model_busy; Roboflow unchanged; 15 a day for the whole app).
The Edge Function `diagnose`: 101 checks under Deno with a fake Roboflow, a fake Gemini, a fake Groq and a stand-in
of Supabase (login, bad photos, Free farmer, a sick leaf with its boxes, nothing, a weak guess, no
credits (402), busy once (503), down, nonsense, the photo not saved, switch off, limits, old photos
deleted, 25 s timeout; Gemini: likely with its boxes turned into ours, olive / no box → only unsure,
weak / none / not a leaf → nothing, the request (model, key in the header, prompt, JSON, thinking
LOW), 429 → busy without a second try, 503 twice → busy, 503 once → tried again, a sentence or no
answer → unavailable, another model name from the setting, back to Roboflow, 40 s timeout → busy;
the backup key: not set → as before; 429 / 503 / 403 / 401 / invalid key / too slow → backup once →
the result; both refused → busy or unavailable, never a 3rd try; a wrong answer → no backup try;
both too slow → busy in 62 s; Groq: only when Gemini gave no answer, its boxes, the same verdict,
a fence / <think> part read, not JSON → unavailable, 429 / 413 / 503 → busy, the setting (empty =
no step, another name), without a backup key straight to Groq, all three too slow → busy in 62 s;
no key, no photo and no sentence of a model in the logs, only "gemini-primary" / "gemini-backup" /
"groq-qwen"). The IoT part: the
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
5. **Done 21 Nov 2026 (section 18)**: the orchard's problems in "بستاني" and the real readings in the 3D panel — now from the ML predictions. Still to do: the screen "معلومات الأرض" (farm context typed by the farmer), real push notifications, a weather service (rain). Old plan: **App alerts, Phase 2** (Phase 1 done, section 15): the sensor alerts of a paid farmer in the tab
   ("بستاني / Mon verger": zone, level, simple advice, texts from the codes in the ARB files; a tap
   opens the zone in the 3D) and the real readings in the 3D zone panel. A small migration **019**
   (the state of the farmer's own boxes with the gateway's offline time; 016 and 018 are the
   diagnosis, 017 the voice assistant).
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

# 5. The ML worker (predictions + Groq texts), section 18. First time: pip install -r requirements-ml.txt
cd "D:\IEEE\aotn chalenge\AOTN-TSYP-chalenge\dashboard\backend"
.venv\Scripts\Activate.ps1
python -m ml.worker
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

## 16. Photo diagnosis (Bêta, paid pack — migrations 016 + 018, Edge Function `diagnose`)

**What the farmer does** (camera button of the assistant bar, or Ask › "صورة"; Free: the locked screen):

1. "صوّر الورقة" + "تجريبي": the tips (ورقة لوز واحدة · من قريب · في الضوء), "يمكنك إرسال 7 صور اليوم",
   where the photo goes: with Gemini (and its backups) **"تُرسل الصورة إلى خدمة ذكاء اصطناعي (غوغل أو
   مزوّد آخر) لفحصها، وتُحفظ في حسابك."** + on Google's free tier **"وقد تستعملها غوغل لتحسين
   خدماتها."** (with Roboflow: "تُرسل الصورة للفحص، وتُحفظ في حسابك فقط."; not known yet or no
   internet: the AI text in full). The round button = the camera
   (web: the photos); "اختر من الصور" under it. The photo is made small (1600 px, JPEG) and its GPS removed.
2. "جاري النظر…" (the photo is sent; a few seconds).
3. The result: "ثقوب في الأوراق" / "تجعّد الأوراق" / "بقع على الأوراق" with **"على الأرجح"** or **"غير
   متأكد"** (never "متأكد"), the photo with the sick spots framed in red, "ماذا أفعل؟" with 3 steps,
   🔊 = "قريبًا".
   Nothing found (or a weak guess, or not an almond leaf): **"لم نجد هذه الأمراض الثلاثة."** + "صوّر
   الورقة من قريب، في الضوء." + "هذا لا يعني أن الشجرة سليمة." (never "your tree is healthy").
   **Every result** (also "لم نجد"): "هذا ليس تشخيصًا نهائيًا. اطلب رأي خبير." and the big "اسأل خبيرًا".
4. **"اسأل خبيرًا"**: the question screen opens with the photo and a ready question ("صوّرت ورقة لوز.
   التطبيق يقول: ثقوب في الأوراق (على الأرجح). هل هذا صحيح؟"), the farmer can change it, "انشر" → the
   community; the question is linked to the diagnosis. A verified expert ("◆ خبير موثّق") answers.
5. Messages: "تحتاج إلى الإنترنت" (+ "حاول مرة أخرى"), "أرسلت اليوم 10 صور. هذا هو الحد. عُد غدًا.", "الفحص
   مشغول اليوم…" (the app's limit of the day; Google busy, its limits or too slow; no Roboflow
   credits), "الفحص غير متوفر الآن. اسأل خبيرًا.", "لم نستطع قراءة الصورة. صوّر من جديد.".

**How it works**: the app → Edge Function `diagnose` (checks the login) → `diagnosis_begin()` (paid
pack, switch, limits) → the photo in the private bucket `diagnoses` (folder = the farmer; the 30
newest are kept) → the model of `app_settings.diagnosis_model` → `diagnosis_finish()` saves the codes
and decides the verdict. The app gets codes only and writes the texts (ARB). The screens only know
`DiagnosisService` (`mobile_app/lib/data/diagnosis_service.dart`).

- **Gemini** (`gemini:gemini-3.6-flash`, key only in the secret `GEMINI_VISION_API_KEY`, Google
  project "looz-vision", separate from the voice assistant's project): one call `generateContent`
  with the photo and our prompt (the same text as `dashboard/backend/tools/diagnosis_eval.py`),
  strict JSON: one label of 5 (shot_hole, leaf_curl, leaf_spot, none, not_a_leaf), its confidence,
  the plant (almond, olive, other, unknown) and up to 5 approximate boxes (drawn on the photo).
  Gemini's sentence ("reason") is dropped, never saved. 429 (a limit) → "busy" at once; 503 (Google
  busy) → one more try after 2 s, then "busy"; more than 40 s → "busy"; a wrong answer or key →
  "unavailable". The app waits up to 70 s.
- **Backup key** (optional secret `GEMINI_API_KEY2`, a key of ANOTHER Google project): when the
  first key gets a limit (429), Google busy (5xx), too slow, a network problem or a key error (401,
  403, invalid key), the backup key is tried ONCE (in the time left: all tries stay under 62 s). Both
  refused → "busy" (if one was a limit, busy or too slow), else "unavailable". A wrong answer or a
  wrong model name: no backup try. Not set: as without it. With a backup on the free tier, Google
  allows 20 + 20 photos a day: you may raise `diagnosis_app_per_day` (e.g. 30).
- **Groq, the 3rd step** (optional secret `GROQ_API_KEY`; the model in the setting
  `diagnosis_groq_model`, `qwen/qwen3.8-27b`; empty = no Groq step; a new name = no new deployment):
  when Gemini gave no answer (also after a wrong answer of Gemini), Groq is tried ONCE with the
  time left (each step keeps 15 s for the steps after it; all stay under 62 s). Same prompt, 5
  labels, JSON schema; Qwen's boxes `bbox_2d` [x1, y1, x2, y2] on 0–1000 are turned into ours (a box
  outside the list "boxes" is not read). Its answers are saved as `groq:<model>` and judged with the
  same conservative verdict. Not valid JSON → "unavailable"; 429 / 413 / 5xx / too slow → "busy".
  Groq's free tier for `qwen/qwen3.8-27b` (its own headers and 429 message, 19 Nov 2026): **1,000
  requests a day, 7,000 input tokens a minute** (a photo ≈ 1,700–2,200 tokens: about 3 photos a
  minute). Not set: as without it. The logs say only "gemini-primary", "gemini-backup" or
  "groq-qwen", never a key, a photo or a sentence of a model.
  ⚠ On the 9 old photos (1 run) it found only **1 of 4** sick photos (0 false alarms; 2 answers
  not valid JSON; not the same answer when asked again): a weak last step — it mostly says "لم نجد"
  where Gemini finds the disease. To turn it off: `diagnosis_groq_model` = '' (empty).
- **Roboflow** (`roboflow` = the secret `ROBOFLOW_MODEL`, or `roboflow:<project>/<version>`): as
  before (`disable_active_learning=true`): the fallback.

**The verdict with Gemini is CONSERVATIVE** (its confidence is its own opinion, not a measured
probability, and our test was small): **"على الأرجح"** only when Gemini's confidence ≥
`diagnosis_gemini_likely` (0.90) **and** it drew at least one box **and** the leaf is almond (or it
can't tell); **"غير متأكد"** from `diagnosis_gemini_unsure` (0.70) (also: an olive or other leaf, no
box); below, or "none" / "not a leaf": **"لم نجد"**.

**Switch to Gemini / back to Roboflow** (no new app, no new deployment): SQL Editor ›
`update app_settings set diagnosis_model = 'gemini:gemini-3.6-flash' where id;` (back:
`'roboflow'`). Another Gemini model later: `gemini:<its name>`.

**Settings** (Table Editor › `app_settings`, no new app needed): `diagnosis_enabled` (on/off),
`diagnosis_model` (above), `diagnosis_per_day` 10 (per farmer), `diagnosis_app_per_day` **15** (whole
app: Gemini's free tier allows 20 photos a day and 5 a minute for the project, so 15 leaves room for
the tries again), `diagnosis_keep_photos` 30, Gemini: `diagnosis_gemini_likely` 0.90,
`diagnosis_gemini_unsure` 0.70, `diagnosis_google_free_tier` true (the camera text); Roboflow:
`diagnosis_likely` 0.65, `diagnosis_unsure` 0.40.

**⚠ Gemini's free tier** (project "looz-vision", `gemini-3.6-flash`, seen in Google's own answers on
16 and 19 Nov 2026): **5 requests a minute, 20 a day** (a new day at 09:00 Tunisia time); the photos
may be used by Google to improve its products; it is often slow or "busy" (503). Enough for the jury,
not for farmers: before a launch, the paid tier (top of this file). Paid price: $0.75 / 1M tokens in,
$3.75 / 1M out until 31 Dec 2026 (doubled from 1 Jan 2027): about $0.0017 a photo (≈ $1.75 for 1,000).
`gemini-3.8-flash` (newer) was too busy on 15–19 Nov 2026 (503 and timeouts): try it again later
by changing the setting.

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

**Model comparison (15 Nov 2026)** — the same 9 photos (3 shot hole, 1 leaf curl, healthy almond,
autumn almond, olive, 2 "not a leaf"), a result counting from 0.40; tool:
`dashboard/backend/tools/diagnosis_eval.py` (photos in `tools/test_photos/`, not in git):

| Option | Diseases found | False alarms | Speed | Cost (credits / 1,000 photos) | Jury rule |
| --- | --- | --- | --- | --- | --- |
| A — public model `l7tfx/2` | 0 / 4 | 1 / 5 (olive) | ~0.5 s (1.1 s in the app) | 0.125–0.19 | FAIL |
| B — workflow `general-segmentation-api-2` (SAM 3), prompts = the 3 class names | 2 / 4 (both as "leaf_spot") | 0 / 5 | ~1.8 s | 0.5 | FAIL |
| B — same, plain words ("holes in leaf", "brown spots on leaf", "curled red leaf") | 1 / 4 | 1 / 5 (blossoms) | ~1.7 s | 0.5 | FAIL |

Jury rule: at least 3 of 4 diseases found (as some disease), at most 1 false alarm. Then (15 Nov):
own RF-DETR model planned (`docs/milestone3_own_model.md`); **changed on 15–19 Nov 2026: Gemini vision**.

**Gemini test (16–19 Nov 2026)**, tool `python tools/diagnosis_eval.py gemini gemini-3.6-flash`, a
test set of 50 photos (`dashboard/backend/tools/test_set.json`: the 9 old ones + 41 from iNaturalist,
research grade, CC0 / CC BY / CC BY-SA, credits in `tools/test_photos/CREDITS.md`). Only **the 9 old
photos** could be done (the free tier's 20 calls a day); the 41 others are tested by hand in the app.

| Model | Diseases found (old 9) | False alarms | Stability | Speed | Cost a photo (paid) | Jury rule |
| --- | --- | --- | --- | --- | --- | --- |
| Roboflow `l7tfx/2` (all 50) | 0 / 4 (0 / 27 on the 50) | 1 / 5 (1 / 23) | — | ~2 s | credits | FAIL |
| Groq `qwen/qwen3.8-27b` (19 Nov, 1 run) | 1 / 4 (2 answers not valid JSON, leaf curl said "none") | 0 / 5 | not the same answer when asked again | ~1–2 s | free tier | FAIL (3rd step only) |
| **Gemini `gemini-3.6-flash`** | **4 / 4** (3 the right disease; a shot-hole close-up said "leaf spot") | **0 / 5** (healthy, autumn, olive, blossoms, green picture) | 6 photos × 3 runs: same answer every time; 3 photos: 1 run, **not tested** | median ~5 s, up to 49 s | ~$0.0017 | **PASS** (small test) |

**Plan only, not built — the "data flywheel"** (our own model later): when a verified expert ("◆
خبير موثّق") answers a question made with "اسأل خبيرًا", the dashboard lets an admin mark the
diagnosis "confirmed: shot hole / leaf curl / leaf spot / healthy / other"; only photos of farmers who
said **yes** to a separate, clear question ("هل نستعمل صورتك لتحسين لوز؟", off by default, can be
taken back in Profile) are copied to a private training folder (no name, no phone, no GPS); when
there are a few hundred per class, they train our own model (Roboflow RF-DETR,
`docs/milestone3_own_model.md`), tested with this same tool and test set before
`diagnosis_model` changes. Needs: a consent column + Profile switch, a "confirmed label" column
and a dashboard page; a migration and a privacy text checked before.

## 17. Voice assistant "لوز" (Bêta, paid pack — migration 017 + Edge Function `voice-token`)

**What the farmer does** ("تكلّم" on the Ask screen, or the assistant bar; Free: the locked screen):

1. The first time only: **"قبل أن تتكلّم"** — "صوتك يُرسل إلى غوغل ليفهمه لوز ويجيبك. لوز لا يسجّل
   صوتك ولا يحفظ كلامك. نحفظ فقط مدّة المحادثة." (+ "وقد تستعمله غوغل لتحسين خدماتها." while the key
   is on Google's free tier) → "موافق" / "لا، شكرًا". Saved in the database (`voice_consents`).
2. "لوز" + "تجريبي", the big microphone, "اضغط وقل سؤالك", "بقيت 5 دقائق اليوم", the button "تكلّم".
3. He talks: "لحظة…" → **"يسمع…"** (the clock of the conversation: 3:00) → "يفكّر…" + "ينظر في
   بستانك…" while it reads his orchard → **"يحكي…"** (its voice; "اضغط على لوز لتقاطعه") → "يسمع…"
   again. The texts appear: "أنت: شنوّة حال السانية؟" / "لوز: السانية لاباس…". The microphone is
   paused while "لوز" speaks (it must not hear itself).
4. "توقّف" (or 3 minutes, or the app hidden) → "انتهت المحادثة", "تكلّم من جديد".
5. Messages: "تحتاج إلى الإنترنت", "انتهى وقتك مع لوز اليوم. ارجع غدًا.", "لوز مشغول اليوم. حاول
   لاحقًا." (the whole app's minutes), "المساعد متوقف الآن.", "لوز لا يجيب الآن." (+ "حاول مرة أخرى"),
   "اسمح باستعمال الميكروفون لتتكلّم مع لوز.". Always at the bottom: "لوز يمكن أن يخطئ. للأدوية اسأل
   خبيرًا."

**How it works**: the app → Edge Function `voice-token` (checks the login) → `voice_begin()` (switch,
paid pack, "yes", minutes of the farmer and of the whole app; opens a conversation) → Google gives a
**short-lived, single-use token, LOCKED** to the model, the instructions of "لوز", its voice and its
tools (the app can't change them; it stops after the conversation's length) → the app talks
**directly** to Gemini Live (the voice never goes through LOOZ). When Gemini needs data it asks the
app for `get_my_orchard`: the app reads the farmer's zones and the last reading of each sensor box
**with his own login** (database rules) and sends a short JSON. At the end the app calls `voice_end()`:
the **database clock** measures the time (at least 20 s, at most the conversation's length; a
conversation never ended counts its whole length).
App files: `lib/data/voice_service.dart`, `gemini_live.dart`, `voice_audio.dart` (microphone:
package `record`; voice: `flutter_soloud`, + the script line in `web/index.html`; Android:
RECORD_AUDIO), `voice_tools.dart`; `lib/features/ask/voice_session.dart`, `voice_screen.dart`.

**The rules of "لوز"** (its instructions, Arabic, in `supabase/functions/voice-token/index.ts`):
simple Tunisian Derja, short sentences; French if the farmer speaks French; almonds in Sfax, Sidi
Bouzid, Kasserine; always `get_my_orchard` before talking about his orchard, never an invented
number; zones as "المنطقة ب" / "Zone B"; old readings or offline boxes said clearly. **Never a
pesticide / medicine / chemical fertiliser / product name, never a quantity, dose, mixture or homemade
recipe, even if the farmer insists or names a product himself → "هذا لازم يقولهولك خبير. اسأل خبير، ولا
اسأل المجتمع في تطبيق لوز."** (French: "Il faut demander à un expert."); not sure → "ما نيش متأكد" + an expert; no medical, legal or money
advice; never asks his name, phone or exact place. Google only gets his governorate and the app
language (no name, no phone, no id).

**Settings** (Table Editor › `app_settings`, no new app needed): `voice_enabled`, `voice_model`
(`gemini-3.8-live`), `voice_speaker` (`Kore`; other voices: listen in Google AI Studio › Live),
`voice_minutes_per_day` 5 (per farmer), `voice_app_minutes_per_day` 60 (whole app: protects the
money), `voice_session_seconds` 180 (one conversation), `voice_google_free_tier` true (set to false
after the switch to the paid tier, see the warning at the top).

**Privacy**: no voice and no words are saved anywhere by LOOZ. `voice_sessions` keeps only: start,
end, seconds counted, why it ended, number of questions / tool calls, Google's token counts.

**Cost (Gemini 3.8 Live, Google prices of Nov 2026)**: voice in $3 / 1M tokens (≈ $0.005 a minute),
voice out $12 / 1M (≈ $0.018 a minute). One question + answer ≈ $0.01 (≈ 0.03 DT); safe upper bound
$0.03 per minute of conversation. With the app limit of 60 minutes a day: at most ≈ $54 a month.
Free tier: $0 (but Google may use the data). The real token counts are in `voice_sessions`.

**Ephemeral tokens are a Google "Preview" feature** (API v1beta): if Google changes them, the voice
stops (nothing else) until `voice-token` is updated.

**Tests**: `mobile_app/test/voice_test.dart` (24: the Milestone 1 scenario with a fake Google, the
first-time message, time over, connection lost, interruptions, every failure, French, the messages
of Google, `get_my_orchard`); SQL 017 on the laptop (68 checks); the function `voice-token` with a
fake Google (36 checks). Live (after the deployment): `dashboard/backend/tests_live/test_live_voice.py`
(22 777 001 asks "شنوّة حال السانية؟" by text, the real Gemini, its answer printed and its voice saved
as a WAV file).

**Milestone 2**: the tools "regional alerts", "my photo diagnoses", "a question for the community"
(shown on the screen first, published only after "إيه" or the button "انشر"); in Profile "أوقف إرسال
صوتي" (takes the consent back); the dashboard page "Assistant vocal" (minutes and cost per day).

## 18. ML predictions: frost tonight + stress of the trees (migration 019, the ML worker)

```
Node-RED (simulated boxes, every 5 s = 15 min)   Supabase (019)                      the app (paid farmers)
raw channels: soil %, soil °C (DS18B20),   ──►   node_readings (1 point / hour)  ──►  Realtime: the 3D, the zone
air °C + % (DHT11), light ADC, piezo              node_latest                         panel, "بستاني" in the alerts,
                                                  ml_latest / ml_history / ml_notifications   the bell, a banner
ML worker (Python, dashboard/backend/ml) ── its own key ──► ml_worker_jobs / _history / _save
  features → frost model (logistic) + stress model (LightGBM) → SHAP → Groq (Derja + French, only when it changes)
```

**What the farmer sees** (paid pack only; free farmers see the locked "★ ابدأ" screen):
- **3D** (بستاني ★): each zone coloured by its state with a label on it — بخير / نقص الماء / ماء زائد / حرارة شديدة /
  ضرر البرد / مشكل في الجذور / خطر صقيع الليلة / مشكل في الحسّاس / قراءات غير كافية / الحسّاس غير متصل / في انتظار
  التركيب. The box light takes the colour. Live: Supabase Realtime (no reload).
- **A tap on a zone** → the panel: the state, "على الأرجح / غير متأكد", "آخر تحديث: منذ …", Groq's text in Derja (or a
  simple text made from the codes), "ماذا أفعل؟" with ONE action, "لماذا؟" = the main reasons as bars (farmer words, never
  a feature name), tonight's frost line, the latest readings.
- **التنبيهات › بستاني**: one card per problem (newest and most serious first, "جديد" until seen); a tap opens the zone
  in 3D. The bell counts them too.
- **In-app notification** (no push, no Firebase: decision of the user): a new problem shows a banner at the top while the
  app is open, once ("المنطقة أ: خطر صقيع الليلة" — "اضغط لترى المنطقة"). The same problem never comes twice (database
  rule: one open notification per box and model; the same problem back within 12 h of measured time = the same one).
- No "تجريبي / Bêta" label on the predictions (decision of the user).

**The models** (`AI_modules_time_series/`, loaded with the pinned versions of `dashboard/backend/requirements-ml.txt`:
scikit-learn 1.6.1 (both bundles say so), LightGBM 4.6.0, numpy 2.2, pandas 2.2):
- `frost_model.joblib`: StandardScaler + LogisticRegression, alarm at 0.664 (90 % of frosts on the training seasons;
  test season: recall 0.85, precision 0.47, PR-AUC 0.69). SHAP = exact linear SHAP.
- `stress_model.joblib`: **LightGBM (tuned)** (not XGBoost) + IQRCapper + imputer, 6 classes, test macro-F1 0.72.
  The notebook classes `IQRCapper` / `BalancedXGBClassifier` are defined exactly as in the notebook before loading.
  SHAP = LightGBM's TreeSHAP (= shap.TreeExplainer).
- ⚠ **The dataset generators were not given** (`almond_stress_dataset.py` daily_features() and the frost generator):
  the features were rebuilt from the notebooks and the bundles. Every feature and every approximation:
  `docs/ml_features.md`. Before real farmers: compare with the generators, and validate on real days and nights.
- ⚠ **Frost model timing**: it was trained for ONE decision time, **2 hours after sunset**. LOOZ runs it **every 15
  minutes, all day long** (decision of the user) with the latest reading as the "evening" values. By day the probability
  stays near 0; in the night it follows the cooling (in the frost scenario the low zone D crosses the threshold about
  1 h after sunset). Outside the evening the inputs are outside what the model learned: treat a daytime or late-night
  answer as an indication. It was trained on November–April only (in summer it gives ≈ 0).
- Stress is a DAILY model: LOOZ uses the last 24 hours at each step (needs ≥ 20 valid hours, else "قراءات غير كافية").
  A box with a sensor problem (or the level "sensor") gets no prediction ("مشكل في الحسّاس"), never a guess.

**Groq** (key `GROQ_API_KEY` in `dashboard/backend/.env`, model = setting `ml_groq_model`): tested on 21 Nov 2026 —
`allam-2-7b` (Arabic, but Modern Standard Arabic and broken format), `openai/gpt-oss-20b` (small, one wrong word),
`openai/gpt-oss-120b` (good), **`qwen/qwen3.8-27b` (chosen: the most natural short Derja, follows the rules, ~0.5 s)**.
Free tier per model: 1,000 requests a day, 8,000 tokens a minute; one text ≈ 1,000 tokens. The text is made only when
the prediction changes (zone, state, how sure, the 3 main reasons); problems get the budget first (6 calls a minute
at most, `ML_GROQ_PER_MINUTE`). Rules checked on every answer: JSON in both languages, short, **no number at all** (the
app shows the readings), no Latin letter in the Arabic, no pesticide / product / dose word (the action says "اسأل خبير"
only for a treatment). A refused answer, a 429 or no answer = the app's simple text from the codes (ARB files).
The prompt: `dashboard/backend/ml/explain.py`. HF_TOKEN is not used.

**Farm context** (019, on each zone; empty = a default, `ml_zone_context()` lists which): soil type and its FC / WP /
SAT, irrigation system, irrigation water EC, ground cover, position low / mid / high, cover crop, root depth, first day
of bloom (per governorate), stage set by hand; orchard elevation. The IoT demo orchard (22 777 001) is filled: A sandy
loam, B sandy loam (EC 1.2), C loamy sand (high), D sand (**low spot**). **How a real farmer gives it**: defaults from the
designer's zone type (تربة رملية → sand, بعلية → rainfed, مسقية → drip, young / old trees → ground cover) + his governorate;
a screen "معلومات الأرض" in the app: **قريبًا** (next step); an admin can set it today in Table Editor › zones.

**The ML worker** (`python -m ml.worker`, window 5 of section 13): every 10 s it asks Supabase for the boxes with a new
reading (`ml_worker_jobs`), reads their orchard's history, predicts both models, explains, saves (`ml_worker_save`). It
uses the **public key + its own key** `ML_WORKER_KEY` (only a hash in the database, like a gateway): no service_role.
New key: `select public.ml_worker_new_key('ML-01');` (the old one stops at once). Logs: "round: N jobs", "groq ok" /
"groq refused: <reason>" — never a key, never a text.

**Settings** (Table Editor › app_settings): `ml_enabled`, `ml_notify_enabled`, `ml_explain_enabled`, `ml_groq_model`
(`qwen/qwen3.8-27b`; `openai/gpt-oss-120b` also works; empty = no Groq), `ml_likely_min` (0.6: "على الأرجح" from this
probability for the stress model; frost risk is "likely" from 0.85).

**Volume** (Free plan): `ml_latest` 2 rows per box; `ml_history` a point per change or per hour of measured time,
kept `iot_history_days` (30) like the readings; resolved notifications deleted after 30 days. Realtime: 3 tables
(node_latest, ml_latest, ml_notifications); each farmer receives only his rows (RLS).

**Node-RED** (`iot/node-red`, code in `src/*.js`, `python tools/build_flows.py` writes flows.json): the simulator sends
every raw channel with the datasets' sensor behaviour (DHT11 whole numbers, 0 °C floor, 20–90 %; DS18B20 1/16 °C; 12-bit
light that saturates; piezo clicks that rise with thirst). Each zone has its soil's FC / WP. **Frost-night scenario**:
switch "Scénario : nuit de gel (floraison)" on Node-RED's dashboard (or `LOOZ_SCENARIO=frost` in `.env`): the clock
jumps FORWARD to 18 February 18:00 (bloom), the 36 h before are sent at once, then the night goes on (clear, dry; zone D
reads 0 °C around 4:00). Switching back: 15 June of the next year. The clock never goes back (no history lost).

**Live test for you** (after 019 + the worker): open the app as 22 777 001 → بستاني ★ → the zone colours change as
Node-RED sends; switch the frost scenario → within 2–3 minutes a banner "المنطقة د: خطر صقيع الليلة".

## 19. Admin dashboard redesign (21 Nov 2026)

- **Look**: the app's colours (dark green menu, leaf-green highlight, cream background; the Tailwind "emerald" scale is
  replaced by the app's greens in `app/globals.css`), the app font **Cairo**, the white LOOZ logo, cards with soft
  shadows, readable tables (light headers, hover line). The menu is grouped (Pilotage · Agriculteurs et vergers ·
  Services de l'application · Comptes et ventes · Administration) with icons; on a tablet (< 1280 px) it shows icons only
  (the button opens it). The top bar shows where you are (group › page), the demo tag, the admin and "Se déconnecter".
- **Vue d'ensemble**: the numbers as before + "Les 30 derniers jours" (6 KPIs with a trend line: sign-ups, demo payments,
  problems found by the AI, photo diagnoses, voice minutes, questions) + bar charts per day + "Prédictions IA en ce moment".
- **New pages**: **Prédictions IA** (the worker's last round, KPIs, states as bars, every box: state, how sure, reasons;
  a click opens what the farmer sees in French AND Derja, the technical SHAP values, the history strip of the box; the
  in-app notifications with seen / ended), **Assistant vocal** (minutes, conversations, questions, tool calls per day and
  per farmer — no words exist), **Diagnostics photo** (every analysis, diseases, models; expert confirmation: Bientôt).
- **A farmer's page** now ends with "Activité dans l'application": KPIs and tabs Chronologie (everything, newest first) ·
  Prédictions IA (+ notifications) · Diagnostics photo · Assistant vocal · Communauté (questions, answers, reports,
  « Moi aussi ») · Paiements · Actions admin. Every list links to the farmer's page.
- Backend: `app/insights.py` + `app/routers/insights.py` (`/api/insights/ml`, `/ml/history/{node}`, `/zones/{id}/context`,
  `/voice`, `/diagnoses`, `/trends`, `/farmers/{id}/activity`), all read-only with the admin's own token.
- Everything else unchanged (actions, rules, "Connexion démo", 127.0.0.1 only).
- ⚠ `npm run build` shows a Next.js message "known security vulnerability" (Next 16.4.2) once, then builds on the second
  run. Upgrading Next.js was **not** done (it could break the dashboard): ask Claude in a separate step.
- Screenshots (demo admin, demo data only, preview over the local end-to-end data): `docs/screenshots/admin-dashboard-redesign/`.
  App screenshots (Arabic + French): `docs/screenshots/ml-predictions-app/`.

## 20. The demo video: story accounts, content and reset (22 Nov 2026)

All files in `supabase/seed/`, tested on the laptop (local PostgreSQL with the leftovers of the real list,
the 3 scenes and the dashboard click played: 63 checks). Real users are never changed.

**The story.** Scene 1: sign up with **+216 22 999 005** (سلمى الشرفي, Sfax, Free). Scene 2: log in as
**+216 22 999 001** (the same سلمى, a demo account: community + the Sfax demo alert; a new sign-up is not a demo
account, so it cannot see a demo alert). Scene 3: log in again as 22 999 005, upgrade to Paid, draw the orchard, pay
(card 4242). Dashboard ("Connexion démo"): Agriculteurs › **سليم الحمروني** (+216 22 123 456) › zone D, box
**DEMO-D** › "Accepter l'installation" (the code is filled in). Paid farmer with live sensors: +216 22 777 001
"عادل البقلوطي". Verified expert: +216 22 123 458 "ريم العلوي". +216 22 123 457 is not used (Kairouan, live tests).

| Order | File | What | Check line |
| --- | --- | --- | --- |
| 1 | `demo_recording_list.sql` | READ ONLY: every account, post, answer, report, alert, diagnosis, voice use, orphan payment and Storage file, with its kind (TEST / demo / REAL user, real numbers masked) | a table |
| 2 | `demo_recording_cleanup.sql` | deletes the test leftovers: designer test accounts (+216 22 98x xxx), payments without account, community content of the test numbers +216 50 000 00x (their accounts stay: live tests), reports by demo accounts, ended demo alerts, test diagnoses and voice of demo accounts; shows again the fake people's hidden posts. Never real users, never the ended "Jalon C" alerts | `0 \| 0 \| 0 \| 0 \| 0 \| 0 \| 0 \| 0 \| 5 \| 8 \| 1 \| 1 \| 3 \| <folders>` |
| 3 | `demo_recording_setup.sql` | the story accounts, the demo community made recent, 2 posts with a photo (`demo:leaf_curl`, `demo:leaf_shot_hole`, pictures in `mobile_app/assets/images/`, CC0 iNaturalist) answered by the expert, the DEMO alert "موجة سخانة في صفاقس" (demo accounts only), the box DEMO-D waiting for installation | `عادل البقلوطي \| سلمى الشرفي \| sfax \| false \| ريم العلوي \| true \| 2 \| 6 \| true \| 0 \| DEMO-D waiting \| contacted` |
| before each take | `reset_demo_recording.sql` | the sign-up account and EVERYTHING it made (orchard, zones, boxes, trees, pack, visit, payments, notifications), today's photos and voice of the demo accounts moved to yesterday, demo notifications, rehearsal posts / answers / reports / demo alerts, the Sfax alert new again, DEMO-D waiting again | `0 \| 0 \| 0 \| 0 \| 1 \| true \| 0 \| DEMO-D waiting` |
| any time | `reset_signup.sql` | only the account of +216 22 999 005 and everything of it | `+216 22 999 005 \| 0 \| 0 \| N` |
| any time | `demo_recording_limits.sql` | READ ONLY: photos and voice minutes left today | a table |

Not reset by SQL: Node-RED's clock (after the frost scenario: delete `iot/node-red/context` to start again on
15 June), the ML predictions, the Google / Groq daily limits, the voice consent, the app's language and login,
the admin action log, photo files in Storage (SQL cannot delete them: the check lines name the folders).

## 21. Orchard designer: "من صورة / Depuis une photo" (22 Nov 2026)

**What.** On "ارسم بستانك", a third card under "بإصبعك، على شبكة" (still the default): **"من صورة"**.
The farmer draws the orchard on paper, takes a photo (on a phone) or chooses one (Chrome), and the app finds
the outline and makes the SAME corner dots as the hand drawing. Then everything is as before: the size, the
zones, the payment. No database change, no migration.

**How (no AI, no API, nothing sent).** Classic image processing in plain Dart, on the phone or in the
browser (`lib/features/orchard_designer/sketch_detect.dart`): the sheet of paper (the big bright areas,
grown into the grey paper of a shadow; when its 4 corners are in the photo, the photo is straightened as if
taken from above) → the ink (darker than the paper around it; light blue / pink squares don't count) →
small gaps of the line closed → the biggest closed shape (numbers, words, trees, lines drawn inside it are
ignored) → its border → the same clean-up as a finger's line (`cleanUpStroke`). When the sheet's corners are
not visible, a tilt under 15° shared by the long sides is straightened. The photo is never sent and never
saved (a draft opened later has the outline, not the photo).

**Screens.** The tips ("قلم أسود غليظ · ورقة بيضاء · صوّر من فوق · الورقة كاملة في الصورة" and "الصورة تبقى في
هاتفك، لا نرسلها."), "نبحث عن حدود البستان…", then the outline step with the photo faded behind the grid
("وجدنا حدود بستانك. حرّك النقاط إذا لزم."; typing the size stretches the photo too). Not found: "لم نجد حدود
البستان في الصورة." + "حدّد الزوايا على الصورة" (the corners tapped on the photo) / "صورة أخرى" / "ارسم بيدك".

**Tests.** `test/sketch_detect_test.dart` (13): 5 test photos made by `tool/make_sketch_photos.py`
(SYNTHETIC: paper, a felt-tip line that wobbles like a hand, JPEG noise) — clean, shadow, numbers + words +
trees + a zone line inside, turned 12° AND taken at an angle, squared paper — all found with the right
number of corners (overlap with the true shape: 99 / 99 / 99 / 99 / 93 %); a drawing turned 9° straightened;
a photo without a closed shape refused. **Real phone photos: put them in `mobile_app/test/sketches/real/`**:
the same test checks each one. `test/sketch_designer_test.dart` (10): the screens with fakes. In Chrome
(the screenshot build `tool/screens/sketch_screens_main.dart`, real picker + real detection): the same
5 photos found, the photo without a shape refused, about 1.5 s each (headless Chrome). Screenshots (Arabic
+ French): `docs/screenshots/sketch-designer/`. Two sign-up tests now scroll to "متابعة مجانًا" (the start
screen is longer).

⚠ **Not tested on a real Android phone** (no Android SDK nor emulator on this laptop). The code is the same
plain Dart as in Chrome and in the tests; the camera is the photo diagnosis' one (`image_picker`). Test it on a
phone before real farmers use it.

⚠ Fixed on the way: on the web, `-1 << 30` is a big POSITIVE number (Dart's bit operations are unsigned
32-bit in JavaScript): the detection found nothing in Chrome. No bit shift in `sketch_detect.dart` now (a test
checks it).

**The demo sketch that works on the first try**: a white A4 sheet without lines, a BLACK felt-tip marker; ONE
closed outline with 4 to 7 straight sides and sharp corners, about 2/3 of the page, 2–3 cm of white margin
all around, the end of the line going 1 cm past its start; the top of the page = north; words or numbers
inside only, not touching the line; no zone lines. Photo straight from above, the WHOLE sheet visible with a
bit of table around it, daylight, no shadow of the phone or the hand on the line. In Chrome: send the photo to
the laptop and choose it with "اختر من الصور".
