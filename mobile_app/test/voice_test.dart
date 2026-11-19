// The voice assistant "لوز" (Bêta, paid pack) with fakes (no internet, no
// Google, no microphone; the test plays Google's part): the first-time
// message, the Milestone 1 scenario ("شنوّة حال السانية؟" -> it looks at the
// orchard and answers, the texts on the screen, the microphone paused while
// it speaks), the stop button, the time over, the connection lost, the
// interruptions, every failure, French, the screen closed, and the messages
// of Google and the orchard tool.
// Run it with: flutter test test/voice_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/data/gemini_live.dart';
import 'package:looz_mobile/data/voice_service.dart';
import 'package:looz_mobile/data/voice_tools.dart';
import 'package:looz_mobile/features/ask/voice_screen.dart';
import 'package:looz_mobile/features/ask/voice_session.dart';
import 'package:looz_mobile/shared/widgets/assistant_button.dart';
import 'package:looz_mobile/shared/widgets/assistant_orb.dart';

import 'fake_voice.dart';
import 'test_helpers.dart';

/// The app on Home (paid pack), then the assistant bar -> the voice screen.
Future<FakeVoice> openVoice(
  WidgetTester tester, {
  String lang = 'ar',
  void Function(FakeVoice v)? before,
}) async {
  usePhoneScreen(tester);
  noAnimations(tester);
  appLocale.value = Locale(lang);
  currentPlan.value = Plan.paid;
  logInTestUser(lang);
  final v = FakeVoice();
  before?.call(v);
  await tester.pumpWidget(const LoozApp(home: MainShell()));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(AssistantButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await settle(tester);
  return v;
}

/// Lets the steps of the conversation happen (no pumpAndSettle: the clock
/// of the conversation ticks every second).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

/// Taps a button of the voice screen (scrolled into view first: the texts
/// of the conversation may push it down).
Future<void> tapText(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
  await settle(tester);
}

/// Taps "تكلّم" / "Parler": "لوز" listens.
Future<void> talk(WidgetTester tester, {String label = 'تكلّم'}) =>
    tapText(tester, label);

/// The big orb of the voice screen (not the one of Home behind it).
Finder get voiceOrb => find
    .descendant(
      of: find.byType(VoiceScreen),
      matching: find.byType(AssistantOrb),
    )
    .first;

List<Map<String, dynamic>> toolResponses(FakeVoice v) => [
  for (final m in v.live.sent)
    if (m['toolResponse'] != null) m['toolResponse'] as Map<String, dynamic>,
];

bool sentAudioEnd(FakeVoice v) => v.live.sent.any(
  (m) => (m['realtimeInput'] as Map?)?['audioStreamEnd'] == true,
);

void main() {
  setUpAll(loadAppFonts);
  tearDown(resetAppState);

  testWidgets('Milestone 1: "شنوّة حال السانية؟" -> it looks at his orchard, '
      'answers in Derja, the texts on the screen, the microphone paused while '
      'it speaks; "توقّف" ends it', (tester) async {
    final v = await openVoice(tester);
    expect(find.text('لوز'), findsOneWidget);
    expect(find.text('تجريبي'), findsOneWidget);
    expect(find.text('اضغط وقل سؤالك'), findsOneWidget);
    expect(find.text('بقيت 5 دقائق اليوم'), findsOneWidget);
    expect(find.text('لوز يمكن أن يخطئ. للأدوية اسأل خبيرًا.'), findsOneWidget);

    await talk(tester);
    // The locked token, Google's address, the setup (the model only).
    expect(v.service.calls, ['quota', 'start ar']);
    final uri = v.live.connected.single;
    expect(uri.scheme, 'wss');
    expect(uri.host, 'generativelanguage.googleapis.com');
    expect(uri.path, endsWith('BidiGenerateContentConstrained'));
    expect(uri.queryParameters['access_token'], 'auth_tokens/test-1');
    expect(v.live.sent.first, {
      'setup': {'model': 'models/gemini-3.8-live'},
    });
    expect(v.speaker.opened, isTrue);
    expect(v.mic.started, isTrue);
    expect(find.text('يسمع…'), findsOneWidget);
    expect(find.text('3:00'), findsOneWidget);
    expect(find.text('توقّف'), findsOneWidget);

    // He speaks: the microphone goes to Google (16 kHz PCM).
    v.mic.speak();
    await settle(tester);
    expect(v.live.audioSent, 1);
    final audio = v.live.sent.last['realtimeInput']['audio'] as Map;
    expect(audio['mimeType'], 'audio/pcm;rate=16000');
    expect(base64Decode(audio['data'] as String).length, 3200);
    v.live.heard('شنوّة حال');
    v.live.heard(' السانية؟');
    await settle(tester);
    expect(find.text('أنت'), findsOneWidget);
    expect(find.text('شنوّة حال السانية؟'), findsOneWidget);

    // Gemini asks for his orchard: the app runs the tool (his login).
    v.tools.hold = Completer<void>();
    v.live.toolCall('call-1', 'get_my_orchard');
    await settle(tester);
    expect(find.text('يفكّر…'), findsOneWidget);
    expect(find.text('ينظر في بستانك…'), findsOneWidget);
    expect(v.tools.calls, ['get_my_orchard']);
    expect(sentAudioEnd(v), isTrue, reason: 'the microphone is paused');
    v.mic.speak();
    await settle(tester);
    expect(v.live.audioSent, 1, reason: 'nothing sent while it thinks');
    v.tools.hold!.complete();
    await settle(tester);
    final response = toolResponses(v).single['functionResponses'] as List;
    expect(response.single['id'], 'call-1');
    expect(response.single['name'], 'get_my_orchard');
    expect((response.single['response']['zones'] as List).length, 2);

    // It answers with its voice and the text: "يحكي…", the loudspeaker
    // plays, the microphone sends nothing.
    v.live.answers('السانية لاباس. المنطقة ب ناقصها ماء شوية.', ms: 1500);
    await settle(tester);
    expect(find.text('يحكي…'), findsOneWidget);
    expect(find.text('اضغط على لوز لتقاطعه'), findsOneWidget);
    expect(
      find.text('السانية لاباس. المنطقة ب ناقصها ماء شوية.'),
      findsOneWidget,
    );
    expect(find.text('لوز'), findsNWidgets(2)); // the title and its line
    expect(v.speaker.bytes, 48 * 1500);
    v.mic.speak();
    await settle(tester);
    expect(v.live.audioSent, 1, reason: 'the microphone is paused');

    // The answer is over: back to listening once its voice is played
    // (1.5 s + 0.5 s for the loudspeaker to start).
    v.live.turnDone();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('يحكي…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('يسمع…'), findsOneWidget);
    v.mic.speak();
    await settle(tester);
    expect(v.live.audioSent, 2);
    expect(find.textContaining('2:5'), findsOneWidget); // the clock runs

    // "توقّف": the end, the database is told (codes and counts only).
    await tapText(tester, 'توقّف');
    expect(find.text('انتهت المحادثة'), findsOneWidget);
    expect(v.service.calls.last, 'end c1 farmer');
    final usage = v.service.ended.single;
    expect(usage.questions, 1);
    expect(usage.toolCalls, 1);
    expect(usage.tokensIn, 900);
    expect(usage.tokensOut, 300);
    expect(v.live.channel!.closed, isTrue);
    expect(v.mic.stopped, isTrue);
    expect(v.speaker.closed, isTrue);
    // The texts stay on the screen (never saved).
    expect(find.text('شنوّة حال السانية؟'), findsOneWidget);
    expect(find.text('تكلّم من جديد'), findsOneWidget);
    expect(find.text('بقيت دقيقتان اليوم'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('the first time: "قبل أن تتكلّم" (free tier: one more '
      'sentence); "موافق" -> ready', (tester) async {
    final v = await openVoice(
      tester,
      before: (v) => v.service.quota = const VoiceQuota(
        enabled: true,
        paid: true,
        consent: false,
        perDaySeconds: 300,
        leftSeconds: 300,
        sessionSeconds: 180,
        appOpen: true,
      ),
    );
    expect(find.text('قبل أن تتكلّم'), findsOneWidget);
    expect(
      find.text(
        'صوتك يُرسل إلى غوغل ليفهمه لوز ويجيبك. لوز لا يسجّل صوتك ولا يحفظ '
        'كلامك. نحفظ فقط مدّة المحادثة. وقد تستعمله غوغل لتحسين خدماتها.',
      ),
      findsOneWidget,
    );
    expect(find.text('تكلّم'), findsNothing);
    await tester.tap(find.text('موافق'));
    await settle(tester);
    expect(v.service.calls, ['quota', 'consent true', 'quota']);
    expect(find.text('اضغط وقل سؤالك'), findsOneWidget);
    expect(find.text('تكلّم'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('the first time, paid tier: no sentence about Google using the '
      'voice; "لا، شكرًا" closes the screen', (tester) async {
    final v = await openVoice(
      tester,
      before: (v) => v.service.quota = const VoiceQuota(
        enabled: true,
        paid: true,
        consent: false,
        perDaySeconds: 300,
        leftSeconds: 300,
        sessionSeconds: 180,
        appOpen: true,
        googleFreeTier: false,
      ),
    );
    expect(find.textContaining('نحفظ فقط مدّة المحادثة.'), findsOneWidget);
    expect(find.textContaining('تحسين خدماتها'), findsNothing);
    await tester.tap(find.text('لا، شكرًا'));
    await tester.pumpAndSettle();
    expect(find.byType(VoiceScreen), findsNothing);
    expect(v.service.calls, ['quota']);
    await closeApp(tester);
  });

  testWidgets('the server asks the consent again (taken back): the message', (
    tester,
  ) async {
    final v = await openVoice(tester);
    v.service.failStart = const VoiceError(VoiceFailure.consent);
    await talk(tester);
    expect(find.text('قبل أن تتكلّم'), findsOneWidget);
    expect(v.live.connected, isEmpty);
    expect(v.speaker.closed, isTrue);
    await closeApp(tester);
  });

  testWidgets('the time of the conversation is over: it ends by itself '
      '(time_up)', (tester) async {
    final v = await openVoice(tester);
    await talk(tester);
    await tester.pump(const Duration(seconds: 100));
    expect(find.text('1:20'), findsOneWidget);
    await tester.pump(const Duration(seconds: 81));
    await settle(tester);
    expect(find.text('انتهت المحادثة'), findsOneWidget);
    expect(v.service.calls.last, 'end c1 time_up');
    expect(v.mic.stopped, isTrue);
    await closeApp(tester);
  });

  testWidgets('the connection lost: "لوز لا يجيب الآن." and "حاول مرة أخرى" '
      '-> a new conversation', (tester) async {
    final v = await openVoice(tester);
    await talk(tester);
    v.live.hangUp();
    await settle(tester);
    expect(find.text('لوز لا يجيب الآن.'), findsOneWidget);
    expect(v.service.calls.last, 'end c1 error');
    await tapText(tester, 'حاول مرة أخرى');
    expect(v.service.calls.last, 'start ar');
    expect(find.text('يسمع…'), findsOneWidget);
    await tapText(tester, 'توقّف');
    expect(v.service.calls.last, 'end c2 farmer');
    await closeApp(tester);
  });

  testWidgets('interrupt "لوز": a tap on the orb stops its voice; Google\'s '
      '"interrupted" too', (tester) async {
    final v = await openVoice(tester);
    await talk(tester);
    v.live.answers('السانية لاباس.', ms: 3000);
    await settle(tester);
    expect(find.text('يحكي…'), findsOneWidget);
    await tester.tap(voiceOrb);
    await settle(tester);
    expect(v.speaker.cuts, 1);
    expect(find.text('يسمع…'), findsOneWidget);
    v.mic.speak();
    await settle(tester);
    expect(v.live.audioSent, 1, reason: 'it listens again at once');

    v.live.answers('المنطقة ب ناقصها ماء.', ms: 3000);
    await settle(tester);
    expect(find.text('يحكي…'), findsOneWidget);
    v.live.interrupted();
    await settle(tester);
    expect(v.speaker.cuts, 2);
    expect(find.text('يسمع…'), findsOneWidget);
    await closeApp(tester);
    await settle(tester);
    expect(v.service.calls.last, 'end c1 farmer');
  });

  group('can\'t talk', () {
    Future<FakeVoice> withQuota(
      WidgetTester tester, {
      bool enabled = true,
      int left = 300,
      bool appOpen = true,
    }) => openVoice(
      tester,
      before: (v) => v.service.quota = VoiceQuota(
        enabled: enabled,
        paid: true,
        consent: true,
        perDaySeconds: 300,
        leftSeconds: left,
        sessionSeconds: 180,
        appOpen: appOpen,
      ),
    );

    testWidgets('his minutes of the day are used', (tester) async {
      await withQuota(tester, left: 20);
      expect(find.text('انتهى وقتك مع لوز اليوم. ارجع غدًا.'), findsOneWidget);
      expect(find.text('تكلّم'), findsNothing);
      expect(find.text('حاول مرة أخرى'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('the minutes of the whole app are used', (tester) async {
      await withQuota(tester, appOpen: false);
      expect(find.text('لوز مشغول اليوم. حاول لاحقًا.'), findsOneWidget);
      expect(find.text('تكلّم'), findsNothing);
      await closeApp(tester);
    });

    testWidgets('switched off by an admin', (tester) async {
      await withQuota(tester, enabled: false);
      expect(find.text('المساعد متوقف الآن.'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('no internet: "تحتاج إلى الإنترنت", then it works', (
      tester,
    ) async {
      final v = await openVoice(
        tester,
        before: (v) =>
            v.service.failQuota = const VoiceError(VoiceFailure.noInternet),
      );
      expect(find.text('تحتاج إلى الإنترنت'), findsOneWidget);
      await tapText(tester, 'حاول مرة أخرى');
      expect(v.service.calls, ['quota', 'quota']);
      expect(find.text('اضغط وقل سؤالك'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('the microphone refused: the message, nothing opened', (
      tester,
    ) async {
      final v = await openVoice(tester, before: (v) => v.mic.allow = false);
      await talk(tester);
      expect(
        find.text('اسمح باستعمال الميكروفون لتتكلّم مع لوز.'),
        findsOneWidget,
      );
      expect(v.service.calls, ['quota']);
      expect(v.live.connected, isEmpty);
      expect(find.text('حاول مرة أخرى'), findsOneWidget);
      await closeApp(tester);
    });

    testWidgets('the server says the limit of the day (another phone used '
        'it)', (tester) async {
      final v = await openVoice(tester);
      v.service.failStart = const VoiceError(VoiceFailure.limitDay);
      await talk(tester);
      expect(find.text('انتهى وقتك مع لوز اليوم. ارجع غدًا.'), findsOneWidget);
      expect(v.live.connected, isEmpty);
      expect(v.speaker.closed, isTrue);
      await closeApp(tester);
    });

    testWidgets('Google can\'t be reached: "لوز لا يجيب الآن.", the '
        'conversation is closed (error)', (tester) async {
      final v = await openVoice(
        tester,
        before: (v) => v.live.unreachable = true,
      );
      await talk(tester);
      expect(find.text('لوز لا يجيب الآن.'), findsOneWidget);
      expect(v.service.calls.last, 'end c1 error');
      await closeApp(tester);
    });

    testWidgets('Google never says ready: after 15 s, "لوز لا يجيب الآن."', (
      tester,
    ) async {
      final v = await openVoice(
        tester,
        before: (v) => v.live.answerSetup = false,
      );
      await talk(tester);
      expect(find.text('لحظة…'), findsOneWidget);
      await tester.pump(VoiceSession.readyTimeout);
      await settle(tester);
      expect(find.text('لوز لا يجيب الآن.'), findsOneWidget);
      expect(v.service.calls.last, 'end c1 error');
      await closeApp(tester);
    });

    testWidgets('the paid pack ended: the locked screen', (tester) async {
      await openVoice(
        tester,
        before: (v) => v.service.quota = const VoiceQuota(
          enabled: true,
          paid: false,
          consent: true,
          perDaySeconds: 300,
          leftSeconds: 300,
          sessionSeconds: 180,
          appOpen: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VoiceScreen), findsNothing);
      expect(currentTab.value, AppTab.orchard);
      await closeApp(tester);
    });
  });

  testWidgets('the screen closed or the app hidden during a conversation: it '
      'ends (farmer)', (tester) async {
    final v = await openVoice(tester);
    await talk(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await settle(tester);
    expect(v.service.calls.last, 'end c1 farmer');
    expect(v.mic.stopped, isTrue);
    // (No frame is drawn while the app is hidden: back first.)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(find.text('انتهت المحادثة'), findsOneWidget);

    await talk(tester, label: 'تكلّم من جديد');
    expect(find.text('يسمع…'), findsOneWidget);
    await closeApp(tester);
    await settle(tester);
    expect(v.service.calls.last, 'end c2 farmer');
  });

  testWidgets('French: "Il écoute…", "Vous", "Looz", "Conversation terminée"', (
    tester,
  ) async {
    final v = await openVoice(tester, lang: 'fr');
    expect(find.text('Appuyez et parlez'), findsOneWidget);
    expect(find.text('Encore 5 minutes aujourd\'hui'), findsOneWidget);
    await talk(tester, label: 'Parler');
    expect(v.service.calls.last, 'start fr');
    expect(find.text('Il écoute…'), findsOneWidget);
    v.live.heard('Comment va mon verger ?');
    v.live.answers('Votre verger va bien.');
    await settle(tester);
    expect(find.text('Il parle…'), findsOneWidget);
    expect(find.text('Vous'), findsOneWidget);
    expect(find.text('Comment va mon verger ?'), findsOneWidget);
    expect(find.text('Votre verger va bien.'), findsOneWidget);
    await tapText(tester, 'Arrêter');
    expect(find.text('Conversation terminée'), findsOneWidget);
    expect(find.text('Encore 2 minutes aujourd\'hui'), findsOneWidget);
    expect(find.text('Parler encore'), findsOneWidget);
    await closeApp(tester);
  });

  group('the messages of Google', () {
    test('the address and the messages sent', () {
      final uri = liveUri('auth_tokens/abc');
      expect(
        uri.toString(),
        'wss://generativelanguage.googleapis.com/ws/google.ai.generative'
        'language.v1beta.GenerativeService.BidiGenerateContentConstrained'
        '?access_token=auth_tokens%2Fabc',
      );
      expect(
        setupMessage('gemini-3.8-live'),
        '{"setup":{"model":"models/gemini-3.8-live"}}',
      );
      expect(
        audioMessage(Uint8List.fromList([1, 2, 3])),
        '{"realtimeInput":{"audio":{"data":"AQID","mimeType":"audio/pcm;rate=16000"}}}',
      );
      expect(audioEndMessage(), '{"realtimeInput":{"audioStreamEnd":true}}');
      expect(
        toolResponseMessage([
          const LiveToolResult('c1', 'get_my_orchard', {'zones': []}),
        ]),
        '{"toolResponse":{"functionResponses":[{"id":"c1","name":"get_my_orchard","response":{"zones":[]}}]}}',
      );
    });

    test('one message -> its events, in order', () {
      final events = parseLiveMessage(
        jsonEncode({
          'serverContent': {
            'inputTranscription': {'text': 'شنوّة'},
            'modelTurn': {
              'parts': [
                {
                  'inlineData': {
                    'mimeType': 'audio/pcm;rate=24000',
                    'data': base64Encode([1, 2, 3, 4]),
                  },
                },
                {'text': 'a thought, not shown'},
                {
                  'inlineData': {'mimeType': 'audio/pcm', 'data': '%%%'},
                },
              ],
            },
            'outputTranscription': {'text': 'لاباس'},
            'interrupted': true,
            'turnComplete': true,
          },
          'usageMetadata': {
            'promptTokenCount': 100,
            'toolUsePromptTokenCount': 20,
            'responseTokenCount': 30,
            'thoughtsTokenCount': 5,
          },
          'goAway': {'timeLeft': '10s'},
        }),
      );
      expect(events.map((e) => e.runtimeType).toList(), [
        LiveHeard,
        LiveAudio,
        LiveSaid,
        LiveInterrupted,
        LiveUsage, // before the end: the tokens count for this answer
        LiveTurnDone,
        LiveGoAway,
      ]);
      expect((events[0] as LiveHeard).text, 'شنوّة');
      expect((events[1] as LiveAudio).pcm, [1, 2, 3, 4]);
      expect((events[2] as LiveSaid).text, 'لاباس');
      expect((events[4] as LiveUsage).input, 120);
      expect((events[4] as LiveUsage).output, 35);
      expect(
        parseLiveMessage('{"usageMetadata":{"promptTokenCount":7}}').single,
        isA<LiveUsage>(),
        reason: 'alone (not with the end of an answer)',
      );
    });

    test('ready, tool calls, cancel; bytes too; nonsense is ignored', () {
      expect(
        parseLiveMessage(utf8.encode('{"setupComplete":{}}')).single,
        isA<LiveReady>(),
      );
      final calls =
          parseLiveMessage(
                jsonEncode({
                  'toolCall': {
                    'functionCalls': [
                      {'id': 'x1', 'name': 'get_my_orchard'},
                      {
                        'id': 'x2',
                        'name': 'other',
                        'args': {'a': 1},
                      },
                      {'id': 'x3'},
                    ],
                  },
                }),
              ).single
              as LiveToolCalls;
      expect(calls.calls.map((c) => '${c.id} ${c.name} ${c.args}').toList(), [
        'x1 get_my_orchard {}',
        'x2 other {a: 1}',
      ]);
      expect(
        (parseLiveMessage('{"toolCallCancellation":{"ids":["x1"]}}').single
                as LiveToolCancel)
            .ids,
        ['x1'],
      );
      expect(parseLiveMessage('not json'), isEmpty);
      expect(parseLiveMessage('[1, 2]'), isEmpty);
      expect(parseLiveMessage(null), isEmpty);
      expect(
        parseLiveMessage(
          '{"serverContent":{"inputTranscription":{"text":""}}}',
        ),
        isEmpty,
      );
    });

    test('the length of a piece of voice (24 kHz, 2 bytes)', () {
      expect(voiceLength(48000), const Duration(seconds: 1));
      expect(voiceLength(4800), const Duration(milliseconds: 100));
    });
  });

  test('get_my_orchard: abjad letters in Arabic, Latin in French, the last '
      'reading of each box, a zone without a box', () {
    final now = DateTime(2026, 11, 15, 10);
    final answer = orchardAnswer(
      [
        {
          'id': 'z1',
          'letter': 'A',
          'name': null,
          'tree_count': 40,
          'cultivar': 'Achaak',
        },
        {'id': 'z2', 'letter': 'B', 'zone_type': 'irrigated', 'tree_count': 25},
      ],
      [
        {
          'zone_id': 'z2',
          'status': 'online',
          'measured_at': DateTime(2026, 11, 15, 9, 48).toIso8601String(),
          'soil_moisture_pct': 18.26,
          'air_temp_c': 21,
          'battery_pct': null,
          'level': 'watch',
          'reasons': ['water_stress'],
          'cause': 'water',
        },
      ],
      now,
    );
    final zones = answer['zones'] as List;
    expect(zones[0], {
      'zone_ar': 'المنطقة أ',
      'zone_fr': 'Zone A',
      'trees': 40,
      'cultivar': 'Achaak',
      'box': 'none',
    });
    expect(zones[1], {
      'zone_ar': 'المنطقة ب',
      'zone_fr': 'Zone B',
      'type': 'irrigated',
      'trees': 25,
      'box': 'online',
      'minutes_since_reading': 12,
      'soil_moisture_pct': 18.3,
      'air_temp_c': 21,
      'level': 'watch',
      'reasons': ['water_stress'],
      'cause': 'water',
    });
    expect(answer['now'], now.toIso8601String());
  });

  test(
    'the answers of the server -> codes; the Arabic plural of the minutes',
    () {
      expect(voiceFailureOfCode('not_paid'), VoiceFailure.notPaid);
      expect(voiceFailureOfCode('consent'), VoiceFailure.consent);
      expect(voiceFailureOfCode('limit_day'), VoiceFailure.limitDay);
      expect(voiceFailureOfCode('busy'), VoiceFailure.busy);
      expect(voiceFailureOfCode('off'), VoiceFailure.off);
      expect(voiceFailureOfCode('unavailable'), VoiceFailure.unavailable);
      expect(voiceFailureOfCode('server'), VoiceFailure.unavailable);
      expect(voiceFailureOfCode('???'), VoiceFailure.unknown);
      final q = VoiceQuota.fromRow({
        'enabled': true,
        'paid': true,
        'consent': false,
        'per_day_seconds': 300,
        'left_seconds': 29,
        'session_seconds': 180,
        'app_open': true,
      });
      expect(q.canTalk, isFalse);
      expect(q.googleFreeTier, isTrue);
      final t = VoiceTicket.fromAnswer({
        'id': 'c1',
        'token': 'auth_tokens/x',
        'model': 'gemini-3.8-live',
        'seconds': 180,
        'left_seconds': 120,
      });
      expect(
        '${t.id} ${t.token} ${t.seconds} ${t.leftSeconds}',
        'c1 auth_tokens/x 180 120',
      );
      final ar = lookupAppLocalizations(const Locale('ar'));
      expect(ar.voiceMinutesLeft(0), 'لم يبق وقت اليوم');
      expect(ar.voiceMinutesLeft(1), 'بقيت دقيقة واحدة اليوم');
      expect(ar.voiceMinutesLeft(2), 'بقيت دقيقتان اليوم');
      expect(ar.voiceMinutesLeft(5), 'بقيت 5 دقائق اليوم');
      expect(ar.voiceMinutesLeft(11), 'بقيت 11 دقيقة اليوم');
    },
  );
}
