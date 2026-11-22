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
| 9 | `camera`, now REAL (photo diagnosis Bêta, line 76) | `lib/features/camera/camera_screen.dart` | [x] | [x] | [x] | [x] camera button, Ask "صورة" (paid pack; Free: locked) |
| 10 | `thinking`: "جاري النظر…" while the REAL diagnosis runs (line 77) | `lib/features/camera/thinking_screen.dart` | [x] | [x] | [x] | [x] the round button / "اختر من الصور" |
| 11 | `result`: the REAL result (line 78) | `lib/features/camera/result_screen.dart` | [x] | [x] | [x] | [x] after "جاري النظر…" |
| 12 | `voice` = the voice assistant "لوز" (Bêta, real Gemini Live): first-time message, "يسمع… / يفكّر… / يحكي…", the texts of both sides, stop, the clock, the messages (PROJECT_STATUS section 17) | `lib/features/ask/voice_screen.dart` | [x] | [x] | [x] | [x] "اسأل المساعد", Ask "تكلّم" / "أرسل" |
| 13 | `alerts` with the REAL regional alerts (line 70) | `lib/features/alerts/alerts_page.dart` | [x] | [x] | [x] | [x] tab "التنبيهات" |
| 14 | `alert` (needs water): removed (fake). A tree on the map says "قريبًا"; Home shows the real alert (line 75) | — | — | — | — | — |
| 15 | `alert` (done: "أحسنت!", falling petals): now in the regional alert's "تمّ" (line 72) | `lib/shared/widgets/falling_petals.dart` | [x] | [x] | [x] | [x] "تمّ" |
| 16 | `regional` with a REAL alert (line 71) | `lib/features/alerts/regional_screen.dart` | [x] | [x] | [x] | [x] a card of the tab, Home's alert card |
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
| 36 | `payment` during the sign-up (no tab bar): "وضع تجريبي", card boxes with icons, errors under them, "جاري التحقق من الدفع…" | `lib/features/premium/payment_screen.dart`, `demo_card_form.dart` | [x] | [x] | [x] | [x] the designer's review "★ ادفع وابنِ بستاني" (line 66) |
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
| 53 | "ارسم بستانك" (start of the orchard designer): 3 steps, the price per zone, "بإصبعك، على شبكة" (default) / "من صورة" (line 86) / "على صورة القمر الصناعي" ("قريبًا"), "★ ابدأ الرسم" (line 58), a draft: "رسمك محفوظ" + "★ أكمل الرسم" / "ابدأ من جديد", "متابعة مجانًا" (sign-up) / "ليس الآن" (in the app) | `lib/features/orchard_designer/designer_start_screen.dart` | [x] | [x] | [x] | [x] packs: Premium + "متابعة"; login with Premium not paid; Premium "★ ابدأ بريميوم" with nothing drawn; tab "بستاني ★" "★ ابدأ الرسم" |
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

## The orchard designer (Phase 3, migration 011)

The designer's steps have no tab bar (drawing needs the whole screen), a back button and
"الخطوة 1 من 3". Big tools with a word under each icon.

