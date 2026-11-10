// The texts of the packs and their payment that depend on the data: the
// name of a pack, its price ("8 د.ت للمنطقة / 30 يومًا"), a date, the
// messages.
import '../../core/locale.dart';
import '../../core/plans.dart';
import '../../data/payment_service.dart';

/// The name of a pack, in the language of the app.
String planName(AppLocalizations l10n, Plan plan) => switch (plan) {
  Plan.free => l10n.free,
  Plan.paid => l10n.planPaid,
};

/// 8000 millimes -> "8", 15500 -> "15.5" (dinars).
String dinars(int millimes) {
  if (millimes % 1000 == 0) return '${millimes ~/ 1000}';
  var text = (millimes / 1000).toStringAsFixed(3);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

/// "8 د.ت للمنطقة / 30 يومًا" (the price of one zone).
String pricePerZoneText(AppLocalizations l10n, PackPrice price) => l10n
    .pricePerZoneForDays(dinars(price.millimes), l10n.daysCount(price.days));

/// What a payment costs now: "32 د.ت / 30 يومًا" (a whole period), or
/// "16 د.ت" (extra zones until the end of the period already paid).
String payNowText(AppLocalizations l10n, OrchardQuote quote) =>
    quote.kind == QuoteKind.extraZones
    ? l10n.dinarsAmount(dinars(quote.dueNowMillimes))
    : l10n.priceForDays(
        dinars(quote.monthlyMillimes),
        l10n.daysCount(quote.days),
      );

/// "30/11/2026" (the same digits in both languages).
String dayText(DateTime date) {
  final local = date.toLocal();
  return '${local.day}/${local.month}/${local.year}';
}

/// The text of a payment error, in the language of the app.
String paymentFailureMessage(AppLocalizations l10n, PaymentFailure failure) =>
    switch (failure) {
      PaymentFailure.noInternet => l10n.errorNoInternet,
      PaymentFailure.notAvailable => l10n.paymentNotAvailable,
      PaymentFailure.noDrawing => l10n.noDrawingYet,
      PaymentFailure.tooManyTries => l10n.tooManyPayments,
      PaymentFailure.sessionExpired => l10n.errorSessionExpired,
      PaymentFailure.unknown => l10n.somethingWrong,
    };
