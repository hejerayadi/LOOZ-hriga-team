// A fake of the packs and the demo payment for the tests (no internet), with
// the same rules as the database (migration 009): the prices, Connected only
// once the kit is installed, demo payments that an admin can turn off, the
// pack for 30 days. Like the app, it never receives a card: only the pack and
// "accepted or not".
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

  /// Like plan_prices: 15 DT / 30 days, 8 DT per sensor / 30 days.
  Map<Plan, PackPrice> prices = const {
    Plan.essential: PackPrice(plan: Plan.essential, millimes: 15000, days: 30),
    Plan.connected: PackPrice(
      plan: Plan.connected,
      millimes: 8000,
      days: 30,
      perSensor: true,
    ),
  };

  /// The LOOZ kit of the user (null = never asked).
  KitRequest? kit;

  /// The paid pack running now.
  ActivePack? activePack;

  /// Like app_settings.demo_payments_enabled = false.
  bool demoOff = false;

  /// The next call fails with this error (once).
  PaymentFailure? failNext;

  /// Not null = the payment waits for it.
  Completer<void>? holdPay;

  /// The calls, e.g. "pay essential accepted" (never a card).
  final List<String> calls = [];

  /// A kit installed by an admin, with [sensors] sensors.
  void installKit(int sensors) => kit = KitRequest(
    id: 'kit-1',
    status: KitStatus.installed,
    sensors: sensors,
    createdAt: DateTime(2026, 10, 20),
  );

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw PaymentError(failure);
    }
  }

  @override
  Future<Map<Plan, PackPrice>> loadPrices() async {
    calls.add('loadPrices');
    _maybeFail();
    return prices;
  }

  @override
  Future<KitRequest?> loadKit() async {
    calls.add('loadKit');
    _maybeFail();
    return kit;
  }

  @override
  Future<KitRequest> requestKit() async {
    calls.add('requestKit');
    _maybeFail();
    if (auth?.me.governorate == null) {
      throw const PaymentError(PaymentFailure.noGovernorate);
    }
    final open = kit;
    if (open != null &&
        (open.status == KitStatus.requested ||
            open.status == KitStatus.contacted)) {
      return open;
    }
    return kit = KitRequest(
      id: 'kit-${calls.length}',
      status: KitStatus.requested,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<ActivePack?> loadActivePack() async {
    calls.add('loadActivePack');
    _maybeFail();
    return activePack;
  }

  @override
  Future<PaymentResult> pay(Plan plan, {required bool cardAccepted}) async {
    calls.add('pay ${plan.name} ${cardAccepted ? 'accepted' : 'refused'}');
    await holdPay?.future;
    _maybeFail();
    if (demoOff) throw const PaymentError(PaymentFailure.notAvailable);
    final price = prices[plan]!;
    final units = price.perSensor ? kit?.sensors : 1;
    if (units == null || (price.perSensor && !(kit?.installed ?? false))) {
      throw const PaymentError(PaymentFailure.kitNotInstalled);
    }
    if (!cardAccepted) {
      return PaymentResult(
        paid: false,
        plan: plan,
        millimes: price.millimes * units,
      );
    }
    // Like activate_pack(): the same pack running = 30 days after its end.
    final running = activePack;
    final from =
        running != null &&
            running.plan == plan &&
            running.endsAt.isAfter(DateTime.now())
        ? running.endsAt
        : DateTime.now();
    final pack = activePack = ActivePack(
      plan: plan,
      endsAt: from.add(Duration(days: price.days)),
    );
    final login = auth;
    if (login != null && login.loggedIn != null) {
      login.plans[login.loggedIn!] = plan;
      login.save(
        login.me,
        chosenPlan: plan,
        paymentStatus: PaymentStatus.paid,
        planChosenAt: login.me.planChosenAt ?? DateTime.now(),
      );
    }
    return PaymentResult(
      paid: true,
      plan: plan,
      millimes: price.millimes * units,
      endsAt: pack.endsAt,
    );
  }
}
