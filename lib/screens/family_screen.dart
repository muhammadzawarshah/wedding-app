import 'package:flutter/material.dart';

import '../models/wedding_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/media_image.dart';
import '../widgets/passport_background.dart';
import 'media_viewer_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  // Loads couple/family entries from the shared backend, with mock fallback.
  late final Future<List<FamilyMember>> _familyFuture =
      ApiService.instance.fetchFamily();

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(
        title: 'Family',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'Couple & Family',
              subtitle:
                  'Mom, dad, couple photos, and family side sections. Super admins manage this from the platform admin panel.',
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<FamilyMember>>(
              future: _familyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final family = snapshot.data ?? const <FamilyMember>[];
                final sides =
                    family.map((member) => member.side).toSet().toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final side in sides) ...[
                      Text(
                        side,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      for (final member
                          in family.where((item) => item.side == side)) ...[
                        Builder(builder: (context) {
                        // The relation tag shows when it has text and the admin
                        // hasn't hidden it for this member (showRelation toggle).
                        final relation = member.relation.trim();
                        final showRelation =
                            member.showRelation && relation.isNotEmpty;
                        final photos = member.imageAssets;
                        final hasPhotos = photos.isNotEmpty;
                        return SectionCard(
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: hasPhotos
                                    ? () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => GalleryViewerScreen(
                                            images: photos,
                                            title: member.name,
                                            description: member.description,
                                          ),
                                        ),
                                      )
                                    : null,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: MediaImage(
                                    source: member.imageAsset,
                                    width: 76,
                                    height: 76,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Relation reads as a gold eyebrow above the
                                    // name; the section heading already shows the
                                    // side, so we don't repeat it per card.
                                    if (showRelation) ...[
                                      Text(
                                        relation.toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.passportGold,
                                          fontSize: 11,
                                          letterSpacing: 1.4,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      member.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                        }),
                        const SizedBox(height: 12),
                      ],
                      const SizedBox(height: 8),
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
