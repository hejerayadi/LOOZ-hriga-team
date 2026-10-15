// Small shared types used by several features.

/// A simple 3-level status: used for tree health AND alert urgency.
/// good = green, warning = orange, danger = red.
enum StatusLevel { good, warning, danger }

/// Who is using the app.
enum UserRole { farmer, expert }
