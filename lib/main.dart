import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'screens/home_screen.dart';
import 'screens/qibla_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/achievements_screen.dart';
import 'package:provider/provider.dart';
import 'core/time_format_settings.dart';
import 'core/adhan_notification_service.dart';
import 'core/permission_manager.dart';
import 'package:timezone/data/latest.dart' as tz;

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
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    debugPrint('App launched from notification!');
    debugPrint('Notification response: ${notificationAppLaunchDetails?.notificationResponse}');
  }
  
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: ChangeNotifierProvider(
        create: (_) => TimeFormatSettings(),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Islamic Prayer Times',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const MainNavigation(),
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
    QiblaScreen(),
    AchievementsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Request all permissions on app launch
    _requestAllPermissions();
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
    } else {
      debugPrint('Some permissions were not granted');
    }
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
            icon: Icon(Icons.explore),
            label: 'Qibla',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Achievements',
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
