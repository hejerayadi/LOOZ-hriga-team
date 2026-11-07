// The 24 governorates of Tunisia: the code saved in the database
// (profiles.zone, migration 008: the same 24 codes) and its name in Arabic
// or French. The community shows it as the region of a farmer.
import 'locale.dart';

const governorates = [
  'tunis', 'ariana', 'ben_arous', 'manouba', 'nabeul', 'zaghouan', //
  'bizerte', 'beja', 'jendouba', 'kef', 'siliana', 'sousse', //
  'monastir', 'mahdia', 'sfax', 'kairouan', 'kasserine', 'sidi_bouzid', //
  'gabes', 'medenine', 'tataouine', 'gafsa', 'tozeur', 'kebili',
];

/// "sfax" -> "صفاقس" / "Sfax"; null = not one of the 24.
String? governorateName(AppLocalizations l10n, String? code) => switch (code) {
  'tunis' => l10n.regionTunis,
  'ariana' => l10n.regionAriana,
  'ben_arous' => l10n.regionBenArous,
  'manouba' => l10n.regionManouba,
  'nabeul' => l10n.regionNabeul,
  'zaghouan' => l10n.regionZaghouan,
  'bizerte' => l10n.regionBizerte,
  'beja' => l10n.regionBeja,
  'jendouba' => l10n.regionJendouba,
  'kef' => l10n.regionKef,
  'siliana' => l10n.regionSiliana,
  'sousse' => l10n.regionSousse,
  'monastir' => l10n.regionMonastir,
  'mahdia' => l10n.regionMahdia,
  'sfax' => l10n.regionSfax,
  'kairouan' => l10n.regionKairouan,
  'kasserine' => l10n.regionKasserine,
  'sidi_bouzid' => l10n.regionSidiBouzid,
  'gabes' => l10n.regionGabes,
  'medenine' => l10n.regionMedenine,
  'tataouine' => l10n.regionTataouine,
  'gafsa' => l10n.regionGafsa,
  'tozeur' => l10n.regionTozeur,
  'kebili' => l10n.regionKebili,
  _ => null,
};
