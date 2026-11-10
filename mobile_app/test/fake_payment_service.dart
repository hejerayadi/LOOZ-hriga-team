// A fake of the paid pack and the demo payment for the tests (no internet),
// with the same rules as the database (migration 011): 8 DT per zone for 30
// days, billed zones = the zones drawn but at least 1 per 2 ha, extra zones
// paid only until the end of the period, nothing drawn = nothing to bill,
// demo payments that an admin can turn off. Like the app, it never
// receives a card: only "accepted or not".
import 'dart:async';

import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/data/payment_service.dart';
import 'package:looz_mobile/data/user_profile.dart';

import 'fake_auth_service.dart';

class FakePaymentService implements PaymentService {
  FakePaymentService({this.auth});

  /// The fake login: a paid pack is written in its accounts (like the
  /// database: the profile says "paid" and the plan changes).
  final FakeAuthService? auth;

  @override
  bool isDemo = true;

  /// Like plan_prices: 8 DT per zone / 30 days.
  PackPrice price = const PackPrice(millimes: 8000, days: 30);

  /// The orchard of the user: its zones and hectares (null = nothing drawn).
  ({int zones, double areaHa})? orchard;

  /// Like app_settings.hectares_per_node.
  double hectaresPerZone = 2;

  /// The paid pack running now.
  ActivePack? activePack;

  /// Like app_settings.demo_payments_enabled = false.
  bool demoOff = false;

  /// The next call fails with this error (once).
  PaymentFailure? failNext;

  /// Not null = the payment waits for it.
  Completer<void>? holdPay;

  /// The calls, e.g. "pay accepted" (never a card).
  final List<String> calls = [];

  /// An orchard of [zones] zones on [areaHa] hectares (like the designer).
  void drawOrchard(int zones, {double areaHa = 1}) =>
      orchard = (zones: zones, areaHa: areaHa);

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw PaymentError(failure);
    }
  }

  @override
  Future<PackPrice> loadPrice() async {
    calls.add('loadPrice');
    _maybeFail();
    return price;
  }

  /// Like orchard_quote() of the database.
  OrchardQuote quote() {
    final drawn = orchard;
    if (drawn == null) throw const PaymentError(PaymentFailure.noDrawing);
    final byArea = (drawn.areaHa / hectaresPerZone).ceil();
    final billed = [drawn.zones, byArea, 1].reduce((a, b) => a > b ? a : b);
    final running = activePack;
    final monthly = billed * price.millimes;
    final paid = running == null ? 0 : running.zones ?? 1000;
    final kind = running == null
        ? QuoteKind.fresh
        : paid >= billed
        ? QuoteKind.covered
        : QuoteKind.extraZones;
    final left = running == null
        ? 0.0
        : running.endsAt.difference(DateTime.now()).inSeconds /
              Duration(days: price.days).inSeconds;
    final extra = ((billed - paid) * price.millimes * left.clamp(0, 1) / 100)
        .ceil();
    return OrchardQuote(
      areaHa: drawn.areaHa,
      zones: drawn.zones,
      billedZones: billed,
      paidZones: running == null ? 0 : paid,
      pricePerZone: price.millimes,
      days: price.days,
      monthlyMillimes: monthly,
      kind: kind,
      dueNowMillimes: switch (kind) {
        QuoteKind.fresh => monthly,
        QuoteKind.covered => 0,
        QuoteKind.extraZones => extra < 1 ? 100 : extra * 100,
      },
      endsAt: running?.endsAt,
    );
  }

  @override
  Future<OrchardQuote> loadQuote() async {
    calls.add('loadQuote');
    _maybeFail();
    return quote();
  }

  @override
  Future<ActivePack?> loadActivePack() async {
    calls.add('loadActivePack');
    _maybeFail();
    return activePack;
  }

  @override
  Future<PaymentResult> pay({required bool cardAccepted}) async {
    calls.add('pay ${cardAccepted ? 'accepted' : 'refused'}');
    await holdPay?.future;
    _maybeFail();
    if (demoOff) throw const PaymentError(PaymentFailure.notAvailable);
    final bill = quote();
    final extra = bill.kind == QuoteKind.extraZones;
    final amount = bill.payNowMillimes;
    if (!cardAccepted) {
      return PaymentResult(
        paid: false,
        millimes: amount,
        zones: bill.billedZones,
        extraZones: extra,
      );
    }
    // Like activate_pack(): a pack running = 30 days after its end;
    // extra zones: the same end.
    final running = activePack;
    final DateTime end;
    if (extra) {
      end = running!.endsAt;
    } else {
      final from = running != null && running.endsAt.isAfter(DateTime.now())
          ? running.endsAt
          : DateTime.now();
      end = from.add(Duration(days: price.days));
    }
    activePack = ActivePack(endsAt: end, zones: bill.billedZones);
    final login = auth;
    if (login != null && login.loggedIn != null) {
      login.plans[login.loggedIn!] = Plan.paid;
      login.save(
        login.me,
        chosenPlan: Plan.paid,
        paymentStatus: PaymentStatus.paid,
        planChosenAt: login.me.planChosenAt ?? DateTime.now(),
      );
    }
    return PaymentResult(
      paid: true,
      millimes: amount,
      zones: bill.billedZones,
      extraZones: extra,
      endsAt: end,
    );
  }
}
