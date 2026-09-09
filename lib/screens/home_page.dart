import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controllers/ble_controller.dart';
import '../controllers/classic_bluetooth_controller.dart';
import '../services/alarm_service.dart';
import '../theme/app_theme.dart';
import '../widgets/classic_device_card.dart';
import '../widgets/device_card.dart';
import '../widgets/section_header.dart';
import '../widgets/skeleton_device_card.dart';
import 'device_details_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.classicController,
    required this.alarmService,
  });

  final BleController controller;
  final ClassicBluetoothController classicController;
  final AlarmService alarmService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.onAlarmTriggered = _showAlarmDialog;
    widget.classicController.addListener(_onControllerChanged);
    widget.classicController.onAlarmTriggered = _showAlarmDialog;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    if (identical(widget.controller.onAlarmTriggered, _showAlarmDialog)) {
      widget.controller.onAlarmTriggered = null;
    }
    widget.classicController.removeListener(_onControllerChanged);
    if (identical(widget.classicController.onAlarmTriggered, _showAlarmDialog)) {
      widget.classicController.onAlarmTriggered = null;
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    await widget.controller.refreshSystemDevices();
  }

  Future<void> _connect(BluetoothDevice device) async {
    try {
      await widget.controller.connect(device);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Connection failed: $e")));
    }
  }

  void _showAlarmDialog(String deviceName, AlarmReason reason) {
    if (!mounted) return;
    final message = reason == AlarmReason.disconnected
        ? "$deviceName has disconnected unexpectedly."
        : "$deviceName is too far away.";

    showDialog(
      context: context,
      barrierDismissible: false, // User must tap Stop
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.red[50],
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Text("Device Disconnected!", style: TextStyle(color: Colors.red)),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 16)),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.alarmService.stop();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.stop_circle_outlined,
                    color: Colors.white),
                label: const Text("STOP ALARM",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          ],
        );
      },
    );
  }

  void _navigateToDeviceDetails(BluetoothDevice device) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => DeviceDataPage(device: device),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final inRangeDevices = controller.inRangeResults;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('ZAlarmee'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 28),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          if (controller.connectedDevices.isNotEmpty) ...[
            const SectionHeader(title: 'Connected Devices'),
            ...controller.connectedDevices.map((d) => DeviceCard(
                  device: d,
                  isConnected: true,
                  onTap: () => _navigateToDeviceDetails(d),
                  onActionTap: () => controller.disconnect(d),
                )),
            const SizedBox(height: 16),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionHeader(title: 'Headphones & Audio Devices'),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Refresh paired audio devices',
                onPressed: () => widget.classicController.refreshPairedDevices(),
              ),
            ],
          ),
          if (widget.classicController.pairedDevices.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'No paired audio devices found. Pair your headphone from '
                "Android's Bluetooth settings, then tap refresh.",
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[500], height: 1.4),
              ),
            ),
          ] else ...[
            ...widget.classicController.pairedDevices.map((d) => ClassicDeviceCard(
                  name: d.name,
                  address: d.address,
                  connected: d.connected,
                  watched: widget.classicController.isWatched(d.address),
                  onWatchedChanged: (v) =>
                      widget.classicController.setWatched(d.address, v),
                )),
            const SizedBox(height: 16),
          ],

          if (controller.attachableSystemDevices.isNotEmpty) ...[
            const SectionHeader(title: 'Connected Elsewhere'),
            ...controller.attachableSystemDevices.map((d) => DeviceCard(
                  device: d,
                  isConnected: false,
                  onTap: () => _connect(d),
                  onActionTap: () => _connect(d),
                )),
            const SizedBox(height: 16),
          ],

          SectionHeader(
              title:
                  'Devices in range (${controller.isScanning ? "Scanning..." : inRangeDevices.length})'),

          // 1. Scanning State -> Show Skeleton Loader
          if (controller.isScanning) ...[
            ...inRangeDevices.map((r) => DeviceCard(
                  device: r.device,
                  rssi: r.rssi,
                  isConnected: false,
                  onTap: () => _connect(r.device),
                  onActionTap: () => _connect(r.device),
                )),
            ...List.generate(3, (index) => const SkeletonDeviceCard()),
          ]
          // 2. Not Scanning & Empty -> Show "No Devices Found" UI
          else if (inRangeDevices.isEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40.0, bottom: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.bluetooth_disabled_rounded,
                        size: 80, color: AppColors.primary),
                    const SizedBox(height: 16),
                    const Text(
                      "No Devices Found",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        "Tap the 'Scan for devices' button to discover connected devices",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]
          // 3. Not Scanning & Has Devices -> Show List
          else ...[
            ...inRangeDevices.map((r) => DeviceCard(
                  device: r.device,
                  rssi: r.rssi,
                  isConnected: false,
                  onTap: () => _connect(r.device),
                  onActionTap: () => _connect(r.device),
                )),
          ],

          if (controller.previouslyConnectedDevices.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionHeader(title: 'Previously Connected'),
            ...controller.previouslyConnectedDevices.map((d) {
              final inRange = controller.isDeviceInRange(d);
              return DeviceCard(
                device: d,
                isConnected: false,
                isOffline: !inRange,
                onTap: inRange ? () => _connect(d) : null,
                onActionTap: inRange ? () => _connect(d) : null,
              );
            }),
          ],

          const SizedBox(height: 100), // Space for bottom button
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: controller.isScanning
                ? () => controller.stopScan()
                : () => controller.startScan(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
            child: controller.isScanning
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3)),
                        SizedBox(width: 12),
                        Text("Stop Scanning",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600))
                      ])
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bluetooth_searching,
                          color: Colors.white, size: 28),
                      SizedBox(width: 12),
                      Text("Scan for devices",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
