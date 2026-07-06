import 'package:flutter/material.dart';

import '../data/mock_wedding_data.dart';
import '../models/wedding_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/media_image.dart';
import '../widgets/passport_background.dart';
import 'media_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  // Approved gallery (official photos + moderated guest memories) from the
  // shared backend, with mock fallback when offline.
  late final Future<List<GalleryItem>> _galleryFuture =
      ApiService.instance.fetchGallery();

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(
        title: 'Gallery',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'Family Gallery',
              subtitle:
                  'Official photos and guest memories approved by the admin team.',
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<GalleryItem>>(
              future: _galleryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final items = snapshot.data ?? const <GalleryItem>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in items) ...[
                      _GalleryCard(item: item),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
            ValueListenableBuilder<List<GuestUpload>>(
              valueListenable: AppState.uploads,
              builder: (context, uploads, _) {
                final approved = uploads
                    .where((upload) => upload.status == UploadStatus.approved)
                    .toList();
                if (approved.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const SectionTitle(title: 'Approved Guest Memories'),
                    const SizedBox(height: 12),
                    for (final upload in approved) ...[
                      SectionCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.passportGold.withValues(
                              alpha: 0.18,
                            ),
                            child: Icon(
                              upload.type == 'Video'
                                  ? Icons.videocam
                                  : Icons.photo,
                            ),
                          ),
                          title: Text(upload.caption),
                          subtitle: Text(
                            'Uploaded by ${upload.guestName} - ${upload.fileName}',
                          ),
                        ),
                      ),
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

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({required this.item});

  final GalleryItem item;

  void _open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          source: item.imageAsset,
          title: item.title,
          isVideo: item.isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              child: AspectRatio(
                aspectRatio: 1.55,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Videos have no still frame, so show a dark tile; photos
                    // show the image itself.
                    item.isVideo
                        ? const ColoredBox(color: Colors.black54)
                        : MediaImage(source: item.imageAsset),
                    if (item.isVideo)
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 56,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(item.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
