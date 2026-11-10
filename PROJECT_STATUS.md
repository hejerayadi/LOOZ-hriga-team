# Looz — project status

Last update: 10 November 2026 (the orchard designer, Phase 3 = Milestone 2).

> **⚠ Before a real launch: turn the DEMO LOGIN off** (section 5). While it is on, anyone who types a
> phone number can open that account: any 6-digit code works. Turn the **demo payment** off too
> (section 9) once a real payment provider is set up.

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
| Home, alerts, camera diagnosis, assistant, voice, map, journal, tips | Screens done | **Fake** data (`mobile_app/lib/data/fake_data.dart`) |
| Admin dashboard (`dashboard/`) | Started, not ready | — |

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
13. Optional, the demo orchard of +216 22 123 456: `supabase/seed/orchard_demo.sql`
    (to remove it: `supabase/seed/orchard_demo_delete.sql`).
14. Optional, demo questions for the community: `supabase/seed/community_demo.sql`
    (to remove them: `supabase/seed/community_demo_delete.sql`).

Then the **Edge Function** `demo-auth`: Edge Functions › Deploy a new function › Via Editor › paste
`supabase/functions/demo-auth/index.ts` › name `demo-auth` › Deploy function; then in its settings
turn **"Verify JWT" off**. No secret to add.

All 12 SQL files and the demo orchard are in the real database, and `demo-auth` answers (checked on
9 November 2026 by `test_live/database_check_test.dart`, `orchard_live_test.dart` and
`demo_login_live_test.dart`).

## 8. Tests

From `mobile_app/`:

| Command | What it checks | Last result |
| --- | --- | --- |
| `flutter analyze` | The code | No issues |
| `flutter test` | All the screens and flows, with a fake login (also in demo mode), fake payment, fake orchard and fake community; the real login code with a fake web server (no internet). The designer: `test/geometry_test.dart` (area, clean-up of the drawing, crossing sides, automatic split, dividing lines) and `test/designer_test.dart` (every step, finger and mouse, resume, errors, French, a 360 x 640 phone) | 192 / 192 pass |
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
- **Fake data**: Home, alerts, diagnosis, assistant, map, journal and tips use
  `lib/data/fake_data.dart`.
- **"Mode test : changer d'offre"** in Profile (debug builds only): switches Free / Premium in the
  app only (not in the database), to see the locked screens.

## 10. Admin how-tos (Supabase > Table Editor)

| To do | Where | How |
| --- | --- | --- |
| **Turn the demo login off** | `app_settings` (one row) | `demo_login_enabled` = `false` (section 5). |
| Turn the demo payment off | `app_settings` (one row) | `demo_payments_enabled` = `false`. The app then says "payment not available". |
| Change the price | `plan_prices`, row `paid` | `price_millimes` = the price of **one zone** (8000 = 8 DT); `period_days` = 30. |
| Change the minimum per area | `app_settings` (one row) | `hectares_per_node` = 2.00 (1 zone billed per 2 ha at least). Empty = bill only the zones drawn. |
| Bill the real number of boxes | `orchards` | `confirmed_nodes` = the boxes really installed (1 to 100). It replaces the area minimum. |
| Installation visits | `kit_requests` | Made **by the database** when a paid orchard is built (the designer), with the number of boxes to install. `new` → `contacted` → `installed` (every waiting box of that orchard becomes "installed" in the 3D), or `cancelled`. |
| Verify an expert | `profiles` (`role` = `expert`) | `verified` = `true`. The "◆ خبير موثّق" badge then appears next to their posts and answers. |
| Make an admin (dashboard) | `profiles` | `role` = `admin`. |
| **Delete the test accounts** of the designer | Authentication › Users | Search **2298**, then "Delete user" on each (+216 22 98x xxx). Their profile, orchard, zones, sensors, trees and installation visit go with them; their demo payments stay, without the user. |

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
4. **Admin dashboard**: pages for installation visits, `confirmed_nodes`, expert verification and
   the two demo switches.
5. **Real sensor readings** in the 3D (soil moisture, temperature), then real alerts and photo
   diagnosis (in place of `fake_data.dart`).
6. Remind farmers before their pack ends (the end date is in `subscriptions.ends_at`).
