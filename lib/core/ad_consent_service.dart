import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdConsentService extends ChangeNotifier {
  AdConsentService({Future<void> Function()? initializeAds})
    : _initializeAds = initializeAds ?? _startAdsSdk;

  final Future<void> Function() _initializeAds;
  Future<void>? _startup;
  bool _sdkInitialized = false;
  bool _disposed = false;
  bool _busy = false;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;

  bool get busy => _busy || _startup == null;
  bool get canRequestAds => _canRequestAds;
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  static Future<void> _startAdsSdk() async {
    await MobileAds.instance.initialize();
  }

  Future<void> start() => _startup ??= _updateConsent();

  Future<void> _updateConsent() async {
    _busy = true;
    try {
      final update = Completer<FormError?>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => update.complete(null),
        update.complete,
      );
      final updateError = await update.future;
      if (_disposed) return;
      if (updateError == null) {
        await ConsentForm.loadAndShowConsentFormIfRequired((error) {
          if (error != null) _logFormError('show consent form', error);
        });
      } else {
        _logFormError('update consent information', updateError);
      }
      // UMP may allow ads based on consent from an earlier session.
      await _refreshAdAvailability();
    } on PlatformException catch (error) {
      debugPrint('AdMob consent setup failed: $error');
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> showPrivacyOptions() async {
    if (busy || !_privacyOptionsRequired) return false;
    _busy = true;
    _canRequestAds = false;
    notifyListeners();
    var formSucceeded = true;
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error == null) return;
        formSucceeded = false;
        _logFormError('show privacy options', error);
      });
      await _refreshAdAvailability();
      return formSucceeded;
    } on PlatformException catch (error) {
      debugPrint('AdMob privacy options failed: $error');
      return false;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _refreshAdAvailability() async {
    if (_disposed) return;
    final info = ConsentInformation.instance;
    _privacyOptionsRequired =
        await info.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    if (_disposed) return;
    final allowed = await info.canRequestAds();
    if (_disposed || !allowed) return;
    if (!_sdkInitialized) {
      await _initializeAds();
      _sdkInitialized = true;
    }
    if (!_disposed) _canRequestAds = true;
  }

  static void _logFormError(String action, FormError error) {
    debugPrint(
      'AdMob could not $action (${error.errorCode}): ${error.message}',
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
