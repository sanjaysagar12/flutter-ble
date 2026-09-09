import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/alarm_service.dart';
import '../services/classic_bluetooth_service.dart';
import '../services/settings_service.dart';

/// Tracks paired Classic Bluetooth (A2DP) audio devices - headphones,
/// earbuds, speakers - and alarms when a watched one disconnects
/// unexpectedly. This is the only way to monitor audio headphones, since
/// they connect over Classic Bluetooth rather than BLE and are invisible
/// to [BleController]'s scanning entirely.
class ClassicBluetoothController extends ChangeNotifier {
  ClassicBluetoothController({
    required this.alarmService,
    required this.settingsService,
    ClassicBluetoothService? service,
  }) : _service = service ?? ClassicBluetoothService();

  final AlarmService alarmService;
  final SettingsService settingsService;
  final ClassicBluetoothService _service;

  List<ClassicDevice> pairedDevices = [];
  StreamSubscription<ClassicBluetoothEvent>? _eventSubscription;
  Timer? _pollTimer;

  /// Set by the UI layer to react whenever the alarm is freshly triggered.
  AlarmTriggeredCallback? onAlarmTriggered;

  void init() {
    refreshPairedDevices();
    _eventSubscription = _service.events.listen(
      _onEvent,
      onError: (Object e) => debugPrint('Classic Bluetooth event error: $e'),
    );
    // Native connection-state broadcasts are the fast path, but some OEM
    // Bluetooth stacks are unreliable about delivering them. This poll is
    // the guaranteed fallback so state (and the alarm) still catches up
    // within a few seconds even if a broadcast is missed entirely.
    _pollTimer = Timer.periodic(
        const Duration(seconds: 4), (_) => refreshPairedDevices());
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> refreshPairedDevices() async {
    final latest = await _service.getPairedAudioDevices();
    final previous = pairedDevices;
    pairedDevices = latest;
    notifyListeners();

    for (final device in latest) {
      final wasConnected = previous
          .where((d) => d.address == device.address)
          .any((d) => d.connected);
      if (!device.connected && wasConnected && isWatched(device.address)) {
        _triggerAlarm(device.name);
      }
    }
  }

  bool isWatched(String address) =>
      settingsService.isClassicDeviceWatched(address);

  void setWatched(String address, bool watched) {
    settingsService.setClassicDeviceWatched(address, watched);
  }

  void _onEvent(ClassicBluetoothEvent event) {
    final index = pairedDevices.indexWhere((d) => d.address == event.address);
    final wasConnected = index != -1 ? pairedDevices[index].connected : false;

    final updated = ClassicDevice(
      address: event.address,
      name: event.name,
      connected: event.connected,
    );
    if (index != -1) {
      pairedDevices = [...pairedDevices]..[index] = updated;
    } else {
      pairedDevices = [...pairedDevices, updated];
    }
    notifyListeners();

    if (!event.connected && wasConnected && isWatched(event.address)) {
      _triggerAlarm(event.name);
    }
  }

  void _triggerAlarm(String deviceName) {
    if (alarmService.isPlaying) return;
    alarmService.setVolume(settingsService.volume);
    alarmService.play();
    onAlarmTriggered?.call(deviceName, AlarmReason.disconnected);
  }

  void stopAlarm() {
    alarmService.stop();
  }
}
