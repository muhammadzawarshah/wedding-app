import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/wedding_models.dart';
import '../screens/media_viewer_screen.dart';
import '../services/api_service.dart';
import '../services/my_uploads.dart';
import 'app_components.dart';
import 'media_image.dart';

class _Memory {
  _Memory({
    required this.id,
    required this.guestName,
    required this.caption,
    required this.url,
    required this.isVideo,
    required this.pending,
  });

  final String id;
  final String guestName;
  final String caption;
  final String url;
  final bool isVideo;
  final bool pending;
}

/// Public wall of guest memories: approved uploads (visible to everyone) plus
/// this device's own not-yet-approved uploads (marked "Pending"). Rejected
/// own-uploads are dropped from local storage.
class GuestMemoriesWall extends StatefulWidget {
  const GuestMemoriesWall({super.key, this.refreshToken = 0});

  /// Bump this to force a reload (e.g. after the guest submits a new memory).
  final int refreshToken;

  @override
  State<GuestMemoriesWall> createState() => _GuestMemoriesWallState();
}

class _GuestMemoriesWallState extends State<GuestMemoriesWall> {
  late Future<List<_Memory>> _future = _load();

  Future<List<_Memory>> _load() async {
    final approved = await ApiService.instance.fetchApprovedUploads();
    final approvedIds = approved.map((u) => u.id).toSet();

    final mine = await MyUploads.all();
    final stillMine = <MyUpload>[];
    final ownPending = <_Memory>[];
    for (final u in mine) {
      if (approvedIds.contains(u.id)) {
        stillMine.add(u);
        continue;
      }
      final record = await ApiService.instance.fetchUploadById(u.id);
      if (record != null && record.status == UploadStatus.rejected) {
        continue; // drop rejected from local store
      }
      stillMine.add(u);
      if (record == null || record.status != UploadStatus.approved) {
        ownPending.add(
          _Memory(
            id: u.id,
            guestName: u.guestName,
            caption: u.caption,
            url: AppConfig.resolveMedia(u.fileUrl),
            isVideo: u.isVideo,
            pending: true,
          ),
        );
      }
    }
    await MyUploads.replace(stillMine);

    final seen = ownPending.map((m) => m.id).toSet();
    final approvedMemories = approved
        .where((u) => !seen.contains(u.id) && u.hasMedia)
        .map(
          (u) => _Memory(
            id: u.id,
            guestName: u.guestName,
            caption: u.caption,
            url: u.fileUrl!,
            isVideo: u.isVideo,
            pending: false,
          ),
        );
    return [...ownPending, ...approvedMemories];
  }

  @override
  void didUpdateWidget(covariant GuestMemoriesWall oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      setState(() => _future = _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_Memory>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final memories = snapshot.data ?? const <_Memory>[];
        if (memories.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'Guest Memories',
              subtitle:
                  'Approved photos and videos shared by guests. Your upload appears as "Pending" until an admin approves it.',
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: memories.length,
              itemBuilder: (context, index) =>
                  _MemoryTile(memory: memories[index]),
            ),
          ],
        );
      },
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.memory});

  final _Memory memory;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(
            source: memory.url,
            isVideo: memory.isVideo,
            title: memory.guestName,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (memory.isVideo)
              const ColoredBox(
                color: Colors.black54,
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 34,
                ),
              )
            else
              MediaImage(source: memory.url, fit: BoxFit.cover),
            if (memory.pending)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF3A2D05),
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
