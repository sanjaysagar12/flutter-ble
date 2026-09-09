import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    this.rssi,
    required this.isConnected,
    this.onTap,
    this.onActionTap,
    this.isOffline = false,
  });

  final BluetoothDevice device;
  final int? rssi;
  final bool isConnected;
  final bool isOffline;
  final VoidCallback? onTap;
  final VoidCallback? onActionTap;

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
                    color: iconColor.withOpacity(isOffline ? 0.06 : 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(deviceIcon,
                      color: isOffline ? Colors.grey : iconColor, size: 28),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isOffline ? Colors.grey[500] : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rssi != null
                            ? "${device.remoteId} · $rssi dBm"
                            : device.remoteId.toString(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: isOffline ? null : onActionTap,
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
                          : (isConnected ? Colors.red[400] : Colors.grey[600]),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
