// The logged-in farmer, as saved in the database (table "profiles").
// The login is the phone number: there is no e-mail.
import '../core/plans.dart';

/// The payment of the pack chosen at sign-up.
enum PaymentStatus {
  /// The free pack: nothing to pay.
  free,

  /// A paid pack, not paid yet (the user has the free plan until then).
  pending,

  /// Paid (by the demo payment, an admin or, later, a payment provider;
  /// never written by the app itself).
  paid,
}

/// Who the user is (asked first at the sign-up). An expert shares his
/// knowledge in the community: the "verified expert" badge only once an
/// admin checked him (`verified`).
enum UserRole { farmer, expert, admin }

/// How the orchard is watered (optional).
enum Irrigation { irrigated, rainfed }

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
    this.role = UserRole.farmer,
    this.verified = false,
    this.organisation,
    this.governorate,
    this.almondTrees,
    this.orchardAreaHa,
    this.irrigation,
  });

  /// The same id as the login account (Supabase Auth).
  final String id;

  /// "+21698123456".
  final String phone;

  /// null until the sign-up step "your information".
  final String? firstName;
  final String? lastName;

  /// 'ar' or 'fr'.
  final String language;

  final UserRole role;

  /// An expert checked by an admin ("◆ خبير موثّق").
  final bool verified;

  /// The organisation of an expert (optional).
  final String? organisation;

  /// The code of the governorate ("sfax", see core/governorates.dart).
  final String? governorate;

  /// The orchard (all optional).
  final int? almondTrees;
  final double? orchardAreaHa;
  final Irrigation? irrigation;

  /// The pack chosen at sign-up (not always the plan the user has: a paid
  /// pack gives its plan only once it is paid).
  final Plan chosenPlan;

  final PaymentStatus paymentStatus;

  /// When the pack was chosen (null = the sign-up is not finished).
  final DateTime? planChosenAt;

  final DateTime createdAt;

  /// The columns read from "profiles".
  static const columns =
      'id, phone, first_name, last_name, language, role, verified, '
      'organisation, zone, almond_trees, orchard_area_ha, irrigation, '
      'chosen_plan, payment_status, plan_chosen_at, created_at';

  /// A row of "profiles" -> UserProfile.
  factory UserProfile.fromRow(Map<String, dynamic> row) {
    final planChosenAt = row['plan_chosen_at'] as String?;
    return UserProfile(
      id: row['id'] as String,
      phone: row['phone'] as String? ?? '',
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      language: row['language'] == 'fr' ? 'fr' : 'ar',
      role: UserRole.values.firstWhere(
        (r) => r.name == row['role'],
        orElse: () => UserRole.farmer,
      ),
      verified: row['verified'] as bool? ?? false,
      organisation: row['organisation'] as String?,
      governorate: row['zone'] as String?,
      almondTrees: (row['almond_trees'] as num?)?.toInt(),
      orchardAreaHa: (row['orchard_area_ha'] as num?)?.toDouble(),
      irrigation: Irrigation.values
          .where((i) => i.name == row['irrigation'])
          .firstOrNull,
      chosenPlan: planFromName(row['chosen_plan']),
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

  /// true once the step "your information" is done (name + governorate).
  bool get hasSignUpInfo => hasName && governorate != null;

  /// true once the pack is chosen (= the sign-up is finished).
  bool get hasChosenPlan => planChosenAt != null;

  bool get isExpert => role == UserRole.expert;

  /// A paid pack chosen at the sign-up, not paid yet: its payment is the
  /// step that is missing.
  bool get waitsForPayment =>
      hasChosenPlan &&
      chosenPlan != Plan.free &&
      paymentStatus == PaymentStatus.pending;

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
    role: role,
    verified: verified,
    organisation: organisation,
    governorate: governorate,
    almondTrees: almondTrees,
    orchardAreaHa: orchardAreaHa,
    irrigation: irrigation,
    chosenPlan: chosenPlan,
    paymentStatus: paymentStatus,
    planChosenAt: planChosenAt,
    createdAt: createdAt,
  );
}
