import 'package:flutter/material.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _sloganOpacity;
  late final Animation<Offset> _sloganSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.0,
        0.58,
        curve: Curves.easeOutCubic,
      ),
    );

    _logoScale = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.0,
          0.70,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    _sloganOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.45,
        1.0,
        curve: Curves.easeOut,
      ),
    );

    _sloganSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.45,
          1.0,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (context, animation, secondaryAnimation) =>
          const AuthControl(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 54),
                        child: Image.asset(
                          'assets/branding/dort_logo_white_orange.png',
                          width: 260,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FadeTransition(
                    opacity: _sloganOpacity,
                    child: SlideTransition(
                      position: _sloganSlide,
                      child: const Text(
                        'Oyunun Eksik Oyuncusunu Bul',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FadeTransition(
              opacity: _sloganOpacity,
              child: const Positioned(
                left: 0,
                right: 0,
                bottom: 28,
                child: Text(
                  'DÖRT.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}