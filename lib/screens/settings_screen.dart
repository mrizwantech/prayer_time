import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/time_format_settings.dart';
import '../core/location_provider.dart';
import 'notification_settings_screen.dart';
import 'adhan_settings_screen.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import '../presentation/widgets/app_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<Map<String, DateTime>> _getQuickPrayerTimes() async {
    try {
      // Try to get last known position for instant load
      Position? position = await Geolocator.getLastKnownPosition();
      
      if (position != null) {
        final coordinates = Coordinates(position.latitude, position.longitude);
        final params = CalculationMethod.muslim_world_league.getParameters();
        final dateComponents = DateComponents.from(DateTime.now());
        final times = PrayerTimes(coordinates, dateComponents, params);
        
        return {
          'Fajr': times.fajr,
          'Sunrise': times.sunrise,
          'Dhuhr': times.dhuhr,
          'Asr': times.asr,
          'Maghrib': times.maghrib,
          'Isha': times.isha,
        };
      }
    } catch (e) {
      // Ignore errors and use defaults
    }
    
    // Return empty map - AdhanSettingsScreen will use defaults
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final timeFormatSettings = Provider.of<TimeFormatSettings>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              city: locationProvider.city,
              state: locationProvider.state,
              isLoading: locationProvider.isLoading,
              onRefresh: () => locationProvider.refreshLocation(),
              showLocation: true,
            ),
            Expanded(
              child: ListView(
                children: [
                  // Adhan Sound Settings
                  ListTile(
                    leading: Icon(Icons.music_note, color: Colors.deepPurple),
                    title: Text('Adhan & Sound'),
                    subtitle: Text('Configure prayer sounds and adhan'),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      // Get prayer times quickly before navigating
                      final prayerTimes = await _getQuickPrayerTimes();
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AdhanSettingsScreen(prayerTimes: prayerTimes),
                          ),
                        );
                      }
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
