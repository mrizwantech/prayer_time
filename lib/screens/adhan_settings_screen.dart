import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../core/adhan_sound_service.dart';
import '../core/adhan_notification_service.dart';
import '../core/prayer_time_service.dart';
import '../presentation/widgets/app_header.dart';

class AdhanSettingsScreen extends StatefulWidget {
  final Map<String, DateTime>? prayerTimes;
  
  const AdhanSettingsScreen({super.key, this.prayerTimes});

  @override
  State<AdhanSettingsScreen> createState() => _AdhanSettingsScreenState();
}

class _AdhanSettingsScreenState extends State<AdhanSettingsScreen> {
  final _soundService = AdhanSoundService();
  
  String _selectedAdhan = 'Silent';
  List<String> _availableAdhans = ['Silent'];
  bool _loading = true;
  String? _currentlyPreviewing;
  
  // Prayer settings
  List<PrayerNotificationSetting> _prayerSettings = [];
  
  // Theme colors matching the app's dark theme
  static const _backgroundColor = Color(0xFF1a1d2e);
  static const _cardColor = Color(0xFF252836);
  static const _accentColor = Color(0xFF00D9A5);
  static const _textColor = Colors.white;
  static const _subtitleColor = Color(0xFF8F92A1);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final adhan = await _soundService.getSelectedAdhan();
    final adhans = await _soundService.getAvailableAdhans();
    
    // Use prayer times passed from parent or defaults
    Map<String, DateTime> prayerTimes;
    if (widget.prayerTimes != null && widget.prayerTimes!.isNotEmpty) {
      prayerTimes = widget.prayerTimes!;
    } else {
      // Fallback to defaults only if not passed
      final now = DateTime.now();
      prayerTimes = {
        'Fajr': DateTime(now.year, now.month, now.day, 5, 0),
        'Sunrise': DateTime(now.year, now.month, now.day, 6, 30),
        'Dhuhr': DateTime(now.year, now.month, now.day, 13, 15),
        'Asr': DateTime(now.year, now.month, now.day, 17, 0),
        'Maghrib': DateTime(now.year, now.month, now.day, 20, 0),
        'Isha': DateTime(now.year, now.month, now.day, 21, 30),
      };
    }
    
    // Load saved settings for each prayer
    List<PrayerNotificationSetting> settings = [];
    for (var entry in prayerTimes.entries) {
      final prayerName = entry.key;
      final prayerTime = entry.value;
      
      // Load enabled state
      final isEnabled = prefs.getBool('prayer_enabled_$prayerName') ?? 
          (prayerName != 'Sunrise'); // Sunrise off by default
      
      // Load selected days (default all days)
      final savedDays = prefs.getStringList('prayer_days_$prayerName');
      List<bool> days;
      if (savedDays != null) {
        days = savedDays.map((d) => d == 'true').toList();
      } else {
        days = List.filled(7, true);
      }
      
      // Load offset minutes (how many minutes before prayer time)
      final offsetMinutes = prefs.getInt('prayer_offset_$prayerName') ?? 0;
      
      settings.add(PrayerNotificationSetting(
        name: prayerName,
        time: prayerTime,
        isEnabled: isEnabled,
        selectedDays: days,
        offsetMinutes: offsetMinutes,
      ));
    }
    
