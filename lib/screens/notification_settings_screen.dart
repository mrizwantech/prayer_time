import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/adhan_notification_service.dart';
import '../core/prayer_time_service.dart';
import '../presentation/widgets/app_header.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _permissionsGranted = false;
  bool _batteryOptimizationDisabled = false;
  bool _overlayPermissionGranted = false;
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
      
      debugPrint('=== PERMISSION CHECK ===');
      debugPrint('Notification permission: $granted');
      
      // Check battery optimization status
      bool batteryUnrestricted = false;
      try {
        batteryUnrestricted = await platform.invokeMethod('isIgnoringBatteryOptimizations');
        debugPrint('Battery unrestricted: $batteryUnrestricted');
      } catch (e) {
        debugPrint('Error checking battery optimization: $e');
      }
      
      // Check overlay permission (optional; only needed if FSI fails)
      bool overlayGranted = false;
      try {
        overlayGranted = await platform.invokeMethod('canDrawOverlays');
        debugPrint('Overlay permission: $overlayGranted');
      } catch (e) {
        debugPrint('Error checking overlay permission: $e');
      }
      
      setState(() {
        _permissionsGranted = granted;
        _batteryOptimizationDisabled = batteryUnrestricted;
        _overlayPermissionGranted = overlayGranted;
        _checking = false;
      });
      
      debugPrint('=== PERMISSION STATUS ===');
      debugPrint('All permissions granted: $_permissionsGranted');
      debugPrint('Battery unrestricted: $_batteryOptimizationDisabled');
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      setState(() => _checking = false);
    }
  }

  Future<void> _requestBatteryOptimization() async {
    try {
      await platform.invokeMethod('requestIgnoreBatteryOptimizations');
      // Wait a bit for user to complete the action, then recheck
      await Future.delayed(Duration(seconds: 2));
      _checkPermissions();
    } catch (e) {
      debugPrint('Error requesting battery optimization: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please disable battery optimization manually in Settings')),
        );
      }
    }
  }

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
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Permission Status
                    if (!_permissionsGranted || !_batteryOptimizationDisabled) ...[
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red.shade700,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'App May Not Work Properly',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade900,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Some permissions are missing. Without them:\n'
                                '• You may not receive prayer time alerts\n'
                                '• Notifications may be delayed or blocked\n'
                                '• Adhan player may not open automatically\n\n'
                                'Please enable the required permissions below. Overlay is optional and only needed if the adhan screen does not appear.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red.shade800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'All Set! ✅',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'All permissions are granted. You will receive prayer notifications reliably.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green.shade800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 24),

                    // Setup Instructions
                    Text(
                      'Setup Checklist',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),

                    _buildChecklistItem(
                      '1. Allow Notifications',
                      'Required to alert you when it\'s time for prayer. Without this, you won\'t receive any prayer reminders.',
                      Icons.notifications,
                      _permissionsGranted,
                    ),
                    _buildChecklistItem(
              '2. Allow Exact Alarms',
              'Ensures notifications arrive at the exact prayer time, not delayed by Android\'s battery saving.',
              Icons.alarm,
              _permissionsGranted,
              action: _permissionsGranted ? null : () async {
                // Open app settings for exact alarms
                try {
                  await platform.invokeMethod('openExactAlarmSettings');
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Go to Settings → Apps → Azanify → Alarms & Reminders → Allow')),
                    );
                  }
                }
              },
              actionLabel: 'Open Settings',
            ),
            _buildChecklistItem(
              '3. Disable Battery Optimization',
              'Prevents Android from killing the app in background. Critical for reliable notifications when phone is asleep.',
              Icons.battery_charging_full,
              _batteryOptimizationDisabled,
              action: _batteryOptimizationDisabled ? null : () => _requestBatteryOptimization(),
              actionLabel: 'Disable',
            ),
                    _buildChecklistItem(
              '4. Keep App in Recent Apps',
              'Don\'t swipe away the app from recent apps list',
              Icons.apps,
              false,
            ),

            SizedBox(height: 16),

            Text(
              'Optional',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            _buildChecklistItem(
              'Display Over Other Apps (Optional)',
              'Only enable if the adhan screen fails to pop over other apps. It helps launch the adhan player on some devices.',
              Icons.picture_in_picture,
              _overlayPermissionGranted,
              action: _overlayPermissionGranted ? null : () async {
                try {
                  await platform.invokeMethod('requestOverlayPermission');
                  await Future.delayed(Duration(seconds: 2));
                  _checkPermissions();
                } catch (e) {
                  debugPrint('Error requesting overlay permission: $e');
                }
              },
              actionLabel: 'Allow',
            ),

            SizedBox(height: 24),
            
            // Test Notification Button
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.notifications_active, color: Colors.blue, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Test Notifications',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Send an immediate test notification',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final service = AdhanNotificationService();
                        // Send immediate notification (no scheduling)
                        await service.showImmediateNotification(
                          id: 999,
                          title: '🕌 Test Notification',
                          body: 'If you see this, notifications are working!',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ Test notification sent! Check your notification tray.'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.send),
                      label: Text('Send Test NOW'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final service = AdhanNotificationService();
                        final testTime = DateTime.now().add(Duration(seconds: 10));
                        await service.schedulePrayerNotification(
                          id: 998,
                          prayerName: 'Test',
                          prayerTime: testTime,
                          nextPrayerTime: testTime.add(Duration(hours: 1)),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('⏰ Scheduled test in 10 seconds. Wait for it!'),
                              duration: Duration(seconds: 5),
                            ),
                          );
                        }
                      },
                      icon: Icon(Icons.alarm),
                      label: Text('Test Scheduled (10s)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 24),
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade900),
                        SizedBox(width: 8),
                        Text(
                          'Important Tips',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildTip('Open the app at least once per day to refresh notifications'),
                    _buildTip('Make sure your phone is not in Do Not Disturb mode'),
                    _buildTip('Check that notification sound/vibration is enabled in phone settings'),
                    _buildTip('If you don\'t receive notifications, try rescheduling in Settings'),
                  ],
                ),
              ),
            ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          completed ? Icons.check_circle : icon,
          color: completed ? Colors.green : Colors.grey,
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
        trailing: action != null
            ? TextButton(
                onPressed: action,
                child: Text(actionLabel ?? 'Action'),
              )
            : null,
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontSize: 16, color: Colors.amber.shade900)),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(fontSize: 13, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }
}
