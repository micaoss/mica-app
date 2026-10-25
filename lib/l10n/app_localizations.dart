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

  /// No description provided for @staleList.
  ///
  /// In en, this message translates to:
  /// **'The list is from {minutes} min ago'**
  String staleList(int minutes);

  /// No description provided for @rescanAp.
  ///
  /// In en, this message translates to:
  /// **'Rescan (briefly drops the hotspot)'**
  String get rescanAp;

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

  /// No description provided for @hotspotTitle.
  ///
  /// In en, this message translates to:
  /// **'Join the device\'s hotspot'**
  String get hotspotTitle;

  /// No description provided for @hotspotSsid.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get hotspotSsid;

  /// No description provided for @hotspotKey.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get hotspotKey;

  /// No description provided for @copySsid.
  ///
  /// In en, this message translates to:
  /// **'Copy the network name'**
  String get copySsid;

  /// No description provided for @copyKey.
  ///
  /// In en, this message translates to:
  /// **'Copy the key'**
  String get copyKey;

  /// No description provided for @hotspotQr.
  ///
  /// In en, this message translates to:
  /// **'QR code to join the device\'s hotspot'**
  String get hotspotQr;

  /// No description provided for @joinHotspot.
  ///
  /// In en, this message translates to:
  /// **'Join the hotspot'**
  String get joinHotspot;

  /// No description provided for @hotspotJoined.
  ///
  /// In en, this message translates to:
  /// **'The phone was asked to join the device\'s hotspot.'**
  String get hotspotJoined;

  /// No description provided for @hotspotJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not join automatically. Scan the QR code or join in the phone\'s Wi-Fi settings.'**
  String get hotspotJoinFailed;

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

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'mica'**
  String get appTitle;

  /// No description provided for @homeLead.
  ///
  /// In en, this message translates to:
  /// **'Set up and manage mica devices.'**
  String get homeLead;

  /// No description provided for @homeBle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth setup'**
  String get homeBle;

  /// No description provided for @homeBleHint.
  ///
  /// In en, this message translates to:
  /// **'A device in its Bluetooth setup window: its Wi-Fi or wired network, without joining its hotspot.'**
  String get homeBleHint;

  /// No description provided for @homeNetwork.
  ///
  /// In en, this message translates to:
  /// **'Manage over the network'**
  String get homeNetwork;

  /// No description provided for @homeNetworkHint.
  ///
  /// In en, this message translates to:
  /// **'A device on this phone\'s network, on its own hotspot or on a cable to this phone: first setup, network and status, with or without Bluetooth and a web console.'**
  String get homeNetworkHint;

  /// No description provided for @manageTitle.
  ///
  /// In en, this message translates to:
  /// **'Network management'**
  String get manageTitle;

  /// No description provided for @discovered.
  ///
  /// In en, this message translates to:
  /// **'On this network'**
  String get discovered;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Signed in before'**
  String get saved;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Looking for devices on this network…'**
  String get searching;

  /// No description provided for @noDiscovered.
  ///
  /// In en, this message translates to:
  /// **'No device answered. A device announces itself on the network it is cabled or joined to; with the phone on a cable to the device, or with announcements off, type its address.'**
  String get noDiscovered;

  /// No description provided for @manualAddress.
  ///
  /// In en, this message translates to:
  /// **'Device address'**
  String get manualAddress;

  /// No description provided for @manualAddressHint.
  ///
  /// In en, this message translates to:
  /// **'An IP address, hostname.local, or the Console line of the device\'s login prompt'**
  String get manualAddressHint;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @consoleLocal.
  ///
  /// In en, this message translates to:
  /// **'This device\'s API serves only the device itself: it cannot be managed over the network.'**
  String get consoleLocal;

  /// No description provided for @unreachable.
  ///
  /// In en, this message translates to:
  /// **'The device did not answer at {address}'**
  String unreachable(String address);

  /// No description provided for @certChanged.
  ///
  /// In en, this message translates to:
  /// **'The device presented another certificate than the one it presented first. If it was reset or its certificate replaced, trust the new one; otherwise something else may be answering at this address.'**
  String get certChanged;

  /// No description provided for @certFingerprint.
  ///
  /// In en, this message translates to:
  /// **'New certificate fingerprint'**
  String get certFingerprint;

  /// No description provided for @trustNew.
  ///
  /// In en, this message translates to:
  /// **'Trust the new certificate'**
  String get trustNew;

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'First setup'**
  String get setupTitle;

  /// No description provided for @setupHint.
  ///
  /// In en, this message translates to:
  /// **'Set the administrator password. It signs in to this app and to the console.'**
  String get setupHint;

  /// No description provided for @deviceCode.
  ///
  /// In en, this message translates to:
  /// **'Device code'**
  String get deviceCode;

  /// No description provided for @deviceCodeHint.
  ///
  /// In en, this message translates to:
  /// **'On the device\'s label, and on its login prompt'**
  String get deviceCodeHint;

  /// No description provided for @deviceCodeIncorrect.
  ///
  /// In en, this message translates to:
  /// **'That is not this device\'s code'**
  String get deviceCodeIncorrect;

  /// No description provided for @throttled.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts: wait a moment and try again'**
  String get throttled;

  /// No description provided for @alreadyConfigured.
  ///
  /// In en, this message translates to:
  /// **'The device already has an administrator: sign in'**
  String get alreadyConfigured;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @dashTitle.
  ///
  /// In en, this message translates to:
  /// **'Device status'**
  String get dashTitle;

  /// No description provided for @health.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get health;

  /// No description provided for @healthOk.
  ///
  /// In en, this message translates to:
  /// **'Responding'**
  String get healthOk;

  /// No description provided for @healthDown.
  ///
  /// In en, this message translates to:
  /// **'micad is not responding'**
  String get healthDown;

  /// No description provided for @software.
  ///
  /// In en, this message translates to:
  /// **'Software'**
  String get software;

  /// No description provided for @board.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get board;

  /// No description provided for @deployment.
  ///
  /// In en, this message translates to:
  /// **'Deployment'**
  String get deployment;

  /// No description provided for @kernel.
  ///
  /// In en, this message translates to:
  /// **'Kernel'**
  String get kernel;

  /// No description provided for @uptime.
  ///
  /// In en, this message translates to:
  /// **'Uptime'**
  String get uptime;

  /// No description provided for @uptimeValue.
  ///
  /// In en, this message translates to:
  /// **'{days} d {hours} h {minutes} min'**
  String uptimeValue(int days, int hours, int minutes);

  /// No description provided for @clock.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get clock;

  /// No description provided for @synchronized.
  ///
  /// In en, this message translates to:
  /// **'Synchronized'**
  String get synchronized;

  /// No description provided for @notSynchronized.
  ///
  /// In en, this message translates to:
  /// **'Not synchronized'**
  String get notSynchronized;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @noAddress.
  ///
  /// In en, this message translates to:
  /// **'no address'**
  String get noAddress;

  /// No description provided for @noConsole.
  ///
  /// In en, this message translates to:
  /// **'This device has no web console: manage it here.'**
  String get noConsole;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Signed out: sign in again'**
  String get sessionExpired;

  /// No description provided for @forget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get forget;

  /// No description provided for @manageInApp.
  ///
  /// In en, this message translates to:
  /// **'Manage in the app'**
  String get manageInApp;

  /// No description provided for @requestFailed.
  ///
  /// In en, this message translates to:
  /// **'The device refused: {code}'**
  String requestFailed(String code);

  /// No description provided for @connectionLost.
  ///
  /// In en, this message translates to:
  /// **'Lost the connection to the device'**
  String get connectionLost;

  /// No description provided for @apiUnsupported.
  ///
  /// In en, this message translates to:
  /// **'The device speaks API {version}: update the app'**
  String apiUnsupported(String version);

  /// No description provided for @networkButton.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkButton;

  /// No description provided for @settingsButton.
  ///
  /// In en, this message translates to:
  /// **'System settings'**
  String get settingsButton;

  /// No description provided for @applied.
  ///
  /// In en, this message translates to:
  /// **'Saved and applied'**
  String get applied;

  /// No description provided for @applyFailed.
  ///
  /// In en, this message translates to:
  /// **'Saved, but applying it failed: {message}'**
  String applyFailed(String message);

  /// No description provided for @applyPending.
  ///
  /// In en, this message translates to:
  /// **'Saved; the device is still applying it'**
  String get applyPending;

  /// No description provided for @maybeMoved.
  ///
  /// In en, this message translates to:
  /// **'The device stopped answering: it may have moved to another network or address. Find it again from the list.'**
  String get maybeMoved;

  /// No description provided for @wrongCurrent.
  ///
  /// In en, this message translates to:
  /// **'The current password is wrong'**
  String get wrongCurrent;

  /// No description provided for @removing.
  ///
  /// In en, this message translates to:
  /// **'Removing {ssid}…'**
  String removing(String ssid);

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not declared (DHCP)'**
  String get notConfigured;

  /// No description provided for @noKnownNetworks.
  ///
  /// In en, this message translates to:
  /// **'No saved networks'**
  String get noKnownNetworks;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @noWiredPorts.
  ///
  /// In en, this message translates to:
  /// **'The device has no wired port'**
  String get noWiredPorts;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change the administrator password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @sshServer.
  ///
  /// In en, this message translates to:
  /// **'SSH server'**
  String get sshServer;

  /// No description provided for @sshKeys.
  ///
  /// In en, this message translates to:
  /// **'Authorized keys'**
  String get sshKeys;

  /// No description provided for @noSshKeys.
  ///
  /// In en, this message translates to:
  /// **'No authorized keys'**
  String get noSshKeys;

  /// No description provided for @addSshKey.
  ///
  /// In en, this message translates to:
  /// **'Add a key'**
  String get addSshKey;

  /// No description provided for @sshKeyHint.
  ///
  /// In en, this message translates to:
  /// **'One OpenSSH public key line, such as ssh-ed25519 AAAA… user@host'**
  String get sshKeyHint;
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
