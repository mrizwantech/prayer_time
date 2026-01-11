import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/home_screen.dart';
import 'screens/qibla_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/adhan_player_screen.dart';
import 'screens/tasbeeh_screen.dart';
import 'screens/quran_screen.dart';
import 'screens/calculation_method_screen.dart';
import 'features/prayer_tracker/rakah_counter_screen.dart';
import 'package:provider/provider.dart';
import 'core/time_format_settings.dart';
import 'core/calculation_method_settings.dart';
import 'core/adhan_notification_service.dart';
import 'core/permission_manager.dart';
import 'core/prayer_time_service.dart';
import 'core/app_theme_settings.dart';
import 'core/prayer_font_settings.dart';
import 'core/prayer_theme_provider.dart';
import 'core/ramadan_reminder_settings.dart';
import 'package:timezone/data/latest.dart' as tz;

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Initialize timezone database for notifications
  tz.initializeTimeZones();

  // Initialize Google Mobile Ads early for rewarded support ad
  await MobileAds.instance.initialize();

  // Initialize notification service and check for notification launch
  final notificationService = AdhanNotificationService();
  await notificationService.initialize();

  // Check if app was launched by tapping a notification
  final notificationAppLaunchDetails = await notificationService
      .getNotificationAppLaunchDetails();
  String? initialPrayerName;

  debugPrint('=== CHECKING NOTIFICATION LAUNCH ===');
  debugPrint(
    'Did notification launch app: ${notificationAppLaunchDetails?.didNotificationLaunchApp}',
  );
  debugPrint(
    'Notification response: ${notificationAppLaunchDetails?.notificationResponse}',
  );

  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    debugPrint('✅ App WAS launched from notification!');
    final payload = notificationAppLaunchDetails?.notificationResponse?.payload;
    debugPrint('Notification payload: $payload');

    // Extract prayer name from payload
    if (payload != null && payload.isNotEmpty) {
      final parts = payload.split('|');
      if (parts.isNotEmpty) {
        initialPrayerName = parts[0];
        debugPrint('🎯 Will auto-launch adhan player for: $initialPrayerName');
      }
    } else {
      debugPrint('⚠️ Payload is null or empty');
    }
  } else {
    debugPrint('ℹ️ App was NOT launched from notification (normal launch)');
  }

  // Initialize calculation method settings
  final calculationMethodSettings = CalculationMethodSettings();
  await calculationMethodSettings.initialize();
  final isFirstTimeSetup = !calculationMethodSettings.hasSelectedMethod;

  // Initialize theme settings
  final appThemeSettings = AppThemeSettings();
  await appThemeSettings.initialize();

  // Create PrayerTimeService (single source of truth)
  final prayerTimeService = PrayerTimeService();
  prayerTimeService.setCalculationMethodSettings(calculationMethodSettings);

  // Ramadan reminders settings
  final ramadanReminderSettings = RamadanReminderSettings();
  await ramadanReminderSettings.load();
  prayerTimeService.setRamadanReminderSettings(ramadanReminderSettings);

  // Load prayer theme prefs (Ramadan preview toggle)
  final prayerThemeProvider = PrayerThemeProvider();
  await prayerThemeProvider.loadPrefs();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TimeFormatSettings()),
          ChangeNotifierProvider(create: (_) => PrayerFontSettings()),
          ChangeNotifierProvider.value(value: calculationMethodSettings),
          ChangeNotifierProvider.value(value: prayerTimeService),
          ChangeNotifierProvider.value(value: appThemeSettings),
          ChangeNotifierProvider.value(value: prayerThemeProvider),
          ChangeNotifierProvider.value(value: ramadanReminderSettings),
        ],
        child: MyApp(
          initialPrayerName: initialPrayerName,
          isFirstTimeSetup: isFirstTimeSetup,
        ),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final String? initialPrayerName;
  final bool isFirstTimeSetup;

  const MyApp({
    super.key,
    this.initialPrayerName,
    this.isFirstTimeSetup = false,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // Auto-launch adhan player if app was opened from notification
    if (widget.initialPrayerName != null) {
      debugPrint(
        '🎵 App launched from notification for ${widget.initialPrayerName}',
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('📱 Auto-launching adhan player screen');
        navigatorKey.currentState?.pushNamed(
          '/adhan-player',
          arguments: {'prayerName': widget.initialPrayerName!},
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = Provider.of<AppThemeSettings>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Islamic Prayer Times',
      darkTheme: AppThemeSettings.darkTheme,
      theme: AppThemeSettings.lightTheme,
      themeMode: themeSettings.flutterThemeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      initialRoute: '/',
      routes: {
        '/': (context) =>
            AppStartupScreen(isFirstTimeSetup: widget.isFirstTimeSetup),
        '/adhan-player': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return AdhanPlayerScreen(prayerName: args['prayerName']);
        },
        '/settings': (context) => SettingsScreen(),
      },
    );
  }
}

/// Startup screen that handles initialization flow
class AppStartupScreen extends StatefulWidget {
  final bool isFirstTimeSetup;

  const AppStartupScreen({super.key, required this.isFirstTimeSetup});

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  bool _showCalculationMethod = false;
  bool _isLoading = true;
  String _statusMessage = 'Initializing...';
  CalculationMethodSettings? _settings;
  Timer? _adhanWaitTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // If first time setup, show calculation method screen first
    if (widget.isFirstTimeSetup) {
      setState(() {
        _showCalculationMethod = true;
        _isLoading = false;
      });

      // Listen for when method is selected
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _settings = Provider.of<CalculationMethodSettings>(
          context,
          listen: false,
        );
        _settings?.addListener(_onMethodSelected);
      });
      return;
    }

    // Otherwise, proceed with initialization
    await _loadEverything();
  }

  void _onMethodSelected() {
    if (_settings != null &&
        _settings!.hasSelectedMethod &&
        _showCalculationMethod) {
      setState(() {
        _showCalculationMethod = false;
        _isLoading = true;
        _statusMessage = 'Getting permissions...';
      });
      _loadEverything();
    }
  }

  Future<void> _loadEverything() async {
    try {
      // Step 1: Request permissions
      setState(() {
        _statusMessage = 'Requesting permissions...';
      });

      final permissionManager = PermissionManager();
      await permissionManager.requestAllPermissions();

      // Step 2: Initialize PrayerTimeService (location + prayer times + notifications)
      setState(() {
        _statusMessage = 'Getting prayer times...';
      });

      final prayerTimeService = Provider.of<PrayerTimeService>(
        context,
        listen: false,
      );
      await prayerTimeService.initialize();

      // If an adhan launch is pending/active, stay put so we don't pop to home
      final notificationService = AdhanNotificationService();
      if (notificationService.isAdhanPlayerActive || notificationService.hasPendingAdhanLaunch) {
        _startAdhanWait();
        return;
      }

      // Step 3: Done - navigate to main screen
      _goToMain();
    } catch (e) {
      debugPrint('Error during startup: $e');
      // Still proceed to main screen even if there's an error
      _goToMain();
    }
  }

  void _startAdhanWait() {
    _adhanWaitTimer?.cancel();
    setState(() {
      _isLoading = true;
      _statusMessage = 'Waiting for adhan to finish...';
    });

    _adhanWaitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final notificationService = AdhanNotificationService();
      if (!notificationService.isAdhanPlayerActive && !notificationService.hasPendingAdhanLaunch) {
        timer.cancel();
        _goToMain();
      }
    });
  }

  void _goToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }

  @override
  void dispose() {
    _adhanWaitTimer?.cancel();
    _settings?.removeListener(_onMethodSelected);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    // Show calculation method screen if needed
    if (_showCalculationMethod) {
      return CalculationMethodScreen(isFirstTime: true);
    }

    // Show loading screen
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo/icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.mosque,
                size: 60,
                color: theme.brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            // App name
            Text(
              'Azanify',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 40),
            // Loading indicator
            CircularProgressIndicator(color: accentColor),
            const SizedBox(height: 20),
            // Status message
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wrapper to show calculation method selection on first launch
class FirstTimeSetupWrapper extends StatefulWidget {
  const FirstTimeSetupWrapper({super.key});

  @override
  State<FirstTimeSetupWrapper> createState() => _FirstTimeSetupWrapperState();
}

class _FirstTimeSetupWrapperState extends State<FirstTimeSetupWrapper> {
  bool _setupComplete = false;
  CalculationMethodSettings? _settings;

  @override
  Widget build(BuildContext context) {
    if (_setupComplete) {
      return const MainNavigation();
    }

    return CalculationMethodScreen(isFirstTime: true);
  }

  @override
  void initState() {
    super.initState();
    // Listen for when the calculation method is selected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settings = Provider.of<CalculationMethodSettings>(
        context,
        listen: false,
      );
      _settings?.addListener(_onMethodSelected);
      // Check if already selected (in case of hot reload)
      _onMethodSelected();
    });
  }

  void _onMethodSelected() {
    if (_settings != null && _settings!.hasSelectedMethod && !_setupComplete) {
      if (mounted) {
        setState(() {
          _setupComplete = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _settings?.removeListener(_onMethodSelected);
    super.dispose();
  }
}

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int selectedIndex = 0;
  final List<Widget> screens = const [
    HomeScreen(),
    QuranScreen(),
    TasbeehScreen(),
    QiblaScreen(),
    RakahCounterScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    // Request all permissions on app launch
    _requestAllPermissions();
  }

  Future<void> _requestAllPermissions() async {
    final permissionManager = PermissionManager();

    // Request all permissions at once
    final allGranted = await permissionManager.requestAllPermissions();

    if (allGranted) {
      debugPrint('All permissions granted!');
      // Note: Prayer notifications are already scheduled by PrayerTimeService
      // during initialization, so we don't need to schedule them again here.

      // Show overlay permission prompt first (most important for auto-launch)
      await _checkOverlayPermission();

      // Then show battery optimization prompt
      _checkBatteryOptimization();
    } else {
      debugPrint('Some permissions were not granted');
      // Show alert explaining why permissions are needed
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                SizedBox(width: 8),
                Expanded(child: Text('Permissions Required')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Azanify needs the following permissions to work properly:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 16),
                _buildPermissionItem(
                  Icons.notifications,
                  'Notifications',
                  'To alert you at prayer times',
                ),
                _buildPermissionItem(
                  Icons.location_on,
                  'Location',
                  'To calculate accurate prayer times for your area',
                ),
                _buildPermissionItem(
                  Icons.alarm,
                  'Exact Alarms',
                  'To notify you at the precise prayer time',
                ),
                SizedBox(height: 16),
                Text(
                  'Without these permissions, you will not receive prayer time notifications.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _requestAllPermissions(); // Try again
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: Text('Grant Permissions'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _checkOverlayPermission() async {
    try {
      const platform = MethodChannel('com.mrizwantech.azanify/battery');
      final canDrawOverlays = await platform.invokeMethod('canDrawOverlays');

      if (!canDrawOverlays && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.picture_in_picture, color: Colors.deepPurple),
                SizedBox(width: 8),
                Expanded(child: Text('Required Permission')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Display Over Other Apps',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'This permission is required to automatically show the Adhan player screen when prayer time arrives.\n\n'
                  'Without this permission, you will only hear the Adhan but won\'t see the player screen automatically.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Later'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await platform.invokeMethod('requestOverlayPermission');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: Text('Enable Now'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking overlay permission: $e');
    }
  }

  Future<void> _checkBatteryOptimization() async {
    try {
      const platform = MethodChannel('com.mrizwantech.azanify/battery');
      final isUnrestricted = await platform.invokeMethod(
        'isIgnoringBatteryOptimizations',
      );

      if (!isUnrestricted && mounted) {
        // Show dialog asking user to disable battery optimization
        Future.delayed(Duration(seconds: 1), () {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.battery_alert, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Important!'),
                ],
              ),
              content: Text(
                'To receive prayer notifications reliably, please disable battery optimization for this app.\n\n'
                'This ensures notifications work even when your phone is in sleep mode.',
                style: TextStyle(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Later'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await platform.invokeMethod(
                      'requestIgnoreBatteryOptimizations',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Allow'),
                ),
              ],
            ),
          );
        });
      }
    } catch (e) {
      debugPrint('Error checking battery optimization: $e');
    }
  }

  Widget _buildPermissionItem(IconData icon, String title, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.deepPurple),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async => false, // disable back navigation
      child: Scaffold(
        body: screens[selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: onItemTapped,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.5),
          type: BottomNavigationBarType.fixed,
          backgroundColor: theme.colorScheme.surface,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Quran'),
            BottomNavigationBarItem(
              icon: Icon(Icons.radio_button_checked),
              label: 'Tasbeeh',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Qibla'),
            BottomNavigationBarItem(
              icon: Icon(Icons.track_changes),
              label: 'RakatTracker',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
