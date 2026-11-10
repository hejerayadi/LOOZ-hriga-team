// The paid pack and its payment (migration 011): the price per zone, the
// bill of the farmer's orchard, the pack he has now, and the payment.
//
// The bill (orchard_quote) is made by the database, never by the app:
// billed zones = the zones of the orchard, at least 1 per 2 ha (an admin
// setting), 8 DT each for 30 days. More zones than paid = only the extra
// zones until the end of the period already paid.
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
  noDrawing, // no orchard drawn yet: nothing to bill
  tooManyTries, // 10 payments in an hour
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

/// The price of the paid pack (table plan_prices).
class PackPrice {
  const PackPrice({
    required this.millimes,
    required this.days,
    this.perZone = true,
  });

  /// 1 DT = 1000 millimes.
  final int millimes;

  /// One payment = the pack for this many days.
  final int days;

  /// true = the price of ONE zone (node) of the orchard.
  final bool perZone;

  static PackPrice fromRow(Map<String, dynamic> row) => PackPrice(
    millimes: (row['price_millimes'] as num).toInt(),
    days: (row['period_days'] as num).toInt(),
    perZone: row['per_node'] as bool? ?? true,
  );
}

/// What the farmer pays for his orchard (orchard_quote() of the database).
enum QuoteKind {
  /// No paid pack running: the whole month.
  fresh,

  /// More zones than paid: the extra zones until the end of the period.
  extraZones,

  /// Nothing to pay now (paying = the next period).
  covered,
}

class OrchardQuote {
  const OrchardQuote({
    required this.areaHa,
    required this.zones,
    required this.billedZones,
    required this.paidZones,
    required this.pricePerZone,
    required this.days,
    required this.monthlyMillimes,
    required this.kind,
    required this.dueNowMillimes,
    this.endsAt,
  });

  final double areaHa;

  /// The zones of the drawing.
  final int zones;

  /// The zones billed (at least 1 per 2 ha of orchard).
  final int billedZones;

  /// The zones of the pack running now (0 = none).
  final int paidZones;
  final int pricePerZone;
  final int days;

  /// billedZones x pricePerZone: one whole period.
  final int monthlyMillimes;
  final QuoteKind kind;

  /// What a payment now costs: the extra zones, or a whole period.
  int get payNowMillimes =>
      kind == QuoteKind.extraZones ? dueNowMillimes : monthlyMillimes;
  final int dueNowMillimes;

  /// The end of the pack running now (null = none).
  final DateTime? endsAt;

  static OrchardQuote fromRow(Map<String, dynamic> row) {
    final ends = row['ends_at'] as String?;
    return OrchardQuote(
      areaHa: (row['area_ha'] as num?)?.toDouble() ?? 0,
      zones: (row['zones'] as num).toInt(),
      billedZones: (row['billed_nodes'] as num).toInt(),
      paidZones: (row['paid_nodes'] as num?)?.toInt() ?? 0,
      pricePerZone: (row['price_per_node'] as num).toInt(),
      days: (row['period_days'] as num).toInt(),
      monthlyMillimes: (row['monthly_millimes'] as num).toInt(),
      kind: switch (row['kind']) {
        'extra_nodes' => QuoteKind.extraZones,
        'covered' => QuoteKind.covered,
        _ => QuoteKind.fresh,
      },
      dueNowMillimes: (row['due_now_millimes'] as num).toInt(),
      endsAt: ends == null ? null : DateTime.parse(ends),
    );
  }
}

/// The paid pack the user has now, until when, and its zones.
class ActivePack {
  const ActivePack({required this.endsAt, this.zones});

  final DateTime endsAt;

  /// The zones paid (null = no limit, given by an admin).
  final int? zones;
}

/// What a payment gave.
class PaymentResult {
  const PaymentResult({
    required this.paid,
    required this.millimes,
    required this.zones,
    this.extraZones = false,
    this.endsAt,
  });

  /// false = not paid (the card was refused).
  final bool paid;

  /// The amount paid (or refused).
  final int millimes;

  /// The zones the pack has after this payment.
  final int zones;

  /// true = extra zones until the end of the period (not a new period).
  final bool extraZones;

  /// The end of the pack (paid only).
  final DateTime? endsAt;
}

/// What the app needs for the paid pack. The app uses DemoPaymentService;
/// the tests use a fake one (no internet needed).
abstract class PaymentService {
  /// true = the demo payment: the screen says "وضع تجريبي / Mode démo".
  bool get isDemo;

  /// The price of the paid pack (per zone).
  Future<PackPrice> loadPrice();

  /// The bill of the user's orchard (PaymentFailure.noDrawing: nothing
  /// drawn yet).
  Future<OrchardQuote> loadQuote();

  /// The paid pack running now (null = the free plan).
  Future<ActivePack?> loadActivePack();

  /// Pays the bill of the user's orchard (see loadQuote).
  /// DEMO: [cardAccepted] = what the card form decided (the test card
  /// 4000 0000 0000 0002 is refused). The card itself is never sent.
  Future<PaymentResult> pay({required bool cardAccepted});
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
  Future<PackPrice> loadPrice() => _run(() async {
    final row = await _client
        .from('plan_prices')
        .select('price_millimes, period_days, per_node')
        .eq('plan', 'paid')
        .single();
    return PackPrice.fromRow(row);
  });

  @override
  Future<OrchardQuote> loadQuote() => _run(() async {
    return OrchardQuote.fromRow(_one(await _client.rpc('orchard_quote')));
  });

  @override
  Future<ActivePack?> loadActivePack() => _run(() async {
    final row = await _client
        .from('subscriptions')
        .select('plan, status, ends_at, nodes')
        .maybeSingle();
    final endsAt = row?['ends_at'] as String?;
    if (row == null ||
        row['status'] != 'active' ||
        endsAt == null ||
        planFromName(row['plan']) == Plan.free) {
      return null;
    }
    final end = DateTime.parse(endsAt);
    if (end.isBefore(DateTime.now())) return null;
    return ActivePack(endsAt: end, zones: (row['nodes'] as num?)?.toInt());
  });

  @override
  Future<PaymentResult> pay({required bool cardAccepted}) => _run(() async {
    // Only the pack and "accepted or not": never the card. The amount and
    // the zones come from the database's bill.
    final row = _one(
      await _client.rpc(
        'demo_payment',
        params: {'p_plan': 'paid', 'p_success': cardAccepted},
      ),
    );
    final paid = row['status'] == 'paid_demo';
    return PaymentResult(
      paid: paid,
      millimes: (row['amount_millimes'] as num).toInt(),
      zones: (row['nodes'] as num?)?.toInt() ?? 0,
      extraZones: row['kind'] == 'extra_nodes',
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
      'PT409' => PaymentFailure.noDrawing, // nothing drawn: nothing to bill
      'PT429' => PaymentFailure.tooManyTries,
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
