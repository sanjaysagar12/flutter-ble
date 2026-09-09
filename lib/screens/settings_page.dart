import 'package:flutter/material.dart';

import '../services/alarm_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.settingsService,
    required this.alarmService,
  });

  final SettingsService settingsService;
  final AlarmService alarmService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: settingsService,
        builder: (context, _) {
          final volumePercent = (settingsService.volume * 100).round();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SettingsCard(
                icon: Icons.volume_up_rounded,
                title: 'Alarm Volume',
                subtitle: '$volumePercent%',
                onDecrease: settingsService.volume > SettingsService.minVolume
                    ? settingsService.decreaseVolume
                    : null,
                onIncrease: settingsService.volume < SettingsService.maxVolume
                    ? settingsService.increaseVolume
                    : null,
                slider: Slider(
                  value: settingsService.volume,
                  min: SettingsService.minVolume,
                  max: SettingsService.maxVolume,
                  divisions: 10,
                  label: '$volumePercent%',
                  onChanged: settingsService.setVolume,
                ),
                trailing: TextButton.icon(
                  onPressed: () async {
                    await alarmService.setVolume(settingsService.volume);
                    await alarmService.play();
                    Future.delayed(const Duration(seconds: 2), alarmService.stop);
                  },
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Test'),
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                icon: Icons.social_distance_rounded,
                title: 'Alarm Distance',
                subtitle: settingsService.distanceLabel,
                onDecrease: settingsService.rssiThreshold <
                        SettingsService.maxRssiThreshold
                    ? settingsService.decreaseDistance
                    : null,
                onIncrease: settingsService.rssiThreshold >
                        SettingsService.minRssiThreshold
                    ? settingsService.increaseDistance
                    : null,
                slider: Slider(
                  value: settingsService.rssiThreshold.toDouble(),
                  min: SettingsService.minRssiThreshold.toDouble(),
                  max: SettingsService.maxRssiThreshold.toDouble(),
                  divisions: (SettingsService.maxRssiThreshold -
                          SettingsService.minRssiThreshold) ~/
                      SettingsService.rssiStep,
                  label: settingsService.distanceLabel,
                  onChanged: (v) => settingsService.setRssiThreshold(v.round()),
                ),
                helperText:
                    "The alarm also sounds if a connected device's signal "
                    'weakens beyond this range, even before it fully '
                    'disconnects. Move toward "Close" to trigger sooner, '
                    'or "Far" to allow more distance.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.slider,
    this.onDecrease,
    this.onIncrease,
    this.trailing,
    this.helperText,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget slider;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final Widget? trailing;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[500])),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: onDecrease,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppColors.primary,
              ),
              Expanded(child: slider),
              IconButton(
                onPressed: onIncrease,
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primary,
              ),
            ],
          ),
          if (helperText != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
              child: Text(
                helperText!,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[500], height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}
