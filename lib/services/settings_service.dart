import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists user-adjustable alarm settings: the alarm volume and the
/// signal-strength (RSSI) threshold that defines "too far away".
class SettingsService extends ChangeNotifier {
  static const _volumeKey = 'alarm_volume';
  static const _rssiThresholdKey = 'alarm_rssi_threshold';
  static const _mutedClassicDevicesKey = 'muted_classic_devices';

  static const double minVolume = 0.0;
  static const double maxVolume = 1.0;
  static const double volumeStep = 0.1;

  // RSSI is negative dBm. Less negative (closer to 0) means the device
  // is closer; more negative means it is farther away.
  static const int minRssiThreshold = -100; // very far
  static const int maxRssiThreshold = -40; // very close
  static const int rssiStep = 5;

  double _volume = 1.0;
  int _rssiThreshold = -85;
  Set<String> _mutedClassicDevices = {};

  double get volume => _volume;
  int get rssiThreshold => _rssiThreshold;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble(_volumeKey) ?? _volume;
    _rssiThreshold = prefs.getInt(_rssiThresholdKey) ?? _rssiThreshold;
    _mutedClassicDevices =
        (prefs.getStringList(_mutedClassicDevicesKey) ?? []).toSet();
    notifyListeners();
  }

  /// Whether the alarm should fire when this Classic Bluetooth (address-
  /// identified) device disconnects. Devices are watched by default.
  bool isClassicDeviceWatched(String address) =>
      !_mutedClassicDevices.contains(address);

  Future<void> setClassicDeviceWatched(String address, bool watched) async {
    if (watched) {
      _mutedClassicDevices.remove(address);
    } else {
      _mutedClassicDevices.add(address);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _mutedClassicDevicesKey, _mutedClassicDevices.toList());
  }

  Future<void> setVolume(double value) async {
    final clamped = value.clamp(minVolume, maxVolume);
    _volume = double.parse(clamped.toStringAsFixed(2));
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, _volume);
  }

  Future<void> increaseVolume() => setVolume(_volume + volumeStep);
  Future<void> decreaseVolume() => setVolume(_volume - volumeStep);

  Future<void> setRssiThreshold(int value) async {
    _rssiThreshold = value.clamp(minRssiThreshold, maxRssiThreshold);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_rssiThresholdKey, _rssiThreshold);
  }

  /// Moves the trigger distance farther away (more negative RSSI) so the
  /// alarm becomes less sensitive to a weakening signal.
  Future<void> increaseDistance() => setRssiThreshold(_rssiThreshold - rssiStep);

  /// Moves the trigger distance closer (less negative RSSI) so the alarm
  /// fires sooner as the signal weakens.
  Future<void> decreaseDistance() => setRssiThreshold(_rssiThreshold + rssiStep);

  String get distanceLabel {
    if (_rssiThreshold >= -55) return 'Very Close';
    if (_rssiThreshold >= -70) return 'Close';
    if (_rssiThreshold >= -85) return 'Medium';
    if (_rssiThreshold >= -95) return 'Far';
    return 'Very Far';
  }
}
