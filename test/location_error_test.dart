import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geocoding_platform_interface/geocoding_platform_interface.dart'
    as gpi;
import 'package:geolocator/geolocator.dart';
import 'package:islamic_prayer_times/core/prayer_time_service.dart';
import 'package:islamic_prayer_times/presentation/widgets/prayer_timeline.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class _FakeLocation extends GeolocatorPlatform {
  bool enabled = false;
  int checks = 0;
  Completer<bool>? serviceResult;
  Completer<Position>? positionResult;

  @override
  Future<bool> isLocationServiceEnabled() {
    checks++;
    return serviceResult?.future ?? Future.value(enabled);
  }

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) =>
      positionResult!.future;
}

class _FakeGeocodingFactory extends GeocodingPlatformFactory {
  @override
  gpi.Geocoding createGeocoding(GeocodingCreationParams params) =>
      _FakeGeocoding(params);
}

class _FakeGeocoding extends gpi.Geocoding {
  _FakeGeocoding(GeocodingCreationParams params) : super.implementation(params);

  @override
  Future<List<Placemark>> placemarkFromCoordinates(
    double latitude,
    double longitude, {
    Locale? locale,
  }) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GeolocatorPlatform originalLocation;
  late _FakeLocation location;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalLocation = GeolocatorPlatform.instance;
    location = _FakeLocation();
    GeolocatorPlatform.instance = location;
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalLocation;
  });

  testWidgets('location failure shows a message and can be retried', (
    tester,
  ) async {
    final service = PrayerTimeService();
    await service.initialize();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: service,
        child: const MaterialApp(home: Scaffold(body: PrayerTimeline())),
      ),
    );

    expect(find.text('Unable to get your location'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(location.checks, 2);
    expect(find.text('Unable to get your location'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    service.dispose();
  });

  testWidgets('location timeout stops loading and ignores a late result', (
    tester,
  ) async {
    final service = PrayerTimeService();
    location.serviceResult = Completer<bool>();
    location.positionResult = Completer<Position>();
    final initialization = service.initialize();

    await tester.pump(const Duration(seconds: 8));
    location.serviceResult!.complete(true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    await tester.pump();
    await initialization;
    expect(service.isLoading, isFalse);
    expect(service.locationUnavailable, isTrue);

    location.positionResult!.complete(
      Position(
        latitude: 40,
        longitude: -74,
        timestamp: DateTime.now(),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 1,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(service.hasLocation, isFalse);
    service.dispose();
  });

  testWidgets('stored coordinates are used when a fresh location fails', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final oldGeocoding = GeocodingPlatformFactory.instance;
    GeocodingPlatformFactory.instance = _FakeGeocodingFactory();
    addTearDown(() {
      if (oldGeocoding != null) GeocodingPlatformFactory.instance = oldGeocoding;
    });
    IOSFlutterLocalNotificationsPlugin.registerWith();
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.UTC);
    const notifications = MethodChannel(
      'dexterous.com/flutter/local_notifications',
    );
    const alarms = MethodChannel('com.mrizwantech.azanify/adhan_alarm');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notifications, (call) async {
      if (call.method == 'pendingNotificationRequests') return <Object>[];
      return null;
    });
    messenger.setMockMethodCallHandler(alarms, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(notifications, null);
      messenger.setMockMethodCallHandler(alarms, null);
    });
    SharedPreferences.setMockInitialValues({
      'latitude': 40.0,
      'longitude': -74.0,
    });
    location.enabled = true;
    location.positionResult = Completer<Position>();
    final service = PrayerTimeService();
    final initialization = service.initialize();
    await tester.pump();
    location.positionResult!.completeError(TimeoutException('GPS unavailable'));
    await tester.pump();
    await tester.pump();
    await initialization;
    expect(service.latitude, 40);
    expect(service.longitude, -74);
    expect(service.hasPrayerTimes, isTrue);
    expect(service.error, isNull);
    service.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
