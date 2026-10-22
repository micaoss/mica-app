import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import 'protocol/client.dart';

enum RadioState { unsupported, unauthorized, off, on, unknown }

/// A device that advertises the provisioning service.
class FoundDevice {
  const FoundDevice(this.id, this.name, this.rssi);

  final String id;

  /// The scan response's local name: the hostname.
  final String name;
  final int rssi;
}

/// The phone's Bluetooth, as the app uses it; the tests stand in for it.
abstract class Bluetooth {
  Stream<RadioState> get state;

  /// Scans for provisioning devices until the subscription is cancelled; each
  /// event is every device seen so far, strongest first.
  Stream<List<FoundDevice>> scan();

  /// Connects, subscribes to `session` and `event`, and returns the link.
  Future<Transport> connect(FoundDevice device);
}

/// The phone's Bluetooth through universal_ble (BSD-3-Clause).
class PlatformBluetooth implements Bluetooth {
  @override
  Stream<RadioState> get state async* {
    yield _state(await UniversalBle.getBluetoothAvailabilityState());
    yield* UniversalBle.availabilityStream.map(_state);
  }

  static RadioState _state(AvailabilityState s) => switch (s) {
    AvailabilityState.poweredOn => RadioState.on,
    AvailabilityState.poweredOff || AvailabilityState.resetting => RadioState.off,
    AvailabilityState.unauthorized => RadioState.unauthorized,
    AvailabilityState.unsupported => RadioState.unsupported,
    AvailabilityState.unknown => RadioState.unknown,
  };

  @override
  Stream<List<FoundDevice>> scan() {
    final seen = <String, FoundDevice>{};
    late StreamSubscription<BleDevice> sub;
    late StreamController<List<FoundDevice>> out;
    out = StreamController(
      onListen: () {
        sub = UniversalBle.scanStream.listen((d) {
          seen[d.deviceId] = FoundDevice(d.deviceId, d.name ?? '', d.rssi ?? -127);
          out.add(seen.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi)));
        }, onError: out.addError);
        // Asks for the Bluetooth permissions first where the platform has them.
        UniversalBle.startScan(scanFilter: ScanFilter(withServices: [serviceUuid])).catchError(out.addError);
      },
      onCancel: () async {
        await sub.cancel();
        await UniversalBle.stopScan();
      },
    );
    return out.stream;
  }

  @override
  Future<Transport> connect(FoundDevice found) async {
    final id = found.id;
    await UniversalBle.connect(id);
    try {
      // Android starts at the 23-byte default; info.maxWrite follows what this
      // negotiates. iOS negotiates by itself.
      try {
        await UniversalBle.requestMtu(id, 517);
      } catch (_) {}
      await UniversalBle.discoverServices(id);
      final t = _UniversalTransport(id);
      // Subscribed before the first write, as the protocol asks.
      await UniversalBle.subscribeNotifications(id, serviceUuid, sessionUuid);
      await UniversalBle.subscribeNotifications(id, serviceUuid, eventUuid);
      return t;
    } catch (_) {
      await UniversalBle.disconnect(id);
      rethrow;
    }
  }
}

class _UniversalTransport implements Transport {
  _UniversalTransport(this._id) {
    _connection = UniversalBle.connectionStream(_id).listen((up) {
      if (!up && !_gone.isCompleted) {
        _gone.complete();
        _connection.cancel();
      }
    });
  }

  final String _id;
  final _gone = Completer<void>();
  late final StreamSubscription<bool> _connection;

  @override
  Future<Uint8List> readInfo() => UniversalBle.read(_id, serviceUuid, infoUuid);

  @override
  Future<void> writeSession(Uint8List fragment) => UniversalBle.write(_id, serviceUuid, sessionUuid, fragment);

  @override
  Future<void> writeCommand(Uint8List fragment) => UniversalBle.write(_id, serviceUuid, commandUuid, fragment);

  @override
  Stream<Uint8List> get sessionNotifications => UniversalBle.characteristicValueStream(_id, sessionUuid);

  @override
  Stream<Uint8List> get eventNotifications => UniversalBle.characteristicValueStream(_id, eventUuid);

  @override
  Future<void> get disconnected => _gone.future;

  @override
  Future<void> disconnect() => UniversalBle.disconnect(_id);
}
