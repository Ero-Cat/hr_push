import 'app_localizations.dart';

/// Resolves stable message keys (used by validators) into localized strings.
///
/// Validators return keys instead of strings so they stay pure and testable;
/// the UI resolves them at render time.
String resolveL10nKey(AppLocalizations l10n, String key, [String? param]) {
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
      return localizedStatus(l10n, key, param);
  }
}

/// Resolves manager/connection status keys into localized strings.
String localizedStatus(AppLocalizations l10n, String key, [String? param]) {
  switch (key) {
    case 'waitingBluetooth':
      return l10n.waitingForBluetooth;
    case 'platformNotSupported':
      return l10n.platformNotSupported;
    case 'notificationPermissionDenied':
      return l10n.notificationPermissionDenied;
    case 'pleaseEnableBluetooth':
      return l10n.pleaseEnableBluetooth;
    case 'bluetoothNotSupported':
      return l10n.bluetoothNotSupported;
    case 'bluetoothUnavailable':
      return l10n.bluetoothUnavailable;
    case 'permissionDenied':
      return l10n.permissionDenied;
    case 'stPermissionFailed':
      return l10n.stPermissionFailed;
    case 'scanningDevices':
      return l10n.scanningDevices;
    case 'disconnected':
      return l10n.disconnected;
    case 'scanNotSupported':
      return l10n.scanNotSupported;
    case 'connectNotSupported':
      return l10n.connectNotSupported;
    case 'staleConnectionReconnecting':
      return l10n.staleConnectionReconnecting;
    case 'stConnectFailed':
      return l10n.stConnectFailed;
    case 'stWaitingBroadcast':
      return l10n.stWaitingBroadcast;
    case 'autoReconnecting':
      return l10n.autoReconnecting;
    case 'stWaitingRebroadcast':
      return l10n.stWaitingRebroadcast;
    case 'stReconnectGaveUp':
      return l10n.stReconnectGaveUp;
    case 'stHrServiceMissingXiaomi':
      return l10n.stHrServiceMissingXiaomi;
    case 'stHrServiceMissing':
      return l10n.stHrServiceMissing;
    case 'connectingTo':
      return l10n.connectingTo(param ?? '');
    case 'deviceConnected':
      return l10n.deviceConnected;
    case 'stConnectedSubscribing':
      return l10n.stConnectedSubscribing;
    case 'stDisconnecting':
      return l10n.stDisconnecting;
    case 'stDisconnectedDone':
      return l10n.stDisconnectedDone;
    case 'stResubscribeFailedReconnecting':
      return l10n.stResubscribeFailedReconnecting;
    case 'stSubscribing':
      return l10n.stSubscribing;
    case 'stDiscovering':
      return l10n.stDiscovering;
    case 'stSubscribeRetrying':
      return l10n.stSubscribeRetrying;
    case 'stSubscribeFailed':
      return l10n.stSubscribeFailed;
    case 'stConnectTimeout':
      return l10n.stConnectTimeout;
    case 'stConnectCancelled':
      return l10n.stConnectCancelled;
    case 'stDeviceDisconnected':
      return l10n.stDeviceDisconnected;
    default:
      return key;
  }
}
