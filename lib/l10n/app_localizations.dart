import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('zh')];

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'mica Bluetooth setup'**
  String get title;

  /// No description provided for @lead.
  ///
  /// In en, this message translates to:
  /// **'Set up a mica device\'s Wi-Fi or wired network over Bluetooth, without joining the device\'s hotspot.'**
  String get lead;

  /// No description provided for @switchTo.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get switchTo;

  /// No description provided for @radioUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This phone has no Bluetooth Low Energy: set the device up through its hotspot'**
  String get radioUnsupported;

  /// No description provided for @radioUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Allow the app to use Bluetooth in the phone\'s settings'**
  String get radioUnauthorized;

  /// No description provided for @radioOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on Bluetooth'**
  String get radioOff;

  /// No description provided for @findHint.
  ///
  /// In en, this message translates to:
  /// **'Devices in setup are listed by hostname, such as mica-a4e2e69e. No Bluetooth pairing is needed.'**
  String get findHint;

  /// No description provided for @findingDevices.
  ///
  /// In en, this message translates to:
  /// **'Looking for devices…'**
  String get findingDevices;

  /// No description provided for @noDeviceHint.
  ///
  /// In en, this message translates to:
  /// **'A device is visible only while its setup window is open: for 10 minutes after it boots, or after setup is opened in the console.'**
  String get noDeviceHint;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @deviceBusy.
  ///
  /// In en, this message translates to:
  /// **'Another phone is connected to the device: try again once it has finished'**
  String get deviceBusy;

  /// No description provided for @device.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get device;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @hostname.
  ///
  /// In en, this message translates to:
  /// **'Hostname'**
  String get hostname;

  /// No description provided for @claimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get claimed;

  /// No description provided for @unclaimed.
  ///
  /// In en, this message translates to:
  /// **'Unclaimed'**
  String get unclaimed;

  /// No description provided for @protocolMismatch.
  ///
  /// In en, this message translates to:
  /// **'Update the app or the device'**
  String get protocolMismatch;

  /// No description provided for @passwordUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Log in to the console once to enable Bluetooth recovery'**
  String get passwordUnavailable;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Administrator password'**
  String get authPassword;

  /// No description provided for @authTempCode.
  ///
  /// In en, this message translates to:
  /// **'Temporary setup code'**
  String get authTempCode;

  /// No description provided for @authTempCodeHint.
  ///
  /// In en, this message translates to:
  /// **'The 8 digits under Bluetooth setup in the console'**
  String get authTempCodeHint;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @verifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get verifying;

  /// No description provided for @wrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get wrongPassword;

  /// No description provided for @wrongCode.
  ///
  /// In en, this message translates to:
  /// **'Wrong setup code'**
  String get wrongCode;

  /// No description provided for @attemptsLeft.
  ///
  /// In en, this message translates to:
  /// **', {n} attempts left'**
  String attemptsLeft(int n);

  /// No description provided for @locked.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong attempts: the device is locked. Try again in {minutes} min'**
  String locked(int minutes);

  /// No description provided for @adminTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up the administrator'**
  String get adminTitle;

  /// No description provided for @adminHint.
  ///
  /// In en, this message translates to:
  /// **'The administrator password and hostname take effect when setup finishes.'**
  String get adminHint;

  /// No description provided for @adminPassword.
  ///
  /// In en, this message translates to:
  /// **'Administrator password (at least 8 characters)'**
  String get adminPassword;

  /// No description provided for @adminPassword2.
  ///
  /// In en, this message translates to:
  /// **'Enter the password again'**
  String get adminPassword2;

  /// No description provided for @hostnameOptional.
  ///
  /// In en, this message translates to:
  /// **'Hostname (optional)'**
  String get hostnameOptional;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'The password needs at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordTooLong.
  ///
  /// In en, this message translates to:
  /// **'The password is too long'**
  String get passwordTooLong;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords do not match'**
  String get passwordMismatch;

  /// No description provided for @hostnameInvalid.
  ///
  /// In en, this message translates to:
  /// **'A hostname is letters, digits and hyphens, at most 63, not starting or ending with a hyphen'**
  String get hostnameInvalid;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @statusTitle.
  ///
  /// In en, this message translates to:
  /// **'Current state'**
  String get statusTitle;

  /// No description provided for @wifiMode.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi mode'**
  String get wifiMode;

  /// No description provided for @modeClient.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi client'**
  String get modeClient;

  /// No description provided for @modeAp.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi access point'**
  String get modeAp;

  /// No description provided for @modeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get modeOff;

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected to {ssid}'**
  String connectedTo(Object ssid);

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get notConnected;

  /// No description provided for @ip.
  ///
  /// In en, this message translates to:
  /// **'IP'**
  String get ip;

  /// No description provided for @configureWifi.
  ///
  /// In en, this message translates to:
  /// **'Configure Wi-Fi'**
  String get configureWifi;

  /// No description provided for @networkTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a network'**
  String get networkTitle;

  /// No description provided for @scanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get scanning;

  /// No description provided for @rescan.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get rescan;

  /// No description provided for @apNoScan.
  ///
  /// In en, this message translates to:
  /// **'The device is a Wi-Fi access point and cannot scan: enter the network name.'**
  String get apNoScan;

  /// No description provided for @scanFailed.
  ///
  /// In en, this message translates to:
  /// **'The scan failed: scan again or enter the name'**
  String get scanFailed;

  /// No description provided for @noNetworks.
  ///
  /// In en, this message translates to:
  /// **'No networks found'**
  String get noNetworks;

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Enter a network name'**
  String get manual;

  /// No description provided for @ssid.
  ///
  /// In en, this message translates to:
  /// **'Network name'**
  String get ssid;

  /// No description provided for @hidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden network (does not broadcast its name)'**
  String get hidden;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @ssidInvalid.
  ///
  /// In en, this message translates to:
  /// **'A network name is 1 to 32 bytes'**
  String get ssidInvalid;

  /// No description provided for @passwordTitle.
  ///
  /// In en, this message translates to:
  /// **'Join {ssid}'**
  String passwordTitle(Object ssid);

  /// No description provided for @wifiPassword.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi password (empty for an open network)'**
  String get wifiPassword;

  /// No description provided for @pskInvalid.
  ///
  /// In en, this message translates to:
  /// **'A Wi-Fi password is 8 to 63 printable characters, or 64 hex digits'**
  String get pskInvalid;

  /// No description provided for @apWarning.
  ///
  /// In en, this message translates to:
  /// **'The device will turn off its hotspot and join {ssid}; anything connected to the hotspot will drop'**
  String apWarning(Object ssid);

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Joining {ssid}…'**
  String progress(Object ssid);

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Connected to {ssid}, IP: {ip}'**
  String success(Object ssid, Object ip);

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get finish;

  /// No description provided for @finishing.
  ///
  /// In en, this message translates to:
  /// **'Finishing…'**
  String get finishing;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Setup finished'**
  String get done;

  /// No description provided for @openConsole.
  ///
  /// In en, this message translates to:
  /// **'Open the console'**
  String get openConsole;

  /// No description provided for @apPsk.
  ///
  /// In en, this message translates to:
  /// **'The device hotspot\'s new key'**
  String get apPsk;

  /// No description provided for @apPskOnce.
  ///
  /// In en, this message translates to:
  /// **'Shown only this once: note it now.'**
  String get apPskOnce;

  /// No description provided for @alreadyClaimed.
  ///
  /// In en, this message translates to:
  /// **'The device has been claimed another way'**
  String get alreadyClaimed;

  /// No description provided for @closingIdle.
  ///
  /// In en, this message translates to:
  /// **'Nothing happened for 2 minutes, so the device disconnected.'**
  String get closingIdle;

  /// No description provided for @disconnectedUnclaimed.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth disconnected before setup finished; the device undid this session\'s changes. Reconnect to start again.'**
  String get disconnectedUnclaimed;

  /// No description provided for @disconnectedClaimed.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth disconnected. Reconnect and verify to continue.'**
  String get disconnectedClaimed;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Start again'**
  String get restart;

  /// No description provided for @commError.
  ///
  /// In en, this message translates to:
  /// **'Talking to the device failed: reconnect'**
  String get commError;

  /// No description provided for @resultWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong Wi-Fi password'**
  String get resultWrongPassword;

  /// No description provided for @resultSsidNotFound.
  ///
  /// In en, this message translates to:
  /// **'Network not found: check the name or move closer to the router'**
  String get resultSsidNotFound;

  /// No description provided for @resultDhcpTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connected but got no IP address: check the router'**
  String get resultDhcpTimeout;

  /// No description provided for @resultUnsupportedSecurity.
  ///
  /// In en, this message translates to:
  /// **'The device does not support this network\'s security'**
  String get resultUnsupportedSecurity;

  /// No description provided for @resultBusy.
  ///
  /// In en, this message translates to:
  /// **'The device is busy: try again shortly'**
  String get resultBusy;

  /// No description provided for @resultConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect: try again'**
  String get resultConnectFailed;

  /// No description provided for @resultInvalidSsid.
  ///
  /// In en, this message translates to:
  /// **'The network name is not valid'**
  String get resultInvalidSsid;

  /// No description provided for @resultInvalidPsk.
  ///
  /// In en, this message translates to:
  /// **'The Wi-Fi password is not valid'**
  String get resultInvalidPsk;

  /// No description provided for @resultNoRadio.
  ///
  /// In en, this message translates to:
  /// **'The device has no usable Wi-Fi'**
  String get resultNoRadio;

  /// No description provided for @resultNotClaimed.
  ///
  /// In en, this message translates to:
  /// **'Set up the administrator first'**
  String get resultNotClaimed;

  /// No description provided for @resultInvalidPassword.
  ///
  /// In en, this message translates to:
  /// **'The administrator password is not valid (8 to 1024 bytes)'**
  String get resultInvalidPassword;

  /// No description provided for @resultInvalidHostname.
  ///
  /// In en, this message translates to:
  /// **'The hostname is not valid'**
  String get resultInvalidHostname;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'The operation failed: {reason}'**
  String failed(Object reason);

  /// No description provided for @chooseHint.
  ///
  /// In en, this message translates to:
  /// **'Does the device reach the network over Wi-Fi or a cable?'**
  String get chooseHint;

  /// No description provided for @configureWired.
  ///
  /// In en, this message translates to:
  /// **'Set up the wired port'**
  String get configureWired;

  /// No description provided for @ethernet.
  ///
  /// In en, this message translates to:
  /// **'Ethernet'**
  String get ethernet;

  /// No description provided for @wifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get wifi;

  /// No description provided for @cableIn.
  ///
  /// In en, this message translates to:
  /// **'cable in'**
  String get cableIn;

  /// No description provided for @noCable.
  ///
  /// In en, this message translates to:
  /// **'no cable'**
  String get noCable;

  /// No description provided for @linkUp.
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get linkUp;

  /// No description provided for @wiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Wired network'**
  String get wiredTitle;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @dhcp.
  ///
  /// In en, this message translates to:
  /// **'Automatic (DHCP)'**
  String get dhcp;

  /// No description provided for @staticAddress.
  ///
  /// In en, this message translates to:
  /// **'Static address'**
  String get staticAddress;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address/prefix (e.g. 192.168.1.40/24)'**
  String get addressLabel;

  /// No description provided for @gateway.
  ///
  /// In en, this message translates to:
  /// **'Gateway (optional)'**
  String get gateway;

  /// No description provided for @dns.
  ///
  /// In en, this message translates to:
  /// **'DNS servers (optional, separated by spaces or commas)'**
  String get dns;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @applying.
  ///
  /// In en, this message translates to:
  /// **'Setting up {name}…'**
  String applying(Object name);

  /// No description provided for @wiredUp.
  ///
  /// In en, this message translates to:
  /// **'{name} is set up, address: {address}'**
  String wiredUp(Object name, Object address);

  /// No description provided for @doneConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected. {kind} {address}.'**
  String doneConnected(Object kind, Object address);

  /// No description provided for @consoleAt.
  ///
  /// In en, this message translates to:
  /// **'Open the console:'**
  String get consoleAt;

  /// No description provided for @consoleOffNetwork.
  ///
  /// In en, this message translates to:
  /// **'The console on this device is not reachable over the network, so it cannot be opened from here.'**
  String get consoleOffNetwork;

  /// No description provided for @doneClaim.
  ///
  /// In en, this message translates to:
  /// **'Open the console to set the administrator password. The console asks for the device code — it is printed on the device\'s label and shown on the device\'s own console (serial / display login prompt).'**
  String get doneClaim;

  /// No description provided for @hotspotOn.
  ///
  /// In en, this message translates to:
  /// **'The device\'s hotspot is still on. It keeps the key on its label until you set your own in the console.'**
  String get hotspotOn;

  /// No description provided for @resultBadRequest.
  ///
  /// In en, this message translates to:
  /// **'The request was malformed'**
  String get resultBadRequest;

  /// No description provided for @resultUnknownOp.
  ///
  /// In en, this message translates to:
  /// **'The device does not support this operation'**
  String get resultUnknownOp;

  /// No description provided for @resultUnknownInterface.
  ///
  /// In en, this message translates to:
  /// **'The device has no such wired port'**
  String get resultUnknownInterface;

  /// No description provided for @resultInvalidAddress.
  ///
  /// In en, this message translates to:
  /// **'The address must be an IPv4 address with its prefix, e.g. 192.168.1.40/24'**
  String get resultInvalidAddress;

  /// No description provided for @resultInvalidGateway.
  ///
  /// In en, this message translates to:
  /// **'The gateway must be an IPv4 address'**
  String get resultInvalidGateway;

  /// No description provided for @resultInvalidDns.
  ///
  /// In en, this message translates to:
  /// **'DNS servers must be IP addresses'**
  String get resultInvalidDns;

  /// No description provided for @resultValidationFailed.
  ///
  /// In en, this message translates to:
  /// **'The device refused these network settings'**
  String get resultValidationFailed;

  /// No description provided for @resultNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'The network settings do not accept this port\'s name'**
  String get resultNameInvalid;

  /// No description provided for @resultGatewayOutOfSubnet.
  ///
  /// In en, this message translates to:
  /// **'The gateway is not in the address\'s subnet'**
  String get resultGatewayOutOfSubnet;

  /// No description provided for @resultAddressOverlap.
  ///
  /// In en, this message translates to:
  /// **'This subnet overlaps another interface\'s'**
  String get resultAddressOverlap;

  /// No description provided for @resultMetricDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Another interface\'s default route has the same metric'**
  String get resultMetricDuplicate;

  /// No description provided for @resultVlanDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Two VLANs on the same parent have the same id'**
  String get resultVlanDuplicate;

  /// No description provided for @resultVlanParentInvalid.
  ///
  /// In en, this message translates to:
  /// **'A VLAN\'s parent is not valid'**
  String get resultVlanParentInvalid;

  /// No description provided for @resultBridgePortInvalid.
  ///
  /// In en, this message translates to:
  /// **'A bridge port is not valid'**
  String get resultBridgePortInvalid;

  /// No description provided for @resultBridgePortAddressed.
  ///
  /// In en, this message translates to:
  /// **'This port belongs to a bridge and has no addressing of its own'**
  String get resultBridgePortAddressed;

  /// No description provided for @resultBridgePortTaken.
  ///
  /// In en, this message translates to:
  /// **'The port is in more than one bridge'**
  String get resultBridgePortTaken;

  /// No description provided for @resultNoCarrier.
  ///
  /// In en, this message translates to:
  /// **'No cable is plugged in. The settings are saved and apply once one is'**
  String get resultNoCarrier;

  /// No description provided for @resultWiredDhcpTimeout.
  ///
  /// In en, this message translates to:
  /// **'No DHCP address within 30 seconds. The settings are saved'**
  String get resultWiredDhcpTimeout;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
