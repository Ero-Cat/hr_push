import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get appTitle;

  /// No description provided for @currentHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Current HR'**
  String get currentHeartRate;

  /// No description provided for @bpmUnit.
  ///
  /// In en, this message translates to:
  /// **'BPM'**
  String get bpmUnit;

  /// No description provided for @deviceOnline.
  ///
  /// In en, this message translates to:
  /// **'Device Online'**
  String get deviceOnline;

  /// No description provided for @waitingForConnection.
  ///
  /// In en, this message translates to:
  /// **'Waiting...'**
  String get waitingForConnection;

  /// No description provided for @noDeviceConnected.
  ///
  /// In en, this message translates to:
  /// **'No Device'**
  String get noDeviceConnected;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @autoReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting...'**
  String get autoReconnecting;

  /// No description provided for @connectDevice.
  ///
  /// In en, this message translates to:
  /// **'Connect Device'**
  String get connectDevice;

  /// No description provided for @signal.
  ///
  /// In en, this message translates to:
  /// **'Signal'**
  String get signal;

  /// No description provided for @nearbyDevices.
  ///
  /// In en, this message translates to:
  /// **'NEARBY DEVICES'**
  String get nearbyDevices;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching for devices...'**
  String get searching;

  /// No description provided for @noDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'No devices found.'**
  String get noDevicesFound;

  /// No description provided for @rssi.
  ///
  /// In en, this message translates to:
  /// **'RSSI'**
  String get rssi;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @sectionWebHttp.
  ///
  /// In en, this message translates to:
  /// **'Web / HTTP'**
  String get sectionWebHttp;

  /// No description provided for @fieldEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get fieldEndpoint;

  /// No description provided for @fieldInterval.
  ///
  /// In en, this message translates to:
  /// **'Interval (ms)'**
  String get fieldInterval;

  /// No description provided for @sectionVrchatOsc.
  ///
  /// In en, this message translates to:
  /// **'VRChat OSC'**
  String get sectionVrchatOsc;

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldAddress;

  /// No description provided for @fieldConnectedParam.
  ///
  /// In en, this message translates to:
  /// **'Connected Param'**
  String get fieldConnectedParam;

  /// No description provided for @fieldHrValueParam.
  ///
  /// In en, this message translates to:
  /// **'HR Value Param'**
  String get fieldHrValueParam;

  /// No description provided for @fieldHrPercentParam.
  ///
  /// In en, this message translates to:
  /// **'HR Percent Param'**
  String get fieldHrPercentParam;

  /// No description provided for @fieldMaxHr.
  ///
  /// In en, this message translates to:
  /// **'Max HR'**
  String get fieldMaxHr;

  /// No description provided for @sectionOscChatbox.
  ///
  /// In en, this message translates to:
  /// **'OSC Chatbox'**
  String get sectionOscChatbox;

  /// No description provided for @fieldEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get fieldEnabled;

  /// No description provided for @fieldTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get fieldTemplate;

  /// No description provided for @sectionMqtt.
  ///
  /// In en, this message translates to:
  /// **'MQTT Client'**
  String get sectionMqtt;

  /// No description provided for @fieldBroker.
  ///
  /// In en, this message translates to:
  /// **'Broker'**
  String get fieldBroker;

  /// No description provided for @fieldPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get fieldPort;

  /// No description provided for @fieldTopic.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get fieldTopic;

  /// No description provided for @fieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get fieldUsername;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldClientId.
  ///
  /// In en, this message translates to:
  /// **'Client ID'**
  String get fieldClientId;

  /// No description provided for @sectionDebugging.
  ///
  /// In en, this message translates to:
  /// **'Debugging'**
  String get sectionDebugging;

  /// No description provided for @fieldEnableLogs.
  ///
  /// In en, this message translates to:
  /// **'Enable Logs'**
  String get fieldEnableLogs;

  /// No description provided for @btnViewLogs.
  ///
  /// In en, this message translates to:
  /// **'View Logs'**
  String get btnViewLogs;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @btnClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get btnClear;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get filterInfo;

  /// No description provided for @filterError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get filterError;

  /// No description provided for @unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get unknownDevice;

  /// No description provided for @signalStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong Signal'**
  String get signalStrong;

  /// No description provided for @signalMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium Signal'**
  String get signalMedium;

  /// No description provided for @signalWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak Signal'**
  String get signalWeak;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
