# Looz 🌳

**Looz** is an AI + IoT decision-support system for almond farmers,
built for the IEEE AOTN competition.

Sensors in the orchard and photos taken by the farmer feed an AI that helps
detect problems early (water stress, diseases, pests) and gives simple advice.

## Repository structure

| Folder         | What it is                                                        |
| -------------- | ----------------------------------------------------------------- |
| `mobile_app/`  | Flutter app for **farmers** and **experts** (Android, iOS, web)   |
| `dashboard/`   | Web dashboard for **admins** (coming later)                       |
| `_archive/`    | Old code kept for reference (not part of the apps)                |

## Run the mobile app

First, put the Supabase keys in `mobile_app/.env` (see `mobile_app/.env.example`).

```powershell
cd mobile_app
flutter pub get
flutter run -d chrome --dart-define-from-file=.env
```

## Database (Supabase)

The SQL files are in `supabase/`. Run them in Supabase > SQL Editor:
`looz_schema.sql` (tables) then `looz_policies.sql` (security rules).
