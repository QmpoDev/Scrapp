import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';

import '../utils/app_animations.dart';
import 'map_screen.dart';

/// Splash screen that plays the DaVinci Resolve animation, then navigates
/// to [MapScreen] when the video finishes (or after a 6-second fallback).
///
/// While the video is initialising, a Lottie animation is shown instead of
/// a blank white screen — this eliminates the perceived "dead time" on cold
/// start (Phase 1 — Lottie Integration).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.asset(
      'assets/video/splash_animation/SplashAnimation_Scrapp.mp4',
    );

    try {
      await _controller.initialize();
      _controller.addListener(_onVideoUpdate);
      if (mounted) {
        setState(() => _initialized = true);
        await _controller.play();
      }
    } catch (_) {
      _navigateToMap();
    }
  }

  void _onVideoUpdate() {
    if (_navigated) return;
    if (!_controller.value.isPlaying &&
        _controller.value.isInitialized &&
        _controller.value.position >= _controller.value.duration) {
      _navigateToMap();
    }
  }

  void _navigateToMap() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MapScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: AppAnimations.easeInOutCubic,
          ),
          child: child,
        ),
        transitionDuration: AppAnimations.emphasisMax,
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _initialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          // Lottie loading indicator while the video asset initialises.
          // This replaces the blank white screen, giving the user immediate
          // visual feedback that the app is alive (Phase 1 — Lottie).
          : Center(
              child: Lottie.asset(
                'assets/lottie/welcome_recycle.json',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                repeat: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
    );
  }
}
