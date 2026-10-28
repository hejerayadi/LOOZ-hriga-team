// Checks of what the user types: the phone number and the names.
// The database checks the same things again (migration 005), so a wrong
// value is refused even if it does not come from the app.

// ----- Phone number -----

/// Tunisia's country code, shown before the number.
const phonePrefix = '+216';

/// A Tunisian number has 8 digits: "•• ••• •••".
const phoneGroups = [2, 3, 3];

/// Digits of a Tunisian number (without +216).
const phoneDigits = 8;

/// Digits of the code sent by SMS.
const codeLength = 6;

final _tunisianPhone = RegExp(r'^\+216[0-9]{8}$');

/// true for a full Tunisian number like "+21698123456".
bool isValidPhone(String phone) => _tunisianPhone.hasMatch(phone);

/// The 8 digits typed -> the number as it is saved: "+21698123456".
String phoneFromDigits(String digits) => '$phonePrefix$digits';

/// "+21698123456" -> "+216 98 123 456" (to show it).
String formatPhone(String phone) {
  if (!isValidPhone(phone)) return phone;
  final digits = phone.substring(phonePrefix.length);
  final groups = <String>[];
  var start = 0;
  for (final size in phoneGroups) {
    groups.add(digits.substring(start, start + size));
    start += size;
  }
  return '$phonePrefix ${groups.join(' ')}';
}

/// true for a code of 6 digits.
bool isValidCode(String code) => RegExp(r'^[0-9]{6}$').hasMatch(code);

// ----- First name and last name -----

/// Longest first name or last name.
const nameMaxLength = 50;

/// What is wrong with a name.
enum NameProblem { empty, tooLong, badCharacters }

// Letters of any language (and their accents / Arabic marks), spaces,
// apostrophes and hyphens: "Mohamed", "بن سالم", "Ben-Ali", "M'barek".
final _nameCharacters = RegExp(r"^[\p{L}\p{M} '’\-]+$", unicode: true);

/// The name as it is saved: no spaces at the ends, single spaces inside.
String cleanName(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ');

/// What is wrong with this name (null = it is fine).
NameProblem? checkName(String name) {
  final clean = cleanName(name);
  if (clean.isEmpty) return NameProblem.empty;
  // Counted like the database: letters, not UTF-16 units.
  if (clean.runes.length > nameMaxLength) return NameProblem.tooLong;
  if (!_nameCharacters.hasMatch(clean)) return NameProblem.badCharacters;
  return null;
}
