// The packs and their payment (migrations 008 and 009): the prices, the
// request of the LOOZ sensor kit (Connected), the pack the user has now,
// and the payment.
//
// FOR NOW, A DEMO PAYMENT: no real money and no payment provider. The card
// typed on the payment screen is only checked there (see
// lib/features/premium/demo_card_form.dart): it is NEVER saved nor sent.
// The database gives the pack only while app_settings.demo_payments_enabled
// is true (an admin turns it off with one change).
//
// A real provider later (Konnect or another): a new PaymentService with its
// own pay(), and its secure page in the place of the card form. The other
// screens (summary, "جاري التحقق من الدفع…", paid, not paid) stay the same.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/plans.dart';
import '../core/supabase_config.dart';
import 'auth_service.dart';

/// Why a step failed. Each one has a message in Arabic and French (see
/// paymentFailureMessage() in lib/features/premium/pack_texts.dart).
enum PaymentFailure {
  noInternet,
  notAvailable, // demo payments turned off by an admin
  kitNotInstalled, // Connected before the LOOZ kit is installed
  tooManyTries, // 10 payments in an hour
  noGovernorate, // a kit request needs the governorate
  sessionExpired,
  unknown,
}

class PaymentError implements Exception {
  const PaymentError(this.failure, [this.cause]);

  final PaymentFailure failure;
  final Object? cause;

  @override
  String toString() => 'PaymentError(${failure.name}, $cause)';
}

/// The price of a paid pack (table plan_prices).
class PackPrice {
  const PackPrice({
    required this.plan,
    required this.millimes,
    required this.days,
    this.perSensor = false,
  });

  final Plan plan;

  /// 1 DT = 1000 millimes.
  final int millimes;

  /// One payment = the pack for this many days.
  final int days;

  /// true = the price of ONE sensor of the LOOZ kit (Connected).
  final bool perSensor;

  static PackPrice fromRow(Map<String, dynamic> row) => PackPrice(
    plan: Plan.values.byName(row['plan'] as String),
    millimes: (row['price_millimes'] as num).toInt(),
    days: (row['period_days'] as num).toInt(),
    perSensor: row['per_sensor'] as bool? ?? false,
  );
}

enum KitStatus { requested, contacted, installed, cancelled }

/// A request of the LOOZ sensor kit (table kit_requests).
class KitRequest {
  const KitRequest({
    required this.id,
    required this.status,
    required this.createdAt,
    this.sensors,
  });

  final String id;
  final KitStatus status;

  /// Set by an admin when the kit is installed.
  final int? sensors;
  final DateTime createdAt;

  bool get installed => status == KitStatus.installed && (sensors ?? 0) > 0;

  static const columns = 'id, status, sensors, created_at';

