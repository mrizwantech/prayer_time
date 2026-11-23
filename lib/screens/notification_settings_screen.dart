import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/adhan_notification_service.dart';
import '../core/prayer_time_service.dart';
import '../presentation/widgets/app_header.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _permissionsGranted = false;
  bool _batteryOptimizationDisabled = true;
  bool _overlayPermissionGranted = true;
  bool _checking = true;

  static const platform = MethodChannel('com.mrizwantech.azanify/battery');

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _checking = true);
    try {
      final service = AdhanNotificationService();
      // Request will also check if already granted
      final granted = await service.requestPermissions();

      // Battery optimization and overlay permissions only exist on Android.
      bool batteryUnrestricted = true;
      bool overlayGranted = true;
      if (Platform.isAndroid) {
        batteryUnrestricted = false;
        try {
          batteryUnrestricted = await platform.invokeMethod('isIgnoringBatteryOptimizations');
        } catch (e) {
          debugPrint('Error checking battery optimization: $e');
        }
        overlayGranted = false;
        try {
          overlayGranted = await platform.invokeMethod('canDrawOverlays');
        } catch (e) {
          debugPrint('Error checking overlay permission: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _permissionsGranted = granted;
        _batteryOptimizationDisabled = batteryUnrestricted;
        _overlayPermissionGranted = overlayGranted;
        _checking = false;
      });
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _requestBatteryOptimization() async {
    try {
      await platform.invokeMethod('requestDisableBatteryOptimization');
      await Future.delayed(const Duration(seconds: 2));
      _checkPermissions();
    } catch (e) {
      debugPrint('Error requesting battery optimization: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please disable battery optimization manually in Settings')),
        );
      }
    }
  }

  bool get _allGood =>
      _permissionsGranted && _batteryOptimizationDisabled;

  @override
  Widget build(BuildContext context) {
    final prayerService = Provider.of<PrayerTimeService>(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              city: prayerService.city,
              state: prayerService.state,
              isLoading: prayerService.isLoading,
              showBackButton: true,
              showLocation: true,
            ),
            Expanded(
              child: _checking
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _statusCard(),
                          const SizedBox(height: 16),
                          if (Platform.isAndroid) ...[
                            const Text(
                              'Setup Checklist',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            _buildChecklistItem(
                              'Allow Notifications',
                              'Required to alert you at prayer times.',
                              Icons.notifications,
                              _permissionsGranted,
                            ),
                            _buildChecklistItem(
                              'Allow Exact Alarms',
                              'Ensures alerts arrive exactly on time.',
                              Icons.alarm,
                              _permissionsGranted,
                              action: _permissionsGranted
                                  ? null
                                  : () async {
                                      try {
                                        await platform.invokeMethod('openExactAlarmSettings');
                                      } catch (e) {
                                        _toast(
                                            'Go to Settings → Apps → Azanify → Alarms & Reminders → Allow');
                                      }
                                    },
                              actionLabel: 'Open Settings',
                            ),
                            _buildChecklistItem(
                              'Disable Battery Optimization',
                              'Prevents Android from blocking alerts while the phone sleeps.',
                              Icons.battery_charging_full,
                              _batteryOptimizationDisabled,
                              action: _batteryOptimizationDisabled ? null : _requestBatteryOptimization,
                              actionLabel: 'Disable',
                            ),
                            _buildChecklistItem(
                              'Display Over Other Apps (optional)',
                              'Only needed if the adhan screen fails to appear automatically.',
                              Icons.picture_in_picture,
                              _overlayPermissionGranted,
                              action: _overlayPermissionGranted
                                  ? null
                                  : () async {
                                      try {
                                        await platform.invokeMethod('requestOverlayPermission');
                                        await Future.delayed(const Duration(seconds: 2));
                                        _checkPermissions();
                                      } catch (e) {
                                        debugPrint('Error requesting overlay permission: $e');
                                      }
                                    },
                              actionLabel: 'Allow',
                            ),
                            const SizedBox(height: 16),
                          ],
                          // Developer-only tools; hidden in release builds
                          if (kDebugMode) _testCard(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard() {
    final theme = Theme.of(context);
    final color = _allGood ? Colors.green : Colors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _allGood ? Icons.check_circle : Icons.warning_amber_rounded,
              color: color,
              size: 40,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _allGood ? 'Notifications are set up' : 'Notifications need attention',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _allGood
                        ? 'You will receive prayer alerts reliably.'
                        : Platform.isAndroid
                            ? 'Complete the checklist below to receive prayer alerts.'
                            : 'Allow notifications for Azanify in iPhone Settings.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Re-check',
              icon: const Icon(Icons.refresh),
              onPressed: _checkPermissions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _testCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Test & Troubleshoot',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final service = AdhanNotificationService();
                await service.showImmediateNotification(
                  id: 999,
                  title: '🕌 Test Notification',
                  body: 'If you see this, notifications are working!',
                );
                _toast('✅ Test notification sent! Check your notification tray.');
              },
              icon: const Icon(Icons.send),
              label: const Text('Send test notification now'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final service = AdhanNotificationService();
                final testTime = DateTime.now().add(const Duration(seconds: 10));
                await service.schedulePrayerNotification(
                  id: 998,
                  prayerName: 'Test',
                  prayerTime: testTime,
                  nextPrayerTime: testTime.add(const Duration(hours: 1)),
                );
                _toast('⏰ Test prayer alert in 10 seconds — lock the phone and wait!');
              },
              icon: const Icon(Icons.alarm),
              label: const Text('Test prayer alert (10s)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final service = AdhanNotificationService();
                await service.scheduleAllPrayersForToday();
                _toast('🔄 Prayer alerts rescheduled.');
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reschedule all prayer alerts'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _showPendingNotifications,
              icon: const Icon(Icons.list_alt),
              label: const Text('View scheduled notifications'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPendingNotifications() async {
    final service = AdhanNotificationService();
    final pending = await service.getPendingNotifications();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pending Notifications (${pending.length})'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: pending.isEmpty
                ? [const Text('No pending notifications scheduled.\n\nNote: on iPhone, prayer alerts scheduled as alarms are not listed here.')]
                : pending
                    .map((n) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'ID ${n.id}: ${n.title}\n${n.payload ?? ""}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ))
                    .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
  }

  Widget _buildChecklistItem(
    String title,
    String description,
    IconData icon,
    bool completed, {
    VoidCallback? action,
    String? actionLabel,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          completed ? Icons.check_circle : icon,
          color: completed ? Colors.green : Colors.grey,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: action != null
            ? TextButton(onPressed: action, child: Text(actionLabel ?? 'Action'))
            : null,
      ),
    );
  }
}
