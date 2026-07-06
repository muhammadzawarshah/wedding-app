import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/passport_background.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  // The polaroid slides up from below, gently rotating into place while it
  // fades in.
  late final Animation<Offset> _photoSlide;
  late final Animation<double> _photoFade;
  late final Animation<double> _photoTilt;

  // The caption / passport text drift in just after the photo settles.
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );

    _photoSlide =
        Tween<Offset>(begin: const Offset(0, 0.55), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
          ),
        );
    _photoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    // Settles from a slight tilt to a gentle final lean, like a placed photo.
    _photoTilt = Tween<double>(begin: -0.14, end: -0.04).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );
    _textSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    _controller.forward();

    Timer(const Duration(milliseconds: 2900), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
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
    return PassportBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ---- Couple polaroid that slides + tilts into place ----
                  FadeTransition(
                    opacity: _photoFade,
                    child: SlideTransition(
                      position: _photoSlide,
                      child: AnimatedBuilder(
                        animation: _photoTilt,
                        builder: (context, child) => Transform.rotate(
                          angle: _photoTilt.value,
                          child: child,
                        ),
                        child: const _CouplePolaroid(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  // ---- Passport title + loader fade in afterwards ----
                  FadeTransition(
                    opacity: _textFade,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Column(
                        children: [
                          // Gold accent line
                          Container(
                            width: 60,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.passportGold,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'WEDDING PASSPORT',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.passportGold,
                                  letterSpacing: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 32),
                          const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.passportGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The couple photo styled as a classic polaroid with a hand-written caption.
class _CouplePolaroid extends StatelessWidget {
  const _CouplePolaroid();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: AspectRatio(
              aspectRatio: 0.82,
              child: Image.asset(
                'assets/couple.jpeg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aija & Abhi',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.deepInk,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
