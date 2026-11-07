// Checks of what the user types: the phone number, the names and the texts
// of the community. The database checks the same things again (migrations
// 005 and 006), so a wrong value is refused even if it does not come from
// the app.

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

// ----- Questions and answers of the community -----

/// Longest question or answer.
const communityTextMaxLength = 1000;

/// What is wrong with a question or an answer.
enum TextProblem { empty, tooLong, badCharacters }

// No < or > (so no HTML), no invisible control characters (line breaks are
// fine) and no characters that turn the text direction.
final _badTextCharacters = RegExp(
  '[<>\u0000-\u0009\u000B\u000C\u000E-\u001F\u007F\u202A-\u202E\u2066-\u2069]',
);

/// The text as it is saved: no spaces or empty lines at the ends.
String cleanText(String text) => text.trim();

/// The length counted like the database (letters, not UTF-16 units).
int textLength(String text) => cleanText(text).runes.length;

/// What is wrong with this text (null = it is fine).
TextProblem? checkText(String text) {
  final clean = cleanText(text);
  if (clean.isEmpty) return TextProblem.empty;
  if (clean.runes.length > communityTextMaxLength) return TextProblem.tooLong;
  if (_badTextCharacters.hasMatch(clean)) return TextProblem.badCharacters;
  return null;
}

// ----- Numbers typed by the farmer -----

/// "١٢٠" (Arabic keyboard) -> "120": the digits the app understands.
String westernDigits(String text) => String.fromCharCodes([
  for (final c in text.runes)
    if (c >= 0x0660 && c <= 0x0669)
      c -
          0x0660 +
          0x30 // ٠ to ٩
    else if (c >= 0x06F0 && c <= 0x06F9)
      c -
          0x06F0 +
          0x30 // ۰ to ۹ (Persian keyboard)
    else
      c,
]);

// ----- The orchard (sign-up, optional fields) -----

/// The same limits as the database (migration 008).
const almondTreesMax = 100000;
const orchardAreaMax = 10000;

/// The number of almond trees typed, or null when it is not a whole number
/// from 1 to 100000. (An empty box = not given: check isEmpty first.)
int? parseAlmondTrees(String text) {
  final value = int.tryParse(westernDigits(text.trim()));
  return value != null && value >= 1 && value <= almondTreesMax ? value : null;
}

/// The area in hectares typed ("2,5" or "2.5"), or null when it is not a
/// number above 0 and up to 10000, with 2 decimals at most.
double? parseOrchardArea(String text) {
  final clean = westernDigits(text.trim()).replaceAll(',', '.');
  if (!RegExp(r'^[0-9]+(\.[0-9]{1,2})?$').hasMatch(clean)) return null;
  final value = double.parse(clean);
  return value > 0 && value <= orchardAreaMax ? value : null;
}
