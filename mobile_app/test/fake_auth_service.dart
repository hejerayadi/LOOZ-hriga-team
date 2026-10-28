// A fake login system for the tests: the accounts are kept in memory,
// like the Supabase test numbers (every code is 123456). No internet needed.
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/validators.dart';
import 'package:looz_mobile/data/auth_service.dart';
import 'package:looz_mobile/data/user_profile.dart';

class FakeAuthService implements AuthService {
  /// The only code accepted.
  static const code = '123456';

  /// The accounts, by phone number ("+21650000001").
  final Map<String, UserProfile> accounts = {};

  /// The plan each account has (free until a pack is paid).
  final Map<String, Plan> plans = {};

  /// The number logged in on this "phone" (null = nobody).
  String? loggedIn;

  /// The next call fails with this error (once).
  AuthFailure? failNext;

  /// Numbers that cannot receive a code (like a real number while only the
  /// test numbers are set up).
  final Set<String> cannotReceive = {};

  /// The methods called, in order (e.g. "sendCode +21650000001").
  final List<String> calls = [];

  @override
  bool get hasSession => loggedIn != null;

  /// A user who already finished the sign-up.
  UserProfile addUser(
    String phone, {
    String? firstName = 'Mohamed',
    String? lastName = 'Ben Salem',
    String language = 'fr',
    Plan chosenPlan = Plan.free,
    bool finished = true,
  }) {
    final paid = chosenPlan != Plan.free;
    return accounts[phone] = UserProfile(
      id: 'id-$phone',
      phone: phone,
      firstName: firstName,
      lastName: lastName,
      language: language,
      chosenPlan: chosenPlan,
      paymentStatus: paid ? PaymentStatus.pending : PaymentStatus.free,
      planChosenAt: finished ? DateTime(2026, 10, 28) : null,
      createdAt: DateTime(2026, 10, 28),
    );
  }

  void _maybeFail() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw AuthError(failure);
    }
  }

  UserProfile get _me {
    final phone = loggedIn;
    if (phone == null) throw const AuthError(AuthFailure.sessionExpired);
    return accounts[phone]!;
  }

  UserProfile _save(
    UserProfile old, {
    String? firstName,
    String? lastName,
    String? language,
    Plan? chosenPlan,
    PaymentStatus? paymentStatus,
    DateTime? planChosenAt,
  }) {
    return accounts[old.phone] = UserProfile(
      id: old.id,
      phone: old.phone,
      firstName: firstName ?? old.firstName,
      lastName: lastName ?? old.lastName,
      language: language ?? old.language,
      chosenPlan: chosenPlan ?? old.chosenPlan,
      paymentStatus: paymentStatus ?? old.paymentStatus,
      planChosenAt: planChosenAt ?? old.planChosenAt,
      createdAt: old.createdAt,
    );
  }

  @override
  Future<void> sendCode(String phone, {required String language}) async {
    calls.add('sendCode $phone');
    _maybeFail();
    if (!isValidPhone(phone)) throw const AuthError(AuthFailure.invalidPhone);
    if (cannotReceive.contains(phone)) {
      throw const AuthError(AuthFailure.cannotReceiveCode);
    }
    // Like Supabase: the account (and its profile) is created with the code.
    if (!accounts.containsKey(phone)) {
      addUser(
        phone,
        firstName: null,
        lastName: null,
        language: language,
        finished: false,
      );
    }
  }

  @override
  Future<void> verifyCode(String phone, String code) async {
    calls.add('verifyCode $phone');
    _maybeFail();
    if (code != FakeAuthService.code || !accounts.containsKey(phone)) {
      throw const AuthError(AuthFailure.wrongCode);
    }
    loggedIn = phone;
  }

  @override
  Future<UserProfile> loadProfile() async {
    calls.add('loadProfile');
    _maybeFail();
    return _me;
  }

  @override
  Future<UserProfile> saveName(String firstName, String lastName) async {
    calls.add('saveName');
    _maybeFail();
    if (checkName(firstName) != null || checkName(lastName) != null) {
      throw const AuthError(AuthFailure.invalidName);
    }
    return _save(
      _me,
      firstName: cleanName(firstName),
      lastName: cleanName(lastName),
    );
  }

  @override
  Future<UserProfile> saveLanguage(String language) async {
    calls.add('saveLanguage $language');
    _maybeFail();
    return _save(_me, language: language);
  }

  @override
  Future<UserProfile> choosePlan(Plan plan) async {
    calls.add('choosePlan ${plan.name}');
    _maybeFail();
    return _save(
      _me,
      chosenPlan: plan,
      paymentStatus: plan == Plan.free
          ? PaymentStatus.free
          : PaymentStatus.pending,
      planChosenAt: DateTime.now(),
    );
  }

  @override
  Future<Plan> loadPlan() async {
    calls.add('loadPlan');
    _maybeFail();
    return plans[_me.phone] ?? Plan.free;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    loggedIn = null;
  }
}
