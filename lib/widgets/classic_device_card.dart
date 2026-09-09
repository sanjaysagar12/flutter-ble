import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A card for a paired Classic Bluetooth audio device (headphone, earbuds,
/// speaker). Unlike [DeviceCard] there's no "Connect" action - Classic
/// Bluetooth connections are managed by the OS, not this app - only a
/// toggle for whether the alarm should watch this device for disconnects.
class ClassicDeviceCard extends StatelessWidget {
  const ClassicDeviceCard({
    super.key,
    required this.name,
    required this.address,
    required this.connected,
    required this.watched,
    required this.onWatchedChanged,
  });

  final String name;
  final String address;
  final bool connected;
  final bool watched;
  final ValueChanged<bool> onWatchedChanged;

  @override
  Widget build(BuildContext context) {
    final statusColor = connected ? Colors.green[600] : Colors.grey[500];

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
              color: (connected ? AppColors.primary : Colors.grey)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.headphones,
                color: connected ? AppColors.primary : Colors.grey, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${connected ? "Connected" : "Not connected"} · $address',
                  style: TextStyle(fontSize: 13, color: statusColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: watched,
                activeThumbColor: AppColors.primary,
                onChanged: onWatchedChanged,
              ),
              Text('Alarm',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }
}
