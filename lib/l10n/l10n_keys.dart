import 'app_localizations.dart';

/// Resolves stable message keys (used by validators) into localized strings.
///
/// Validators return keys instead of strings so they stay pure and testable;
/// the UI resolves them at render time.
String resolveL10nKey(AppLocalizations l10n, String key) {
  switch (key) {
    case 'errInvalidUrl':
      return l10n.errInvalidUrl;
    case 'errInvalidOscAddress':
      return l10n.errInvalidOscAddress;
    case 'errInvalidOscPath':
      return l10n.errInvalidOscPath;
    case 'errInvalidPort':
      return l10n.errInvalidPort;
    case 'errInvalidInterval':
      return l10n.errInvalidInterval;
    case 'errInvalidMaxHr':
      return l10n.errInvalidMaxHr;
    case 'errInvalidPulseDuration':
      return l10n.errInvalidPulseDuration;
    case 'hintOscEmpty':
      return l10n.hintOscEmpty;
    case 'hintMqttLwt':
      return l10n.hintMqttLwt;
    case 'hintClientId':
      return l10n.hintClientId;
    case 'hintOscNote':
      return l10n.hintOscNote;
    case 'fixErrorsBeforeSave':
      return l10n.fixErrorsBeforeSave;
    case 'savedToast':
      return l10n.savedToast;
    case 'testSuccess':
      return l10n.testSuccess;
    case 'testFailed':
      return l10n.testFailed;
    default:
      return key;
  }
}
