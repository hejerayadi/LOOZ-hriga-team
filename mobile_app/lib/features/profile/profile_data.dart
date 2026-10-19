// FAKE user for the "Profil" page. Edit freely.
// The plan is not here: it is in core/plans.dart (currentPlan).
import '../../core/enums.dart';

class UserProfile {
  const UserProfile({required this.name, required this.role});

  final String name;
  final UserRole role;
}

const UserProfile fakeUser = UserProfile(
  name: 'Ahmed Ben Ali',
  role: UserRole.farmer,
);
