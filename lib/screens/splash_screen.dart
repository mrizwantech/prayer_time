import 'dart:math';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final String statusMessage;
  final bool isLoading;

  const SplashScreen({
    super.key,
    this.statusMessage = 'Initializing...',
    this.isLoading = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _starsController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _pulseAnimation;
  late Animation<double> _textSlide;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeIn),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Use addListener + setState instead of AnimatedBuilder
    _logoController.addListener(_rebuild);
    _pulseController.addListener(_rebuild);
    _starsController.addListener(_rebuild);

    _logoController.forward();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _logoController.removeListener(_rebuild);
    _pulseController.removeListener(_rebuild);
    _starsController.removeListener(_rebuild);
    _logoController.dispose();
    _pulseController.dispose();
    _starsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0D1117),
              Color(0xFF1A1D2E),
              Color(0xFF0D1117),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated stars background
            CustomPaint(
              size: size,
              painter: _StarsPainter(progress: _starsController.value),
            ),

            // Crescent moon (top right)
            Positioned(
              top: size.height * 0.08,
              right: size.width * 0.1,
              child: Opacity(
                opacity: _textOpacity.value * 0.3,
                child: const Icon(
                  Icons.nightlight_round,
                  size: 40,
                  color: Color(0xFFFFD700),
                ),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing glow + Logo
                  _buildLogo(),
                  const SizedBox(height: 30),
                  // Title
                  _buildTitle(),
                  const SizedBox(height: 60),
                  // Loader
                  if (widget.isLoading) _buildLoader(),
                ],
              ),
            ),

            // Bottom branding
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: _buildBottomBranding(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 160 * _pulseAnimation.value,
      height: 160 * _pulseAnimation.value,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(79, 195, 247, 0.15 * (2.0 - _pulseAnimation.value)),
            blurRadius: 60,
            spreadRadius: 20,
          ),
        ],
      ),
      child: Center(
        child: Opacity(
          opacity: _logoOpacity.value,
          child: Transform.scale(
            scale: _logoScale.value,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4FC3F7),
                    Color(0xFF1E88E5),
                    Color(0xFF1565C0),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(79, 195, 247, 0.4),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  'assets/images/logoprayer.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.mosque, size: 70, color: Colors.white);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Opacity(
      opacity: _textOpacity.value,
      child: Transform.translate(
        offset: Offset(0, _textSlide.value),
        child: Column(
          children: [
            const Text(
              'Azanify',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Islamic Prayer Times',
              style: TextStyle(
                fontSize: 16,
                color: Color.fromRGBO(255, 255, 255, 0.6),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Opacity(
      opacity: _textOpacity.value,
      child: Column(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color.fromRGBO(79, 195, 247, 0.8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.statusMessage,
            style: const TextStyle(
              fontSize: 14,
              color: Color.fromRGBO(255, 255, 255, 0.5),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBranding() {
    return Opacity(
      opacity: _textOpacity.value * 0.5,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDot(),
              const SizedBox(width: 6),
              _buildDot(dotSize: 5),
              const SizedBox(width: 6),
              const Icon(Icons.star, size: 10, color: Color(0xFFFFD700)),
              const SizedBox(width: 6),
              _buildDot(dotSize: 5),
              const SizedBox(width: 6),
              _buildDot(),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيم',
            style: TextStyle(
              fontSize: 16,
              color: Color.fromRGBO(255, 255, 255, 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot({double dotSize = 3}) {
    return Container(
      width: dotSize,
      height: dotSize,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color.fromRGBO(255, 255, 255, 0.3),
      ),
    );
  }
}

/// Custom painter that draws twinkling stars
class _StarsPainter extends CustomPainter {
  final double progress;
  final List<_Star> _stars;

  _StarsPainter({required this.progress})
      : _stars = List.generate(50, (i) => _Star(i));

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in _stars) {
      final twinkle = (sin((progress * 2 * pi) + star.phase) + 1) / 2;
      final opacity = (star.baseOpacity * (0.3 + 0.7 * twinkle)).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, opacity);

      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Star {
  final double x;
  final double y;
  final double radius;
  final double phase;
  final double baseOpacity;

  _Star(int seed)
      : x = _seededRandom(seed * 3),
        y = _seededRandom(seed * 3 + 1),
        radius = 0.5 + _seededRandom(seed * 3 + 2) * 1.5,
        phase = _seededRandom(seed * 7) * 2 * pi,
        baseOpacity = 0.2 + _seededRandom(seed * 5) * 0.6;

  static double _seededRandom(int seed) {
    return ((sin(seed.toDouble()) * 43758.5453) % 1).abs();
  }
}