| # | Screen (state) | Flutter file | Built | Arabic checked | French checked | Opened from the right button(s) |
|---|---|---|---|---|---|---|
| 58 | Step 1, the outline: the grid (north, "المربّع = 25 م"), "قلم" / "نقاط" / "تراجع" / "إعادة" / "امسح", the corners (drag to move), "العرض" / "الطول" / the area in hectares | `lib/features/orchard_designer/outline_screen.dart`, `orchard_canvas.dart`, `outline_editor.dart` | [x] | [x] | [x] | [x] "★ ابدأ الرسم", "★ أكمل الرسم" |
| 59 | Step 1: the problems ("خطّان يتقاطعان. حرّك نقطة.", "الشكل صغير جدًا"), no "التالي" | `outline_screen.dart` | [x] | [x] | [x] | [x] (when it happens) |
| 60 | The size sheet: "مقاس بستانك تقريبًا", width and length in metres (5 to 3000), "تمّ" | `designer_widgets.dart` (`showSizeSheet`) | [x] | [x] | [x] | [x] the "العرض" / "الطول" boxes |
| 61 | Step 2, how: "أعطي عدد المناطق والأشجار" / "أرسم خطوط التقسيم بنفسي" | `zones_screen.dart` | [x] | [x] | [x] | [x] step 1 "★ التالي", "غيّر الطريقة" |
| 62 | Step 2, automatic: "عدد المناطق" − / +, the trees of each zone, the strips drawn | `zones_screen.dart` | [x] | [x] | [x] | [x] "أعطي عدد المناطق والأشجار" |
| 63 | Step 2, my lines: drag a line (dashed), "تراجع" / "امسح", "4 مناطق", "الخط لم يقسم أي منطقة." | `zones_screen.dart` | [x] | [x] | [x] | [x] "أرسم خطوط التقسيم بنفسي" |
| 64 | The zones: each zone (colour, letter, name, trees, type) | `zone_details_screen.dart` | [x] | [x] | [x] | [x] step 2 "★ التالي", "★ أكمل الرسم" |
| 65 | The sheet of a zone: trees, type (6), name (optional, 30 letters), colour (10), "تمّ" | `zone_details_screen.dart` (`_ZoneSheet`) | [x] | [x] | [x] | [x] a tap on a zone |
| 66 | Step 3, the review: the drawing, area, zones, trees, sensors, the price (from the database); the area minimum in one sentence; "باقتك تكفي هذا البستان." + "★ ابنِ بستاني"; "بستانك كبير جدًا. اتصل بنا." | `review_screen.dart` | [x] | [x] | [x] | [x] the zones "★ التالي", "★ أكمل الرسم" |
| 67 | "جاري بناء بستانك…" (the database builds the orchard), "حاول مرة أخرى" | `build_orchard_screen.dart` | [x] | [x] | [x] | [x] paid "متابعة", "★ ابنِ بستاني" |
| 68 | After building: (sign-up) the welcome, then "بستاني ★" in 3D with the new orchard | `welcome_screen.dart` (`openTab`), `orchard_tab.dart` | [x] | [x] | [x] | [x] "جاري بناء بستانك…" |
| 69 | "هل تمسح رسمك وتبدأ من جديد؟" "امسح" / "إلغاء" | `designer_widgets.dart` (`confirmErase`) | [x] | [x] | [x] | [x] "ابدأ من جديد" |
| 86 | "من صورة" (22 Nov 2026): "صوّر رسمة بستانك", the tips (قلم أسود غليظ · ورقة بيضاء · صوّر من فوق · الورقة كاملة في الصورة), "الصورة تبقى في هاتفك، لا نرسلها.", the round button (web: the photos), "اختر من الصور", "نبحث عن حدود البستان…" | `lib/features/orchard_designer/sketch_screen.dart`, `sketch_reader.dart`, `sketch_detect.dart` | [x] | [x] | [x] | [x] "من صورة" + "★ ابدأ الرسم" |
| 87 | Step 1 with the photo: the outline found, its dots on the faded photo, "وجدنا حدود بستانك. حرّك النقاط إذا لزم.", the size stretches the photo too | `outline_screen.dart`, `orchard_canvas.dart`, `outline_editor.dart` | [x] | [x] | [x] | [x] a photo with a closed outline |
| 88 | Not found: "لم نجد حدود البستان في الصورة." + "حدّد الزوايا على الصورة" (corners tapped on the photo) / "صورة أخرى" / "ارسم بيدك" | `sketch_screen.dart` (`_NotFoundCard`) | [x] | [x] | [x] | [x] a photo without a closed outline |

Checked with `test/geometry_test.dart` (28 tests), `test/designer_test.dart` (24 tests: every step
with a finger and with a mouse, resume, errors, French, a 360 x 640 phone), `test/languages_test.dart`,
screenshots of every step in both languages (390 x 844 and 360 x 640), the real app in Chrome with
a mouse (Arabic with the automatic zones, French with my own lines: new numbers 22 989 005 / 006)
and `test_live/designer_live_test.dart` (real Supabase, a new number each run).

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

## Alerts and "إبلاغ" (connected to Supabase, migration 015)

