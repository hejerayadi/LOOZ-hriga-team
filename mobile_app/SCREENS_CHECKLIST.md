# Screens checklist

Every screen and state of the design (`App.tsx`), its Flutter file, and the checks.

| # | Design screen (state) | Flutter file | Built in the new design | Arabic checked | French checked | Opened from the right button(s) |
|---|---|---|---|---|---|---|
| 1 | `language` → now the start screen: the photo, "عربي \| FR" (remembered on the phone), "إنشاء حساب" / "تسجيل الدخول" | `lib/features/onboarding/start_screen.dart` (`StartScreen`) | [x] | [x] | [x] | [x] start of the app (logged out), "تسجيل الخروج" |
| 2 | `phone` (empty, typing) | `lib/features/onboarding/phone_screen.dart` (`PhoneScreen`) | [x] | [x] | [x] | [x] "إنشاء حساب" / "تسجيل الدخول" |
| 3 | `code` (empty, typing) | `lib/features/onboarding/phone_screen.dart` (`CodeScreen`) | [x] | [x] | [x] | [x] "إرسال الرمز" |
| 4 | `welcome` | `lib/features/onboarding/welcome_screen.dart` | [x] | [x] | [x] | [x] end of the sign-up: Free "متابعة", "تم الدفع!" "متابعة", "متابعة مجانًا", kit "متابعة", expert "متابعة" |
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
| 17 | `locked` ("بستاني ★" without Premium) | `lib/features/orchard_3d/orchard_tab.dart` | [x] | [x] | [x] | [x] tab "بستاني ★", camera / map on the free plan, Premium "ليس الآن" |
| 18 | My orchard in 3D (app's own, in the "بستاني ★" tab) | `lib/features/orchard_3d/orchard_tab.dart`, `assets/orchard_3d/index.html` | [x] | [x] | [x] | [x] tab "بستاني ★" with Premium |
| 19 | `premium` | `lib/features/premium/premium_screen.dart` | [x] | [x] | [x] | [x] "★ ابدأ بريميوم", Profile "خطتي" (*) |
| 20 | `payment` (the design's card boxes: DEMO payment, see line 36) | `lib/features/premium/payment_screen.dart`, `demo_card_form.dart` | [x] | [x] | [x] | [x] Premium "★ ابدأ بريميوم" → packs → "متابعة" |
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
| 35 | Packs: Free / Essential 15 DT / Connected 8 DT per sensor (prices from the database) | `lib/features/onboarding/pack_screen.dart` | [x] | [x] | [x] | [x] "متابعة" (farmer's information), login with no pack yet |
| 36 | `payment` during the sign-up (no tab bar): "وضع تجريبي", card boxes with icons, errors under them, "جاري التحقق من الدفع…" | `lib/features/premium/payment_screen.dart`, `demo_card_form.dart` | [x] | [x] | [x] | [x] Essential + "متابعة"; login or "إنشاء حساب" with Essential not paid; "حاول مرة أخرى" |
| 37 | Profile: real name, phone number, "خطتي" with the pack and its end date, "تسجيل الخروج" | `lib/features/profile/profile_page.dart` | [x] | [x] | [x] | [x] tab "حسابي" |

The old "pay now or later" screen (`payment_choice_screen.dart`) and the name screen
(`name_screen.dart`) were removed: the payment comes right after the pack, and the name is in
"معلوماتك".

Checked with `test/sign_up_test.dart` (both flows, errors, session, log out, with a fake login),
`test/languages_test.dart` and screenshots in both languages.
`test_live/auth_live_test.dart` runs the same flow against the real Supabase (users 01, 02).

## Start of the app: roles, packs, demo payment (migrations 008 and 009)

| # | Screen (state) | Flutter file | Built | Arabic checked | French checked | Opened from the right button(s) |
|---|---|---|---|---|---|---|
| 49 | "مرحبًا من جديد": "هذا الرقم لديه حساب بالفعل." + "تسجيل الدخول" (nothing changed) | `lib/features/onboarding/phone_screen.dart` (`AccountExistsScreen`) | [x] | [x] | [x] | [x] "إنشاء حساب" with a number that has an account |
| 50 | After the payment: "تم الدفع!" + "باقتك مفعّلة حتى …" / "لم يكتمل الدفع" + "حاول مرة أخرى" / "متابعة مجانًا" | `lib/features/premium/payment_result_screen.dart` | [x] | [x] | [x] | [x] "★ تأكيد" |
| 51 | "عُدّة لوز": "سنتصل بك لتركيب عُدّة الحسّاسات في بستانك." (the farmer stays on Free) | `lib/features/premium/kit_requested_screen.dart` | [x] | [x] | [x] | [x] Connected + "متابعة" (no kit installed yet) |
| 52 | Welcome of an expert: "ستظهر شارة «◆ خبير موثّق» بعد أن نتحقق من حسابك." | `lib/features/onboarding/welcome_screen.dart` | [x] | [x] | [x] | [x] "متابعة" (expert's information) |
| 53 | Packs from Premium: only the paid packs; Connected = 8 DT × the sensors of the installed kit | `lib/features/onboarding/pack_screen.dart` (`upgrade: true`) | [x] | [x] | [x] | [x] Premium "★ ابدأ بريميوم" |
| 54 | Payment of Connected after the installation ("40 د.ت / 30 يومًا", "5 حسّاسات") → `qr` | `lib/features/premium/payment_screen.dart` | [x] | [x] | [x] | [x] packs (line 53) → Connected → "متابعة" |
| 55 | "من أنت؟" on its own screen: two big buttons with an icon, "فلاح" (عندي بستان لوز) / "مهندس فلاحي أو مرشد" (أنصح الفلاحين في المجتمع) | `lib/features/onboarding/role_screen.dart` | [x] | [x] | [x] | [x] "تأكيد" (new number), login with no information yet, "back" from "معلوماتك" |

Checked with `test/sign_up_test.dart` (start screen, sign in, sign up Free / Essential / refused card
/ demo off / Connected / expert / account exists / French, stopped in the middle, Premium, Profile),
`test/payment_unit_test.dart`, `test/languages_test.dart` and screenshots in both languages.
`test_live/signup_payment_live_test.dart` runs it against the real Supabase (users 04, 05).

## Demo login: any number, any 6-digit code (migration 010 + Edge Function `demo-auth`)

No new screen: the phone and code screens of lines 2, 3 and 32 stay the same. While
`app_settings.demo_login_enabled` is true, no SMS is sent and any 6 digits log in; the sign-up then
shows every step (lines 55, 33, 35, 36 / 51, 4). Checked with `test/demo_login_unit_test.dart`,
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
  The 3D view (line 18) was checked in Chrome: Arabic right to left, then a live switch to French.
- **Opened from the right button(s)**: `test/navigation_test.dart` taps each button and checks the
  screen that opens (and `test/widget_test.dart` for the login steps).

(*) The "ابدأ بريميوم" button inside the 3D view also opens Premium (message `looz:upgrade`).
That one can't run in the tests (they have no WebView): it was checked in the code only.
