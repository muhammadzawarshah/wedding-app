import 'dart:async';

import 'package:flutter/material.dart';

import '../models/wedding_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/media_image.dart';
import '../widgets/passport_background.dart';
import 'media_viewer_screen.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  static const _deckVisuals = [
    'assets/images/itinerary_slide_1.png',
    'assets/images/itinerary_slide_2.png',
    'assets/images/itinerary_slide_3.png',
    'assets/images/itinerary_slide_4.png',
  ];

  // Loads events from the shared backend; the service falls back to bundled
  // mock data automatically if the server is unreachable.
  late final Future<List<WeddingEvent>> _eventsFuture = ApiService.instance
      .fetchEvents();

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(
        title: 'Itinerary',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle(
              title: 'Wedding Itinerary',
              subtitle:
                  'Live from the wedding platform. Organisers update timings from the admin dashboard.',
            ),
            const SizedBox(height: 16),
            const _DeckVisualSlider(images: _deckVisuals),
            const SizedBox(height: 20),
            FutureBuilder<List<WeddingEvent>>(
              future: _eventsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final events = snapshot.data ?? const <WeddingEvent>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final event in events) ...[
                      _EventCard(event: event),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckVisualSlider extends StatefulWidget {
  const _DeckVisualSlider({required this.images});

  final List<String> images;

  @override
  State<_DeckVisualSlider> createState() => _DeckVisualSliderState();
}

class _DeckVisualSliderState extends State<_DeckVisualSlider> {
  final _controller = PageController();
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_controller.hasClients) return;
        final next = (_current + 1) % widget.images.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _openImage(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        // Slides are wide landscape artwork; rotate 90° on portrait phones so
        // the itinerary text fills the screen and is readable without zooming.
        builder: (_) =>
            MediaViewerScreen(source: widget.images[index], quarterTurns: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (index) => setState(() => _current = index),
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () => _openImage(context, index),
                    child: MediaImage(
                      source: widget.images[index],
                      fit: BoxFit.contain,
                    ),
                  );
                },
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Deck Visuals',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black87),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < widget.images.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _current ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: i == _current
                                  ? AppColors.passportGold
                                  : Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final WeddingEvent event;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${event.date} - ${event.time}'),
          const SizedBox(height: 4),
          Text(event.venue, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(event.description),
          if (event.hasStream || event.hasRecording) ...[
            const SizedBox(height: 12),
            _WatchButton(event: event),
          ],
        ],
      ),
    );
  }
}

/// Per-event "watch" button. Playable streams/recordings (HLS .m3u8 / MP4) open
/// the in-app player; other links (e.g. YouTube) show the link to open.
class _WatchButton extends StatelessWidget {
  const _WatchButton({required this.event});

  final WeddingEvent event;

  bool _isPlayable(String url) {
    final u = url.toLowerCase();
    return u.contains('.m3u8') ||
        u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.webm');
  }

  @override
  Widget build(BuildContext context) {
    final live = event.hasStream;
    final url = event.watchUrl;
    return Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton.icon(
        style: live
            ? ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              )
            : null,
        onPressed: () {
          if (_isPlayable(url)) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MediaViewerScreen(
                  source: url,
                  isVideo: true,
                  title: event.title,
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Open the stream link: $url')),
            );
          }
        },
        icon: Icon(live ? Icons.live_tv : Icons.play_circle_fill, size: 18),
        label: Text(live ? 'Watch live' : 'Watch recording'),
      ),
    );
  }
}