  static KitRequest fromRow(Map<String, dynamic> row) => KitRequest(
    id: row['id'] as String,
    status: switch (row['status']) {
      'contacted' => KitStatus.contacted,
      'installed' => KitStatus.installed,
      'cancelled' => KitStatus.cancelled,
      _ => KitStatus.requested,
    },
    sensors: (row['sensors'] as num?)?.toInt(),
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

/// The paid pack the user has now, and until when.
class ActivePack {
  const ActivePack({required this.plan, required this.endsAt});

  final Plan plan;
  final DateTime endsAt;
}

/// What a payment gave.
class PaymentResult {
  const PaymentResult({
    required this.paid,
    required this.plan,
    required this.millimes,
    this.endsAt,
  });

  /// false = not paid (the card was refused).
  final bool paid;
  final Plan plan;

  /// The amount (Connected: the price x the sensors of the kit).
  final int millimes;

  /// The end of the pack (paid only).
  final DateTime? endsAt;
}

/// What the app needs for the packs. The app uses DemoPaymentService; the
/// tests use a fake one (no internet needed).
abstract class PaymentService {
  /// true = the demo payment: the screen says "وضع تجريبي / Mode démo".
  bool get isDemo;

  /// The prices of Essential and Connected.
  Future<Map<Plan, PackPrice>> loadPrices();

  /// The last request of the LOOZ kit of the user (null = never asked).
  Future<KitRequest?> loadKit();

  /// Asks for the LOOZ kit (asked twice: the same open request).
  Future<KitRequest> requestKit();

  /// The paid pack running now (null = the free plan).
  Future<ActivePack?> loadActivePack();

  /// Pays [plan] (Essential, or Connected once the kit is installed).
  /// DEMO: [cardAccepted] = what the card form decided (the test card
  /// 4000 0000 0000 0002 is refused). The card itself is never sent.
  Future<PaymentResult> pay(Plan plan, {required bool cardAccepted});
}

PaymentService? _paymentService;

/// The packs: Supabase in the app (the tests put a fake one).
PaymentService get paymentService =>
    _paymentService ??= DemoPaymentService(supabase);
set paymentService(PaymentService service) => _paymentService = service;

class DemoPaymentService implements PaymentService {
  DemoPaymentService(this._client);

  final SupabaseClient _client;

  static const timeout = Duration(seconds: 20);

  @override
  bool get isDemo => true;

  @override
  Future<Map<Plan, PackPrice>> loadPrices() => _run(() async {
    final rows = await _client
        .from('plan_prices')
        .select('plan, price_millimes, period_days, per_sensor');
    return {
      for (final row in rows)
        Plan.values.byName(row['plan'] as String): PackPrice.fromRow(row),
    };
  });

  @override
  Future<KitRequest?> loadKit() => _run(() async {
    final row = await _client
        .from('kit_requests')
        .select(KitRequest.columns)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : KitRequest.fromRow(row);
  });

  @override
  Future<KitRequest> requestKit() => _run(() async {
    // The database copies the governorate, trees, area and phone from
    // the profile: the app sends nothing.
    final row = await _client.rpc('request_kit');
    return KitRequest.fromRow(_one(row));
  });

  @override
  Future<ActivePack?> loadActivePack() => _run(() async {
    final row = await _client
        .from('subscriptions')
        .select('plan, status, ends_at')
        .maybeSingle();
    final endsAt = row?['ends_at'] as String?;
    if (row == null || row['status'] != 'active' || endsAt == null) {
      return null;
    }
    final end = DateTime.parse(endsAt);
    final plan = Plan.values.byName(row['plan'] as String);
    if (plan == Plan.free || end.isBefore(DateTime.now())) return null;
    return ActivePack(plan: plan, endsAt: end);
  });

  @override
  Future<PaymentResult> pay(Plan plan, {required bool cardAccepted}) =>
      _run(() async {
        // Only the pack and "accepted or not": never the card.
        final row = _one(
          await _client.rpc(
            'demo_payment',
            params: {'p_plan': plan.name, 'p_success': cardAccepted},
          ),
        );
        final paid = row['status'] == 'paid_demo';
        return PaymentResult(
          paid: paid,
          plan: plan,
          millimes: (row['amount_millimes'] as num).toInt(),
          endsAt: paid ? (await loadActivePack())?.endsAt : null,
        );
      });

  /// A function that returns one row: an object (or a list of one).
  static Map<String, dynamic> _one(Object? result) => switch (result) {
    final Map<String, dynamic> row => row,
    final List<dynamic> rows when rows.isNotEmpty =>
      rows.first as Map<String, dynamic>,
    _ => throw const PaymentError(PaymentFailure.unknown),
  };

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call().timeout(timeout);
    } on PaymentError {
      rethrow;
    } catch (error) {
      throw PaymentError(paymentFailureOf(error), error);
    }
  }
}

/// Turns an error of Supabase into a PaymentFailure.
PaymentFailure paymentFailureOf(Object error) {
  if (error is PaymentError) return error.failure;
  if (error is PostgrestException) {
    return switch (error.code ?? '') {
      'PT403' => PaymentFailure.notAvailable, // demo payments turned off
      'PT409' => PaymentFailure.kitNotInstalled,
      'PT429' => PaymentFailure.tooManyTries,
      '22023' when error.message.contains('governorate') =>
        PaymentFailure.noGovernorate,
      final code when code.startsWith('PGRST30') =>
        PaymentFailure.sessionExpired,
      _ => PaymentFailure.unknown,
    };
  }
  return switch (failureOf(error)) {
    AuthFailure.noInternet => PaymentFailure.noInternet,
    AuthFailure.sessionExpired => PaymentFailure.sessionExpired,
    _ => PaymentFailure.unknown,
  };
}