    if (mounted) {
      setState(() {
        _selectedAdhan = adhan;
        _availableAdhans = adhans;
        _prayerSettings = settings;
        _loading = false;
      });
    }
  }
  
  Future<void> _savePrayerSetting(PrayerNotificationSetting setting) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayer_enabled_${setting.name}', setting.isEnabled);
    await prefs.setStringList(
      'prayer_days_${setting.name}',
      setting.selectedDays.map((d) => d.toString()).toList(),
    );
    await prefs.setInt('prayer_offset_${setting.name}', setting.offsetMinutes);
    
    // Update notification service
    await _soundService.setSoundEnabled(setting.name, setting.isEnabled);
  }

  @override
  void dispose() {
    _soundService.stopPreview();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    int hour = time.hour % 12;
    if (hour == 0) hour = 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  
  String _formatPeriod(DateTime time) {
    return time.hour >= 12 ? 'PM' : 'AM';
  }

  IconData _getPrayerIcon(String prayerName) {
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        return FontAwesomeIcons.cloudSun;
      case 'sunrise':
        return FontAwesomeIcons.sun;
      case 'dhuhr':
        return FontAwesomeIcons.sun;
      case 'asr':
        return FontAwesomeIcons.cloudSun;
      case 'maghrib':
        return FontAwesomeIcons.cloudMoon;
      case 'isha':
        return FontAwesomeIcons.moon;
      default:
        return FontAwesomeIcons.clock;
    }
  }

  void _showAdhanPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildAdhanPicker(),
    );
  }
  
  Widget _buildAdhanPicker() {
    return StatefulBuilder(
      builder: (context, setModalState) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaIcon(FontAwesomeIcons.music, color: _accentColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Select Adhan Sound',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ..._availableAdhans.map((adhan) {
              final isSelected = _selectedAdhan == adhan;
              final isPreviewing = _currentlyPreviewing == adhan;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _accentColor.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? _accentColor : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: ListTile(
                  leading: FaIcon(
                    adhan == 'Silent' ? FontAwesomeIcons.volumeXmark : FontAwesomeIcons.volumeHigh,
                    color: isSelected ? _accentColor : _subtitleColor,
                    size: 18,
                  ),
                  title: Text(
                    _formatAdhanName(adhan),
                    style: TextStyle(
                      color: isSelected ? _accentColor : _textColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: adhan != 'Silent'
                      ? IconButton(
                          icon: FaIcon(
                            isPreviewing ? FontAwesomeIcons.stop : FontAwesomeIcons.play,
                            color: _accentColor,
                            size: 16,
                          ),
                          onPressed: () async {
                            await _togglePreview(adhan);
                            setModalState(() {});
                            setState(() {});
                          },
                        )
                      : null,
                  onTap: () async {
                    await _soundService.setSelectedAdhan(adhan);
                    await _soundService.stopPreview();
                    setState(() {
                      _selectedAdhan = adhan;
                      _currentlyPreviewing = null;
                    });
                    Navigator.pop(context);
                  },
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  String _formatAdhanName(String name) {
    if (name == 'Silent') return name;
    return name.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  Future<void> _togglePreview(String adhan) async {
    if (_currentlyPreviewing == adhan) {
      await _soundService.stopPreview();
      if (mounted) setState(() => _currentlyPreviewing = null);
    } else {
      try {
        await _soundService.stopPreview();
        await _soundService.previewAdhan(adhan);
        if (mounted) setState(() => _currentlyPreviewing = adhan);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not play ${_formatAdhanName(adhan)}')),
          );
        }
      }
    }
  }

  void _showDayPicker(PrayerNotificationSetting setting, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildDayPicker(setting, index),
    );
  }

  Widget _buildDayPicker(PrayerNotificationSetting setting, int index) {
    final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    return StatefulBuilder(
      builder: (context, setModalState) => SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FaIcon(FontAwesomeIcons.calendarDays, color: _accentColor, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    '${setting.name} - Select Days',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ...List.generate(7, (dayIndex) {
                return CheckboxListTile(
                  value: setting.selectedDays[dayIndex],
                  onChanged: (value) {
                    setModalState(() {
                      setting.selectedDays[dayIndex] = value ?? false;
                    });
                    setState(() {
                      _prayerSettings[index] = setting;
                    });
                    _savePrayerSetting(setting);
                  },
                  title: Text(
                    dayNames[dayIndex],
                    style: TextStyle(color: _textColor),
                  ),
                  activeColor: _accentColor,
                  checkColor: _backgroundColor,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showOffsetPicker(PrayerNotificationSetting setting, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildOffsetPicker(setting, index),
    );
  }

  Widget _buildOffsetPicker(PrayerNotificationSetting setting, int index) {
    final offsets = [0, 5, 10, 15, 20, 30, 45, 60];
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.clock, color: _accentColor, size: 20),
              const SizedBox(width: 12),
              Text(
                '${setting.name} - Notification Time',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Notify before prayer time',
            style: TextStyle(color: _subtitleColor, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ...offsets.map((offset) {
            final isSelected = setting.offsetMinutes == offset;
            String label = offset == 0 
                ? 'At prayer time' 
                : '$offset minutes before';
            
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? _accentColor.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? _accentColor : Colors.transparent,
                ),
              ),
              child: ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? _accentColor : _textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected 
                    ? FaIcon(FontAwesomeIcons.check, color: _accentColor, size: 16)
                    : null,
                onTap: () {
                  setState(() {
                    setting.offsetMinutes = offset;
                    _prayerSettings[index] = setting;
                  });
                  _savePrayerSetting(setting);
                  Navigator.pop(context);
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prayerService = Provider.of<PrayerTimeService>(context);
    
    if (_loading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
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
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: _accentColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
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
              child: Column(
                children: [
                  // Current Adhan Selection Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: _showAdhanPicker,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _accentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: FaIcon(
                              _selectedAdhan == 'Silent' 
                                  ? FontAwesomeIcons.volumeXmark 
                                  : FontAwesomeIcons.volumeHigh,
                              color: _accentColor,
                              size: 20,
                            ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adhan Sound',
                          style: TextStyle(color: _subtitleColor, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatAdhanName(_selectedAdhan),
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FaIcon(FontAwesomeIcons.chevronRight, color: _subtitleColor, size: 14),
                ],
              ),
            ),
          ),
          
          // Prayer List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _prayerSettings.length,
              itemBuilder: (context, index) {
                return _buildPrayerCard(_prayerSettings[index], index);
              },
            ),
          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerCard(PrayerNotificationSetting setting, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Prayer name and time
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                setting.name,
                style: TextStyle(
                  color: _subtitleColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(setting.time),
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      _formatPeriod(setting.time),
                      style: TextStyle(
                        color: _subtitleColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const Spacer(),
          
          // Day selector
          GestureDetector(
            onTap: () => _showDayPicker(setting, index),
            child: _buildDaySelector(setting),
          ),
          
          const SizedBox(width: 16),
          
          // Bell icon
          GestureDetector(
            onTap: () {
              setState(() {
                setting.isEnabled = !setting.isEnabled;
                _prayerSettings[index] = setting;
              });
              _savePrayerSetting(setting);
            },
            child: FaIcon(
              setting.isEnabled ? FontAwesomeIcons.solidBell : FontAwesomeIcons.bellSlash,
              color: setting.isEnabled ? _accentColor : _subtitleColor,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector(PrayerNotificationSetting setting) {
    final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final today = DateTime.now().weekday % 7;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (index) {
        final isSelected = setting.selectedDays[index];
        final isToday = index == today;
        
        return Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isSelected && setting.isEnabled 
                ? _accentColor.withOpacity(0.2) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              days[index],
              style: TextStyle(
                color: isSelected && setting.isEnabled
                    ? _accentColor
                    : _subtitleColor.withOpacity(0.5),
                fontSize: 9,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class PrayerNotificationSetting {
  String name;
  DateTime time;
  bool isEnabled;
  List<bool> selectedDays;
  int offsetMinutes;
  
  PrayerNotificationSetting({
    required this.name,
    required this.time,
    this.isEnabled = true,
    List<bool>? selectedDays,
    this.offsetMinutes = 0,
  }) : selectedDays = selectedDays ?? List.filled(7, true);
}
