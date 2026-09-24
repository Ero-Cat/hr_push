import '../../models/models.dart';

/// Contract each settings section state implements so the page shell can
/// validate, dirty-check and merge them uniformly.
///
/// Sections live inside a lazy ListView, so a section that has never been
/// built (scrolled into view) simply does not participate — its fields are
/// still the untouched initial values.
abstract class SettingsSectionContract {
  /// Error-message keys for invalid fields; empty when the section is valid.
  List<String> validate();

  /// True when any field differs from the initial settings.
  bool isDirty();

  /// Apply this section's fields onto [settings] and return the result.
  HeartRateSettings merge(HeartRateSettings settings);
}
