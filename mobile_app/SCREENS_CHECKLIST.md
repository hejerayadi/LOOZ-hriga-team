# Screens checklist

Every screen and state of the design (`App.tsx`), its Flutter file, and the checks.

| # | Design screen (state) | Flutter file | Built in the new design | Arabic checked | French checked | Opened from the right button(s) |
|---|---|---|---|---|---|---|
| 1 | `language` → now the start screen: the photo, "عربي \| FR" (remembered on the phone), "إنشاء حساب" / "تسجيل الدخول" | `lib/features/onboarding/start_screen.dart` (`StartScreen`) | [x] | [x] | [x] | [x] start of the app (logged out), "تسجيل الخروج" |
| 2 | `phone` (empty, typing) | `lib/features/onboarding/phone_screen.dart` (`PhoneScreen`) | [x] | [x] | [x] | [x] "إنشاء حساب" / "تسجيل الدخول" |
| 3 | `code` (empty, typing) | `lib/features/onboarding/phone_screen.dart` (`CodeScreen`) | [x] | [x] | [x] | [x] "إرسال الرمز" |
| 4 | `welcome` | `lib/features/onboarding/welcome_screen.dart` | [x] | [x] | [x] | [x] end of the sign-up: Free "متابعة", "تم الدفع!" "متابعة", "متابعة مجانًا" (also on "ارسم بستانك"), expert "متابعة" |
| 5 | `home` | `lib/features/home/home_page.dart` | [x] | [x] | [x] | [x] "ابدأ", tab "الرئيسية" |
| 6 | `community` | `lib/features/community/community_page.dart` | [x] | [x] | [x] | [x] tab "المجتمع", "اسأل خبيرًا" (result) |
| 7 | `ask` | `lib/features/ask/ask_screen.dart` | [x] | [x] | [x] | [x] Home "اسأل", Community "اسأل سؤالًا" |
| 8 | `tips` | `lib/features/community/tips_screen.dart` | [x] | [x] | [x] | [x] speaker of the tip of the day |
| 9 | `camera` | `lib/features/camera/camera_screen.dart` | [x] | [x] | [x] | [x] camera button, Ask "صورة" |
| 10 | `thinking` | `lib/features/camera/thinking_screen.dart` | [x] | [x] | [x] | [x] shutter, end of the voice screen |
| 11 | `result` | `lib/features/camera/result_screen.dart` | [x] | [x] | [x] | [x] after "جاري النظر…" |
| 12 | `voice` (listening, moving bars) | `lib/features/ask/voice_screen.dart` | [x] | [x] | [x] | [x] "اسأل المساعد", Ask "تكلّم" / "أرسل" |
| 13 | `alerts` | `lib/features/alerts/alerts_page.dart` | [x] | [x] | [x] | [x] tab "التنبيهات" |
| 14 | `alert` (needs water) | `lib/features/alerts/alert_screen.dart` | [x] | [x] | [x] | [x] Home alert, "الشجرة 18 عطشى", a tree on the map |
| 15 | `alert` (done: "أحسنت!", falling petals) | `lib/features/alerts/alert_screen.dart` | [x] | [x] | [x] | [x] "تمّ" |
| 16 | `regional` | `lib/features/alerts/regional_screen.dart` | [x] | [x] | [x] | [x] "حشرة قريبة" |
| 17 | `locked` ("بستاني ★" without Premium) | `lib/features/orchard_3d/orchard_tab.dart` | [x] | [x] | [x] | [x] tab "بستاني ★", camera / map, the assistant bar and Ask "تكلّم" on Free, Premium "ليس الآن" |
| 18 | My orchard in 3D (app's own, in the "بستاني ★" tab) with the farmer's **real** orchard (migration 011): outline, zone colours and types, names in Arabic / French, trees, one sensor box per zone (installed or "في انتظار التركيب", online / offline, battery), "قريبًا" for moisture and temperature; loading, error + "حاول مرة أخرى" | `lib/features/orchard_3d/orchard_tab.dart`, `orchard_3d_data.dart`, `lib/data/orchard_service.dart`, `assets/orchard_3d/index.html` | [x] | [x] | [x] | [x] tab "بستاني ★" with Premium and an orchard |
| 19 | `premium` | `lib/features/premium/premium_screen.dart` | [x] | [x] | [x] | [x] "★ ابدأ بريميوم", Profile "خطتي" (*); "★ ابدأ بريميوم" / "★ جدّد باقتك" → the bill (line 54) or "ارسم بستانك" (line 53) |
| 20 | `payment` (the design's card boxes: DEMO payment, see line 36) | `lib/features/premium/payment_screen.dart`, `demo_card_form.dart` | [x] | [x] | [x] | [x] Premium "★ ابدأ بريميوم" / "★ جدّد باقتك" (line 54) |
| 21 | `qr` | `lib/features/premium/qr_screen.dart` | [x] | [x] | [x] | [x] "★ تأكيد" |
| 22 | `map` | `lib/features/map/map_screen.dart` | [x] | [x] | [x] | [x] Home "خريطة", QR "فتح الخريطة" |
| 23 | `journal` | `lib/features/journal/journal_screen.dart` | [x] | [x] | [x] | [x] Home "دفتر" |
| 24 | `profile` | `lib/features/profile/profile_page.dart` | [x] | [x] | [x] | [x] tab "حسابي" |
| 25 | `states` | `lib/features/states/states_screen.dart` | [x] | [x] | [x] | [x] Profile "حالات التطبيق" |
| 26 | `states`: pending ("سيُرسل لاحقًا") | `lib/features/states/states_screen.dart` | [x] | [x] | [x] | [x] (in the states sheet) |
| 27 | `states`: offline ("لا يوجد إنترنت") | `lib/features/states/states_screen.dart` | [x] | [x] | [x] | [x] (in the states sheet) |
| 28 | `states`: error ("حاول مرة أخرى") — warning icon (▲!) instead of the design's bug, at the user's request (the bug is only for pests) | `lib/features/states/states_screen.dart` | [x] | [x] | [x] | [x] (in the states sheet) |
| 29 | `states`: empty ("اسأل سؤالك الأول") | `lib/features/states/states_screen.dart` | [x] | [x] | [x] | [x] (in the states sheet) |
| 30 | Shell: assistant bar + tab bar (5 tabs) | `lib/shared/widgets/shell.dart`, `looz_tab_bar.dart` | [x] | [x] | [x] | [x] on every screen with tabs |

## Sign up / sign in (not in the design: app's own screens, in the design's style)

| # | Screen (state) | Flutter file | Built | Arabic checked | French checked | Opened from the right button(s) |
|---|---|---|---|---|---|---|
| 31 | Launch: logged in → Home or the missing step; logged out / session expired → start screen (line 1); offline → "لا يوجد إنترنت" + "حاول مرة أخرى" | `lib/features/onboarding/sign_up_flow.dart` (`LaunchScreen`, `openNextStep`) | [x] | [x] | [x] | [x] start of the app |
| 32 | `phone` / `code`: waiting ("جاري الإرسال…"), error messages, "أعد إرسال الرمز"; demo login on: no SMS, any 6 digits; errors with the warning icon; sign in with no account: "لا يوجد حساب بهذا الرقم." + "إنشاء حساب" (keeps the number, nothing created) | `lib/features/onboarding/phone_screen.dart` | [x] | [x] | [x] | [x] "إرسال الرمز", "تأكيد" |
| 33 | "معلوماتك" (no role question any more): first name, last name, governorate; farmer: optional trees / area / irrigation; expert: only the optional organisation (no orchard boxes); errors under the boxes | `lib/features/onboarding/sign_up_info_screen.dart` | [x] | [x] | [x] | [x] "فلاح" / "مهندس فلاحي أو مرشد" (line 55); an expert who stopped before the end |
| 34 | The list of the 24 governorates (sorted, big rows) | `lib/features/onboarding/sign_up_info_screen.dart` (`chooseGovernorate`), `lib/core/governorates.dart` | [x] | [x] | [x] | [x] the "الولاية" box |
| 35 | Packs: Free / Premium 8 DT per zone / 30 days (price from the database), "كل منطقة من بستانك فيها حسّاس لوز واحد، نركّبه لك." | `lib/features/onboarding/pack_screen.dart` | [x] | [x] | [x] | [x] "متابعة" (farmer's information), login with no pack yet |
| 36 | `payment` during the sign-up (no tab bar): "وضع تجريبي", card boxes with icons, errors under them, "جاري التحقق من الدفع…" | `lib/features/premium/payment_screen.dart`, `demo_card_form.dart` | [x] | [x] | [x] | [ ] Phase 3: opened after the drawing (review → pay). Today only in the tests (`languages_test`) |
| 37 | Profile: real name, phone number, "خطتي" with the pack and its end date, "تسجيل الخروج" | `lib/features/profile/profile_page.dart` | [x] | [x] | [x] | [x] tab "حسابي" |

The old "pay now or later" screen (`payment_choice_screen.dart`) and the name screen
(`name_screen.dart`) were removed: the payment comes right after the pack, and the name is in
"معلوماتك".

Checked with `test/sign_up_test.dart` (both flows, errors, session, log out, with a fake login),
`test/languages_test.dart` and screenshots in both languages.
`test_live/auth_live_test.dart` runs the same flow against the real Supabase (users 01, 02).

## Start of the app: roles, packs, demo payment (migrations 008, 009 and 011)

| # | Screen (state) | Flutter file | Built | Arabic checked | French checked | Opened from the right button(s) |
|---|---|---|---|---|---|---|
| 49 | "مرحبًا من جديد": "هذا الرقم لديه حساب بالفعل." + "تسجيل الدخول" (nothing changed) | `lib/features/onboarding/phone_screen.dart` (`AccountExistsScreen`) | [x] | [x] | [x] | [x] "إنشاء حساب" with a number that has an account |
| 50 | After the payment: "تم الدفع!" + "باقتك مفعّلة حتى …" / "لم يكتمل الدفع" + "حاول مرة أخرى" / "متابعة مجانًا" | `lib/features/premium/payment_result_screen.dart` | [x] | [x] | [x] | [x] "★ تأكيد" |
| 52 | Welcome of an expert: "ستظهر شارة «◆ خبير موثّق» بعد أن نتحقق من حسابك." | `lib/features/onboarding/welcome_screen.dart` | [x] | [x] | [x] | [x] "متابعة" (expert's information) |
| 53 | "ارسم بستانك" (start of the orchard designer): 3 steps, the price per zone, "★ ابدأ الرسم" = "قريبًا" (Phase 3), "متابعة مجانًا" (sign-up) / "ليس الآن" (in the app) | `lib/features/orchard_designer/designer_start_screen.dart` | [x] | [x] | [x] | [x] packs: Premium + "متابعة"; login with Premium not paid; Premium "★ ابدأ بريميوم" with nothing drawn; tab "بستاني ★" "★ ابدأ الرسم" |
| 54 | Payment of Premium from the bill of the database: a month ("32 د.ت / 30 يومًا", "4 مناطق") or the extra zones ("8 د.ت", "6 مناطق · حتى …") → `qr` | `lib/features/premium/payment_screen.dart` | [x] | [x] | [x] | [x] Premium "★ ابدأ بريميوم" / "★ جدّد باقتك" |
| 55 | "من أنت؟" on its own screen: two big buttons with an icon, "فلاح" (عندي بستان لوز) / "مهندس فلاحي أو مرشد" (أنصح الفلاحين في المجتمع) | `lib/features/onboarding/role_screen.dart` | [x] | [x] | [x] | [x] "تأكيد" (new number), login with no information yet, "back" from "معلوماتك" |
| 56 | Tab "بستاني ★" with Premium and nothing drawn yet: "ارسم بستانك" + "★ ابدأ الرسم" | `lib/features/orchard_3d/orchard_tab.dart` (`_DrawYourOrchard`) | [x] | [x] | [x] | [x] tab "بستاني ★" |
| 57 | Profile "خطتي": "بريميوم · 4 مناطق · حتى …" (2 lines if needed) or "مجاني" | `lib/features/profile/profile_page.dart` | [x] | [x] | [x] | [x] tab "حسابي" |

Checked with `test/sign_up_test.dart` (start screen, sign in, sign up Free / Premium → "ارسم بستانك"
/ refused card / demo off / extra zones / expert / account exists / French, stopped in the middle,
Premium, Profile), `test/plans_test.dart` (what each pack can open), `test/payment_unit_test.dart`,
`test/orchard_3d_data_test.dart`, `test/languages_test.dart` and screenshots in both languages.
`test_live/signup_payment_live_test.dart` (users 04, 05) and `test_live/orchard_live_test.dart`
(22 123 456 Premium with the demo orchard, 22 123 457 Free) run it against the real Supabase.

The two packs (migration 011, 9 November 2026): the old lines 51 (kit request), 53 (paid packs from
Premium) and 54 (Connected payment) were replaced. The kit screen was removed: installation visits
are made by the database when a paid orchard is built (Phase 3).

## Demo login: any number, any 6-digit code (migration 010 + Edge Function `demo-auth`)

No new screen: the phone and code screens of lines 2, 3 and 32 stay the same. While
`app_settings.demo_login_enabled` is true, no SMS is sent and any 6 digits log in; the sign-up then
shows every step (lines 55, 33, 35, 53 for Premium, 4). Checked with `test/demo_login_unit_test.dart`,
`test/sign_up_test.dart` (group "demo login"), `test_live/demo_login_live_test.dart` (numbers
22 999 001 / 002 / 003) and the real app in Chrome (22 123 456 Arabic, 22 123 457 French,
22 123 458 expert).

## Community (connected to Supabase, migration 006)

| # | Screen (state) | Flutter file | Built | Arabic checked | French checked | Opened from the right button(s) |
|---|---|---|---|---|---|---|
| 38 | `community` with the real questions (newest on top like the design, then the tip, "اسأل سؤالًا", the older ones) | `lib/features/community/community_page.dart`, `post_card.dart` | [x] | [x] | [x] | [x] tab "المجتمع", "اسأل خبيرًا" (result) |
| 39 | `community`: loading (pale card), empty ("اسأل سؤالك الأول"), no internet, "حاول مرة أخرى" | `lib/features/community/community_widgets.dart` | [x] | [x] | [x] | [x] (when it happens) |
| 40 | A question with its answers, write an answer, delete my answer / question (app's own) | `lib/features/community/post_screen.dart` | [x] | [x] | [x] | [x] a question of the list |
| 41 | "حذف؟" sheet (app's own) | `lib/features/community/community_widgets.dart` (`confirmDelete`) | [x] | [x] | [x] | [x] 🗑 on my answer / question |
| 42 | Write a question (app's own) | `lib/features/community/write_post_screen.dart` | [x] | [x] | [x] | [x] Ask "كتابة" |
| 43 | "قريبًا" message of the buttons that don't work yet (▶, tips speakers) | `lib/shared/widgets/soon_message.dart` | [x] | [x] | [x] | [x] ▶, 🔊 in the tips library |

Checked with `test/community_test.dart` (list, question, write, delete, errors, states, both
languages, with a fake community), `test/languages_test.dart` and screenshots in both languages.
`test_live/community_live_test.dart` runs it against the real Supabase (users 01, 02, 03).

## Community photos (Supabase Storage, migration 007)

| # | Screen (state) | Flutter file | Built | Arabic checked | French checked | Opened from the right button(s) |
|---|---|---|---|---|---|---|
| 44 | "＋ انشر" pill next to the title of the community (app's own) | `lib/features/community/community_page.dart`, `community_widgets.dart` (`PublishButton`) | [x] | [x] | [x] | [x] tab "المجتمع" |
| 45 | "انشر في المجتمع": text + "التقط صورة" / "اختر من الصور" (web: gallery only), "جاري تحضير الصورة…", preview with "تغيير" / "إزالة", "جاري رفع الصورة…" → "جاري النشر…" | `lib/features/community/write_post_screen.dart` | [x] | [x] | [x] | [x] "＋ انشر", Ask "كتابة" |
| 46 | Photo errors: camera / photos refused, no camera, too big, not a photo, upload failed | `write_post_screen.dart`, `community_widgets.dart` (`CommunityNote`) | [x] | [x] | [x] | [x] (when it happens) |
| 47 | The photo in the card and on the post's screen, "تعذّر عرض الصورة" | `lib/features/community/post_photo.dart`, `post_card.dart` | [x] | [x] | [x] | [x] the list, a question |
| 48 | The photo on the whole screen (pinch to zoom, ×) | `lib/features/community/photo_viewer.dart` | [x] | [x] | [x] | [x] tap on a photo |

Checked with `test/community_photo_test.dart` (fake community and fake camera),
`test/languages_test.dart` and screenshots in both languages.
`test_live/community_photo_live_test.dart` runs it against the real Supabase (users 01, 02).

## How each box was checked

- **Built in the new design**: rebuilt from the design's CSS (sizes, colors, fonts, positions).
- **Arabic / French checked**: a screenshot of the Flutter screen (390 x 844) was compared with
  the design's screenshot in the same language, element by element (0 element off by 2 px or
  more), and `test/languages_test.dart` checks that no text of the other language is shown.
  The 3D view (line 18) was checked in Chrome with the real orchard of 22 123 456 (real Supabase),
  in Arabic and in French, with the zone panels.
- **Opened from the right button(s)**: `test/navigation_test.dart` taps each button and checks the
  screen that opens (and `test/widget_test.dart` for the login steps).

(*) The "ابدأ بريميوم" button inside the 3D view also opens Premium (message `looz:upgrade`).
That one can't run in the tests (they have no WebView): it was checked in the code only.
