// The Spanish names of the project colours, icons and languages. They are
// UI strings, so they come from app_es.arb.
import 'package:estudicards/app/l10n/generated/app_localizations.dart';
import 'package:estudicards/app/theme/project_palette.dart';
import 'package:estudicards/features/projects/presentation/project_icon.dart';

String colorName(AppLocalizations l10n, ProjectColor color) => switch (color) {
  ProjectColor.orange => l10n.colorOrange,
  ProjectColor.amber => l10n.colorAmber,
  ProjectColor.lime => l10n.colorLime,
  ProjectColor.green => l10n.colorGreen,
  ProjectColor.teal => l10n.colorTeal,
  ProjectColor.cyan => l10n.colorCyan,
  ProjectColor.blue => l10n.colorBlue,
  ProjectColor.indigo => l10n.colorIndigo,
  ProjectColor.violet => l10n.colorViolet,
  ProjectColor.pink => l10n.colorPink,
  ProjectColor.fuchsia => l10n.colorFuchsia,
  ProjectColor.slate => l10n.colorSlate,
};

String iconName(AppLocalizations l10n, ProjectIcon icon) => switch (icon) {
  ProjectIcon.globe => l10n.iconGlobe,
  ProjectIcon.scales => l10n.iconScales,
  ProjectIcon.flask => l10n.iconFlask,
  ProjectIcon.book => l10n.iconBook,
  ProjectIcon.cards => l10n.iconCards,
  ProjectIcon.layers => l10n.iconLayers,
  ProjectIcon.star => l10n.iconStar,
  ProjectIcon.sparkles => l10n.iconSparkles,
};

/// The name of a BCP-47 [code]. A code outside the list (e.g. from an
/// imported file) is shown as is.
String languageName(AppLocalizations l10n, String code) => switch (code) {
  'es-ES' => l10n.languageEsES,
  'en-GB' => l10n.languageEnGB,
  'en-US' => l10n.languageEnUS,
  'fr-FR' => l10n.languageFrFR,
  'de-DE' => l10n.languageDeDE,
  'it-IT' => l10n.languageItIT,
  'pt-PT' => l10n.languagePtPT,
  'pt-BR' => l10n.languagePtBR,
  'ca-ES' => l10n.languageCaES,
  'gl-ES' => l10n.languageGlES,
  'eu-ES' => l10n.languageEuES,
  'nl-NL' => l10n.languageNlNL,
  'zh-CN' => l10n.languageZhCN,
  'ja-JP' => l10n.languageJaJP,
  _ => code,
};
