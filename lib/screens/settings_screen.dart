import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/ad_consent_service.dart';
import '../core/time_format_settings.dart';
import '../core/calculation_method_settings.dart';
import '../core/prayer_time_service.dart';
import '../core/app_theme_settings.dart';
import '../core/prayer_font_settings.dart';
import '../core/prayer_theme_provider.dart';
import '../core/ramadan_reminder_settings.dart';
import '../core/adhan_sound_service.dart';
import '../core/adhan_notification_service.dart';
import 'notification_settings_screen.dart';
import 'adhan_settings_screen.dart';
import 'monthly_calendar_screen.dart';
import '../presentation/widgets/app_header.dart';
import '../presentation/widgets/home_background.dart';

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
    final adConsent = context.watch<AdConsentService?>();

    return Scaffold(
      body: HomeBackground(
        child: SafeArea(
        child: Column(
          children: [
            AppHeader(
              city: prayerService.city,
              state: prayerService.state,
              isLoading: prayerService.isLoading,
              onRefresh: () => prayerService.refresh(),
              showLocation: true,
              overlayStyle: true,
            ),
            Expanded(
              child: Material(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.75),
                child: ListView(
                children: [
                  // Prayer Calculation Method (inline dropdown)
                  ExpansionTile(
                    leading: Icon(Icons.calculate, color: Colors.deepPurple),
                    title: const Text('Prayer Calculation Method'),
                    subtitle: Text(
                      calculationMethodSettings.selectedMethod?.displayName ?? 'Not selected',
                    ),
                    children: CalculationMethodOption.values.map((method) {
                      final isSelected =
                          calculationMethodSettings.selectedMethod == method;
                      final accentColor = Theme.of(context).colorScheme.primary;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected ? accentColor : null,
                        ),
                        title: Text(
                          method.displayName,
                          style: TextStyle(
                            color: isSelected ? accentColor : null,
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                        ),
                        subtitle: Text(method.description),
                        onTap: () => _applyCalculationMethod(
                          context,
                          calculationMethodSettings,
                          prayerService,
                          method,
                        ),
                      );
                    }).toList(),
                  ),
                  Divider(),

                  // Monthly Prayer Calendar (full-page view)
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

                  // Adhan Sound Settings (inline dropdown)
                  ExpansionTile(
                    leading: Icon(Icons.music_note, color: Colors.deepPurple),
                    title: const Text('Adhan & Sound'),
                    subtitle: const Text('Configure prayer sounds and adhan'),
                    children: const [
                      _AdhanSoundInlineSettings(),
                    ],
                  ),
                  Divider(),

                  // Notification Settings (device setup checks)
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

                  if (adConsent != null && adConsent.privacyOptionsRequired) ...[
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Ad privacy choices'),
                      subtitle: const Text('Review or change your ad consent'),
                      onTap: adConsent.busy
                          ? null
                          : () async {
                              final opened = await adConsent.showPrivacyOptions();
                              if (opened || !context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not open ad privacy choices. Please try again.'),
                                ),
                              );
                            },
                    ),
                    const Divider(),
                  ],

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

                  // Ramadan Reminders (inline dropdown)
                  ExpansionTile(
                    leading: const Icon(Icons.nightlight_round, color: Colors.amber),
                    title: const Text('Ramadan Reminders'),
                    subtitle: const Text('Suhoor repeats, Iftar alert'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildRamadanReminderOptions(context, ramadanSettings),
                      ),
                    ],
                  ),
                  Divider(),

                  // Theme Mode (inline dropdown)
                  ExpansionTile(
                    leading: Icon(themeSettings.themeModeIcon, color: Colors.deepPurple),
                    title: const Text('App Theme'),
                    subtitle: Text(themeSettings.themeModeDisplayName),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _applyCalculationMethod(
    BuildContext context,
    CalculationMethodSettings settings,
    PrayerTimeService prayerService,
    CalculationMethodOption method,
  ) async {
    if (settings.selectedMethod == method) return;

    await settings.setMethod(method);
    if (!context.mounted) return;

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
      child: Material(
        color: Colors.transparent,
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
              ? Icon(Icons.check_circle, color: accentColor)
              : null,
          onTap: () => themeSettings.setThemeMode(mode),
        ),
      ),
    );
  }

  Widget _buildRamadanReminderOptions(
    BuildContext context,
    RamadanReminderSettings settings,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              _intervalChip(context, settings, 5),
              const SizedBox(width: 8),
              _intervalChip(context, settings, 10),
              const SizedBox(width: 8),
              _intervalChip(context, settings, 15),
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

/// Inline Adhan & Sound options shown inside the settings ExpansionTile.
/// Lets the user pick Silent / Notification / Adhan per prayer, the adhan
/// voice, and volume without leaving the settings screen.
class _AdhanSoundInlineSettings extends StatefulWidget {
  const _AdhanSoundInlineSettings();

  @override
  State<_AdhanSoundInlineSettings> createState() => _AdhanSoundInlineSettingsState();
}

class _AdhanSoundInlineSettingsState extends State<_AdhanSoundInlineSettings> {
  final _soundService = AdhanSoundService();
  static const _prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

  bool _loading = true;
  String _selectedAdhan = 'Silent';
  List<String> _availableAdhans = [];
  double _adhanVolume = 1.0;
  final Map<String, PrayerSoundMode> _modes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final adhan = await _soundService.getSelectedAdhan();
    // Exclude 'fajr' adhan - it's reserved for Fajr prayer only
    final adhans = (await _soundService.getAvailableAdhans(excludeFajr: true))
        .where((name) => name != 'Silent')
        .toList();
    final volume = await _soundService.getAdhanVolume();
    final modes = <String, PrayerSoundMode>{};
    for (final prayer in _prayers) {
      modes[prayer] = await _soundService.getPrayerSoundMode(prayer);
    }
    if (!mounted) return;
    setState(() {
      _selectedAdhan = adhan;
      _availableAdhans = adhans;
      _adhanVolume = volume;
      _modes
        ..clear()
        ..addAll(modes);
      _loading = false;
    });
  }

  Future<void> _rescheduleIos() async {
    if (!Platform.isIOS) return;
    final service = context.read<PrayerTimeService>();
    if (!service.hasLocation) return;
    try {
      await AdhanNotificationService().rescheduleIosPrayerNotifications(
        latitude: service.latitude!,
        longitude: service.longitude!,
      );
    } catch (error) {
      debugPrint('Could not update prayer alerts: $error');
    }
  }

  Future<void> _setMode(String prayer, PrayerSoundMode mode) async {
    final previous = _modes[prayer];
    setState(() => _modes[prayer] = mode);
    try {
      await _soundService.setPrayerSoundMode(prayer, mode);
      await _rescheduleIos();
    } catch (error) {
      debugPrint('Could not save prayer sound: $error');
      if (mounted) {
        setState(() => _modes[prayer] = previous ?? PrayerSoundMode.defaultTone);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save the prayer sound setting.'),
        ));
      }
    }
  }

  Future<void> _setAdhanVoice(String adhan) async {
    setState(() => _selectedAdhan = adhan);
    await _soundService.setSelectedAdhan(adhan);
    await _soundService.stopPreview();
    await _rescheduleIos();
  }

  String _formatAdhanName(String name) {
    if (name == 'Silent') return name;
    return name
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final prayerService = Provider.of<PrayerTimeService>(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Per-prayer sound mode
          for (final prayer in _prayers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      prayer,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: SegmentedButton<PrayerSoundMode>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          padding: WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                        segments: const [
                          ButtonSegment(
                            value: PrayerSoundMode.silent,
                            label: Text('Silent'),
                          ),
                          ButtonSegment(
                            value: PrayerSoundMode.defaultTone,
                            label: Text('Notification'),
                          ),
                          ButtonSegment(
                            value: PrayerSoundMode.adhan,
                            label: Text('Adhan'),
                          ),
                        ],
                        selected: {_modes[prayer] ?? PrayerSoundMode.defaultTone},
                        onSelectionChanged: (selection) =>
                            _setMode(prayer, selection.first),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),

          // Adhan voice selection
          Row(
            children: [
              Icon(Icons.volume_up, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Adhan Voice')),
              DropdownButton<String>(
                value: _availableAdhans.contains(_selectedAdhan) ? _selectedAdhan : null,
                hint: const Text('Select'),
                underline: const SizedBox.shrink(),
                items: _availableAdhans
                    .map((adhan) => DropdownMenuItem(
                          value: adhan,
                          child: Text(_formatAdhanName(adhan)),
                        ))
                    .toList(),
                onChanged: (adhan) {
                  if (adhan != null) _setAdhanVoice(adhan);
                },
              ),
            ],
          ),

          // Adhan volume
          Row(
            children: [
              Icon(Icons.volume_down, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text('Volume'),
              Expanded(
                child: Slider(
                  value: _adhanVolume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: '${(_adhanVolume * 100).round()}%',
                  onChanged: (value) => setState(() => _adhanVolume = value),
                  onChangeEnd: (value) => _soundService.setAdhanVolume(value),
                ),
              ),
              Text('${(_adhanVolume * 100).round()}%'),
            ],
          ),

          // Advanced options (days, reminders, previews)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(Icons.tune, color: theme.colorScheme.primary, size: 20),
            title: const Text('Advanced adhan options'),
            subtitle: const Text('Days, reminders and previews'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
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
        ],
      ),
    );
  }
}
