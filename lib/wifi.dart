import 'package:flutter/services.dart';

/// The phone's Wi-Fi, to join the device's hotspot.
abstract class Wifi {
  /// Asks the system to join a WPA network; false when it refused or cannot.
  Future<bool> join(String ssid, String psk);
}

/// Android's add-network dialog (a network suggestion on Android 10), iOS's
/// NEHotspotConfiguration; both in the app's platform code on `mica/wifi`.
class PlatformWifi implements Wifi {
  static const _channel = MethodChannel('mica/wifi');

  @override
  Future<bool> join(String ssid, String psk) async {
    try {
      return await _channel.invokeMethod<bool>('join', {'ssid': ssid, 'psk': psk}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
