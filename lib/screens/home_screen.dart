import 'dart:async';

import 'package:flutter/material.dart';

import '../data/mock_wedding_data.dart';
import '../models/wedding_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/hero_carousel.dart';
import '../widgets/passport_background.dart';
import 'admin_dashboard_screen.dart';
import 'chatbot_screen.dart';
import 'family_screen.dart';
import 'gallery_screen.dart';
import 'gift_screen.dart';
import 'itinerary_screen.dart';
import 'location_screen.dart';
import 'media_viewer_screen.dart';
import 'stream_screen.dart';
import 'upload_memories_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Fallback slides used if the admin-managed carousel can't be reached.
  static const List<String> _fallbackHeroImages = [
    'assets/images/couple_login.jpg',
    'assets/images/passport_invitation.jpeg',
    'assets/images/itinerary_slide_1.png',
    'assets/images/itinerary_slide_2.png',
    'assets/images/itinerary_slide_3.png',
    'assets/images/itinerary_slide_4.png',
  ];

  // Carousel slides managed by admins via the dashboard; empty -> fallback.
  late final Future<List<String>> _heroFuture = ApiService.instance
      .fetchCarousel();

  // Drives the "LIVE NOW" banner when the couple is broadcasting.
  late final Future<WeddingOverview> _overviewFuture = ApiService.instance
      .fetchOverview();

  Future<void> _showTransport(BuildContext context) async {
    const fallbackDescription =
        'On 17/07, there will be transport from Riga to the wedding place. Details will follow.';
    final overview = await ApiService.instance.fetchOverview().catchError(
      (_) => WeddingOverview.fallback,
    );
    if (!mounted || !context.mounted) return;
    final description = overview.transportDescription.trim().isNotEmpty
        ? overview.transportDescription.trim()
        : fallbackDescription;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.directions_bus),
            SizedBox(width: 8),
            Expanded(child: Text('Transport from Riga')),
          ],
        ),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Tiles shown for the signed-in user:
  ///   - "Upload Memories" is hidden from non-attending guests.
  ///   - "Admin Dashboard" is shown only to organisers/super-admins.
  List<FeatureItem> _visibleFeatures() {
    final user = ApiService.instance.currentUser;
    final canUpload = user?.canUploadMemories ?? true;
    final canModerate = user?.canModerate ?? false;
    return MockWeddingData.features
        .where((feature) {
          if (feature.title == 'Upload Memories' && !canUpload) return false;
          if (feature.title == 'Admin Dashboard' && !canModerate) return false;
          return true;
        })
        .toList(growable: false);
  }

  void _openFeature(BuildContext context, String title) {
    if (title == 'Transport') {
      unawaited(_showTransport(context));
      return;
    }
    final Widget screen = switch (title) {
      'Live Stream' => const StreamScreen(),
      'Send Gift' => const GiftScreen(),
      'Itinerary' => const ItineraryScreen(),
      'Gallery' => const GalleryScreen(),
      'Location' => const LocationScreen(),
      'Family' => const FamilyScreen(),
      'AI Assistant' => const ChatbotScreen(),
      'Upload Memories' => const UploadMemoriesScreen(),
      'Admin Dashboard' => AdminDashboardScreen(
        // The signed-in admin (set at login) — never a hardcoded identity.
        admin:
            ApiService.instance.currentUser ??
            const AdminUser(name: 'Admin', role: UserRole.organizer, code: ''),
      ),
      _ => const ItineraryScreen(),
    };

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openHeroImage(BuildContext context, String image) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MediaViewerScreen(source: image)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(
        title: 'Aija & Abhi',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "LIVE NOW" banner — appears while the couple is broadcasting.
            FutureBuilder<WeddingOverview>(
              future: _overviewFuture,
              builder: (context, snapshot) {
                final info = snapshot.data;
                if (info == null ||
                    !info.liveIsActive ||
                    info.streamUrl.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Material(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StreamScreen()),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 10,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                info.liveTitle.trim().isNotEmpty
                                    ? 'LIVE — ${info.liveTitle.trim()}'
                                    : 'LIVE NOW — Watch the ceremony',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            // Welcome hero banner (admin-managed, auto-playing carousel)
            Card(
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<List<String>>(
                future: _heroFuture,
                builder: (context, snapshot) {
                  final slides =
                      (snapshot.data == null || snapshot.data!.isEmpty)
                      ? _fallbackHeroImages
                      : snapshot.data!;
                  return HeroCarousel(
                    images: slides,
                    onImageTap: (image) => _openHeroImage(context, image),
                    overlay: Positioned(
                      left: 18,
                      right: 18,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WELCOME ABOARD',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.passportGold,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Aija & Abhi',
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Wedding Control Deck',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Live stream, gifts, itinerary, gallery, AI help, uploads, and admin moderation.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 680;
                final features = _visibleFeatures();
                return GridView.builder(
                  itemCount: features.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 3 : 2,
                    childAspectRatio: isWide ? 1.35 : 1.05,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final feature = features[index];
                    return _FeatureTile(
                      feature: feature,
                      onTap: () => _openFeature(context, feature.title),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.feature, required this.onTap});

  final FeatureItem feature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.passportGold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  feature.icon,
                  color: AppColors.passportGold,
                  size: 26,
                ),
              ),
              const Spacer(),
              Text(
                feature.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                feature.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
