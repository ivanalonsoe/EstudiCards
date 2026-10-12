// The choices of a study session that the domain rules depend on (P08,
// SPEC §4.2 `study_sessions`). The enum names are the stored values.

/// `normal` | `errors` ("Solo errores", R 7.2).
enum StudyMode { normal, errors }

/// `normal` | `reverse` ("Sentido"). Reverse only affects simple cards of
/// language decks (R 7.3).
enum StudyDirection { normal, reverse }
