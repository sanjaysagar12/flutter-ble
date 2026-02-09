import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZAlarmee',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FE), // Light background
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C79FF),
          primary: const Color(0xFF5C79FF),
          surface: const Color(0xFFF8F9FE),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F9FE),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Color(0xFF5C79FF),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.black87),
        ),
      ),
      home: const ZAlarmeeHomePage(),
    );
  }
}

class ZAlarmeeHomePage extends StatefulWidget {
  const ZAlarmeeHomePage({super.key});

  @override
  State<ZAlarmeeHomePage> createState() => _ZAlarmeeHomePageState();
}

class _ZAlarmeeHomePageState extends State<ZAlarmeeHomePage> {
  // Device Lists
  List<ScanResult> _scanResults = [];
  final List<BluetoothDevice> _connectedDevices = [];

  // Simulation for previously connected devices (persisted IDs in a real app)
  // For now, we'll just track devices we disconnect from during this session
  final List<BluetoothDevice> _previouslyConnectedDevices = [];

  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;

  @override
  void initState() {
    super.initState();
    _initPermissions();
    _initBluetooth();
  }

  Future<void> _initPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();

    if (statuses.values.every((status) => status.isGranted)) {
      // Permissions granted
    }
  }

  void _initBluetooth() {
    _scanResultsSubscription = FlutterBluePlus.onScanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results;
        });
      }
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      if (mounted) {
        setState(() {
          _isScanning = state;
        });
      }
    });
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      debugPrint("Start scan failed: $e");
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    try {
      await device.connect();
      setState(() {
        if (!_connectedDevices.contains(device)) {
          _connectedDevices.add(device);
        }
        if (_previouslyConnectedDevices.contains(device)) {
          _previouslyConnectedDevices.remove(device);
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Connection failed: $e")));
    }
  }

  Future<void> _disconnectFromDevice(BluetoothDevice device) async {
    try {
      await device.disconnect();
      setState(() {
        _connectedDevices.remove(device);
        if (!_previouslyConnectedDevices.contains(device)) {
          _previouslyConnectedDevices.add(device);
        }
      });
    } catch (e) {
      debugPrint("Disconnection failed: $e");
    }
  }

  void _navigateToDeviceDetails(BluetoothDevice device) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => DeviceDataPage(device: device),
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Filter scan results to exclude connected devices
    final inRangeDevices = _scanResults
        .where((r) =>
            !_connectedDevices.any((d) => d.remoteId == r.device.remoteId))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF5C79FF),
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
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (_connectedDevices.isNotEmpty) ...[
                  const SectionHeader(title: 'Connected Devices'),
                  ..._connectedDevices.map((d) => DeviceCard(
                        device: d,
                        isConnected: true,
                        onTap: () => _navigateToDeviceDetails(d),
                        onActionTap: () => _disconnectFromDevice(d),
                      )),
                  const SizedBox(height: 16),
                ],

                SectionHeader(
                    title:
                        'Devices in range (${_isScanning ? "Scanning..." : inRangeDevices.length})'),

                // 1. Scanning State -> Show Skeleton Loader
                if (_isScanning) ...[
                  // Show mixed content: existing devices if any + skeletons
                  ...inRangeDevices.map((r) => DeviceCard(
                        device: r.device,
                        rssi: r.rssi,
                        isConnected: false,
                        onTap: () => _connectToDevice(r.device),
                        onActionTap: () => _connectToDevice(r.device),
                      )),
                  // Add skeletons to indicate ongoing search
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
                              size: 80, color: Color(0xFF5C79FF)),
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
                        onTap: () => _connectToDevice(r.device),
                        onActionTap: () => _connectToDevice(r.device),
                      )),
                ],

                if (_previouslyConnectedDevices.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'Previously Connected'),
                  ..._previouslyConnectedDevices.map((d) => DeviceCard(
                        device: d,
                        isConnected: false,
                        onTap: () => _connectToDevice(d),
                        onActionTap: () => _connectToDevice(d),
                        isOffline: false,
                      )),
                ],

                const SizedBox(height: 100), // Space for bottom button
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed:
                _isScanning ? () => FlutterBluePlus.stopScan() : _startScan,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C79FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF5C79FF).withOpacity(0.4),
            ),
            child: _isScanning
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
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF5C79FF),
        unselectedItemColor: Colors.grey[400],
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded, size: 30), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined, size: 30), label: 'Settings'),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class DeviceCard extends StatelessWidget {
  final BluetoothDevice device;
  final int? rssi;
  final bool isConnected;
  final bool isOffline;
  final VoidCallback onTap;
  final VoidCallback onActionTap;

  const DeviceCard({
    super.key,
    required this.device,
    this.rssi,
    required this.isConnected,
    required this.onTap,
    required this.onActionTap,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    IconData deviceIcon = Icons.bluetooth;
    final name = device.platformName.toLowerCase();
    if (name.contains('bud') ||
        name.contains('headphone') ||
        name.contains('airpod')) {
      deviceIcon = Icons.headphones;
    } else if (name.contains('speaker') || name.contains('sound')) {
      deviceIcon = Icons.speaker;
    } else if (name.contains('watch') ||
        name.contains('band') ||
        name.contains('fit')) {
      deviceIcon = Icons.watch;
    }

    final iconColor = isConnected
        ? const Color(0xFF5C79FF)
        : (name.contains('speaker') ? Colors.redAccent : Colors.purpleAccent);

    // Fixed unused variable warning by effectively using the color in decoration logic directly
    // or we could just remove the variable if we were not using it.
    // Here we use iconColor.withOpacity(0.1) for background.

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(deviceIcon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.platformName.isNotEmpty
                            ? device.platformName
                            : "Unknown Device",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rssi != null ? "$rssi dBm" : device.remoteId.toString(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                    onPressed: onActionTap,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      isOffline
                          ? "Offline"
                          : (isConnected ? "Disconnect" : "Connect"),
                      style: TextStyle(
                        fontSize: 14,
                        color: isOffline
                            ? Colors.grey
                            : (isConnected
                                ? Colors.red[400]
                                : Colors.grey[600]),
                        fontWeight: FontWeight.w600,
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SkeletonDeviceCard extends StatefulWidget {
  const SkeletonDeviceCard({super.key});

  @override
  State<SkeletonDeviceCard> createState() => _SkeletonDeviceCardState();
}

class _SkeletonDeviceCardState extends State<SkeletonDeviceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.grey[200],
      end: Colors.grey[300],
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _colorAnimation.value,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _colorAnimation.value,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _colorAnimation.value,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 20,
                decoration: BoxDecoration(
                  color: _colorAnimation.value,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DeviceDataPage extends StatefulWidget {
  final BluetoothDevice device;
  const DeviceDataPage({super.key, required this.device});

  @override
  State<DeviceDataPage> createState() => _DeviceDataPageState();
}

class _DeviceDataPageState extends State<DeviceDataPage> {
  List<BluetoothService> _services = [];
  Map<Guid, List<int>> _readValues = {};

  @override
  void initState() {
    super.initState();
    _discoverServices();
  }

  Future<void> _discoverServices() async {
    try {
      _services = await widget.device.discoverServices();
      setState(() {});
    } catch (e) {
      debugPrint("Discover services failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _services.length,
        itemBuilder: (context, index) {
          final service = _services[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              title: Text("Service: ${service.uuid}",
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              children: service.characteristics
                  .map((c) => _buildCharacteristicTile(c))
                  .toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCharacteristicTile(BluetoothCharacteristic c) {
    return Column(
      children: [
        ListTile(
          title: Text(c.uuid.toString(), style: const TextStyle(fontSize: 12)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_readValues[c.uuid] != null)
                Text("Value: ${_readValues[c.uuid]}"),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.properties.read)
                    TextButton(
                        onPressed: () => _onRead(c), child: const Text("READ")),
                  if (c.properties.write)
                    TextButton(
                        onPressed: () => _onWrite(c),
                        child: const Text("WRITE")),
                  if (c.properties.notify)
                    TextButton(
                        onPressed: () => _onNotify(c),
                        child: const Text("NOTIFY")),
                ],
              )
            ],
          ),
        ),
        const Divider(),
      ],
    );
  }

  void _onRead(BluetoothCharacteristic c) async {
    try {
      final value = await c.read();
      setState(() {
        _readValues[c.uuid] = value;
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Read failed: $e")));
    }
  }

  void _onWrite(BluetoothCharacteristic c) async {
    await showDialog(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text("Write"),
            content: TextField(controller: controller),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () {
                    c.write(utf8.encode(controller.text));
                    Navigator.pop(context);
                  },
                  child: const Text("Send")),
            ],
          );
        });
  }

  void _onNotify(BluetoothCharacteristic c) async {
    try {
      await c.setNotifyValue(true);
      c.lastValueStream.listen((value) {
        setState(() {
          _readValues[c.uuid] = value;
        });
      });
    } catch (e) {
      debugPrint("Notify error: $e");
    }
  }
}
