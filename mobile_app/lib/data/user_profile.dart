// The logged-in farmer, as saved in the database (table "profiles").
// The login is the phone number: there is no e-mail.
import '../core/plans.dart';

/// The payment of the pack chosen at sign-up.
enum PaymentStatus {
  /// The free pack: nothing to pay.
  free,

  /// A paid pack, not paid yet (the user has the free plan until then).
  pending,

  /// Paid (set by an admin or, later, the payment server; never by the app).
  paid,
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.language,
    required this.chosenPlan,
    required this.paymentStatus,
    required this.planChosenAt,
    required this.createdAt,
  });

  /// The same id as the login account (Supabase Auth).
  final String id;

  /// "+21698123456".
  final String phone;

  /// null until the sign-up step "your name".
  final String? firstName;
  final String? lastName;

  /// 'ar' or 'fr'.
  final String language;

  /// The pack chosen at sign-up (not always the plan the user has: a paid
  /// pack gives its plan only once it is paid).
  final Plan chosenPlan;

  final PaymentStatus paymentStatus;

  /// When the pack was chosen (null = the sign-up is not finished).
  final DateTime? planChosenAt;

  final DateTime createdAt;

  /// The columns read from "profiles".
  static const columns =
      'id, phone, first_name, last_name, language, chosen_plan, '
      'payment_status, plan_chosen_at, created_at';

  /// A row of "profiles" -> UserProfile.
  factory UserProfile.fromRow(Map<String, dynamic> row) {
    final planChosenAt = row['plan_chosen_at'] as String?;
    return UserProfile(
      id: row['id'] as String,
      phone: row['phone'] as String? ?? '',
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      language: row['language'] == 'fr' ? 'fr' : 'ar',
      chosenPlan: Plan.values.firstWhere(
        (p) => p.name == row['chosen_plan'],
        orElse: () => Plan.free,
      ),
      paymentStatus: PaymentStatus.values.firstWhere(
        (s) => s.name == row['payment_status'],
        orElse: () => PaymentStatus.free,
      ),
      planChosenAt: planChosenAt == null ? null : DateTime.parse(planChosenAt),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  /// true once the first name and last name are saved.
  bool get hasName => firstName != null && lastName != null;

  /// true once the pack is chosen (= the sign-up is finished).
  bool get hasChosenPlan => planChosenAt != null;

  /// "Mohamed Ben Salem".
  String get fullName => [firstName, lastName].whereType<String>().join(' ');

  /// The letter on the avatar: the first letter of the first name.
  String get initial {
    final name = firstName ?? '';
    return name.isEmpty ? '' : String.fromCharCode(name.runes.first);
  }

  UserProfile copyWith({String? language}) => UserProfile(
    id: id,
    phone: phone,
    firstName: firstName,
    lastName: lastName,
    language: language ?? this.language,
    chosenPlan: chosenPlan,
    paymentStatus: paymentStatus,
    planChosenAt: planChosenAt,
    createdAt: createdAt,
  );
}
