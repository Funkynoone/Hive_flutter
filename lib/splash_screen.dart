import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _glowController;

  // Animation phases
  late Animation<double> _chefOpacity;
  late Animation<double> _chefScale;
  late Animation<Offset> _chefPosition;
  late Animation<double> _cameraZoom;
  late Animation<Offset> _forkPosition;
  late Animation<double> _forkRotation;
  late Animation<double> _forkOpacity;
  late Animation<double> _hLetterOpacity;
  late Animation<double> _vLetterOpacity;
  late Animation<double> _eLetterOpacity;
  late Animation<double> _textOpacity;
  late Animation<double> _glowOpacity;

  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimation();
  }

  void _initializeAnimations() {
    // Main animation controller (6 seconds total)
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 6000),
      vsync: this,
    );

    // Glow effect controller
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Phase 1: Chef appears (0-1s) - larger and centered
    _chefOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.16, curve: Curves.easeInOut),
    ));

    _chefScale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.16, curve: Curves.easeOutBack),
    ));

    // Phase 2: Camera zoom out (1-2s)
    _cameraZoom = Tween<double>(
      begin: 1.2,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.16, 0.33, curve: Curves.easeOut),
    ));

    // Chef moves to left as camera zooms
    _chefPosition = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.6, 0),
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.16, 0.5, curve: Curves.easeInOut),
    ));

    // Phase 3: Fork throw (2-3.5s)
    _forkPosition = Tween<Offset>(
      begin: const Offset(-0.2, -0.1),
      end: const Offset(0.4, -0.2),
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.33, 0.58, curve: Curves.easeInOut),
    ));

    _forkRotation = Tween<double>(
      begin: -0.5,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.33, 0.58, curve: Curves.easeOut),
    ));

    _forkOpacity = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.58, 0.65, curve: Curves.easeOut),
    ));

    // Phase 4: Letters form (3.5-5s)
    _hLetterOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.65, 0.75, curve: Curves.easeInOut),
    ));

    _vLetterOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.7, 0.8, curve: Curves.easeInOut),
    ));

    _eLetterOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.75, 0.85, curve: Curves.easeInOut),
    ));

    // Phase 5: Text appears (5-6s)
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.85, 1.0, curve: Curves.easeInOut),
    ));

    // Glow effect
    _glowOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimation() async {
    // Start main animation
    _mainController.forward();

    // Start glow effect when letters are forming
    await Future.delayed(const Duration(milliseconds: 4000));
    if (mounted) {
      _glowController.forward();
    }

    // Wait for animation to complete
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted && !_hasNavigated) {
      _navigateToNextScreen();
    }
  }

  Future<void> _navigateToNextScreen() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (mounted) {
        if (user != null) {
          Navigator.pushReplacementNamed(context, '/');
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      print("Auth check error: $e");
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF59E0B), // Yellow-orange background
      body: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return Transform.scale(
            scale: _cameraZoom.value,
            child: Container(
              width: screenSize.width,
              height: screenSize.height,
              child: Stack(
                children: [
                  // Chef character - starts center, moves left
                  Positioned(
                    left: screenSize.width * 0.5 + (_chefPosition.value.dx * screenSize.width * 0.3) - 60,
                    top: screenSize.height * 0.4,
                    child: Transform.scale(
                      scale: _chefScale.value,
                      child: Opacity(
                        opacity: _chefOpacity.value,
                        child: const ChefCharacter(),
                      ),
                    ),
                  ),

                  // Flying Fork
                  Positioned(
                    left: screenSize.width * 0.35 + (_forkPosition.value.dx * screenSize.width * 0.3),
                    top: screenSize.height * 0.35 + (_forkPosition.value.dy * screenSize.height * 0.1),
                    child: Transform.rotate(
                      angle: _forkRotation.value,
                      child: Opacity(
                        opacity: _chefOpacity.value * _forkOpacity.value,
                        child: const ForkIcon(),
                      ),
                    ),
                  ),

                  // HIVE Letters - centered
                  Positioned(
                    left: screenSize.width * 0.5 - 140,
                    top: screenSize.height * 0.35,
                    child: AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            boxShadow: _glowOpacity.value > 0
                                ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15 * _glowOpacity.value),
                                blurRadius: 20 * _glowOpacity.value,
                                spreadRadius: 3 * _glowOpacity.value,
                              ),
                            ]
                                : null,
                          ),
                          child: HiveLetters(
                            hOpacity: _hLetterOpacity.value,
                            iOpacity: 1.0 - _forkOpacity.value, // I appears as fork fades
                            vOpacity: _vLetterOpacity.value,
                            eOpacity: _eLetterOpacity.value,
                          ),
                        );
                      },
                    ),
                  ),

                  // HIVE text below - centered
                  Positioned(
                    left: 0,
                    right: 0,
                    top: screenSize.height * 0.55,
                    child: Center(
                      child: Opacity(
                        opacity: _textOpacity.value,
                        child: const Text(
                          'HIVE',
                          style: TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w200,
                            color: Colors.black87,
                            letterSpacing: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Chef Character Widget - Made larger and more visible
class ChefCharacter extends StatelessWidget {
  const ChefCharacter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(120, 140),
      painter: ChefPainter(),
    );
  }
}

class ChefPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Chef hat - larger
    final hatPath = Path();
    hatPath.moveTo(size.width * 0.15, size.height * 0.25);
    hatPath.quadraticBezierTo(
      size.width * 0.5, size.height * 0.05,
      size.width * 0.85, size.height * 0.25,
    );
    hatPath.lineTo(size.width * 0.85, size.height * 0.4);
    hatPath.lineTo(size.width * 0.15, size.height * 0.4);
    hatPath.close();
    canvas.drawPath(hatPath, paint);

    // Head (circle) - larger
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.18,
      paint,
    );

    // Body - larger
    final bodyRect = RRect.fromLTRBR(
      size.width * 0.3,
      size.height * 0.65,
      size.width * 0.7,
      size.height * 0.9,
      const Radius.circular(12),
    );
    canvas.drawRRect(bodyRect, paint);

    // Arms - more visible
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.7),
      Offset(size.width * 0.05, size.height * 0.8),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, size.height * 0.7),
      Offset(size.width * 0.95, size.height * 0.75),
      paint,
    );

    // Add simple face
    final facePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    // Eyes
    canvas.drawCircle(
      Offset(size.width * 0.43, size.height * 0.47),
      2,
      facePaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.57, size.height * 0.47),
      2,
      facePaint,
    );

    // Smile
    final smilePaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final smilePath = Path();
    smilePath.moveTo(size.width * 0.42, size.height * 0.53);
    smilePath.quadraticBezierTo(
      size.width * 0.5, size.height * 0.57,
      size.width * 0.58, size.height * 0.53,
    );
    canvas.drawPath(smilePath, smilePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Fork Icon Widget - Made larger
class ForkIcon extends StatelessWidget {
  const ForkIcon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 80),
      painter: ForkPainter(),
    );
  }
}

class ForkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Fork handle
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.4),
      Offset(size.width * 0.5, size.height * 0.95),
      paint,
    );

    // Fork prongs
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.05),
      Offset(size.width * 0.25, size.height * 0.4),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.05),
      Offset(size.width * 0.5, size.height * 0.4),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.05),
      Offset(size.width * 0.75, size.height * 0.4),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// HIVE Letters Widget - Better positioning and sequencing
class HiveLetters extends StatelessWidget {
  final double hOpacity;
  final double iOpacity;
  final double vOpacity;
  final double eOpacity;

  const HiveLetters({
    Key? key,
    required this.hOpacity,
    required this.iOpacity,
    required this.vOpacity,
    required this.eOpacity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(280, 100),
      painter: HiveLettersPainter(
        hOpacity: hOpacity,
        iOpacity: iOpacity,
        vOpacity: vOpacity,
        eOpacity: eOpacity,
      ),
    );
  }
}

class HiveLettersPainter extends CustomPainter {
  final double hOpacity;
  final double iOpacity;
  final double vOpacity;
  final double eOpacity;

  HiveLettersPainter({
    required this.hOpacity,
    required this.iOpacity,
    required this.vOpacity,
    required this.eOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final letterWidth = size.width / 4;
    final strokeWidth = 6.0;

    // H
    final hPaint = Paint()
      ..color = Colors.black87.withOpacity(hOpacity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(letterWidth * 0.1, size.height * 0.2),
      Offset(letterWidth * 0.1, size.height * 0.8),
      hPaint,
    );
    canvas.drawLine(
      Offset(letterWidth * 0.7, size.height * 0.2),
      Offset(letterWidth * 0.7, size.height * 0.8),
      hPaint,
    );
    canvas.drawLine(
      Offset(letterWidth * 0.1, size.height * 0.5),
      Offset(letterWidth * 0.7, size.height * 0.5),
      hPaint,
    );

    // I (this is where the fork becomes the I)
    final iPaint = Paint()
      ..color = Colors.black87.withOpacity(iOpacity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(letterWidth * 1.4, size.height * 0.2),
      Offset(letterWidth * 1.4, size.height * 0.8),
      iPaint,
    );

    // V
    final vPaint = Paint()
      ..color = Colors.black87.withOpacity(vOpacity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(letterWidth * 2.1, size.height * 0.2),
      Offset(letterWidth * 2.4, size.height * 0.8),
      vPaint,
    );
    canvas.drawLine(
      Offset(letterWidth * 2.7, size.height * 0.2),
      Offset(letterWidth * 2.4, size.height * 0.8),
      vPaint,
    );

    // E
    final ePaint = Paint()
      ..color = Colors.black87.withOpacity(eOpacity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(letterWidth * 3.1, size.height * 0.2),
      Offset(letterWidth * 3.1, size.height * 0.8),
      ePaint,
    );
    canvas.drawLine(
      Offset(letterWidth * 3.1, size.height * 0.2),
      Offset(letterWidth * 3.8, size.height * 0.2),
      ePaint,
    );
    canvas.drawLine(
      Offset(letterWidth * 3.1, size.height * 0.5),
      Offset(letterWidth * 3.7, size.height * 0.5),
      ePaint,
    );
    canvas.drawLine(
      Offset(letterWidth * 3.1, size.height * 0.8),
      Offset(letterWidth * 3.8, size.height * 0.8),
      ePaint,
    );

    // Chef hat on E (when E appears)
    if (eOpacity > 0.5) {
      final hatPaint = Paint()
        ..color = Colors.black87.withOpacity(eOpacity)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final hatPath = Path();
      hatPath.moveTo(letterWidth * 3.05, size.height * 0.12);
      hatPath.quadraticBezierTo(
        letterWidth * 3.15, size.height * 0.05,
        letterWidth * 3.25, size.height * 0.12,
      );
      hatPath.lineTo(letterWidth * 3.25, size.height * 0.18);
      hatPath.lineTo(letterWidth * 3.05, size.height * 0.18);
      canvas.drawPath(hatPath, hatPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}