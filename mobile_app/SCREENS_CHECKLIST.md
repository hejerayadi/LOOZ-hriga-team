# Screens checklist

Every screen and state of the design (`App.tsx`), its Flutter file, and the checks.

| # | Design screen (state) | Flutter file | Built in the new design | Arabic checked | French checked | Opened from the right button(s) |
|---|---|---|---|---|---|---|
| 1 | `language` | `lib/features/onboarding/language_screen.dart` | [x] | [x] | [x] | [x] start of the app |
| 2 | `phone` (empty, typing) | `lib/features/onboarding/phone_screen.dart` (`PhoneScreen`) | [x] | [x] | [x] | [x] "العربية" / "Français" |
| 3 | `code` (empty, typing) | `lib/features/onboarding/phone_screen.dart` (`CodeScreen`) | [x] | [x] | [x] | [x] "إرسال الرمز" |
| 4 | `welcome` | `lib/features/onboarding/welcome_screen.dart` | [x] | [x] | [x] | [x] "تأكيد" |
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
| 20 | `payment` | `lib/features/premium/payment_screen.dart` | [x] | [x] | [x] | [x] Premium "★ ابدأ بريميوم" |
| 21 | `qr` | `lib/features/premium/qr_screen.dart` | [x] | [x] | [x] | [x] "★ تأكيد" |
| 22 | `map` | `lib/features/map/map_screen.dart` | [x] | [x] | [x] | [x] Home "خريطة", QR "فتح الخريطة" |
| 23 | `journal` | `lib/features/journal/journal_screen.dart` | [x] | [x] | [x] | [x] Home "دفتر" |
| 24 | `profile` | `lib/features/profile/profile_page.dart` | [x] | [x] | [x] | [x] tab "حسابي" |
| 25 | `states` | `lib/features/states/states_screen.dart` | [x] | [x] | [x] | [x] Profile "حالات التطبيق" |
| 26 | `states`: pending ("سيُرسل لاحقًا") | `lib/features/states/states_screen.dart` | [x] | [x] | [x] | [x] (in the states sheet) |
| 27 | `states`: offline ("لا يوجد إنترنت") | `lib/features/states/states_screen.dart` | [x] | [x] | [x] | [x] (in the states sheet) |
| 28 | `states`: error ("حاول مرة أخرى") | `lib/features/states/states_screen.dart` | [x] | [x] | [x] | [x] (in the states sheet) |
| 29 | `states`: empty ("اسأل سؤالك الأول") | `lib/features/states/states_screen.dart` | [x] | [x] | [x] | [x] (in the states sheet) |
| 30 | Shell: assistant bar + tab bar (5 tabs) | `lib/shared/widgets/shell.dart`, `looz_tab_bar.dart` | [x] | [x] | [x] | [x] on every screen with tabs |

## Sign up / sign in (not in the design: app's own screens, in the design's style)

| # | Screen (state) | Flutter file | Built | Arabic checked | French checked | Opened from the right button(s) |
|---|---|---|---|---|---|---|
| 31 | Start: logged in → Home; offline → "لا يوجد إنترنت" + "حاول مرة أخرى" | `lib/features/onboarding/sign_up_flow.dart` (`StartScreen`) | [x] | [x] | [x] | [x] start of the app |
| 32 | `phone` / `code`: waiting ("جاري الإرسال…"), error messages, "أعد إرسال الرمز" | `lib/features/onboarding/phone_screen.dart` | [x] | [x] | [x] | [x] "إرسال الرمز", "تأكيد" |
| 33 | Name: first name + last name, errors under the boxes | `lib/features/onboarding/name_screen.dart` | [x] | [x] | [x] | [x] "تأكيد" (new number) |
| 34 | Pack: Free / Essential / Connected | `lib/features/onboarding/pack_screen.dart` | [x] | [x] | [x] | [x] "متابعة" (name), login with no pack yet |
| 35 | Pay now or later (paid pack) | `lib/features/onboarding/payment_choice_screen.dart` | [x] | [x] | [x] | [x] "متابعة" with a paid pack |
| 36 | `payment` during the sign-up (no tab bar) | `lib/features/premium/payment_screen.dart` | [x] | [x] | [x] | [x] "★ ادفع الآن" |
| 37 | Profile: real name, phone number, "تسجيل الخروج" | `lib/features/profile/profile_page.dart` | [x] | [x] | [x] | [x] tab "حسابي" |

Checked with `test/sign_up_test.dart` (both flows, errors, session, log out, with a fake login),
`test/languages_test.dart` (lines 32 to 36) and screenshots in both languages.
`test_live/auth_live_test.dart` runs the same flow against the real Supabase.

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
