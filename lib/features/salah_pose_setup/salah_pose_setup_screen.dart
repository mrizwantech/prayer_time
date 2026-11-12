import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/prayer_time_service.dart';

class SalahPoseSetupScreen extends StatefulWidget {
  const SalahPoseSetupScreen({super.key});

  @override
  State<SalahPoseSetupScreen> createState() => _SalahPoseSetupScreenState();
}

class _SalahPoseSetupScreenState extends State<SalahPoseSetupScreen>
    with WidgetsBindingObserver {
  static const _background = Color(0xFF031711);
  static const _panel = Color(0xE609241B);
  static const _green = Color(0xFF39F27A);
  static const _muted = Color(0xFFB7C8C0);
  static const _stableFramesRequired = 8;
  static const _raisedHandsFramesRequired = 4;

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(),
  );
  final Map<DeviceOrientation, int> _deviceOrientations = const {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  CameraDescription? _selectedCamera;
  Pose? _pose;
  Size? _imageSize;
  InputImageRotation? _imageRotation;
  CameraLensDirection _lensDirection = CameraLensDirection.front;
  _FrameAssessment _assessment = const _FrameAssessment.searching();
  String? _cameraError;
  String _selectedPrayer = 'Dhuhr';
  bool _initializedPrayerSelection = false;
  bool _isProcessing = false;
  bool _isStarting = true;
  bool _canProcess = true;
  bool _isPaused = false;
  bool _framingConfirmed = false;
  bool _prayerStarted = false;
  bool _isFullView = false;
  bool _prayerComplete = false;
  int _stableReadyFrames = 0;
  int _raisedHandsFrames = 0;
  int _currentStepIndex = 0;
  int _completedRakats = 0;
  int _stageHoldFrames = 0;
  int _stageMissingFrames = 0;
  int _standingBaselineSamples = 0;
  double? _standingTiltBaseline;
  double? _standingDepthBaseline;
  double? _standingVerticalBaseline;
  double? _standingHipHingeBaseline;
  double? _standingHipYBaseline;
  double _shoulderHipKneeAngle = 180;
  double _hipHingeAngle = 0;
  double _backTiltAngle = 0;
  double _headBackAlignmentAngle = 0;
  double _lastKneeAngle = 180;
  double _lastHipAngle = 180;
  bool _hasKneeAngle = false;
  double _lastHeadTorsoRatio = 0;
  double _lastHeadY = -1;
  double _lastFootY = -1;
  double _lastHipY = -1;
  double _lastHeadFootGap = 1;
  double _lastHeadFootDistance = 1;
  _PrayerPosition? _candidatePosition;
  _PrayerPosition _detectedPosition = _PrayerPosition.unknown;
  DateTime _lastProcessedFrame = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastPoseDiagnosticAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _supportsPoseCamera => Platform.isAndroid || Platform.isIOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedPrayerSelection) return;
    _initializedPrayerSelection = true;
    final prayerTimeService = context.read<PrayerTimeService>();
    final currentPrayer = prayerTimeService.getCurrentPrayerName();
    if (['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'].contains(currentPrayer)) {
      _selectedPrayer = currentPrayer;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(WakelockPlus.enable());
    unawaited(ScreenBrightness.instance.setApplicationScreenBrightness(0.9));
    if (_supportsPoseCamera) {
      _initializeCamera();
    } else {
      _isStarting = false;
      _cameraError = 'Use an Android or iPhone device for camera tracking.';
    }
  }

  @override
  void dispose() {
    _canProcess = false;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WakelockPlus.disable());
    unawaited(ScreenBrightness.instance.resetApplicationScreenBrightness());
    unawaited(_stopCamera());
    unawaited(_poseDetector.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(WakelockPlus.enable());
      unawaited(ScreenBrightness.instance.setApplicationScreenBrightness(0.9));
    } else {
      unawaited(WakelockPlus.disable());
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _isStarting = true;
      _cameraError = null;
    });
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw CameraException('NoCamera', 'No camera is available.');
      }
      _selectedCamera ??= _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
      await _startCamera(_selectedCamera!);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = error.code.contains('Denied')
            ? 'Allow camera access to check your framing.'
            : 'The camera could not be started. Check camera access and try again.';
        _isStarting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'The camera could not be started. Try again.';
        _isStarting = false;
      });
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _cameraController = controller;
    _lensDirection = camera.lensDirection;
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    await controller.startImageStream(_processCameraImage);
    if (mounted) {
      setState(() => _isStarting = false);
    }
  }

  Future<void> _stopCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    if (controller == null) return;
    if (controller.value.isInitialized && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    final currentDirection = _selectedCamera?.lensDirection;
    final next = _cameras.firstWhere(
      (camera) => camera.lensDirection != currentDirection,
      orElse: () => _cameras.first,
    );
    setState(() {
      _isStarting = true;
      _isPaused = false;
      _isFullView = false;
      _pose = null;
      _assessment = const _FrameAssessment.searching();
      _framingConfirmed = false;
      _prayerStarted = false;
      _prayerComplete = false;
      _stableReadyFrames = 0;
      _raisedHandsFrames = 0;
      _currentStepIndex = 0;
      _completedRakats = 0;
      _stageHoldFrames = 0;
      _stageMissingFrames = 0;
      _standingBaselineSamples = 0;
      _standingTiltBaseline = null;
      _standingDepthBaseline = null;
      _standingVerticalBaseline = null;
      _standingHipHingeBaseline = null;
      _standingHipYBaseline = null;
      _candidatePosition = null;
      _detectedPosition = _PrayerPosition.unknown;
    });
    await _stopCamera();
    _selectedCamera = next;
    try {
      await _startCamera(next);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Could not switch cameras. Try again.';
        _isStarting = false;
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_canProcess || _isProcessing) return;
    final now = DateTime.now();
    if (now.difference(_lastProcessedFrame).inMilliseconds < 120) return;
    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;

    _lastProcessedFrame = now;
    _isProcessing = true;
    try {
      final poses = await _poseDetector.processImage(inputImage);
      if (!mounted || !_canProcess) return;
      final detectedPose = poses.isEmpty ? null : poses.first;
      final frameAssessment = _assessFrame(
        detectedPose,
        inputImage.metadata?.size,
        inputImage.metadata?.rotation,
      );
      if (!_framingConfirmed) {
        _stableReadyFrames = frameAssessment.isReady
            ? _stableReadyFrames + 1
            : 0;
        _framingConfirmed = _stableReadyFrames >= _stableFramesRequired;
      }
      final handsRaised =
          _framingConfirmed &&
          _isOpeningTakbirPose(
            detectedPose,
            inputImage.metadata?.size,
            inputImage.metadata?.rotation,
          );
      _raisedHandsFrames = handsRaised ? _raisedHandsFrames + 1 : 0;
      if (_raisedHandsFrames >= _raisedHandsFramesRequired) {
        if (!_prayerStarted) {
          _prayerStarted = true;
          _currentStepIndex = 0;
          _completedRakats = 0;
          _prayerComplete = false;
        }
      }
      final nextExpectedPosition =
          _prayerStarted && _currentStepIndex + 1 < _prayerStages.length
          ? _prayerStages[_currentStepIndex + 1].position
          : null;
      _detectedPosition = _framingConfirmed
          ? _positionForPose(
              detectedPose,
              inputImage.metadata?.size,
              inputImage.metadata?.rotation,
              expectedPosition: nextExpectedPosition,
            )
          : _PrayerPosition.unknown;
      if (_prayerStarted) _advancePrayerSequence(_detectedPosition);
      if (now.difference(_lastPoseDiagnosticAt) >= const Duration(seconds: 1)) {
        final poseStatus = _prayerStarted
            ? 'detected=${_detectedPosition.name} expected=${_activePrayerStage.label} '
                  'S-H-K=${_shoulderHipKneeAngle.round()} '
                  'hinge=${_hipHingeAngle.round()} back=${_backTiltAngle.round()} '
                  'headBack=${_headBackAlignmentAngle.round()} '
                  'H-K-A=${_lastKneeAngle.round()} hasKnee=$_hasKneeAngle '
                  'S-H-K=${_lastHipAngle.round()} '
                  'headY=${_lastHeadY.toStringAsFixed(2)} '
                  'headTorso=${_lastHeadTorsoRatio.toStringAsFixed(2)} '
                  'footY=${_lastFootY.toStringAsFixed(2)} '
                  'hipY=${_lastHipY.toStringAsFixed(2)} '
                  'headFootGap=${_lastHeadFootGap.toStringAsFixed(2)} '
                  'headFoot2d=${_lastHeadFootDistance.toStringAsFixed(2)} '
                  'rakat=${math.min(_completedRakats + 1, _rakatCount)}/$_rakatCount'
            : 'framingReady=${frameAssessment.isReady} '
                  'locked=$_framingConfirmed confidence=${frameAssessment.confidence.toStringAsFixed(2)} '
                  'head=${frameAssessment.hasHead} feet=${frameAssessment.hasFeet} '
                  'handsRaised=$handsRaised raisedFrames=$_raisedHandsFrames';
        debugPrint('[SalahPose] $poseStatus');
        _lastPoseDiagnosticAt = now;
      }
      setState(() {
        _pose = detectedPose;
        _imageSize = inputImage.metadata?.size;
        _imageRotation = inputImage.metadata?.rotation;
        _assessment = frameAssessment.withConfirmation(
          _framingConfirmed,
          prayerStarted: _prayerStarted,
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _assessment = const _FrameAssessment.searching(
            message: 'Hold still while the camera finds your full body.',
          );
          if (!_framingConfirmed) _stableReadyFrames = 0;
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  bool _isOpeningTakbirPose(
    Pose? pose,
    Size? imageSize,
    InputImageRotation? rotation,
  ) {
    if (pose == null || imageSize == null || rotation == null) return false;

    final head = _bestMovementLandmark(pose, const [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftEar,
      PoseLandmarkType.rightEar,
    ]);
    final leftShoulder = _movementLandmark(pose, PoseLandmarkType.leftShoulder);
    final rightShoulder = _movementLandmark(
      pose,
      PoseLandmarkType.rightShoulder,
    );
    final leftElbow = _movementLandmark(pose, PoseLandmarkType.leftElbow);
    final rightElbow = _movementLandmark(pose, PoseLandmarkType.rightElbow);
    final leftWrist = _movementLandmark(pose, PoseLandmarkType.leftWrist);
    final rightWrist = _movementLandmark(pose, PoseLandmarkType.rightWrist);
    if (head == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftWrist == null ||
        rightWrist == null) {
      return false;
    }

    final headPoint = _normalizedPoint(head, imageSize, rotation);
    final leftShoulderPoint = _normalizedPoint(
      leftShoulder,
      imageSize,
      rotation,
    );
    final rightShoulderPoint = _normalizedPoint(
      rightShoulder,
      imageSize,
      rotation,
    );
    final shoulderY = (leftShoulderPoint.dy + rightShoulderPoint.dy) / 2;
    final shoulderWidth = (leftShoulderPoint.dx - rightShoulderPoint.dx).abs();
    final headToShoulderHeight = (headPoint.dy - shoulderY).abs();
    final maxHeadOffsetX = math.max(shoulderWidth * 2.0, 0.08);
    final raisedHandHeight = math.max(headToShoulderHeight * 1.5, 0.10);

    bool wristRaisedNearHead(PoseLandmark wrist, PoseLandmark elbow) {
      final wristPoint = _normalizedPoint(wrist, imageSize, rotation);
      final elbowPoint = _normalizedPoint(elbow, imageSize, rotation);
      return (wristPoint.dx - headPoint.dx).abs() <= maxHeadOffsetX &&
          wristPoint.dy <= shoulderY + raisedHandHeight * 0.35 &&
          elbowPoint.dy <= shoulderY + raisedHandHeight;
    }

    return wristRaisedNearHead(leftWrist, leftElbow) &&
        wristRaisedNearHead(rightWrist, rightElbow);
  }

  int get _rakatCount => switch (_selectedPrayer) {
    'Fajr' => 2,
    'Maghrib' => 3,
    _ => 4,
  };

  List<_PrayerStage> get _prayerStages {
    final stages = <_PrayerStage>[];
    for (var rakat = 1; rakat <= _rakatCount; rakat++) {
      stages.addAll([
        _PrayerStage('Standing', 'Qiyam', _PrayerPosition.standing, rakat),
        _PrayerStage('Bowing', 'Ruku', _PrayerPosition.bowing, rakat),
        _PrayerStage('Standing', 'Qawmah', _PrayerPosition.standing, rakat),
        _PrayerStage(
          'First prostration',
          'Sujood 1',
          _PrayerPosition.prostration,
          rakat,
        ),
        _PrayerStage('Sitting', 'Jalsa', _PrayerPosition.sitting, rakat),
        _PrayerStage(
          'Second prostration',
          'Sujood 2',
          _PrayerPosition.prostration,
          rakat,
          completesRakat: true,
        ),
      ]);
      if (rakat.isEven || rakat == _rakatCount) {
        stages.add(
          _PrayerStage(
            'Sitting for Tashahhud',
            rakat == _rakatCount ? 'Final sitting' : 'Tashahhud',
            _PrayerPosition.sitting,
            rakat,
            isFinal: rakat == _rakatCount,
          ),
        );
      }
    }
    return stages;
  }

  _PrayerPosition _positionForPose(
    Pose? pose,
    Size? imageSize,
    InputImageRotation? rotation, {
    _PrayerPosition? expectedPosition,
  }) {
    if (pose == null || imageSize == null || rotation == null) {
      return _PrayerPosition.unknown;
    }
    final head = _bestMovementLandmark(pose, const [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftEar,
      PoseLandmarkType.rightEar,
    ]);
    final shoulders = _movementLandmarks(pose, const [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
    ]);
    final hips = _movementLandmarks(pose, const [
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ]);
    final expectedSujood = expectedPosition == _PrayerPosition.prostration;
    if (shoulders.isEmpty || hips.isEmpty) {
      return _PrayerPosition.unknown;
    }

    final shoulder = _averageMotionPoints(
      shoulders.map((landmark) => _motionPoint(landmark, imageSize, rotation)),
    );
    final hip = _averageMotionPoints(
      hips.map((landmark) => _motionPoint(landmark, imageSize, rotation)),
    );
    if (head == null) {
      final lowTorso = shoulder.y > 0.42 && hip.y > 0.48;
      final foldedTorso =
          (shoulder.y - hip.y).abs() < 0.18 ||
          (shoulder.z - hip.z).abs() > 0.045;
      return expectedSujood && lowTorso && foldedTorso
          ? _PrayerPosition.prostration
          : _PrayerPosition.unknown;
    }

    final headPoint = _motionPoint(head, imageSize, rotation);
    _lastHeadY = headPoint.y;
    final ankles = _movementLandmarks(pose, const [
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
    ]);
    final anklePoints = ankles
        .map((landmark) => _motionPoint(landmark, imageSize, rotation))
        .toList();
    final footLandmarks = _movementLandmarks(pose, const [
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftHeel,
      PoseLandmarkType.rightHeel,
      PoseLandmarkType.leftFootIndex,
      PoseLandmarkType.rightFootIndex,
    ]);
    final footPoints = footLandmarks
        .map((landmark) => _motionPoint(landmark, imageSize, rotation))
        .toList();
    final headFootDistance = footPoints.isEmpty
        ? 1.0
        : footPoints
              .map(
                (point) => math.sqrt(
                  math.pow(headPoint.x - point.x, 2) +
                      math.pow(headPoint.y - point.y, 2),
                ),
              )
              .reduce(math.min);
    final verticalHeadFootGap = footPoints.isEmpty
        ? 1.0
        : footPoints
              .map((point) => (headPoint.y - point.y).abs())
              .reduce(math.min);
    _lastFootY = footPoints.isEmpty
        ? -1
        : footPoints.map((point) => point.y).reduce(math.max);
    _lastHeadFootGap = verticalHeadFootGap;
    _lastHeadFootDistance = headFootDistance;
    _lastHipY = hip.y;
    final bodyHeight = anklePoints.isNotEmpty
        ? (anklePoints.map((point) => point.y).reduce((a, b) => a + b) /
                      anklePoints.length -
                  headPoint.y)
              .abs()
        : (hip.y - headPoint.y).abs() * 1.8;
    if (bodyHeight <= 0) return _PrayerPosition.unknown;

    final torsoX = shoulder.x - hip.x;
    final torsoY = shoulder.y - hip.y;
    final torsoZ = shoulder.z - hip.z;
    final torsoTilt =
        math.atan2(math.sqrt(torsoX * torsoX + torsoZ * torsoZ), torsoY.abs()) *
        180 /
        math.pi;
    final depthRatio = torsoZ.abs() / bodyHeight;
    final verticalRatio = torsoY.abs() / bodyHeight;
    _lastHeadTorsoRatio = (headPoint.y - shoulder.y).abs() / bodyHeight;
    final kneeAngles = <double>[];
    final hipAngles = <double>[];
    for (final side in const [
      (
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
      ),
      (
        PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle,
      ),
    ]) {
      final sideHip = _movementLandmark(pose, side.$1);
      final sideKnee = _movementLandmark(pose, side.$2);
      final sideAnkle = _movementLandmark(pose, side.$3);
      if (sideHip == null || sideKnee == null || sideAnkle == null) continue;
      final hipPoint = _motionPoint(sideHip, imageSize, rotation);
      final kneePoint = _motionPoint(sideKnee, imageSize, rotation);
      final anklePoint = _motionPoint(sideAnkle, imageSize, rotation);
      kneeAngles.add(_jointAngle3d(hipPoint, kneePoint, anklePoint));

      final shoulderType = side.$1 == PoseLandmarkType.leftHip
          ? PoseLandmarkType.leftShoulder
          : PoseLandmarkType.rightShoulder;
      final sideShoulder = _movementLandmark(pose, shoulderType);
      if (sideShoulder != null) {
        hipAngles.add(
          _jointAngle3d(
            _motionPoint(sideShoulder, imageSize, rotation),
            hipPoint,
            kneePoint,
          ),
        );
      }
    }
    final kneeAngle = kneeAngles.isEmpty
        ? 180.0
        : kneeAngles.reduce((a, b) => a + b) / kneeAngles.length;
    final hipAngle = hipAngles.isEmpty
        ? 180.0
        : hipAngles.reduce((a, b) => a + b) / hipAngles.length;
    _lastKneeAngle = kneeAngle;
    _hasKneeAngle = kneeAngles.isNotEmpty;
    _lastHipAngle = hipAngle;
    final hipHingeAngle = (180 - hipAngle).clamp(0.0, 180.0).toDouble();
    final headShoulderHipAngle = _jointAngle3d(headPoint, shoulder, hip);
    final headBackAlignmentAngle = (180 - headShoulderHipAngle).abs();
    _shoulderHipKneeAngle = hipAngle;
    _hipHingeAngle = hipHingeAngle;
    _backTiltAngle = torsoTilt;
    _headBackAlignmentAngle = headBackAlignmentAngle;

    final neutralStanding =
        torsoTilt < 35 &&
        depthRatio < 0.14 &&
        kneeAngle > 130 &&
        hipAngle > 120;
    if (!_prayerStarted &&
        _framingConfirmed &&
        neutralStanding &&
        _standingBaselineSamples < 30) {
      final nextSample = _standingBaselineSamples + 1;
      _standingTiltBaseline = _runningMean(
        _standingTiltBaseline,
        torsoTilt,
        nextSample,
      );
      _standingDepthBaseline = _runningMean(
        _standingDepthBaseline,
        depthRatio,
        nextSample,
      );
      _standingVerticalBaseline = _runningMean(
        _standingVerticalBaseline,
        verticalRatio,
        nextSample,
      );
      _standingHipHingeBaseline = _runningMean(
        _standingHipHingeBaseline,
        hipHingeAngle,
        nextSample,
      );
      _standingHipYBaseline = _runningMean(
        _standingHipYBaseline,
        hip.y,
        nextSample,
      );
      _standingBaselineSamples = nextSample;
    }

    final bowingTiltThreshold = math.max(
      18.0,
      (_standingTiltBaseline ?? 4.0) + 12.0,
    );
    final bowingDepthThreshold = math.max(
      0.045,
      (_standingDepthBaseline ?? 0.0) + 0.025,
    );
    final hipHingeThreshold = math.max(
      24.0,
      (_standingHipHingeBaseline ?? 0.0) + 20.0,
    );
    final compressedTorso =
        verticalRatio < (_standingVerticalBaseline ?? verticalRatio) * 0.72;

    final headBelowShoulders =
        headPoint.y > shoulder.y + math.max(bodyHeight * 0.035, 0.025);
    final headNearFloor = headPoint.y > 0.48 || hip.y > 0.58;
    final headBelowHip = headPoint.y > hip.y + bodyHeight * 0.02;
    final headNearFeet = headFootDistance < math.max(bodyHeight * 0.9, 0.16);
    final hipDroppedForSujood =
        _standingHipYBaseline != null &&
        hip.y > _standingHipYBaseline! + math.max(bodyHeight * 0.10, 0.06);
    final torsoFolded =
        torsoTilt > 22 || depthRatio > 0.055 || verticalRatio < 0.22;
    if (expectedSujood &&
        headNearFloor &&
        headNearFeet &&
        torsoFolded &&
        (hipDroppedForSujood || (_hasKneeAngle && kneeAngle < 110))) {
      return _PrayerPosition.prostration;
    }
    if (headBelowShoulders &&
        headNearFloor &&
        headBelowHip &&
        torsoFolded &&
        kneeAngle < 175) {
      return _PrayerPosition.prostration;
    }

    final headAlignedWithBack = headBackAlignmentAngle < 40;
    final clearHipHinge = hipHingeAngle > hipHingeThreshold;
    final expectedSitting = expectedPosition == _PrayerPosition.sitting;
    final hipLoweredFromStanding =
        _standingHipYBaseline != null &&
        hip.y > _standingHipYBaseline! + bodyHeight * 0.08;
    final seatedShape =
        torsoTilt < 60 &&
        hipLoweredFromStanding &&
        hip.y > shoulder.y &&
        (expectedSitting ||
            (_hasKneeAngle && kneeAngle < 145 && hipAngle < 160));
    if (seatedShape) return _PrayerPosition.sitting;

    if (clearHipHinge &&
        torsoTilt > bowingTiltThreshold &&
        headAlignedWithBack) {
      return _PrayerPosition.bowing;
    }
    if (headPoint.y > shoulder.y + bodyHeight * 0.025 &&
        hip.y < headPoint.y &&
        (torsoTilt > 28 || depthRatio > 0.10) &&
        kneeAngle < 170) {
      return _PrayerPosition.prostration;
    }
    if ((torsoTilt > bowingTiltThreshold ||
            depthRatio > bowingDepthThreshold ||
            compressedTorso ||
            hipHingeAngle > hipHingeThreshold) &&
        headAlignedWithBack) {
      return _PrayerPosition.bowing;
    }
    if (hipAngle > 135 && hipHingeAngle < hipHingeThreshold && torsoTilt < 38) {
      return _PrayerPosition.standing;
    }
    return _PrayerPosition.unknown;
  }

  PoseLandmark? _movementLandmark(Pose pose, PoseLandmarkType type) {
    final landmark = pose.landmarks[type];
    return landmark != null && landmark.likelihood >= 0.35 ? landmark : null;
  }

  List<PoseLandmark> _movementLandmarks(
    Pose pose,
    List<PoseLandmarkType> types,
  ) => types
      .map((type) => _movementLandmark(pose, type))
      .whereType<PoseLandmark>()
      .toList();

  PoseLandmark? _bestMovementLandmark(Pose pose, List<PoseLandmarkType> types) {
    final landmarks = _movementLandmarks(pose, types)
      ..sort((first, second) => second.likelihood.compareTo(first.likelihood));
    return landmarks.isEmpty ? null : landmarks.first;
  }

  _MotionPoint _motionPoint(
    PoseLandmark landmark,
    Size imageSize,
    InputImageRotation rotation,
  ) {
    final point = _normalizedPoint(landmark, imageSize, rotation);
    final depthScale = math.max(imageSize.width, imageSize.height).toDouble();
    return _MotionPoint(point.dx, point.dy, landmark.z / depthScale);
  }

  _MotionPoint _averageMotionPoints(Iterable<_MotionPoint> points) {
    final values = points.toList();
    return _MotionPoint(
      values.map((point) => point.x).reduce((a, b) => a + b) / values.length,
      values.map((point) => point.y).reduce((a, b) => a + b) / values.length,
      values.map((point) => point.z).reduce((a, b) => a + b) / values.length,
    );
  }

  void _advancePrayerSequence(_PrayerPosition position) {
    if (_isPaused || _prayerComplete) {
      return;
    }
    final stages = _prayerStages;
    final currentStage = stages[_currentStepIndex];
    if (currentStage.isFinal) return;
    final nextStage = stages[_currentStepIndex + 1];
    if (position == _PrayerPosition.unknown) {
      if (_candidatePosition == nextStage.position) {
        _stageMissingFrames++;
        if (_stageMissingFrames > 5) {
          _candidatePosition = null;
          _stageHoldFrames = 0;
          _stageMissingFrames = 0;
        }
      }
      return;
    }
    if (position != nextStage.position) {
      _candidatePosition = null;
      _stageHoldFrames = 0;
      _stageMissingFrames = 0;
      return;
    }
    if (_candidatePosition == position) {
      _stageHoldFrames++;
    } else {
      _candidatePosition = position;
      _stageHoldFrames = 1;
    }
    _stageMissingFrames = 0;
    final confirmationFrames = switch (position) {
      _PrayerPosition.prostration => 1,
      _PrayerPosition.sitting => 2,
      _ => _raisedHandsFramesRequired,
    };
    if (_stageHoldFrames < confirmationFrames) return;
    if (currentStage.completesRakat) _completedRakats++;
    _currentStepIndex++;
    _stageHoldFrames = 0;
    _stageMissingFrames = 0;
    _candidatePosition = null;
  }

  double _runningMean(double? current, double value, int sampleCount) =>
      ((current ?? 0) * (sampleCount - 1) + value) / sampleCount;

  void _resetPrayerProgress() {
    _isPaused = false;
    _isFullView = false;
    _prayerStarted = false;
    _prayerComplete = false;
    _raisedHandsFrames = 0;
    _currentStepIndex = 0;
    _completedRakats = 0;
    _stageHoldFrames = 0;
    _stageMissingFrames = 0;
    _candidatePosition = null;
    _detectedPosition = _PrayerPosition.unknown;
    _assessment = _assessment.withConfirmation(_framingConfirmed);
  }

  void _finishPrayer() {
    setState(() => _prayerComplete = true);
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _cameraController;
    final camera = _selectedCamera;
    if (controller == null || camera == null) return null;

    final int rotationDegrees;
    if (Platform.isIOS) {
      rotationDegrees = camera.sensorOrientation;
    } else {
      final compensation =
          _deviceOrientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      rotationDegrees = camera.lensDirection == CameraLensDirection.front
          ? (camera.sensorOrientation + compensation) % 360
          : (camera.sensorOrientation - compensation + 360) % 360;
    }

    final rotation = InputImageRotationValue.fromRawValue(rotationDegrees);
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.isEmpty) return null;
    final bytes = image.planes.length == 1
        ? image.planes.first.bytes
        : _joinPlanes(image.planes);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _joinPlanes(List<Plane> planes) {
    final length = planes.fold<int>(
      0,
      (total, plane) => total + plane.bytes.length,
    );
    final bytes = Uint8List(length);
    var offset = 0;
    for (final plane in planes) {
      bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return bytes;
  }

  _FrameAssessment _assessFrame(
    Pose? pose,
    Size? imageSize,
    InputImageRotation? rotation,
  ) {
    if (pose == null || imageSize == null || rotation == null) {
      return const _FrameAssessment.searching();
    }

    final head = _bestMovementLandmark(pose, const [
      PoseLandmarkType.nose,
      PoseLandmarkType.leftEar,
      PoseLandmarkType.rightEar,
      PoseLandmarkType.leftEye,
      PoseLandmarkType.rightEye,
    ]);
    final leftShoulder = _movementLandmark(pose, PoseLandmarkType.leftShoulder);
    final rightShoulder = _movementLandmark(
      pose,
      PoseLandmarkType.rightShoulder,
    );
    final leftHip = _movementLandmark(pose, PoseLandmarkType.leftHip);
    final rightHip = _movementLandmark(pose, PoseLandmarkType.rightHip);
    final leftKnee = _movementLandmark(pose, PoseLandmarkType.leftKnee);
    final rightKnee = _movementLandmark(pose, PoseLandmarkType.rightKnee);
    final leftAnkle = _movementLandmark(pose, PoseLandmarkType.leftAnkle);
    final rightAnkle = _movementLandmark(pose, PoseLandmarkType.rightAnkle);
    final leftFoot = _bestMovementLandmark(pose, const [
      PoseLandmarkType.leftHeel,
      PoseLandmarkType.leftFootIndex,
    ]);
    final rightFoot = _bestMovementLandmark(pose, const [
      PoseLandmarkType.rightHeel,
      PoseLandmarkType.rightFootIndex,
    ]);
    final keyLandmarks = [
      head,
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
      leftKnee,
      rightKnee,
      leftAnkle,
      rightAnkle,
    ];
    final confidence =
        keyLandmarks.fold<double>(
          0,
          (total, landmark) => total + (landmark?.likelihood ?? 0),
        ) /
        keyLandmarks.length;
    final hasShoulders = leftShoulder != null && rightShoulder != null;
    final footLandmarks = [leftAnkle, rightAnkle, leftFoot, rightFoot];
    final hasFootLandmarks = footLandmarks.every(
      (landmark) => landmark != null,
    );
    final footPoints = footLandmarks
        .whereType<PoseLandmark>()
        .map((landmark) => _normalizedPoint(landmark, imageSize, rotation))
        .toList();
    final feetInFrame =
        hasFootLandmarks &&
        footPoints.every(
          (point) =>
              point.dx >= 0.02 &&
              point.dx <= 0.98 &&
              point.dy >= 0.02 &&
              point.dy <= 0.98,
        );

    if (head == null || !feetInFrame) {
      return _FrameAssessment(
        confidence: confidence,
        hasHead: head != null,
        hasShoulders: hasShoulders,
        hasFeet: false,
        message:
            'Move the camera farther back until your head and both feet are visible.',
      );
    }

    if (!hasShoulders ||
        leftHip == null ||
        rightHip == null ||
        leftKnee == null ||
        rightKnee == null) {
      return _FrameAssessment(
        confidence: confidence,
        hasHead: true,
        hasShoulders: hasShoulders,
        hasFeet: feetInFrame,
        message:
            'Stand fully in view and hold still while your body is detected.',
      );
    }

    final points = keyLandmarks
        .whereType<PoseLandmark>()
        .map((landmark) => _normalizedPoint(landmark, imageSize, rotation))
        .toList();
    final minX = points.map((point) => point.dx).reduce(math.min);
    final maxX = points.map((point) => point.dx).reduce(math.max);
    final headY = _normalizedPoint(head, imageSize, rotation).dy;
    final feetY = footPoints
        .map((point) => point.dy)
        .reduce((first, second) => first > second ? first : second);
    final bodyHeight = feetY - headY;
    final hasHead = headY >= 0.02 && headY <= 0.98;
    if (headY < 0.02 || feetY > 0.98 || bodyHeight > 0.96) {
      return _FrameAssessment(
        confidence: confidence,
        hasHead: hasHead,
        hasShoulders: hasShoulders,
        hasFeet: feetInFrame,
        message: 'Move the camera farther away to fit your whole body.',
      );
    }
    if (minX < 0.02 || maxX > 0.98) {
      return _FrameAssessment(
        confidence: confidence,
        hasHead: hasHead,
        hasShoulders: hasShoulders,
        hasFeet: feetInFrame,
        message: 'Center yourself in the camera view.',
      );
    }
    if (bodyHeight < 0.35) {
      return _FrameAssessment(
        confidence: confidence,
        hasHead: hasHead,
        hasShoulders: hasShoulders,
        hasFeet: feetInFrame,
        message: 'Move a little closer so your posture is easier to read.',
      );
    }
    if (confidence < 0.45) {
      return _FrameAssessment(
        confidence: confidence,
        hasHead: hasHead,
        hasShoulders: hasShoulders,
        hasFeet: feetInFrame,
        message: 'Improve the lighting and stand still for a moment.',
      );
    }

    return _FrameAssessment(
      isReady: true,
      confidence: confidence,
      hasHead: hasHead,
      hasShoulders: hasShoulders,
      hasFeet: feetInFrame,
      message: 'Full body is in frame.',
    );
  }

  Offset _normalizedPoint(
    PoseLandmark landmark,
    Size imageSize,
    InputImageRotation rotation,
  ) => _mapPoint(landmark, imageSize, rotation, _lensDirection);

  void _showCameraInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF10271F),
        title: const Text(
          'Tracking settings',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Pose detection runs on this device. Camera frames are not saved or uploaded.',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;
    final cameraReady = controller?.value.isInitialized ?? false;
    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (cameraReady)
            CameraPreview(
              controller!,
              child: CustomPaint(
                painter: _PoseSkeletonPainter(
                  pose: _pose,
                  imageSize: _imageSize,
                  rotation: _imageRotation,
                  lensDirection: _lensDirection,
                ),
                child: const SizedBox.expand(),
              ),
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF142820), _background, Color(0xFF020906)],
                ),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x44031711),
                  Colors.transparent,
                  Color(0x66031711),
                ],
                stops: [0, 0.32, 1],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildPrayerSelector(),
                _buildDetectionStatus(),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _FrameGuidePainter(
                              isReady: _framingConfirmed,
                            ),
                          ),
                        ),
                      ),
                      if (_prayerStarted && !_isFullView)
                        Positioned(
                          top: 12,
                          right: 8,
                          width: 126,
                          child: _buildStageRail(),
                        ),
                      if (!cameraReady) _buildCameraPlaceholder(),
                    ],
                  ),
                ),
                if (_prayerStarted) ...[
                  if (!_isFullView) _buildActivePositionCard(),
                  if (!_isFullView) _buildRakatProgress(),
                  _buildPrayerControls(),
                ] else
                  _buildFramingPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => SizedBox(
    height: 54,
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
        ),
        const Expanded(
          child: Text(
            'Salah Tracker',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Tracking settings',
          onPressed: _showCameraInfo,
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
        ),
      ],
    ),
  );

  Widget _buildPrayerSelector() => Container(
    height: 44,
    margin: const EdgeInsets.symmetric(horizontal: 20),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.46),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _selectedPrayer,
        dropdownColor: const Color(0xFF10271F),
        iconEnabledColor: Colors.white,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        items: const ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']
            .map(
              (prayer) => DropdownMenuItem(
                value: prayer,
                child: Text('$prayer Prayer'),
              ),
            )
            .toList(),
        onChanged: (prayer) {
          if (prayer != null) {
            setState(() {
              _selectedPrayer = prayer;
              _resetPrayerProgress();
            });
          }
        },
      ),
    ),
  );

  Widget _buildDetectionStatus() {
    final activeStage = _prayerStarted
        ? _prayerStages[_currentStepIndex]
        : null;
    final color = _prayerStarted || _framingConfirmed
        ? _green
        : const Color(0xFFFFC857);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 0, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.38)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 8),
            Text(
              _isStarting
                  ? 'Starting camera...'
                  : _prayerComplete
                  ? 'Prayer sequence complete'
                  : _prayerStarted
                  ? _isPaused
                        ? 'Paused'
                        : activeStage!.label
                  : _framingConfirmed
                  ? 'Start prayer'
                  : _assessment.isCandidate
                  ? 'Hold still to confirm'
                  : 'Adjust camera position',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(_assessment.confidence * 100).round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    final error = _cameraError;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 38),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error == null
                  ? Icons.camera_alt_outlined
                  : Icons.no_photography_outlined,
              color: Colors.white70,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              error ?? 'Connecting to camera',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!_isStarting && error != null && _supportsPoseCamera) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFramingPanel() {
    final color = _prayerStarted || _framingConfirmed
        ? _green
        : const Color(0xFFFFC857);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                _prayerStarted || _framingConfirmed
                    ? Icons.check_circle
                    : Icons.center_focus_strong,
                color: color,
                size: 25,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _prayerStarted
                      ? 'Prayer started'
                      : _framingConfirmed
                      ? 'Start your prayer'
                      : _assessment.isCandidate
                      ? 'Checking your position'
                      : 'Set your camera position',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_cameras.length > 1)
                IconButton(
                  tooltip: 'Switch camera',
                  onPressed: _switchCamera,
                  icon: const Icon(
                    Icons.flip_camera_ios_outlined,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _assessment.message,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.35),
            ),
          ),
          if (_assessment.isCandidate && !_framingConfirmed) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _stableReadyFrames / _stableFramesRequired,
              minHeight: 3,
              color: _green,
              backgroundColor: Colors.white24,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _VisibilityCheck(label: 'Head', isVisible: _assessment.hasHead),
              _VisibilityCheck(
                label: 'Shoulders',
                isVisible: _assessment.hasShoulders,
              ),
              _VisibilityCheck(label: 'Feet', isVisible: _assessment.hasFeet),
            ],
          ),
        ],
      ),
    );
  }

  _PrayerStage get _activePrayerStage =>
      _prayerStages[_currentStepIndex.clamp(0, _prayerStages.length - 1)];

  Widget _buildStageRail() {
    final stages = _prayerStages;
    final activeStage = stages[_currentStepIndex];
    final rows = <Widget>[];
    for (var index = 0; index < stages.length; index++) {
      final stage = stages[index];
      if (stage.rakat != activeStage.rakat) continue;
      final isActive = index == _currentStepIndex;
      final isComplete = index < _currentStepIndex || _prayerComplete;
      final color = isActive || isComplete ? _green : Colors.white54;
      rows.add(
        Container(
          height: 40,
          margin: const EdgeInsets.only(top: 5),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xD9092D20) : const Color(0xB3091712),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isActive ? _green : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle : _stageIcon(stage.position),
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  stage.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive || isComplete
                        ? Colors.white
                        : Colors.white70,
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 8, 7, 9),
      decoration: BoxDecoration(
        color: const Color(0xC9091712),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RAKAT ${activeStage.rakat}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildActivePositionCard() {
    final stage = _activePrayerStage;
    final instruction = _prayerComplete
        ? 'Prayer sequence complete.'
        : _isPaused
        ? 'Tracking is paused.'
        : _stageInstruction(stage.label);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _green.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            _prayerComplete ? Icons.check_circle : _stageIcon(stage.position),
            color: _green,
            size: 25,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _prayerComplete ? 'Prayer sequence complete' : stage.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  instruction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Detected: ${_positionLabel(_detectedPosition)}',
                  style: TextStyle(
                    color: _detectedPosition == stage.position
                        ? _green
                        : Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 9,
                  runSpacing: 3,
                  children: [
                    _PoseAngle(label: 'H-K-A', degrees: _lastKneeAngle),
                    _PoseAngle(label: 'S-H-K', degrees: _shoulderHipKneeAngle),
                    _PoseAngle(label: 'Hinge', degrees: _hipHingeAngle),
                    _PoseAngle(label: 'Shoulder-hip', degrees: _backTiltAngle),
                    _PoseAngle(
                      label: 'Head/torso',
                      degrees: _headBackAlignmentAngle,
                    ),
                    _PoseMetric(
                      label: 'Head Δ',
                      value: _lastHeadTorsoRatio.toStringAsFixed(2),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (stage.isFinal && !_prayerComplete)
            IconButton(
              tooltip: 'Finish prayer',
              onPressed: _finishPrayer,
              icon: const Icon(Icons.check_circle, color: _green),
            ),
        ],
      ),
    );
  }

  Widget _buildRakatProgress() {
    final stage = _activePrayerStage;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rakat progress',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${stage.rakat} / $_rakatCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_rakatCount, (index) {
              final rakatNumber = index + 1;
              final complete = rakatNumber <= _completedRakats;
              final current = rakatNumber == stage.rakat && !_prayerComplete;
              final color = complete || current ? _green : Colors.white24;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(
                        alpha: complete || current ? 0.22 : 0.12,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: color),
                    ),
                    child: Text(
                      complete ? '✓' : '$rakatNumber',
                      style: TextStyle(
                        color: complete || current ? _green : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerControls() => Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xD9091712),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Reset prayer tracking',
          onPressed: () => setState(_resetPrayerProgress),
          icon: const Icon(Icons.restart_alt, color: Colors.white),
        ),
        FilledButton.icon(
          onPressed: _prayerComplete
              ? null
              : () => setState(() => _isPaused = !_isPaused),
          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
          label: Text(_isPaused ? 'Resume' : 'Pause'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            foregroundColor: Colors.white,
          ),
        ),
        IconButton(
          tooltip: _isFullView ? 'Show movement steps' : 'Full camera view',
          onPressed: () => setState(() => _isFullView = !_isFullView),
          icon: Icon(
            _isFullView ? Icons.fit_screen : Icons.fullscreen,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );

  IconData _stageIcon(_PrayerPosition position) => switch (position) {
    _PrayerPosition.standing => Icons.accessibility_new,
    _PrayerPosition.bowing => Icons.sports_gymnastics,
    _PrayerPosition.prostration => Icons.self_improvement,
    _PrayerPosition.sitting => Icons.chair_alt,
    _PrayerPosition.unknown => Icons.more_horiz,
  };

  String _stageInstruction(String label) => switch (label) {
    'Qiyam' => 'Stand upright and recite.',
    'Ruku' => 'Bow, keeping your back steady.',
    'Qawmah' => 'Stand upright after Ruku.',
    'Sujood 1' || 'Sujood 2' => 'Move into prostration.',
    'Jalsa' => 'Sit briefly between prostrations.',
    'Tashahhud' || 'Final sitting' => 'Remain seated for Tashahhud.',
    _ => 'Follow the next prayer movement.',
  };

  String _positionLabel(_PrayerPosition position) => switch (position) {
    _PrayerPosition.standing => 'Standing',
    _PrayerPosition.bowing => 'Ruku',
    _PrayerPosition.prostration => 'Sujood',
    _PrayerPosition.sitting => 'Sitting',
    _PrayerPosition.unknown => 'Detecting',
  };
}

class _FrameAssessment {
  const _FrameAssessment({
    this.isReady = false,
    this.isCandidate = false,
    this.confidence = 0,
    this.hasHead = false,
    this.hasShoulders = false,
    this.hasFeet = false,
    this.message =
        'Stand in front of the camera so your full body can be seen.',
  });

  const _FrameAssessment.searching({
    this.message =
        'Stand in front of the camera so your full body can be seen.',
  }) : isReady = false,
       isCandidate = false,
       confidence = 0,
       hasHead = false,
       hasShoulders = false,
       hasFeet = false;

  final bool isReady;
  final bool isCandidate;
  final double confidence;
  final bool hasHead;
  final bool hasShoulders;
  final bool hasFeet;
  final String message;

  _FrameAssessment withConfirmation(
    bool confirmed, {
    bool prayerStarted = false,
  }) => _FrameAssessment(
    isReady: confirmed,
    isCandidate: isReady,
    confidence: confidence,
    hasHead: hasHead,
    hasShoulders: hasShoulders,
    hasFeet: hasFeet,
    message: prayerStarted
        ? 'Takbir detected. Prayer started.'
        : confirmed
        ? 'Framing locked. Raise both hands beside your head to start prayer.'
        : isReady
        ? 'Hold still while we confirm your full-body framing.'
        : message,
  );
}

class _VisibilityCheck extends StatelessWidget {
  const _VisibilityCheck({required this.label, required this.isVisible});

  final String label;
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    final color = isVisible ? const Color(0xFF39F27A) : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVisible ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PoseAngle extends StatelessWidget {
  const _PoseAngle({required this.label, required this.degrees});

  final String label;
  final double degrees;

  @override
  Widget build(BuildContext context) => Text(
    '$label ${degrees.round()}°',
    style: const TextStyle(
      color: Color(0xFFB7C8C0),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _PoseMetric extends StatelessWidget {
  const _PoseMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Text(
    '$label $value',
    style: const TextStyle(
      color: Color(0xFFB7C8C0),
      fontSize: 10,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _FrameGuidePainter extends CustomPainter {
  const _FrameGuidePainter({required this.isReady});

  final bool isReady;

  @override
  void paint(Canvas canvas, Size size) {
    final color = isReady ? const Color(0xFF39F27A) : Colors.white70;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: math.min(size.width * 0.76, 310),
      height: size.height * 0.88,
    );
    const cornerLength = 24.0;
    final corners = [
      [rect.topLeft, rect.topLeft + const Offset(cornerLength, 0)],
      [rect.topLeft, rect.topLeft + const Offset(0, cornerLength)],
      [rect.topRight, rect.topRight + const Offset(-cornerLength, 0)],
      [rect.topRight, rect.topRight + const Offset(0, cornerLength)],
      [rect.bottomLeft, rect.bottomLeft + const Offset(cornerLength, 0)],
      [rect.bottomLeft, rect.bottomLeft + const Offset(0, -cornerLength)],
      [rect.bottomRight, rect.bottomRight + const Offset(-cornerLength, 0)],
      [rect.bottomRight, rect.bottomRight + const Offset(0, -cornerLength)],
    ];
    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FrameGuidePainter oldDelegate) =>
      oldDelegate.isReady != isReady;
}

class _PoseSkeletonPainter extends CustomPainter {
  const _PoseSkeletonPainter({
    required this.pose,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
  });

  final Pose? pose;
  final Size? imageSize;
  final InputImageRotation? rotation;
  final CameraLensDirection lensDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final currentPose = pose;
    final sourceSize = imageSize;
    final imageRotation = rotation;
    if (currentPose == null || sourceSize == null || imageRotation == null) {
      return;
    }

    final linePaint = Paint()
      ..color = const Color(0xFF39F27A)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = const Color(0xFF39F27A);
    const connections = [
      [PoseLandmarkType.nose, PoseLandmarkType.leftShoulder],
      [PoseLandmarkType.nose, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel],
      [PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
      [PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel],
      [PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex],
    ];

    Offset map(PoseLandmark landmark) {
      final point = _mapPoint(
        landmark,
        sourceSize,
        imageRotation,
        lensDirection,
      );
      return Offset(point.dx * size.width, point.dy * size.height);
    }

    for (final connection in connections) {
      final start = currentPose.landmarks[connection[0]];
      final end = currentPose.landmarks[connection[1]];
      if (start != null &&
          end != null &&
          start.likelihood > 0.25 &&
          end.likelihood > 0.25) {
        canvas.drawLine(map(start), map(end), linePaint);
      }
    }
    for (final landmark in currentPose.landmarks.values) {
      if (landmark.likelihood > 0.3) {
        canvas.drawCircle(map(landmark), 4, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PoseSkeletonPainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.imageSize != imageSize ||
      oldDelegate.rotation != rotation ||
      oldDelegate.lensDirection != lensDirection;
}

Offset _mapPoint(
  PoseLandmark landmark,
  Size imageSize,
  InputImageRotation rotation,
  CameraLensDirection lensDirection,
) {
  final double x;
  final double y;
  switch (rotation) {
    case InputImageRotation.rotation90deg:
      x = landmark.x / (Platform.isIOS ? imageSize.width : imageSize.height);
      y = landmark.y / (Platform.isIOS ? imageSize.height : imageSize.width);
    case InputImageRotation.rotation270deg:
      x =
          1 -
          landmark.x / (Platform.isIOS ? imageSize.width : imageSize.height);
      y = landmark.y / (Platform.isIOS ? imageSize.height : imageSize.width);
    case InputImageRotation.rotation180deg:
      x = lensDirection == CameraLensDirection.front
          ? 1 - landmark.x / imageSize.width
          : landmark.x / imageSize.width;
      y = 1 - landmark.y / imageSize.height;
    case InputImageRotation.rotation0deg:
      x = lensDirection == CameraLensDirection.front
          ? 1 - landmark.x / imageSize.width
          : landmark.x / imageSize.width;
      y = landmark.y / imageSize.height;
  }
  return Offset(x, y);
}

enum _PrayerPosition { standing, bowing, prostration, sitting, unknown }

class _PrayerStage {
  const _PrayerStage(
    this.title,
    this.label,
    this.position,
    this.rakat, {
    this.completesRakat = false,
    this.isFinal = false,
  });

  final String title;
  final String label;
  final _PrayerPosition position;
  final int rakat;
  final bool completesRakat;
  final bool isFinal;
}

class _MotionPoint {
  const _MotionPoint(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;
}

double _jointAngle3d(
  _MotionPoint first,
  _MotionPoint center,
  _MotionPoint last,
) {
  final firstX = first.x - center.x;
  final firstY = first.y - center.y;
  final firstZ = first.z - center.z;
  final lastX = last.x - center.x;
  final lastY = last.y - center.y;
  final lastZ = last.z - center.z;
  final firstLength = math.sqrt(
    firstX * firstX + firstY * firstY + firstZ * firstZ,
  );
  final lastLength = math.sqrt(lastX * lastX + lastY * lastY + lastZ * lastZ);
  if (firstLength == 0 || lastLength == 0) return 180;
  final cosine =
      ((firstX * lastX + firstY * lastY + firstZ * lastZ) /
              (firstLength * lastLength))
          .clamp(-1.0, 1.0);
  return math.acos(cosine) * 180 / math.pi;
}
