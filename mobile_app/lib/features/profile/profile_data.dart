// FAKE user for the "Profil" page. Edit freely.
import '../../core/enums.dart';

class UserProfile {
  const UserProfile({
    required this.name,
    required this.role,
    required this.isPremium,
  });

  final String name;
  final UserRole role;
  final bool isPremium; // true = "Premium", false = "Gratuit"
}

const UserProfile fakeUser = UserProfile(
  name: 'Ahmed Ben Ali',
  role: UserRole.farmer,
  isPremium: false,
);
