import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../config/app_config.dart';
import '../models/wedding_models.dart';
import '../services/api_service.dart';
import '../widgets/app_components.dart';
import '../widgets/passport_background.dart';

/// Live stream screen. When the couple is broadcasting (admin toggles "LIVE"
/// in Wedding settings) and the source is a playable video (HLS .m3u8 / MP4),
/// it plays in-app. Other links (YouTube/Meet) and the pre-show state fall back
/// to a tappable link panel.
class StreamScreen extends StatefulWidget {
  const StreamScreen({super.key});

  @override
  State<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends State<StreamScreen> {
  late final Future<WeddingOverview> _overview = ApiService.instance
      .fetchOverview();

  bool _isPlayable(String url) {
    final u = url.toLowerCase();
    return u.contains('.m3u8') ||
        u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.webm');
  }

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(
        title: 'Live Stream',
        child: FutureBuilder<WeddingOverview>(
          future: _overview,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final info = snapshot.data ?? WeddingOverview.fallback;
            final url = info.streamUrl.trim();
            final isLive = info.liveIsActive && url.isNotEmpty;
            final title = info.liveTitle.trim().isNotEmpty
                ? info.liveTitle.trim()
                : 'Watch the ceremony live';

            if (isLive && _isPlayable(url)) {
              return _LivePlayer(url: url, title: title);
            }
            if (isLive) {
              return LinkPanel(
                title: title,
                description: 'We are live now — tap to open the live stream.',
                url: url,
                icon: Icons.live_tv,
              );
            }
            if (url.isNotEmpty) {
              return LinkPanel(
                title: 'Live stream',
                description:
                    'The live stream is not active yet. It will start at ceremony time — check back then.',
                url: url,
                icon: Icons.live_tv,
              );
            }
            return const SectionCard(
              child: Text(
                'The live stream will appear here once the couple sets it up.',
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LivePlayer extends StatefulWidget {
  const _LivePlayer({required this.url, required this.title});

  final String url;
  final String title;

  @override
  State<_LivePlayer> createState() => _LivePlayerState();
}

class _LivePlayerState extends State<_LivePlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(AppConfig.resolveMedia(widget.url)),
    );
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() => _ready = true);
          _controller.play();
        })
        .catchError((Object _) {
          if (!mounted) return;
          setState(
            () => _error =
                'The live stream could not be loaded. Please try again shortly.',
          );
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
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(_error!),
            )
          else if (!_ready)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            GestureDetector(
              onTap: _toggle,
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio == 0
                    ? 16 / 9
                    : _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
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
            ),
        ],
      ),
    );
  }
}
