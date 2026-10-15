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

```powershell
cd mobile_app
flutter pub get
flutter run -d chrome
```
