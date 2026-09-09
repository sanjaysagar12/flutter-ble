import 'package:flutter/material.dart';

import '../controllers/ble_controller.dart';
import '../controllers/classic_bluetooth_controller.dart';
import '../screens/home_page.dart';
import '../screens/settings_page.dart';
import '../services/alarm_service.dart';
import '../services/settings_service.dart';

/// Hosts the bottom navigation and keeps the Bluetooth/alarm state alive
/// across tab switches.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final SettingsService _settingsService = SettingsService();
  final AlarmService _alarmService = AlarmService();
  late final BleController _bleController = BleController(
    alarmService: _alarmService,
    settingsService: _settingsService,
  );
  late final ClassicBluetoothController _classicController =
      ClassicBluetoothController(
    alarmService: _alarmService,
    settingsService: _settingsService,
  );

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _bleController.init();
    _classicController.init();
    _settingsService.addListener(_syncVolume);
    _settingsService.load().then((_) => _syncVolume());
  }

  void _syncVolume() {
    _alarmService.setVolume(_settingsService.volume);
  }

  @override
  void dispose() {
    _settingsService.removeListener(_syncVolume);
    _bleController.dispose();
    _classicController.dispose();
    _alarmService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomePage(
            controller: _bleController,
            classicController: _classicController,
            alarmService: _alarmService,
          ),
          SettingsPage(
            settingsService: _settingsService,
            alarmService: _alarmService,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF5C79FF),
        unselectedItemColor: Colors.grey[400],
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded, size: 30), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined, size: 30),
              label: 'Settings'),
        ],
      ),
    );
  }
}
