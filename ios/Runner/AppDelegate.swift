import ActivityKit
import AlarmKit
import AppIntents
import AVFoundation
import Flutter
import SwiftUI
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by flutter_local_notifications to show alerts in the foreground and handle taps.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PrayerAlarmBridge") {
      PrayerAlarmBridge.shared.register(with: registrar.messenger())
    }
  }
}

/// Bridges AlarmKit (iOS 26+) to Dart so prayers can ring as full-screen alarms,
/// and hands "Open" taps from the alarm back to Dart to show the adhan screen.
final class PrayerAlarmBridge {
  static let shared = PrayerAlarmBridge()
  private static let pendingKey = "pending_adhan_launch"

  private var adhanChannel: FlutterMethodChannel?
  private var previewPlayer: AVAudioPlayer?
  private var dartReady = false

  func register(with messenger: FlutterBinaryMessenger) {
    let alarmChannel = FlutterMethodChannel(name: "com.mrizwantech.azanify/ios_alarm", binaryMessenger: messenger)
    alarmChannel.setMethodCallHandler { [weak self] call, result in
      self?.handleAlarmCall(call, result: result)
    }

    // Same channel Android uses, so Dart's existing adhan-launch handling works unchanged.
    let adhan = FlutterMethodChannel(name: "com.mrizwantech.azanify/adhan", binaryMessenger: messenger)
    adhan.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "Adhan bridge unavailable", details: nil))
        return
      }
      switch call.method {
      case "consumePendingAdhanLaunch":
        self.dartReady = true
        let defaults = UserDefaults.standard
        let pending = defaults.string(forKey: Self.pendingKey)
        defaults.removeObject(forKey: Self.pendingKey)
        result(pending)
      case "previewAdhan":
        guard
          let args = call.arguments as? [String: Any],
          let name = args["soundFile"] as? String,
          ["adhan_rabeh.caf", "adhan_sharqawe.caf"].contains(name),
          let url = Bundle.main.url(forResource: name, withExtension: nil)
        else {
          result(FlutterError(code: "bad_sound", message: "Preview sound is unavailable", details: nil))
          return
        }
        do {
          self.previewPlayer?.stop()
          self.previewPlayer = try AVAudioPlayer(contentsOf: url)
          let volume = (args["volume"] as? Double) ?? 1.0
          self.previewPlayer?.volume = Float(max(0.0, min(1.0, volume)))
          guard self.previewPlayer?.play() == true else {
            result(FlutterError(code: "preview_failed", message: "Could not play preview", details: nil))
            return
          }
          result(nil)
        } catch {
          result(FlutterError(code: "preview_failed", message: error.localizedDescription, details: nil))
        }
      case "stopPreview":
        self.previewPlayer?.stop()
        self.previewPlayer = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    adhanChannel = adhan
  }

  /// Called when the user taps "Open" on a ringing prayer alarm.
  func openAdhan(prayerName: String) {
    if dartReady, let channel = adhanChannel {
      channel.invokeMethod("launchAdhanPlayer", arguments: ["prayerName": prayerName])
    } else {
      // Cold start: Dart picks this up via consumePendingAdhanLaunch once it is running.
      UserDefaults.standard.set(prayerName, forKey: Self.pendingKey)
    }
  }

  private func handleAlarmCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *) else {
      result(call.method == "isAvailable" ? false : FlutterError(code: "unavailable", message: "AlarmKit needs iOS 26", details: nil))
      return
    }

    switch call.method {
    case "isAvailable":
      result(true)
    case "isAuthorized":
      result(AlarmManager.shared.authorizationState == .authorized)
    case "requestAuthorization":
      Task {
        let state = try? await AlarmManager.shared.requestAuthorization()
        await MainActor.run { result(state == .authorized) }
      }
    case "cancelAll":
      for alarm in (try? AlarmManager.shared.alarms) ?? [] {
        try? AlarmManager.shared.cancel(id: alarm.id)
      }
      result(nil)
    case "schedule":
      guard
        let args = call.arguments as? [String: Any],
        let prayerName = args["prayerName"] as? String,
        let title = args["title"] as? String,
        let millis = args["time"] as? NSNumber
      else {
        result(FlutterError(code: "bad_args", message: "prayerName, title and time are required", details: nil))
        return
      }
      let date = Date(timeIntervalSince1970: millis.doubleValue / 1000)
      let sound = args["sound"] as? String
      Task {
        do {
          try await Self.schedule(prayerName: prayerName, title: title, date: date, sound: sound)
          await MainActor.run { result(true) }
        } catch {
          await MainActor.run {
            result(FlutterError(code: "schedule_failed", message: "\(error)", details: nil))
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 26.0, *)
  private static func schedule(prayerName: String, title: String, date: Date, sound: String?) async throws {
    let openButton = AlarmButton(text: "Open", textColor: .white, systemImageName: "moon.stars.fill")
    let alertTitle = LocalizedStringResource(stringLiteral: title)
    let alert: AlarmPresentation.Alert
    if #available(iOS 26.1, *) {
      alert = AlarmPresentation.Alert(title: alertTitle, secondaryButton: openButton, secondaryButtonBehavior: .custom)
    } else {
      alert = AlarmPresentation.Alert(
        title: alertTitle,
        stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.circle"),
        secondaryButton: openButton,
        secondaryButtonBehavior: .custom
      )
    }
    let attributes = AlarmAttributes<PrayerAlarmMetadata>(
      presentation: AlarmPresentation(alert: alert),
      metadata: PrayerAlarmMetadata(prayerName: prayerName),
      tintColor: Color(red: 0, green: 0.85, blue: 0.65)
    )
    let configuration = AlarmManager.AlarmConfiguration<PrayerAlarmMetadata>.alarm(
      schedule: .fixed(date),
      attributes: attributes,
      secondaryIntent: OpenAdhanIntent(prayerName: prayerName),
      sound: sound.map { .named($0) } ?? .default
    )
    _ = try await AlarmManager.shared.schedule(id: UUID(), configuration: configuration)
  }
}

@available(iOS 26.0, *)
struct PrayerAlarmMetadata: AlarmMetadata {
  var prayerName: String
}

@available(iOS 26.0, *)
struct OpenAdhanIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Open Adhan"
  static var openAppWhenRun = true

  @Parameter(title: "Prayer")
  var prayerName: String

  init() {}

  init(prayerName: String) {
    self.prayerName = prayerName
  }

  func perform() async throws -> some IntentResult {
    let name = prayerName
    await MainActor.run { PrayerAlarmBridge.shared.openAdhan(prayerName: name) }
    return .result()
  }
}
