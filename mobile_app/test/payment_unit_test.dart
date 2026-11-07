// The small pieces of the sign-up and the demo payment: prices, numbers
// typed by the farmer, the 24 governorates, the errors and their messages.
// Run it with: flutter test
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:looz_mobile/core/governorates.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/validators.dart';
import 'package:looz_mobile/data/payment_service.dart';
import 'package:looz_mobile/features/premium/pack_texts.dart';

final ar = lookupAppLocalizations(const Locale('ar'));
final fr = lookupAppLocalizations(const Locale('fr'));
final latin = RegExp('[A-Za-zÀ-ÖØ-öø-ÿ]');
final arabic = RegExp('[؀-ۿ]');

void main() {
  test('prices in dinars, per 30 days, per sensor', () {
    expect(dinars(15000), '15');
    expect(dinars(8000), '8');
    expect(dinars(15500), '15.5');
    expect(dinars(12345), '12.345');
    const essential = PackPrice(
      plan: Plan.essential,
      millimes: 15000,
      days: 30,
    );
    const connected = PackPrice(
      plan: Plan.connected,
      millimes: 8000,
      days: 30,
      perSensor: true,
    );
    expect(priceText(ar, essential), '15 د.ت / 30 يومًا');
    expect(priceText(fr, essential), '15 DT / 30 jours');
    expect(priceText(ar, connected), '8 د.ت لكل حسّاس / 30 يومًا');
    expect(priceText(fr, connected), '8 DT par capteur / 30 jours');
    // The installed kit: the whole amount.
    expect(priceText(ar, connected, sensors: 5), '40 د.ت / 30 يومًا');
    expect(ar.kitSensors(5), '5 حسّاسات');
    expect(ar.kitSensors(1), 'حسّاس واحد');
    expect(fr.kitSensors(12), '12 capteurs');
    expect(dayText(DateTime(2026, 11, 30, 12)), '30/11/2026');
  });

  test('numbers typed by the farmer (also with an Arabic keyboard)', () {
    expect(westernDigits('١٢٠'), '120');
    expect(parseAlmondTrees('120'), 120);
    expect(parseAlmondTrees(' ١٢٠ '), 120);
    for (final wrong in ['0', '-5', '100001', '12.5', 'abc', '']) {
      expect(parseAlmondTrees(wrong), isNull, reason: wrong);
    }
    expect(parseOrchardArea('2,5'), 2.5);
    expect(parseOrchardArea('٢٫٥'), isNull); // Arabic comma: not a number
    expect(parseOrchardArea('0.25'), 0.25);
    for (final wrong in ['0', '10001', '1.234', 'abc', '']) {
      expect(parseOrchardArea(wrong), isNull, reason: wrong);
    }
  });

  test('the 24 governorates: same codes as the database, a name in each '
      'language', () {
    expect(governorates, hasLength(24));
    expect(governorates.toSet(), hasLength(24));
    final arNames = [for (final g in governorates) governorateName(ar, g)!];
    final frNames = [for (final g in governorates) governorateName(fr, g)!];
    expect(arNames.toSet(), hasLength(24));
    expect(frNames.toSet(), hasLength(24));
    for (final name in arNames) {
      expect(name, isNot(matches(latin)), reason: name);
    }
    for (final name in frNames) {
      expect(name, isNot(matches(arabic)), reason: name);
    }
    expect(governorateName(ar, 'sidi_bouzid'), 'سيدي بوزيد');
    expect(governorateName(fr, 'kef'), 'Le Kef');
    expect(governorateName(ar, 'paris'), isNull);
  });

  test('errors of the demo payment become the right message', () {
    final cases = <Object, PaymentFailure>{
      const PostgrestException(
        message: 'Demo payments are turned off',
        code: 'PT403',
      ): PaymentFailure.notAvailable,
      const PostgrestException(
        message: 'The LOOZ kit is not installed yet',
        code: 'PT409',
      ): PaymentFailure.kitNotInstalled,
      const PostgrestException(message: 'Too many payments', code: 'PT429'):
          PaymentFailure.tooManyTries,
      const PostgrestException(
        message: 'Choose your governorate first',
        code: '22023',
      ): PaymentFailure.noGovernorate,
      const PostgrestException(message: 'JWT expired', code: 'PGRST303'):
          PaymentFailure.sessionExpired,
      Exception('ClientException: Failed host lookup'):
          PaymentFailure.noInternet,
      StateError('?'): PaymentFailure.unknown,
    };
    cases.forEach((error, failure) {
      expect(paymentFailureOf(error), failure, reason: '$error');
    });

    final arTexts = [
      for (final f in PaymentFailure.values) paymentFailureMessage(ar, f),
    ];
    final frTexts = [
      for (final f in PaymentFailure.values) paymentFailureMessage(fr, f),
    ];
    for (final text in arTexts) {
      expect(text, isNot(matches(latin)), reason: text);
    }
    for (final text in frTexts) {
      expect(text, isNot(matches(arabic)), reason: text);
    }
    expect(arTexts.toSet(), hasLength(arTexts.length));
  });
}
