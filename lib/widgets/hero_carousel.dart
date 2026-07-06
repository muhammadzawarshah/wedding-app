import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'media_image.dart';

/// Auto-playing image carousel used as the home hero banner.
///
/// Cycles through [images] (asset paths or remote URLs) with a swipeable
/// `PageView`, an auto-advance timer, and page indicator dots. An optional
/// [overlay] is painted on top of every slide (e.g. the welcome text), above a
/// bottom gradient for legibility.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({
    super.key,
    required this.images,
    this.aspectRatio = 16 / 9,
    this.autoPlayInterval = const Duration(seconds: 4),
    this.overlay,
    this.onImageTap,
  });

  final List<String> images;
  final double aspectRatio;
  final Duration autoPlayInterval;
  final Widget? overlay;
  final ValueChanged<String>? onImageTap;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (widget.images.length < 2) return;
    _timer = Timer.periodic(widget.autoPlayInterval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_current + 1) % widget.images.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _current = index),
            itemBuilder: (context, index) {
              final image = widget.images[index];
              final child = MediaImage(source: image);
              if (widget.onImageTap == null) return child;
              return InkWell(
                onTap: () => widget.onImageTap!(image),
                child: child,
              );
            },
          ),
          // Bottom gradient for text/dot legibility.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (widget.overlay != null) widget.overlay!,
          if (widget.images.length > 1)
            Positioned(
              bottom: 10,
              right: 14,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _current ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _current
                            ? AppColors.passportGold
                            : Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
