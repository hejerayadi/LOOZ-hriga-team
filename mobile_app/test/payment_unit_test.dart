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
  test('prices in dinars, per zone and 30 days', () {
    expect(dinars(15000), '15');
    expect(dinars(8000), '8');
    expect(dinars(15500), '15.5');
    expect(dinars(12345), '12.345');
    const price = PackPrice(millimes: 8000, days: 30);
    expect(pricePerZoneText(ar, price), '8 د.ت للمنطقة / 30 يومًا');
    expect(pricePerZoneText(fr, price), '8 DT par zone / 30 jours');
    expect(ar.zonesCount(1), 'منطقة واحدة');
    expect(ar.zonesCount(2), 'منطقتان');
    expect(ar.zonesCount(4), '4 مناطق');
    expect(ar.zonesCount(12), '12 منطقة');
    expect(fr.zonesCount(1), '1 zone');
    expect(fr.zonesCount(4), '4 zones');
    expect(dayText(DateTime(2026, 11, 30, 12)), '30/11/2026');
    expect(planName(ar, Plan.paid), 'بريميوم');
    expect(planName(fr, Plan.free), 'Gratuit');
  });

  test('the bill of the database (orchard_quote) and what to pay now', () {
    // The row given by the real database for the demo orchard.
    final covered = OrchardQuote.fromRow({
      'area_ha': 2.37,
      'zones': 4,
      'min_nodes_by_area': 2,
      'billed_nodes': 4,
      'paid_nodes': 4,
      'price_per_node': 8000,
      'period_days': 30,
      'monthly_millimes': 32000,
      'kind': 'covered',
      'due_now_millimes': 0,
      'ends_at': '2026-12-03T18:15:54.733489+00:00',
    });
    expect(covered.kind, QuoteKind.covered);
    expect(covered.billedZones, 4);
    expect(covered.endsAt, DateTime.utc(2026, 12, 3, 18, 15, 54, 733, 489));
    // Covered: paying = the next whole period.
    expect(covered.payNowMillimes, 32000);
    expect(payNowText(ar, covered), '32 د.ت / 30 يومًا');

    final extra = OrchardQuote.fromRow({
      'area_ha': 2.37,
      'zones': 6,
      'min_nodes_by_area': 2,
      'billed_nodes': 6,
      'paid_nodes': 4,
      'price_per_node': 8000,
      'period_days': 30,
      'monthly_millimes': 48000,
      'kind': 'extra_nodes',
      'due_now_millimes': 15500,
      'ends_at': '2026-12-08T10:00:00+00:00',
    });
    expect(extra.kind, QuoteKind.extraZones);
    // Only the extra zones until the end of the period.
    expect(extra.payNowMillimes, 15500);
    expect(payNowText(ar, extra), '15.5 د.ت');
    expect(payNowText(fr, extra), '15.5 DT');

    final fresh = OrchardQuote.fromRow({
      'area_ha': 10,
      'zones': 1,
      'min_nodes_by_area': 5,
      'billed_nodes': 5,
      'paid_nodes': 0,
      'price_per_node': 8000,
      'period_days': 30,
      'monthly_millimes': 40000,
      'kind': 'new',
      'due_now_millimes': 40000,
      'ends_at': null,
    });
    expect(fresh.kind, QuoteKind.fresh);
    expect(fresh.paidZones, 0);
    expect(fresh.endsAt, isNull);
    expect(payNowText(fr, fresh), '40 DT / 30 jours');
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
        message: 'Draw your orchard first',
        code: 'PT409',
      ): PaymentFailure.noDrawing,
      const PostgrestException(message: 'Too many payments', code: 'PT429'):
          PaymentFailure.tooManyTries,
      const PostgrestException(message: 'Unknown paid pack', code: '22023'):
          PaymentFailure.unknown,
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
