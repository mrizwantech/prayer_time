import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_prayer_times/core/ad_consent_service.dart';
import 'package:islamic_prayer_times/core/prayer_font_settings.dart';
import 'package:islamic_prayer_times/core/prayer_theme_provider.dart';
import 'package:islamic_prayer_times/core/prayer_time_service.dart';
import 'package:islamic_prayer_times/core/time_format_settings.dart';
import 'package:islamic_prayer_times/screens/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('rewarded ads wait for UMP and still require opt-in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var adCalls = 0;
    var initializeCalls = 0;
    var canRequestAds = true;
    final form = Completer<void>();
    final consent = AdConsentService(
      initializeAds: () async => initializeCalls++,
    );
    const channel = 'plugins.flutter.io/google_mobile_ads';
    const umpChannel = 'plugins.flutter.io/google_mobile_ads/ump';
    const codec = StandardMethodCodec();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMessageHandler(channel, (message) async {
      adCalls++;
      return const StandardMethodCodec().encodeSuccessEnvelope(null);
    });
    messenger.setMockMessageHandler(umpChannel, (message) async {
      // The update request carries a custom UMP parameter object. Only the
      // method name (the first encoded value) is needed by this mock.
      final method = const StandardMessageCodec().readValue(
        ReadBuffer(message!),
      );
      final result = switch (method) {
        'ConsentInformation#requestConsentInfoUpdate' => null,
        'UserMessagingPlatform#loadAndShowConsentFormIfRequired' =>
          await form.future.then((_) => null),
        'ConsentInformation#getPrivacyOptionsRequirementStatus' => 1,
        'ConsentInformation#canRequestAds' => canRequestAds,
        'UserMessagingPlatform#showPrivacyOptionsForm' => null,
        _ => throw StateError('Unexpected UMP call: $method'),
      };
      return codec.encodeSuccessEnvelope(result);
    });
    addTearDown(() {
      messenger.setMockMessageHandler(channel, null);
      messenger.setMockMessageHandler(umpChannel, null);
      consent.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: consent),
          ChangeNotifierProvider(create: (_) => PrayerTimeService()),
          ChangeNotifierProvider(create: (_) => PrayerThemeProvider()),
          ChangeNotifierProvider(create: (_) => PrayerFontSettings()),
          ChangeNotifierProvider(create: (_) => TimeFormatSettings()),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    final startup = consent.start();
    await tester.pump();
    expect(adCalls, 0);
    expect(initializeCalls, 0);
    form.complete();
    await tester.pumpAndSettle();
    await startup;
    await consent.start();
    expect(adCalls, 1);
    expect(initializeCalls, 1);
    expect(consent.privacyOptionsRequired, isTrue);
    await tester.tap(find.byTooltip('Dua Generator'));
    await tester.pumpAndSettle();
    expect(
      find.text('Watch a short ad to open the Dua Generator?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Open Dua Generator'), findsNothing);
    expect(adCalls, 1);

    // If UMP stops allowing requests after a privacy change, don't load or show.
    canRequestAds = false;
    final privacy = consent.showPrivacyOptions();
    await tester.pumpAndSettle();
    expect(await privacy, isTrue);
    await tester.tap(find.byTooltip('Dua Generator'));
    await tester.pump();
    expect(
      find.text('Rewarded ads are currently unavailable.'),
      findsOneWidget,
    );
    expect(adCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
