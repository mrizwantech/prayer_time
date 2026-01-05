import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

class CelebrationOverlay extends StatefulWidget {
  final Widget child;
  final bool shouldCelebrate;
  final VoidCallback onCelebrationEnd;

  const CelebrationOverlay({
    Key? key,
    required this.child,
    required this.shouldCelebrate,
    required this.onCelebrationEnd,
  }) : super(key: key);

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void didUpdateWidget(CelebrationOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldCelebrate && !oldWidget.shouldCelebrate) {
      _confettiController.play();
      Future.delayed(const Duration(seconds: 3), () {
        widget.onCelebrationEnd();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: pi / 2,
            maxBlastForce: 5,
            minBlastForce: 2,
            emissionFrequency: 0.05,
            numberOfParticles: 50,
            gravity: 0.1,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple,
            ],
          ),
        ),
      ],
    );
  }
}
