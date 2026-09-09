import 'package:flutter/services.dart';

class ClassicDevice {
  const ClassicDevice({
    required this.address,
    required this.name,
    required this.connected,
  });

  final String address;
  final String name;
  final bool connected;

  factory ClassicDevice.fromMap(Map<dynamic, dynamic> map) {
    final address = map['address'] as String;
    final name = map['name'] as String?;
    return ClassicDevice(
      address: address,
      name: (name != null && name.isNotEmpty) ? name : address,
      connected: map['connected'] as bool? ?? false,
    );
  }
}

class ClassicBluetoothEvent {
  const ClassicBluetoothEvent({
    required this.address,
    required this.name,
    required this.connected,
  });

  final String address;
  final String name;
  final bool connected;

  factory ClassicBluetoothEvent.fromMap(Map<dynamic, dynamic> map) {
    final address = map['address'] as String;
    final name = map['name'] as String?;
    return ClassicBluetoothEvent(
      address: address,
      name: (name != null && name.isNotEmpty) ? name : address,
      connected: map['connected'] as bool? ?? false,
    );
  }
}

/// Talks to the native Android listener for Classic Bluetooth (A2DP) audio
/// devices - headphones, earbuds, speakers - which are invisible to BLE
/// scanning. Android-only: on other platforms the method channel has no
/// native handler, so calls are caught and treated as "no devices".
class ClassicBluetoothService {
  static const MethodChannel _methodChannel =
      MethodChannel('zalarmee/classic_bt');
  static const EventChannel _eventChannel =
      EventChannel('zalarmee/classic_bt_events');

  Stream<ClassicBluetoothEvent>? _events;

  Stream<ClassicBluetoothEvent> get events {
    return _events ??= _eventChannel
        .receiveBroadcastStream()
        .map((e) => ClassicBluetoothEvent.fromMap(e as Map));
  }

  Future<List<ClassicDevice>> getPairedAudioDevices() async {
    try {
      final result = await _methodChannel
          .invokeMethod<List<dynamic>>('getPairedAudioDevices');
      return (result ?? [])
          .map((e) => ClassicDevice.fromMap(e as Map))
          .toList();
    } on MissingPluginException {
      return [];
    } on PlatformException {
      return [];
    }
  }
}
