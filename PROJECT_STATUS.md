# Looz — project status

Last update: 3 November 2026.

> **⚠ Before a real launch: turn the DEMO LOGIN off** (section 3). While it is on, anyone who types a
> phone number can open that account: any 6-digit code works. Turn the **demo payment** off too
> (section 7) once a real payment provider is set up.

## 1. What works today

| Module | Status | Data |
| --- | --- | --- |
| Design (23 screens of the Figma, Arabic right to left + French) | Done | — |
| Start of the app: start screen, sign in, sign up (who are you → information → pack) | Done | **Real** (Supabase) |
| Login with the phone | Done as a **demo login** (any number, any code, no SMS) | **Real** accounts and sessions (Edge Function `demo-auth`) |
| Payment of the packs | Done as a **demo** (no real money) | **Real** database, demo card |
| LOOZ kit request (Connected pack) | Done | **Real** (Supabase) |
| Profile: name, phone, my pack and its end date, log out | Done | **Real** (Supabase) |
| Community: questions, answers, delete, photos | Done | **Real** (Supabase + Storage) |
| Plans: what each pack can use (Free / Essential / Connected) | Done | **Real** (database rules + app) |
| Home, alerts, my orchard in 3D, camera diagnosis, assistant, voice, map, journal, tips | Screens done | **Fake** data (`mobile_app/lib/data/fake_data.dart`) |
| Admin dashboard (`dashboard/`) | Started, not ready | — |

The list of every screen and how it was checked: `mobile_app/SCREENS_CHECKLIST.md`.

## 2. The start of the app (how it works now)

- **Start screen**: the almond-blossom photo, "عربي | FR" (remembered on the phone),
  "إنشاء حساب" (sign up) and "تسجيل الدخول" (sign in).
- **Sign in**: phone → code → Home. A number with no account gets
  "لا يوجد حساب بهذا الرقم." and a button "إنشاء حساب" (nothing is created).
- **Sign up**: phone → code → **"من أنت؟"** (its own screen, two big buttons with an icon: "فلاح"
  or "مهندس فلاحي أو مرشد") → **"معلوماتك"**:
  - first name, last name, governorate (24), all required;
  - farmers, optional: almond trees, area in hectares, irrigated / rain-fed;
  - experts, optional: only their organisation (no orchard boxes).
- **Farmer, then the pack**:
  - Free → welcome → Home.
  - Essential (15 DT / 30 days) → demo payment → welcome → Home.
  - Connected (8 DT per sensor / 30 days) → a **kit request**. The farmer stays on Free and sees
    "we will contact you". After the installation, they pay from Premium.
- **Expert**: no pack, no payment → welcome → Home. The "◆ خبير موثّق" badge appears only after an
  admin verifies them (see 7).
- **A number that already has an account**: "هذا الرقم لديه حساب بالفعل." + "تسجيل الدخول". Nothing
  is changed.
- **Stopped in the middle** (no information, no pack, Essential not paid): the next login opens the
  missing step.
- **Errors** (no internet, wrong code...) show a neutral warning icon (▲!). The insect icon is only
  for real pests (alerts, diagnosis, tips, journal).

