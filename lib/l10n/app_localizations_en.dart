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
  String get lead =>
      'Set up a mica device\'s Wi-Fi or wired network over Bluetooth, without joining the device\'s hotspot.';

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
  String staleList(int minutes) {
    return 'The list is from $minutes min ago';
  }

  @override
  String get rescanAp => 'Rescan (briefly drops the hotspot)';

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
      'Bluetooth disconnected before setup finished; the device undid this session\'s changes. Reconnect to start again.';

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

  @override
  String get chooseHint => 'Does the device reach the network over Wi-Fi or a cable?';

  @override
  String get configureWired => 'Set up the wired port';

  @override
  String get ethernet => 'Ethernet';

  @override
  String get wifi => 'Wi-Fi';

  @override
  String get cableIn => 'cable in';

  @override
  String get noCable => 'no cable';

  @override
  String get linkUp => 'connected';

  @override
  String get wiredTitle => 'Wired network';

  @override
  String get port => 'Port';

  @override
  String get dhcp => 'Automatic (DHCP)';

  @override
  String get staticAddress => 'Static address';

  @override
  String get addressLabel => 'Address/prefix (e.g. 192.168.1.40/24)';

  @override
  String get gateway => 'Gateway (optional)';

  @override
  String get dns => 'DNS servers (optional, separated by spaces or commas)';

  @override
  String get apply => 'Apply';

  @override
  String applying(Object name) {
    return 'Setting up $name…';
  }

  @override
  String wiredUp(Object name, Object address) {
    return '$name is set up, address: $address';
  }

  @override
  String doneConnected(Object kind, Object address) {
    return 'Connected. $kind $address.';
  }

  @override
  String get hotspotTitle => 'Join the device\'s hotspot';

  @override
  String get hotspotSsid => 'Network';

  @override
  String get hotspotKey => 'Key';

  @override
  String get copySsid => 'Copy the network name';

  @override
  String get copyKey => 'Copy the key';

  @override
  String get hotspotQr => 'QR code to join the device\'s hotspot';

  @override
  String get joinHotspot => 'Join the hotspot';

  @override
  String get hotspotJoined => 'The phone was asked to join the device\'s hotspot.';

  @override
  String get hotspotJoinFailed =>
      'Could not join automatically. Scan the QR code or join in the phone\'s Wi-Fi settings.';

  @override
  String get consoleAt => 'Open the console:';

  @override
  String get consoleOffNetwork =>
      'The console on this device is not reachable over the network, so it cannot be opened from here.';

  @override
  String get doneClaim =>
      'Open the console to set the administrator password. The console asks for the device code — it is printed on the device\'s label and shown on the device\'s own console (serial / display login prompt).';

  @override
  String get hotspotOn =>
      'The device\'s hotspot is still on. It keeps the key on its label until you set your own in the console.';

  @override
  String get resultBadRequest => 'The request was malformed';

  @override
  String get resultUnknownOp => 'The device does not support this operation';

  @override
  String get resultUnknownInterface => 'The device has no such wired port';

  @override
  String get resultInvalidAddress => 'The address must be an IPv4 address with its prefix, e.g. 192.168.1.40/24';

  @override
  String get resultInvalidGateway => 'The gateway must be an IPv4 address';

  @override
  String get resultInvalidDns => 'DNS servers must be IP addresses';

  @override
  String get resultValidationFailed => 'The device refused these network settings';

  @override
  String get resultNameInvalid => 'The network settings do not accept this port\'s name';

  @override
  String get resultGatewayOutOfSubnet => 'The gateway is not in the address\'s subnet';

  @override
  String get resultAddressOverlap => 'This subnet overlaps another interface\'s';

  @override
  String get resultMetricDuplicate => 'Another interface\'s default route has the same metric';

  @override
  String get resultVlanDuplicate => 'Two VLANs on the same parent have the same id';

  @override
  String get resultVlanParentInvalid => 'A VLAN\'s parent is not valid';

  @override
  String get resultBridgePortInvalid => 'A bridge port is not valid';

  @override
  String get resultBridgePortAddressed => 'This port belongs to a bridge and has no addressing of its own';

  @override
  String get resultBridgePortTaken => 'The port is in more than one bridge';

  @override
  String get resultNoCarrier => 'No cable is plugged in. The settings are saved and apply once one is';

  @override
  String get resultWiredDhcpTimeout => 'No DHCP address within 30 seconds. The settings are saved';

  @override
  String get appTitle => 'mica';

  @override
  String get homeLead => 'Set up and manage mica devices.';

  @override
  String get homeBle => 'Bluetooth setup';

  @override
  String get homeBleHint =>
      'A device in its Bluetooth setup window: its Wi-Fi or wired network, without joining its hotspot.';

  @override
  String get homeNetwork => 'Manage over the network';

  @override
  String get homeNetworkHint =>
      'A device on this phone\'s network, on its own hotspot or on a cable to this phone: first setup, network and status, with or without Bluetooth and a web console.';

  @override
  String get manageTitle => 'Network management';

  @override
  String get discovered => 'On this network';

  @override
  String get saved => 'Signed in before';

  @override
  String get searching => 'Looking for devices on this network…';

  @override
  String get noDiscovered =>
      'No device answered. A device announces itself on the network it is cabled or joined to; with the phone on a cable to the device, or with announcements off, type its address.';

  @override
  String get manualAddress => 'Device address';

  @override
  String get manualAddressHint => 'An IP address, hostname.local, or the Console line of the device\'s login prompt';

  @override
  String get connect => 'Connect';

  @override
  String get consoleLocal => 'This device\'s API serves only the device itself: it cannot be managed over the network.';

  @override
  String unreachable(String address) {
    return 'The device did not answer at $address';
  }

  @override
  String get certChanged =>
      'The device presented another certificate than the one it presented first. If it was reset or its certificate replaced, trust the new one; otherwise something else may be answering at this address.';

  @override
  String get certFingerprint => 'New certificate fingerprint';

  @override
  String get trustNew => 'Trust the new certificate';

  @override
  String get setupTitle => 'First setup';

  @override
  String get setupHint => 'Set the administrator password. It signs in to this app and to the console.';

  @override
  String get deviceCode => 'Device code';

  @override
  String get deviceCodeHint => 'On the device\'s label, and on its login prompt';

  @override
  String get deviceCodeIncorrect => 'That is not this device\'s code';

  @override
  String get throttled => 'Too many attempts: wait a moment and try again';

  @override
  String get alreadyConfigured => 'The device already has an administrator: sign in';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signIn => 'Sign in';

  @override
  String get dashTitle => 'Device status';

  @override
  String get health => 'Health';

  @override
  String get healthOk => 'Responding';

  @override
  String get healthDown => 'micad is not responding';

  @override
  String get software => 'Software';

  @override
  String get board => 'Board';

  @override
  String get deployment => 'Deployment';

  @override
  String get kernel => 'Kernel';

  @override
  String get uptime => 'Uptime';

  @override
  String uptimeValue(int days, int hours, int minutes) {
    return '$days d $hours h $minutes min';
  }

  @override
  String get clock => 'Clock';

  @override
  String get synchronized => 'Synchronized';

  @override
  String get notSynchronized => 'Not synchronized';

  @override
  String get features => 'Features';

  @override
  String get noAddress => 'no address';

  @override
  String get noConsole => 'This device has no web console: manage it here.';

  @override
  String get refresh => 'Refresh';

  @override
  String get signOut => 'Sign out';

  @override
  String get sessionExpired => 'Signed out: sign in again';

  @override
  String get forget => 'Forget';

  @override
  String get manageInApp => 'Manage in the app';

  @override
  String requestFailed(String code) {
    return 'The device refused: $code';
  }

  @override
  String get connectionLost => 'Lost the connection to the device';

  @override
  String apiUnsupported(String version) {
    return 'The device speaks API $version: update the app';
  }

  @override
  String get networkButton => 'Network';

  @override
  String get settingsButton => 'System settings';

  @override
  String get applied => 'Saved and applied';

  @override
  String applyFailed(String message) {
    return 'Saved, but applying it failed: $message';
  }

  @override
  String get applyPending => 'Saved; the device is still applying it';

  @override
  String get maybeMoved =>
      'The device stopped answering: it may have moved to another network or address. Find it again from the list.';

  @override
  String get wrongCurrent => 'The current password is wrong';

  @override
  String removing(String ssid) {
    return 'Removing $ssid…';
  }

  @override
  String get notConfigured => 'Not declared (DHCP)';

  @override
  String get noKnownNetworks => 'No saved networks';

  @override
  String get remove => 'Remove';

  @override
  String get noWiredPorts => 'The device has no wired port';

  @override
  String get saving => 'Saving…';

  @override
  String get save => 'Save';

  @override
  String get changePassword => 'Change the administrator password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get sshServer => 'SSH server';

  @override
  String get sshKeys => 'Authorized keys';

  @override
  String get noSshKeys => 'No authorized keys';

  @override
  String get addSshKey => 'Add a key';

  @override
  String get sshKeyHint => 'One OpenSSH public key line, such as ssh-ed25519 AAAA… user@host';
}
