# islamic_prayer_times

A new Flutter project.

## AdMob release setup

Publish the applicable consent messages for both Azanify app entries in
**AdMob → Privacy & messaging** (including the European regulations message
if serving ads in the EEA, UK, or Switzerland). Add the app's privacy-policy
URL in AdMob when configuring the message. The app checks Google UMP at
startup before requesting ads. **Settings → Ad privacy choices** appears
when UMP requires it.

Debug and profile builds use Google's rewarded test ad units. Before release,
test a fresh install with UMP's test geography and confirm that the form works,
the ad is opt-in, and users can reopen the form from Settings when required.

## Prayer notification sounds

In Adhan & Sound, choose Default tone, Adhan, or Silent for each prayer.
Silent still displays a notification. Android uses its dedicated Fajr adhan;
other adhan alerts use the selected recording. The Android adhan volume slider
scales playback relative to the device's media volume. Default notification
tones use the device's notification volume.

On iOS, adhan alerts use the selected bundled short clip, including for Fajr.
iOS controls scheduled notification and alarm volume using device settings;
the app cannot set a separate volume for those alerts.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
