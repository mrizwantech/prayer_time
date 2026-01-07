import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/time_format_settings.dart';
import '../core/calculation_method_settings.dart';
import '../core/prayer_time_service.dart';
import 'notification_settings_screen.dart';
import 'adhan_settings_screen.dart';
import 'calculation_method_screen.dart';
import '../presentation/widgets/app_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final timeFormatSettings = Provider.of<TimeFormatSettings>(context);
    final prayerService = Provider.of<PrayerTimeService>(context);
    final calculationMethodSettings = Provider.of<CalculationMethodSettings>(context);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              city: prayerService.city,
              state: prayerService.state,
              isLoading: prayerService.isLoading,
              onRefresh: () => prayerService.refresh(),
              showLocation: true,
            ),
            Expanded(
              child: ListView(
                children: [
                  // Prayer Calculation Method
                  ListTile(
                    leading: Icon(Icons.calculate, color: Colors.deepPurple),
                    title: Text('Prayer Calculation Method'),
                    subtitle: Text(
                      calculationMethodSettings.selectedMethod?.displayName ?? 'Not selected',
                    ),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CalculationMethodScreen(),
                        ),
                      );
                      
                      // If method was changed, reload prayer times
                      if (result == true && context.mounted) {
                        // Clear cache and reinitialize with new method
                        prayerService.clearCache();
                        debugPrint('🔄 Refreshing prayer times with new calculation method...');
                        
                        // Show a loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => PopScope(
                            canPop: false,
                            child: AlertDialog(
                              content: Row(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(width: 20),
                                  Text('Updating prayer times...'),
                                ],
                              ),
                            ),
                          ),
                        );
                        
                        // Refresh prayer times
                        await prayerService.refresh();
                        
                        // Close the loading dialog and show success
                        if (context.mounted) {
                          Navigator.of(context).pop(); // Close dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Prayer times updated with new calculation method'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  Divider(),
                  
                  // Adhan Sound Settings
                  ListTile(
                    leading: Icon(Icons.music_note, color: Colors.deepPurple),
                    title: Text('Adhan & Sound'),
                    subtitle: Text('Configure prayer sounds and adhan'),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      // Use prayer times from PrayerTimeService
                      final prayerTimes = <String, DateTime>{};
                      if (prayerService.hasPrayerTimes) {
                        prayerTimes['Fajr'] = prayerService.fajr!;
                        prayerTimes['Sunrise'] = prayerService.sunrise!;
                        prayerTimes['Dhuhr'] = prayerService.dhuhr!;
                        prayerTimes['Asr'] = prayerService.asr!;
                        prayerTimes['Maghrib'] = prayerService.maghrib!;
                        prayerTimes['Isha'] = prayerService.isha!;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdhanSettingsScreen(prayerTimes: prayerTimes),
                        ),
                      );
                    },
                  ),
                  Divider(),
                  
                  // Notification Settings
                  ListTile(
                    leading: Icon(Icons.notifications_active, color: Colors.deepPurple),
                    title: Text('Notification Setup'),
                    subtitle: Text('Ensure notifications work reliably'),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => NotificationSettingsScreen()),
                      );
                    },
                  ),
                  Divider(),
                  
                  // Time Format
                  SwitchListTile(
                    title: const Text('24-Hour Time Format'),
                    value: timeFormatSettings.is24Hour,
                    onChanged: (val) => timeFormatSettings.setFormat(val),
                    subtitle: Text(timeFormatSettings.is24Hour ? '24-hour' : '12-hour'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
