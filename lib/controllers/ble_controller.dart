import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../services/alarm_service.dart';
import '../services/settings_service.dart';

/// Owns all Bluetooth scanning/connection state and decides when the
/// alarm should fire: on an unintentional disconnect, or when a
/// connected device's signal weakens past the user's configured
/// distance threshold.
class BleController extends ChangeNotifier {
  BleController({required this.alarmService, required this.settingsService});

  final AlarmService alarmService;
  final SettingsService settingsService;

  List<ScanResult> scanResults = [];
  final List<BluetoothDevice> connectedDevices = [];
  final List<BluetoothDevice> previouslyConnectedDevices = [];

  /// Devices already connected at the OS/GATT level (by this or any other
  /// app) that this app hasn't attached a session to yet. Note this can
  /// only ever surface BLE (GATT) connections — a headphone connected via
  /// Classic Bluetooth (A2DP/HFP) is invisible to this API and to BLE
  /// scanning in general; that is a platform limitation, not something
  /// this app can work around.
  List<BluetoothDevice> systemDevices = [];

  final Set<String> _intentionalDisconnects = {};
  final Map<String, StreamSubscription<BluetoothConnectionState>>
      _connectionSubscriptions = {};
  final Map<String, Timer> _rssiTimers = {};

  bool isScanning = false;

  late final StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late final StreamSubscription<bool> _isScanningSubscription;

  /// Set by the UI layer to react whenever the alarm is freshly triggered.
  AlarmTriggeredCallback? onAlarmTriggered;

  void init() {
    _scanResultsSubscription =
        FlutterBluePlus.onScanResults.listen((results) {
      scanResults = results;
      notifyListeners();
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      isScanning = state;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    for (final sub in _connectionSubscriptions.values) {
      sub.cancel();
    }
    for (final timer in _rssiTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  bool isDeviceInRange(BluetoothDevice device) =>
      scanResults.any((r) => r.device.remoteId == device.remoteId);

  List<ScanResult> get inRangeResults => scanResults
      .where((r) =>
          !connectedDevices.any((d) => d.remoteId == r.device.remoteId))
      .toList();

  /// Devices already GATT-connected at the system level that this app
  /// hasn't attached to yet (i.e. not already in [connectedDevices]).
  List<BluetoothDevice> get attachableSystemDevices => systemDevices
      .where((d) => !connectedDevices.any((c) => c.remoteId == d.remoteId))
      .toList();

  /// Looks up devices already GATT-connected at the OS level (by this or
  /// any other app) so they can be shown even without a fresh scan
  /// discovering their advertisement. This will NOT find devices only
  /// connected via Classic Bluetooth (e.g. most audio headphones/earbuds
  /// using A2DP) — BLE scanning and GATT queries simply cannot see those.
  Future<void> refreshSystemDevices() async {
    try {
      // Empty service filter: on Android this returns all GATT-connected
      // devices; iOS requires at least one service UUID for privacy, so
      // this call intentionally can't surface anything there.
      systemDevices = await FlutterBluePlus.systemDevices([]);
      notifyListeners();
    } catch (e) {
      debugPrint('Read system devices failed: $e');
    }
  }

  Future<void> startScan() async {
    try {
      await refreshSystemDevices();
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Start scan failed: $e');
    }
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<void> connect(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    await device.connect();

    _intentionalDisconnects.remove(device.remoteId.toString());

    if (!connectedDevices.contains(device)) {
      connectedDevices.add(device);
    }
    previouslyConnectedDevices.remove(device);
    notifyListeners();

    _monitorConnection(device);
    _monitorRssi(device);
  }

  Future<void> disconnect(BluetoothDevice device) async {
    _intentionalDisconnects.add(device.remoteId.toString());
    _stopMonitoring(device);

    try {
      await device.disconnect();
      connectedDevices.remove(device);
      if (!previouslyConnectedDevices.contains(device)) {
        previouslyConnectedDevices.add(device);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Disconnection failed: $e');
    }
  }

  void _monitorConnection(BluetoothDevice device) {
    final id = device.remoteId.toString();
    if (_connectionSubscriptions.containsKey(id)) return;

    _connectionSubscriptions[id] = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        if (!_intentionalDisconnects.contains(id)) {
          _triggerAlarm(device, AlarmReason.disconnected);
        }

        connectedDevices.remove(device);
        if (!previouslyConnectedDevices.contains(device)) {
          previouslyConnectedDevices.add(device);
        }
        notifyListeners();

        _stopMonitoring(device);
      }
    });
  }

  void _monitorRssi(BluetoothDevice device) {
    final id = device.remoteId.toString();
    _rssiTimers[id]?.cancel();
    _rssiTimers[id] = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!connectedDevices.contains(device)) return;
      if (alarmService.isPlaying) return;
      try {
        final rssi = await device.readRssi();
        if (rssi < settingsService.rssiThreshold) {
          _triggerAlarm(device, AlarmReason.outOfRange);
        }
      } catch (e) {
        debugPrint('Read RSSI failed: $e');
      }
    });
  }

  void _stopMonitoring(BluetoothDevice device) {
    final id = device.remoteId.toString();
    _connectionSubscriptions[id]?.cancel();
    _connectionSubscriptions.remove(id);
    _rssiTimers[id]?.cancel();
    _rssiTimers.remove(id);
  }

  void _triggerAlarm(BluetoothDevice device, AlarmReason reason) {
    if (alarmService.isPlaying) return;
    alarmService.setVolume(settingsService.volume);
    alarmService.play();
    final name = device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.toString();
    onAlarmTriggered?.call(name, reason);
  }

  void stopAlarm() {
    alarmService.stop();
  }
}