## 3. Demo login (any number, any code) — TURN IT OFF BEFORE A REAL LAUNCH

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
that account** (and see that person's profile, pack and posts). It is only for demos and tests.

**How to turn it off** (takes effect at once, no new app needed):

1. Supabase › Table Editor › `app_settings` (one row).
2. Set `demo_login_enabled` to `false` and save.

Then the app uses the normal Supabase SMS code again. **Before that**, set up a real SMS provider in
Supabase › Authentication › Sign In / Providers › Phone; otherwise only the 5 test numbers of
section 4 can log in. To turn the demo back on: `true`.

**The demo accounts.** To list them (read only, in the SQL Editor):

```sql
select phone, created_at from auth.users
where raw_app_meta_data->>'demo_login' = 'true' order by created_at;
```

Delete the ones you don't need in Supabase › Authentication › Users (their profile goes with them).

**If you deploy `demo-auth` again** (Edge Functions › `demo-auth` › edit › Deploy): check in its
settings that **"Verify JWT" is still off** (the app calls it before anyone is logged in; some
dashboards switch it back on after a deploy). If the function is missing, the app quietly uses the
normal SMS code.

## 4. Run the app

Put the Supabase URL and the **publishable** key in `mobile_app/.env` (see `mobile_app/.env.example`).
Never put the `service_role` key in the app.

```powershell
cd mobile_app
flutter pub get
flutter run -d chrome --dart-define-from-file=.env
```

With the demo login on, **any number works** (type only the 8 digits: "+216" is already there) with
**any 6 digits** as the code.

**Numbers already used by the tests** (they have accounts):

| Number | Used for |
| --- | --- |
| +216 50 000 001 ... 005 | Supabase test numbers (code `123456`, also without the demo login): auth, community, sign-up and payment live tests |
| +216 22 999 001 | Demo login live test: farmer |
| +216 22 999 003 | Demo login live test: expert |
| +216 22 999 002 | Demo login live test: must **never** get an account ("no account" check) |
| +216 22 123 456 | Real app in Chrome, Arabic: farmer + Essential paid (demo) |
| +216 22 123 457 | Real app in Chrome, French: farmer + Connected (kit request) |
| +216 22 123 458 | Real app in Chrome, Arabic: expert |

## 5. Database and Edge Function (Supabase)

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
12. Optional, demo questions for the community: `supabase/seed/community_demo.sql`
    (to remove them: `supabase/seed/community_demo_delete.sql`).

Then the **Edge Function** `demo-auth`: Edge Functions › Deploy a new function › Via Editor › paste
`supabase/functions/demo-auth/index.ts` › name `demo-auth` › Deploy function; then in its settings
turn **"Verify JWT" off**. No secret to add.

All 11 SQL files are in the real database, and `demo-auth` answers (checked on 3 November 2026 by
`test_live/database_check_test.dart` and `test_live/demo_login_live_test.dart`).

## 6. Tests

From `mobile_app/`:

| Command | What it checks | Last result |
| --- | --- | --- |
| `flutter analyze` | The code | No issues |
| `flutter test` | All the screens and flows, with a fake login (also in demo mode), fake payment and fake community; the real login code with a fake web server (no internet) | 133 / 133 pass |
| `python tool/find_hardcoded_texts.py` | No text written in the code (all texts in `lib/l10n/*.arb`) | 0 |

**Live tests**: against the real Supabase. They need internet and `mobile_app/.env`.
Run each one with `--dart-define-from-file=.env`.

| File | What it does | Last result |
| --- | --- | --- |
| `test_live/database_check_test.dart` | Are all the SQL files in the database? (read only) | 11 / 11 |
| `test_live/demo_login_live_test.dart` | `demo-auth` answers; sign up with a new number and any code (farmer, expert), sign in with another code, "no account", the rules | 6 / 6 |
| `test_live/auth_live_test.dart` | Sign in 01 and 02, the security rules of the profiles | 5 / 5 |
| `test_live/signup_payment_live_test.dart` | Sign up 04 + demo payment (refused, then paid 30 days), 05 + kit request, the payment rules | 4 / 4 |
| `test_live/community_live_test.dart` | Questions, answers, rules (01, 02, 03) | 6 / 6 |
| `test_live/community_photo_live_test.dart` | Photos in Storage (01, 02) | 3 / 3 |

Example:

```powershell
flutter test test_live/demo_login_live_test.dart --dart-define-from-file=.env
```

The numbers of the live tests have accounts now: the sign-up tests then check "account exists"
instead. To test them as new users again, delete them in Supabase > Authentication > Users.

## 7. What is demo or fake

- **Login = DEMO** (section 3): any number, any code, no SMS. Turn it off before a real launch.
- **Payment = DEMO.** No money moves, there is no payment provider.
  - The card boxes only *look* real: the app checks the format (16 digits, a date, 3 digits,
    a name), then clears them.
  - The card is never saved, never sent (not to Supabase, not anywhere), never in a log or a test.
  - The database only records "paid_demo" or "failed_demo".
  - The test card **4000 0000 0000 0002** is always refused, to show the "not paid" screen.
    Any other well-formed card is accepted.
  - The payment screen shows a small "وضع تجريبي / Mode démo" label.
  - The code is ready for a real provider: only `DemoPaymentService` in
    `mobile_app/lib/data/payment_service.dart` would change.
- **Fake data**: Home, alerts, 3D orchard, diagnosis, assistant, map, journal and tips use
  `lib/data/fake_data.dart`.
- **"Mode test : changer d'offre"** in Profile: a switch for testing that changes the plan in the
  app only (not in the database).

## 8. Admin how-tos (Supabase > Table Editor)

| To do | Where | How |
| --- | --- | --- |
| **Turn the demo login off** | `app_settings` (one row) | `demo_login_enabled` = `false` (section 3). |
| Turn the demo payment off | `app_settings` (one row) | `demo_payments_enabled` = `false`. The app then says "payment not available". |
| Mark a kit as installed | `kit_requests` | `status` = `installed` **and** `sensors` = the number of sensors (e.g. 5). The farmer can then pay Connected (8 DT × 5 = 40 DT) from Premium. Other statuses: `new`, `contacted`, `cancelled`. |
| Verify an expert | `profiles` (`role` = `expert`) | `verified` = `true`. The "◆ خبير موثّق" badge then appears next to their posts and answers. |
| Change a price | `plan_prices` | `price_millimes` (15000 = 15 DT). Connected has `per_sensor` = `true`. |
| Make an admin (dashboard) | `profiles` | `role` = `admin`. |

Users can't do any of these themselves: the database rules refuse it (checked by the live tests).

## 9. Next steps

1. **Real SMS** (an SMS provider in Supabase Auth), then **turn the demo login off**.
2. **Real payment**: choose the provider (Konnect was compared), add an Edge Function and its
   secret key in Supabase secrets (never in the app), and replace `DemoPaymentService`.
3. **Admin dashboard**: pages for kit requests, expert verification and the two demo switches.
4. **Real data** for the orchard, sensors, alerts and photo diagnosis (in place of `fake_data.dart`).
5. Remind farmers before their pack ends (the end date is in `subscriptions.ends_at`).
