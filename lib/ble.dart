import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'protocol/client.dart';

enum RadioState { unsupported, unauthorized, off, on, unknown }

/// A device that advertises the provisioning service.
class FoundDevice {
  const FoundDevice(this.id, this.name, this.rssi, [this.handle]);

  final String id;

  /// The scan response's local name: the hostname.
  final String name;
  final int rssi;
  final Object? handle;
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

final _service = Guid(serviceUuid);

class FlutterBlueBluetooth implements Bluetooth {
  @override
  Stream<RadioState> get state async* {
    if (!await FlutterBluePlus.isSupported) {
      yield RadioState.unsupported;
      return;
    }
    yield* FlutterBluePlus.adapterState.map(
      (s) => switch (s) {
        BluetoothAdapterState.on => RadioState.on,
        BluetoothAdapterState.off ||
        BluetoothAdapterState.turningOff ||
        BluetoothAdapterState.turningOn => RadioState.off,
        BluetoothAdapterState.unauthorized => RadioState.unauthorized,
        BluetoothAdapterState.unavailable => RadioState.unsupported,
        _ => RadioState.unknown,
      },
    );
  }

  @override
  Stream<List<FoundDevice>> scan() {
    late StreamSubscription<List<ScanResult>> sub;
    late StreamController<List<FoundDevice>> out;
    out = StreamController(
      onListen: () {
        sub = FlutterBluePlus.onScanResults.listen((results) {
          final list = [
            for (final r in results)
              FoundDevice(
                r.device.remoteId.str,
                r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : r.device.platformName,
                r.rssi,
                r.device,
              ),
          ]..sort((a, b) => b.rssi.compareTo(a.rssi));
          out.add(list);
        }, onError: out.addError);
        FlutterBluePlus.startScan(withServices: [_service]).catchError(out.addError);
      },
      onCancel: () async {
        await sub.cancel();
        await FlutterBluePlus.stopScan();
      },
    );
    return out.stream;
  }

  @override
  Future<Transport> connect(FoundDevice found) async {
    final device = found.handle! as BluetoothDevice;
    await device.connect(license: License.nonprofit, autoConnect: false);
    try {
      final service = (await device.discoverServices()).firstWhere((s) => s.uuid == _service);
      BluetoothCharacteristic ch(String uuid) => service.characteristics.firstWhere((c) => c.uuid == Guid(uuid));
      final t = _BlueTransport(device, ch(infoUuid), ch(sessionUuid), ch(commandUuid), ch(eventUuid));
      await t._subscribe();
      return t;
    } catch (_) {
      await device.disconnect();
      rethrow;
    }
  }
}

class _BlueTransport implements Transport {
  _BlueTransport(this._device, this._info, this._session, this._command, this._event) {
    _stateSub = _device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected && !_gone.isCompleted) {
        _gone.complete();
        _stateSub.cancel();
      }
    });
  }

  final BluetoothDevice _device;
  final BluetoothCharacteristic _info, _session, _command, _event;
  final _gone = Completer<void>();
  late final StreamSubscription<BluetoothConnectionState> _stateSub;

  // Subscribed before the first write, as the protocol asks.
  Future<void> _subscribe() async {
    await _session.setNotifyValue(true);
    await _event.setNotifyValue(true);
  }

  @override
  Future<Uint8List> readInfo() async => Uint8List.fromList(await _info.read());

  @override
  Future<void> writeSession(Uint8List fragment) => _session.write(fragment);

  @override
  Future<void> writeCommand(Uint8List fragment) => _command.write(fragment);

  @override
  Stream<Uint8List> get sessionNotifications => _session.onValueReceived.map(Uint8List.fromList);

  @override
  Stream<Uint8List> get eventNotifications => _event.onValueReceived.map(Uint8List.fromList);

  @override
  Future<void> get disconnected => _gone.future;

  @override
  Future<void> disconnect() => _device.disconnect();
}
