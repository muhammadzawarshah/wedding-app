import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';
import '../widgets/formatted_text.dart';
import '../widgets/media_image.dart';

/// Full-screen viewer for a single photo or video opened from the gallery /
/// family screens. Photos are zoomable; videos play with tap-to-toggle and a
/// scrub bar. Works with both remote URLs and bundled assets.
class MediaViewerScreen extends StatelessWidget {
  const MediaViewerScreen({
    super.key,
    required this.source,
    this.title,
    this.isVideo = false,
    this.quarterTurns = 0,
  });

  /// Image/video URL or asset path.
  final String source;
  final String? title;
  final bool isVideo;

  /// Rotates a still image by [quarterTurns] * 90 degrees. Used to show wide
  /// landscape artwork (e.g. itinerary slides) filling a portrait screen so the
  /// text is readable without having to pinch-zoom.
  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    // Only rotate on portrait screens; on a wide/landscape screen the image is
    // already large enough, so showing it upright is clearer.
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final effectiveTurns = isPortrait ? quarterTurns : 0;

    Widget image = MediaImage(source: source, fit: BoxFit.contain);
    if (effectiveTurns % 4 != 0) {
      image = RotatedBox(quarterTurns: effectiveTurns, child: image);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: title == null ? null : Text(title!),
      ),
      body: Center(
        child: isVideo
            ? _VideoView(source: source)
            : InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: image,
              ),
      ),
    );
  }
}

/// iPhone-style photo gallery: a large main image with a thumbnail strip below
/// to switch between a member's photos, plus an optional formatted description.
class GalleryViewerScreen extends StatefulWidget {
  const GalleryViewerScreen({
    super.key,
    required this.images,
    this.title,
    this.description,
  });

  final List<String> images;
  final String? title;
  final String? description;

  @override
  State<GalleryViewerScreen> createState() => _GalleryViewerScreenState();
}

class _GalleryViewerScreenState extends State<GalleryViewerScreen> {
  int _active = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images;
    final desc = widget.description?.trim() ?? '';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.title == null ? null : Text(widget.title!),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: MediaImage(
                    source: images[_active],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            if (images.length > 1)
              SizedBox(
                height: 74,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  itemCount: images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => setState(() => _active = i),
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: i == _active
                              ? AppColors.passportGold
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Opacity(
                          opacity: i == _active ? 1 : 0.6,
                          child: MediaImage(
                            source: images[i],
                            width: 62,
                            height: 62,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (desc.isNotEmpty)
              Container(
                width: double.infinity,
                color: Colors.white,
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(child: FormattedText(desc)),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoView extends StatefulWidget {
  const _VideoView({required this.source});

  final String source;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final isRemote = widget.source.startsWith('http');
    _controller = isRemote
        ? VideoPlayerController.networkUrl(
            Uri.parse(AppConfig.resolveMedia(widget.source)),
          )
        : VideoPlayerController.asset(widget.source);
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          _controller
            ..setLooping(true)
            ..play();
        })
        .catchError((Object e) {
          if (!mounted) return;
          setState(() => _error = 'The video could not be loaded.');
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.white70));
    }
    if (!_ready) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return GestureDetector(
      onTap: _toggle,
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            VideoProgressIndicator(_controller, allowScrubbing: true),
            // Play/pause overlay icon, shown while paused.
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                if (value.isPlaying) return const SizedBox.shrink();
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 48,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
