import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/time_format_settings.dart';
import '../core/calculation_method_settings.dart';
import '../core/prayer_time_service.dart';
import '../core/app_theme_settings.dart';
import '../core/prayer_font_settings.dart';
import '../core/prayer_theme_provider.dart';
import '../core/ramadan_reminder_settings.dart';
import 'notification_settings_screen.dart';
import 'adhan_settings_screen.dart';
import 'calculation_method_screen.dart';
import 'monthly_calendar_screen.dart';
import '../presentation/widgets/app_header.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final timeFormatSettings = Provider.of<TimeFormatSettings>(context);
    final prayerService = Provider.of<PrayerTimeService>(context);
    final calculationMethodSettings = Provider.of<CalculationMethodSettings>(context);
    final themeSettings = Provider.of<AppThemeSettings>(context);
    final fontSettings = Provider.of<PrayerFontSettings>(context);
    final prayerThemeProvider = Provider.of<PrayerThemeProvider>(context);
    final ramadanSettings = Provider.of<RamadanReminderSettings>(context);
    
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

                  // Monthly Prayer Calendar
                  ListTile(
                    leading: Icon(Icons.calendar_month, color: Colors.deepPurple),
                    title: const Text('Monthly Prayer Calendar'),
                    subtitle: const Text('View dates with daily prayer times'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MonthlyCalendarScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(),

                  // Prayer Font Size
                  ListTile(
                    leading: Icon(Icons.format_size, color: Colors.deepPurple),
                    title: const Text('Prayer Font Size'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${(fontSettings.scale * 100).round()}%'),
                        Slider(
                          value: fontSettings.scale,
                          min: PrayerFontSettings.minScale,
                          max: PrayerFontSettings.maxScale,
                          divisions: 7,
                          label: '${(fontSettings.scale * 100).round()}%',
                          onChanged: (val) => fontSettings.setScale(val),
                        ),
                      ],
                    ),
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
                  Divider(),

                  // Ramadan Theme Preview
                  SwitchListTile(
                    title: const Text('Preview Ramadan Theme'),
                    subtitle: const Text('Force Ramadan visuals year-round'),
                    value: prayerThemeProvider.ramadanPreviewEnabled,
                    onChanged: (val) async => prayerThemeProvider.setRamadanPreview(val),
                  ),
                  Divider(),

                  // Ramadan Reminders
                  ListTile(
                    leading: const Icon(Icons.nightlight_round, color: Colors.amber),
                    title: const Text('Ramadan Reminders'),
                    subtitle: const Text('Suhoor repeats, Iftar alert'),
                    onTap: () => _showRamadanRemindersSheet(context, ramadanSettings),
                    trailing: const Icon(Icons.arrow_forward_ios),
                  ),
                  Divider(),
                  
                  // Theme Mode
                  ListTile(
                    leading: Icon(themeSettings.themeModeIcon, color: Colors.deepPurple),
                    title: const Text('App Theme'),
                    subtitle: Text(themeSettings.themeModeDisplayName),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showThemePicker(context, themeSettings),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showThemePicker(BuildContext context, AppThemeSettings themeSettings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Select Theme',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildThemeOption(
              context,
              themeSettings,
              AppThemeMode.light,
              Icons.light_mode,
              'Light',
              'Bright theme for daytime use',
            ),
            _buildThemeOption(
              context,
              themeSettings,
              AppThemeMode.dark,
              Icons.dark_mode,
              'Dark',
              'Dark theme for nighttime use',
            ),
            _buildThemeOption(
              context,
              themeSettings,
              AppThemeMode.system,
              Icons.brightness_auto,
              'System',
              'Follow device settings',
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
  
  Widget _buildThemeOption(
    BuildContext context,
    AppThemeSettings themeSettings,
    AppThemeMode mode,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final isSelected = themeSettings.themeMode == mode;
    final accentColor = Theme.of(context).colorScheme.primary;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? accentColor.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? accentColor : Colors.transparent,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? accentColor : Theme.of(context).iconTheme.color?.withOpacity(0.6),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? accentColor : null,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.white)
            : null,
        onTap: () {
          themeSettings.setThemeMode(mode);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showRamadanRemindersSheet(
    BuildContext context,
    RamadanReminderSettings settings,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: settings,
          builder: (_, __) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.nightlight_round, color: Colors.amber),
                      SizedBox(width: 8),
                      Text('Ramadan Reminders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Suhoor reminders'),
                    subtitle: const Text('Repeat until Fajr from 1 hour before'),
                    value: settings.suhoorEnabled,
                    onChanged: (val) => settings.setSuhoorEnabled(val),
                  ),
                  if (settings.suhoorEnabled) ...[
                    const SizedBox(height: 4),
                    const Text('Repeat every'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _intervalChip(ctx, settings, 5),
                        const SizedBox(width: 8),
                        _intervalChip(ctx, settings, 10),
                        const SizedBox(width: 8),
                        _intervalChip(ctx, settings, 15),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Start before Fajr'),
                        Text('${settings.suhoorStartMinutesBeforeFajr} min'),
                      ],
                    ),
                    Slider(
                      value: settings.suhoorStartMinutesBeforeFajr.toDouble(),
                      min: 30,
                      max: 90,
                      divisions: 12,
                      label: '${settings.suhoorStartMinutesBeforeFajr} min',
                      onChanged: (v) => settings.setSuhoorStartMinutesBeforeFajr(v.round()),
                    ),
                  ],
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Iftar alert'),
                    subtitle: Text('Single alert ${settings.iftarMinutesBeforeMaghrib} min before Maghrib'),
                    value: settings.iftarEnabled,
                    onChanged: (val) => settings.setIftarEnabled(val),
                  ),
                  if (settings.iftarEnabled) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Alert before Maghrib'),
                        Text('${settings.iftarMinutesBeforeMaghrib} min'),
                      ],
                    ),
                    Slider(
                      value: settings.iftarMinutesBeforeMaghrib.toDouble(),
                      min: 5,
                      max: 20,
                      divisions: 3,
                      label: '${settings.iftarMinutesBeforeMaghrib} min',
                      onChanged: (v) => settings.setIftarMinutesBeforeMaghrib(v.round()),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _intervalChip(BuildContext ctx, RamadanReminderSettings settings, int minutes) {
    final selected = settings.suhoorIntervalMinutes == minutes;
    final color = Theme.of(ctx).colorScheme.primary;
    return ChoiceChip(
      label: Text('$minutes min'),
      selected: selected,
      selectedColor: color.withOpacity(0.15),
      labelStyle: TextStyle(color: selected ? color : null),
      onSelected: (_) => settings.setSuhoorIntervalMinutes(minutes),
    );
  }
}