| # | Screen (state) | Flutter file | Built | Arabic checked | French checked | Opened from the right button(s) |
|---|---|---|---|---|---|---|
| 70 | The tab "التنبيهات": "{n} تحتاج انتباهك" / "لا تنبيه اليوم", "في منطقتك · صفاقس", the cards (face + bar by severity, icon of the kind, "جديد", the first step or the severity, a done one paler at the end), loading, no internet + "حاول مرة أخرى", "لا تنبيه في منطقتك. كل شيء هادئ.", pull down; Premium: "بستاني" + "قريبًا"; "الإشعارات على الهاتف — قريبًا" | `lib/features/alerts/alerts_page.dart`, `alert_widgets.dart`, `alerts_store.dart` | [x] | [x] | [x] | [x] tab "التنبيهات", Home's "كل شيء بخير" |
| 71 | A regional alert: "تنبيه في منطقتك" + governorate, the card (icon, "خطر" / "انتباه" / "معلومة", the kind, title, text), "ماذا أفعل؟" with numbered steps and 🔊 ("قريبًا"), "صالح حتى …" / "صالح حتى إشعار آخر", the count | `lib/features/alerts/regional_screen.dart` | [x] | [x] | [x] | [x] a card of the tab, Home |
| 72 | "أنا أيضًا" → "✓ أنا أيضًا" + "تراجع"; "تمّ" (with advice) → "أحسنت!" + petals + "تراجع"; ended while open: "انتهى هذا التنبيه." + "رجوع إلى التنبيهات"; a failed button: a short message | `regional_screen.dart` | [x] | [x] | [x] | [x] (on the alert's screen) |
| 73 | The number of new alerts on the bell of the tab bar | `lib/shared/widgets/looz_tab_bar.dart` | [x] | [x] | [x] | [x] (every screen with the tab bar) |
| 74 | "إبلاغ" on the question and the answers of others, "✓ أبلغت"; the sheet "لماذا تبلّغ؟" (4 reasons + "إلغاء"); "شكرًا. سيراجعه فريق لوز.", "بلغت الحد اليوم. حاول غدًا." | `lib/features/community/post_screen.dart`, `post_card.dart`, `community_widgets.dart` (`ReportButton`, `chooseReportReason`) | [x] | [x] | [x] | [x] a question of the community |
| 75 | Home: the most important real alert (or "كل شيء بخير"), "انتبه: تنبيه في منطقتك" under the title | `lib/features/home/home_page.dart` | [x] | [x] | [x] | [x] tab "الرئيسية" |

Checked with `test/alerts_test.dart` (18 tests), `test/report_test.dart` (11 tests, also a 360 x 640
phone), `test/languages_test.dart`, `test/navigation_test.dart`, the real app in Chrome with the real
Supabase (22 777 001, Arabic and French: `docs/screenshots/app-alerts/`) and
`dashboard/backend/tests_live/test_live_app_alerts.py` (the jury scenario).

## Photo diagnosis (Bêta, migrations 016 + 018 + Edge Function "diagnose", Gemini or Roboflow)

| # | Screen (state) | Flutter file | Built | Arabic checked | French checked | Opened from the right button(s) |
|---|---|---|---|---|---|---|
| 76 | Camera: "تجريبي", the tips (ورقة لوز واحدة · من قريب · في الضوء), "يمكنك إرسال {n} صور اليوم", the privacy line (Gemini: "تُرسل الصورة إلى خدمة ذكاء اصطناعي (غوغل أو مزوّد آخر) لفحصها، وتُحفظ في حسابك." + on the free tier "وقد تستعملها غوغل لتحسين خدماتها."), the round button (web: the photos), "اختر من الصور", "جاري تحضير الصورة…"; messages: no photo left, switched off, "تحتاج إلى الإنترنت", camera / photos refused | `lib/features/camera/camera_screen.dart`, `diagnosis_widgets.dart` | [x] | [x] | [x] | [x] camera button, Ask "صورة", "صوّر ورقة أخرى" |
| 77 | "جاري النظر…" with the photo; failures: "تحتاج إلى الإنترنت" + "حاول مرة أخرى", the limit of the day (plural) + "اسأل خبيرًا", busy, unavailable, unreadable photo + "صوّر ورقة أخرى", "رجوع"; pack ended: the locked screen | `lib/features/camera/thinking_screen.dart` | [x] | [x] | [x] | [x] the round button, "اختر من الصور" |
| 78 | Result: the disease + "على الأرجح" / "غير متأكد", "تجريبي", 🔊 ("قريبًا"), the photo with the spots framed, "ماذا أفعل؟" (3 steps, drafts), "هذا ليس تشخيصًا نهائيًا…", "اسأل خبيرًا", "صوّر ورقة أخرى" | `lib/features/camera/result_screen.dart`, `diagnosis_texts.dart` | [x] | [x] | [x] | [x] after "جاري النظر…" |
| 79 | Result "لم نجد هذه الأمراض الثلاثة.": the tip, "هذا لا يعني أن الشجرة سليمة.", "نبحث فقط عن: ثقوب، تجعّد، بقع.", "هذا ليس تشخيصًا نهائيًا…", no marks | `lib/features/camera/result_screen.dart` | [x] | [x] | [x] | [x] after "جاري النظر…" |
| 80 | "اسأل خبيرًا": the question screen with the photo and a ready question → "انشر" → the community + "سؤالك في المجتمع" | `lib/features/community/write_post_screen.dart` (`initialText`, `initialPhoto`, `onPublished`) | [x] | [x] | [x] | [x] the result, the failures |
| 81 | Zone letters in Arabic: أ ب ج د… (abjad) in the designer and the 3D ("المنطقة أ") | `lib/core/zone_letters.dart` | [x] | [x] | [x] | [x] (every zone) |

Checked with `test/diagnosis_test.dart` (29 tests), `test/languages_test.dart` (no Latin letter on an
Arabic screen any more, zone letters included), `test/navigation_test.dart`, the Edge Function's local
test (101 checks, fake Roboflow, fake Gemini, backup key, fake Groq) and, once `diagnose` is deployed, the real app in Chrome and
`dashboard/backend/tests_live/test_live_diagnosis.py`.

## ML predictions (paid pack, migration 019)

| # | Screen (state) | Flutter file | Built | Arabic checked | French checked | Opened from the right button(s) |
|---|---|---|---|---|---|---|
| 82 | 3D: each zone coloured by its state, its label (name + state), the box light | `lib/features/orchard_3d/orchard_tab.dart`, `orchard_3d_data.dart` (`orchardLiveJson`), `assets/orchard_3d/index.html` (`loozSetLive`) | [x] | [x] | [x] | [x] tab "بستاني ★" |
| 83 | The zone panel: state pill, "على الأرجح / غير متأكد", "آخر تحديث", the explanation (Groq or from the codes), "ماذا أفعل؟", "لماذا؟" bars, tonight / the trees line, the readings; sensor problem, offline, not enough data, waiting | `lib/features/orchard_3d/zone_panel.dart`, `zone_live_texts.dart` | [x] | [x] | [x] | [x] a tap on a zone in 3D, an alert card, a banner |
| 84 | Alerts tab, "بستاني": one card per problem ("جديد"), "كل مناطقك بخير.", "ننتظر قراءات حسّاساتك."; the bell counts them | `lib/features/alerts/orchard_alerts.dart`, `alerts_page.dart`, `shared/widgets/looz_tab_bar.dart` | [x] | [x] | [x] | [x] tab "التنبيهات" |
| 85 | In-app notification: the banner at the top (once per problem), tap → the zone | `lib/features/alerts/orchard_alerts.dart` (`MlBannerHost`), `app.dart` | [x] | [x] | [x] | [x] a new problem while the app is open (Realtime) |

Checked with `test/ml_test.dart` (11 tests), the whole suite (286) and screenshots in both languages
(`docs/screenshots/ml-predictions-app/`, made with the fakes: `tool/screens/ml_screens_main.dart`).

## How each box was checked

- **Built in the new design**: rebuilt from the design's CSS (sizes, colors, fonts, positions).
- **Arabic / French checked**: a screenshot of the Flutter screen (390 x 844) was compared with
  the design's screenshot in the same language, element by element (0 element off by 2 px or
  more), and `test/languages_test.dart` checks that no text of the other language is shown.
  The 3D view (line 18) was checked in Chrome with the real orchard of 22 123 456 (real Supabase),
  in Arabic and in French, with the zone panels, and with orchards just made by the designer.
- **Opened from the right button(s)**: `test/navigation_test.dart` taps each button and checks the
  screen that opens (and `test/widget_test.dart` for the login steps).

(*) The "ابدأ بريميوم" button inside the 3D view also opens Premium (message `looz:upgrade`).
That one can't run in the tests (they have no WebView): it was checked in the code only.
