// The texts of the packs and their payment that depend on the data: the
// name of a pack, its price ("15 د.ت / 30 يومًا"), a date, the messages.
import '../../core/locale.dart';
import '../../core/plans.dart';
import '../../data/payment_service.dart';

/// The name of a pack, in the language of the app.
String planName(AppLocalizations l10n, Plan plan) => switch (plan) {
  Plan.free => l10n.free,
  Plan.essential => l10n.planEssential,
  Plan.connected => l10n.planConnected,
};

/// 15000 millimes -> "15", 15500 -> "15.5" (dinars).
String dinars(int millimes) {
  if (millimes % 1000 == 0) return '${millimes ~/ 1000}';
  var text = (millimes / 1000).toStringAsFixed(3);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

/// "15 د.ت / 30 يومًا", "8 د.ت لكل حسّاس / 30 يومًا". With [sensors] (the
/// installed kit): the whole amount, "40 د.ت / 30 يومًا".
String priceText(AppLocalizations l10n, PackPrice price, {int? sensors}) {
  final period = l10n.daysCount(price.days);
  if (price.perSensor && sensors == null) {
    return l10n.pricePerSensorForDays(dinars(price.millimes), period);
  }
  final amount = price.millimes * (price.perSensor ? sensors! : 1);
  return l10n.priceForDays(dinars(amount), period);
}

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
      PaymentFailure.kitNotInstalled => l10n.kitNotInstalled,
      PaymentFailure.tooManyTries => l10n.tooManyPayments,
      PaymentFailure.noGovernorate => l10n.chooseGovernorateFirst,
      PaymentFailure.sessionExpired => l10n.errorSessionExpired,
      PaymentFailure.unknown => l10n.somethingWrong,
    };
