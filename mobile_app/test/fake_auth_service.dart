// A fake login system for the tests: the accounts are kept in memory,
// like the Supabase test numbers (every code is 123456). No internet needed.
// demoLogin = true: like the demo login (migration 010 + "demo-auth"): no
// SMS, any 6-digit code, a new number + sign up gets its account at the code.
// Same rules as Supabase and the database: a sign-in with a number without
// account creates nothing; the role is chosen only during the sign-up.
import 'package:looz_mobile/core/governorates.dart';
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

  /// The methods called, in order (e.g. "sendCode +21650000001 sign up").
  final List<String> calls = [];

  /// Like app_settings.demo_login_enabled = true.
  bool demoLogin = false;

  /// The number waiting for its code with the demo login.
  ({String phone, bool signUp, String language})? _demo;

  @override
  bool get hasSession => loggedIn != null;

  /// A user who already finished the sign-up (or not: [finished] false).
  UserProfile addUser(
    String phone, {
    String? firstName = 'Mohamed',
    String? lastName = 'Ben Salem',
    String language = 'fr',
    Plan chosenPlan = Plan.free,
    bool finished = true,
    String? governorate = 'sfax',
    UserRole role = UserRole.farmer,
    bool verified = false,
    PaymentStatus? paymentStatus,
  }) {
    final paid = chosenPlan != Plan.free;
    return accounts[phone] = UserProfile(
      id: 'id-$phone',
      phone: phone,
      firstName: firstName,
      lastName: lastName,
      language: language,
      role: role,
      verified: verified,
      governorate: governorate,
      chosenPlan: chosenPlan,
      paymentStatus:
          paymentStatus ?? (paid ? PaymentStatus.pending : PaymentStatus.free),
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

  UserProfile get me {
    final phone = loggedIn;
    if (phone == null) throw const AuthError(AuthFailure.sessionExpired);
    return accounts[phone]!;
  }

  /// Saves a changed copy of [old].
  UserProfile save(
    UserProfile old, {
    String? firstName,
    String? lastName,
    String? language,
    UserRole? role,
    String? organisation,
    String? governorate,
    int? almondTrees,
    double? orchardAreaHa,
    Irrigation? irrigation,
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
      role: role ?? old.role,
      verified: old.verified,
      organisation: organisation ?? old.organisation,
      governorate: governorate ?? old.governorate,
      almondTrees: almondTrees ?? old.almondTrees,
      orchardAreaHa: orchardAreaHa ?? old.orchardAreaHa,
      irrigation: irrigation ?? old.irrigation,
      chosenPlan: chosenPlan ?? old.chosenPlan,
      paymentStatus: paymentStatus ?? old.paymentStatus,
      planChosenAt: planChosenAt ?? old.planChosenAt,
      createdAt: old.createdAt,
    );
  }

  @override
  Future<void> sendCode(
    String phone, {
    required String language,
    required bool createAccount,
  }) async {
    calls.add('sendCode $phone ${createAccount ? 'sign up' : 'sign in'}');
    _maybeFail();
    if (!isValidPhone(phone)) throw const AuthError(AuthFailure.invalidPhone);
    _demo = null;
    if (demoLogin) {
      // No SMS (so any number "receives" it); sign in still needs an account.
      if (!createAccount && !accounts.containsKey(phone)) {
        throw const AuthError(AuthFailure.noAccount);
      }
      _demo = (phone: phone, signUp: createAccount, language: language);
      return;
    }
    if (cannotReceive.contains(phone)) {
      throw const AuthError(AuthFailure.cannotReceiveCode);
    }
    if (!accounts.containsKey(phone)) {
      // Like Supabase: sign in never creates an account ("otp_disabled").
      if (!createAccount) throw const AuthError(AuthFailure.noAccount);
      // Sign up: the account (and its profile) is created with the code.
      addUser(
        phone,
        firstName: null,
        lastName: null,
        governorate: null,
        language: language,
        finished: false,
      );
    }
  }

  @override
  Future<void> verifyCode(String phone, String code) async {
    calls.add('verifyCode $phone');
    _maybeFail();
    final demo = _demo;
    if (demoLogin && demo != null && demo.phone == phone) {
      if (!isValidCode(code)) throw const AuthError(AuthFailure.wrongCode);
      if (!accounts.containsKey(phone)) {
        if (!demo.signUp) throw const AuthError(AuthFailure.noAccount);
        addUser(
          phone,
          firstName: null,
          lastName: null,
          governorate: null,
          language: demo.language,
          finished: false,
        );
      }
      _demo = null;
      loggedIn = phone;
      return;
    }
    if (code != FakeAuthService.code || !accounts.containsKey(phone)) {
      throw const AuthError(AuthFailure.wrongCode);
    }
    loggedIn = phone;
  }

  @override
  Future<UserProfile> loadProfile() async {
    calls.add('loadProfile');
    _maybeFail();
    return me;
  }

  @override
  Future<UserProfile> saveSignUpInfo(SignUpInfo info) async {
    calls.add('saveSignUpInfo ${info.role.name}');
    _maybeFail();
    if (checkName(info.firstName) != null || checkName(info.lastName) != null) {
      throw const AuthError(AuthFailure.invalidName);
    }
    // Like choose_role(): only during the sign-up, never "admin".
    if (me.hasChosenPlan || info.role == UserRole.admin) {
      throw const AuthError(AuthFailure.unknown);
    }
    assert(governorates.contains(info.governorate));
    return save(
      me,
      firstName: cleanName(info.firstName),
      lastName: cleanName(info.lastName),
      role: info.role,
      organisation: info.organisation,
      governorate: info.governorate,
      almondTrees: info.almondTrees,
      orchardAreaHa: info.orchardAreaHa,
      irrigation: info.irrigation,
    );
  }

  @override
  Future<UserProfile> saveLanguage(String language) async {
    calls.add('saveLanguage $language');
    _maybeFail();
    return save(me, language: language);
  }

  @override
  Future<UserProfile> choosePlan(Plan plan) async {
    calls.add('choosePlan ${plan.name}');
    _maybeFail();
    return save(
      me,
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
    return plans[me.phone] ?? Plan.free;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    loggedIn = null;
  }
}
