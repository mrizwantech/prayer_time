import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_prayer_times/core/app_theme_settings.dart';
import 'package:islamic_prayer_times/core/calculation_method_settings.dart';
import 'package:islamic_prayer_times/core/prayer_font_settings.dart';
import 'package:islamic_prayer_times/core/prayer_theme_provider.dart';
import 'package:islamic_prayer_times/core/prayer_time_service.dart';
import 'package:islamic_prayer_times/core/ramadan_reminder_settings.dart';
import 'package:islamic_prayer_times/core/time_format_settings.dart';
import 'package:islamic_prayer_times/features/prayer_tracker/rakah_counter_screen.dart';
import 'package:islamic_prayer_times/presentation/widgets/home_background.dart';
import 'package:islamic_prayer_times/screens/settings_screen.dart';
import 'package:islamic_prayer_times/screens/tasbeeh_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child, ThemeData theme) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => PrayerTimeService()),
      ChangeNotifierProvider(create: (_) => PrayerThemeProvider()),
      ChangeNotifierProvider(create: (_) => TimeFormatSettings()),
      ChangeNotifierProvider(create: (_) => CalculationMethodSettings()),
      ChangeNotifierProvider(create: (_) => AppThemeSettings()),
      ChangeNotifierProvider(create: (_) => PrayerFontSettings()),
      ChangeNotifierProvider(create: (_) => RamadanReminderSettings()),
    ],
    child: MaterialApp(theme: theme, home: child),
  );
}

String _backgroundAsset(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(HomeBackground),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).image != null,
          ),
        )
        .first,
  );
  final decoration = container.decoration! as BoxDecoration;
  return (decoration.image!.image as AssetImage).assetName;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('background follows the active light and dark theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const HomeBackground(child: SizedBox.expand()),
        AppThemeSettings.lightTheme,
      ),
    );
    expect(_backgroundAsset(tester), 'assets/images/home_bg_light.png');

    await tester.pumpWidget(
      _app(
        const HomeBackground(child: SizedBox.expand()),
        AppThemeSettings.darkTheme,
      ),
    );
    await tester.pumpAndSettle();
    expect(_backgroundAsset(tester), 'assets/images/home_bg_dark.png');
  });

  testWidgets('rakat selection and counting work over the background', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const RakahCounterScreen(), AppThemeSettings.lightTheme),
    );
    await tester.pump();
    expect(_backgroundAsset(tester), 'assets/images/home_bg_light.png');
    await tester.tap(find.text('Fajr'));
    await tester.pump();
    await tester.tap(find.text('START'));
    await tester.pump();
    expect(find.text('0 of 2 Rakats'), findsOneWidget);
  });

  testWidgets('settings options still expand over the background', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const SettingsScreen(), AppThemeSettings.darkTheme),
    );
    await tester.pump();
    expect(_backgroundAsset(tester), 'assets/images/home_bg_dark.png');
    await tester.tap(find.text('Prayer Calculation Method'));
    await tester.pumpAndSettle();
    expect(find.text('Muslim World League'), findsOneWidget);
  });

  testWidgets('tasbeeh selector works over the background', (tester) async {
    const channel = MethodChannel('flutter_tts');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => 1,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });

    await tester.pumpWidget(
      _app(const TasbeehScreen(), AppThemeSettings.lightTheme),
    );
    await tester.pumpAndSettle();
    expect(_backgroundAsset(tester), 'assets/images/home_bg_light.png');
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alhamdulillah').last);
    await tester.pumpAndSettle();
    expect(find.text('All praise is due to Allah'), findsOneWidget);
  });
}
