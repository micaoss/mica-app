// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get title => 'mica Bluetooth setup';

  @override
  String get lead => 'Send a mica device the site\'s Wi-Fi over Bluetooth, without joining the device\'s hotspot.';

  @override
  String get switchTo => '中文';

  @override
  String get radioUnsupported => 'This phone has no Bluetooth Low Energy: set the device up through its hotspot';

  @override
  String get radioUnauthorized => 'Allow the app to use Bluetooth in the phone\'s settings';

  @override
  String get radioOff => 'Turn on Bluetooth';

  @override
  String get findHint =>
      'Devices in setup are listed by hostname, such as mica-a4e2e69e. No Bluetooth pairing is needed.';

  @override
  String get findingDevices => 'Looking for devices…';

  @override
  String get noDeviceHint =>
      'A device is visible only while its setup window is open: for 10 minutes after it boots, or after setup is opened in the console.';

  @override
  String get connecting => 'Connecting…';

  @override
  String get deviceBusy => 'Another phone is connected to the device: try again once it has finished';

  @override
  String get device => 'Device';

  @override
  String get model => 'Model';

  @override
  String get hostname => 'Hostname';

  @override
  String get claimed => 'Claimed';

  @override
  String get unclaimed => 'Unclaimed';

  @override
  String get protocolMismatch => 'Update the app or the device';

  @override
  String get passwordUnavailable => 'Log in to the console once to enable Bluetooth recovery';

  @override
  String get authPassword => 'Administrator password';

  @override
  String get authTempCode => 'Temporary setup code';

  @override
  String get authTempCodeHint => 'The 8 digits under Bluetooth setup in the console';

  @override
  String get verify => 'Verify';

  @override
  String get verifying => 'Verifying…';

  @override
  String get wrongPassword => 'Wrong password';

  @override
  String get wrongCode => 'Wrong setup code';

  @override
  String attemptsLeft(int n) {
    return ', $n attempts left';
  }

  @override
  String locked(int minutes) {
    return 'Too many wrong attempts: the device is locked. Try again in $minutes min';
  }

  @override
  String get adminTitle => 'Set up the administrator';

  @override
  String get adminHint => 'The administrator password and hostname take effect when setup finishes.';

  @override
  String get adminPassword => 'Administrator password (at least 8 characters)';

  @override
  String get adminPassword2 => 'Enter the password again';

  @override
  String get hostnameOptional => 'Hostname (optional)';

  @override
  String get passwordTooShort => 'The password needs at least 8 characters';

  @override
  String get passwordTooLong => 'The password is too long';

  @override
  String get passwordMismatch => 'The passwords do not match';

  @override
  String get hostnameInvalid =>
      'A hostname is letters, digits and hyphens, at most 63, not starting or ending with a hyphen';

  @override
  String get next => 'Next';

  @override
  String get statusTitle => 'Current state';

  @override
  String get wifiMode => 'Wi-Fi mode';

  @override
  String get modeClient => 'Wi-Fi client';

  @override
  String get modeAp => 'Wi-Fi access point';

  @override
  String get modeOff => 'Off';

  @override
  String get connection => 'Connection';

  @override
  String connectedTo(Object ssid) {
    return 'Connected to $ssid';
  }

  @override
  String get notConnected => 'Not connected';

  @override
  String get ip => 'IP';

  @override
  String get configureWifi => 'Configure Wi-Fi';

  @override
  String get networkTitle => 'Choose a network';

  @override
  String get scanning => 'Scanning…';

  @override
  String get rescan => 'Scan again';

  @override
  String get apNoScan => 'The device is a Wi-Fi access point and cannot scan: enter the network name.';

  @override
  String get scanFailed => 'The scan failed: scan again or enter the name';

  @override
  String get noNetworks => 'No networks found';

  @override
  String get manual => 'Enter a network name';

  @override
  String get ssid => 'Network name';

  @override
  String get hidden => 'Hidden network (does not broadcast its name)';

  @override
  String get open => 'Open';

  @override
  String get ssidInvalid => 'A network name is 1 to 32 bytes';

  @override
  String passwordTitle(Object ssid) {
    return 'Join $ssid';
  }

  @override
  String get wifiPassword => 'Wi-Fi password (empty for an open network)';

  @override
  String get pskInvalid => 'A Wi-Fi password is 8 to 63 printable characters, or 64 hex digits';

  @override
  String apWarning(Object ssid) {
    return 'The device will turn off its hotspot and join $ssid; anything connected to the hotspot will drop';
  }

  @override
  String get join => 'Join';

  @override
  String get back => 'Back';

  @override
  String progress(Object ssid) {
    return 'Joining $ssid…';
  }

  @override
  String success(Object ssid, Object ip) {
    return 'Connected to $ssid, IP: $ip';
  }

  @override
  String get finish => 'Finish setup';

  @override
  String get finishing => 'Finishing…';

  @override
  String get done => 'Setup finished';

  @override
  String doneText(Object ssid, Object ip, Object hostname) {
    return 'Make sure the phone is on $ssid, then open http://$ip (or http://$hostname.local)';
  }

  @override
  String get openConsole => 'Open the console';

  @override
  String get apPsk => 'The device hotspot\'s new key';

  @override
  String get apPskOnce => 'Shown only this once: note it now.';

  @override
  String get alreadyClaimed => 'The device has been claimed another way';

  @override
  String get closingIdle => 'Nothing happened for 2 minutes, so the device disconnected.';

  @override
  String get disconnectedUnclaimed =>
      'Bluetooth disconnected and the staged administrator settings were dropped. Reconnect to start again from verification.';

  @override
  String get disconnectedClaimed => 'Bluetooth disconnected. Reconnect and verify to continue.';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get restart => 'Start again';

  @override
  String get commError => 'Talking to the device failed: reconnect';

  @override
  String get resultWrongPassword => 'Wrong Wi-Fi password';

  @override
  String get resultSsidNotFound => 'Network not found: check the name or move closer to the router';

  @override
  String get resultDhcpTimeout => 'Connected but got no IP address: check the router';

  @override
  String get resultUnsupportedSecurity => 'The device does not support this network\'s security';

  @override
  String get resultBusy => 'The device is busy: try again shortly';

  @override
  String get resultConnectFailed => 'Could not connect: try again';

  @override
  String get resultInvalidSsid => 'The network name is not valid';

  @override
  String get resultInvalidPsk => 'The Wi-Fi password is not valid';

  @override
  String get resultNoRadio => 'The device has no usable Wi-Fi';

  @override
  String get resultNotClaimed => 'Set up the administrator first';

  @override
  String get resultInvalidPassword => 'The administrator password is not valid (8 to 1024 bytes)';

  @override
  String get resultInvalidHostname => 'The hostname is not valid';

  @override
  String failed(Object reason) {
    return 'The operation failed: $reason';
  }
}
