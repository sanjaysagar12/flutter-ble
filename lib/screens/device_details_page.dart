import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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
