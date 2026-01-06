import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'screens/home_screen.dart';
import 'screens/qibla_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/adhan_player_screen.dart';
import 'screens/tasbeeh_screen.dart';
import 'features/prayer_tracker/prayer_tracker_screen.dart';
import 'package:provider/provider.dart';
import 'core/time_format_settings.dart';
import 'core/adhan_notification_service.dart';
import 'core/permission_manager.dart';
import 'core/location_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'presentation/widgets/app_header.dart';

// Global navigator key for navigation from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  
  // Initialize timezone database for notifications
  tz.initializeTimeZones();
  
  // Initialize notification service and check for notification launch
  final notificationService = AdhanNotificationService();
  await notificationService.initialize();
  
  // Check if app was launched by tapping a notification
  final notificationAppLaunchDetails = await notificationService.getNotificationAppLaunchDetails();
  String? initialPrayerName;
  
  debugPrint('=== CHECKING NOTIFICATION LAUNCH ===');
  debugPrint('Did notification launch app: ${notificationAppLaunchDetails?.didNotificationLaunchApp}');
  debugPrint('Notification response: ${notificationAppLaunchDetails?.notificationResponse}');
  
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
  
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => TimeFormatSettings()),
          ChangeNotifierProvider(create: (_) => LocationProvider()),
        ],
        child: MyApp(initialPrayerName: initialPrayerName),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  final String? initialPrayerName;
  
  const MyApp({super.key, this.initialPrayerName});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // Auto-launch adhan player if app was opened from notification
    if (widget.initialPrayerName != null) {
      debugPrint('🎵 App launched from notification for ${widget.initialPrayerName}');
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
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Islamic Prayer Times',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const MainNavigation(),
      routes: {
        '/adhan-player': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return AdhanPlayerScreen(prayerName: args['prayerName']);
        },
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int selectedIndex = 0;
  final List<Widget> screens = const [
    HomeScreen(),
    TasbeehScreen(),
    QiblaScreen(),
    PrayerTrackerScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Request all permissions on app launch
    _requestAllPermissions();
    // Initialize location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationProvider>(context, listen: false).initializeLocation();
    });
  }

  Future<void> _requestAllPermissions() async {
    final permissionManager = PermissionManager();
    
    // Request all permissions at once
    final allGranted = await permissionManager.requestAllPermissions();
    
    if (allGranted) {
      debugPrint('All permissions granted!');
      // Schedule all prayer notifications for today
      final notificationService = AdhanNotificationService();
      await notificationService.scheduleAllPrayersForToday();
      
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
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
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
                _buildPermissionItem(Icons.notifications, 'Notifications', 'To alert you at prayer times'),
                _buildPermissionItem(Icons.location_on, 'Location', 'To calculate accurate prayer times for your area'),
                _buildPermissionItem(Icons.alarm, 'Exact Alarms', 'To notify you at the precise prayer time'),
                SizedBox(height: 16),
                Text(
                  'Without these permissions, you will not receive prayer time notifications.',
                  style: TextStyle(fontSize: 13, color: Colors.red.shade700, fontWeight: FontWeight.w500),
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
      final isUnrestricted = await platform.invokeMethod('isIgnoringBatteryOptimizations');
      
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
                    await platform.invokeMethod('requestIgnoreBatteryOptimizations');
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
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
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
    return Scaffold(
      body: screens[selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onItemTapped,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radio_button_checked),
            label: 'Tasbeeh',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Qibla',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.track_changes),
            label: 'Tracker',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
