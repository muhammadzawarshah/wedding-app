import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/mock_wedding_data.dart';
import '../models/wedding_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/media_image.dart';
import '../widgets/passport_background.dart';
import 'admin/access_codes_screen.dart';
import 'admin/admin_panels.dart';
import 'admin/ai_notes_screen.dart';
import 'media_viewer_screen.dart';

/// The admin home: a hub showing live counts and tiles that open each
/// management panel (wedding settings, events, family, gallery, guest uploads,
/// home slider, FAQs, and the AI handoff queue).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({required this.admin, super.key});

  final AdminUser admin;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<DashboardStats?> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = ApiService.instance.fetchDashboardStats();
  }

  /// Reloads the header counts (e.g. after returning from a panel where the
  /// admin may have approved an upload or answered a question).
  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    setState(() => _statsFuture = ApiService.instance.fetchDashboardStats());
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.admin;
    return PassportBackground(
      child: AppScaffold(
        title: 'Admin Dashboard',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionCard(
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.admin_panel_settings)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          admin.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          admin.role == UserRole.superAdmin
                              ? 'Super admin: couple access'
                              : 'Organiser: main responder',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _StatsHeader(future: _statsFuture),
            const SizedBox(height: 20),
            const SectionTitle(
              title: 'Manage wedding content',
              subtitle: 'Tap any section to edit it.',
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _AdminTile(
                  icon: Icons.favorite,
                  label: 'Wedding details',
                  subtitle: 'Names, venue, links',
                  onTap: () => _open(const WeddingSettingsScreen()),
                ),
                _AdminTile(
                  icon: Icons.event,
                  label: 'Itinerary',
                  subtitle: 'Events & streams',
                  onTap: () => _open(const EventsScreen()),
                ),
                _AdminTile(
                  icon: Icons.family_restroom,
                  label: 'Family',
                  subtitle: 'Couple & family',
                  onTap: () => _open(const FamilyScreen()),
                ),
                _AdminTile(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  subtitle: 'Photos & videos',
                  onTap: () => _open(const GalleryAdminScreen()),
                ),
                _AdminTile(
                  icon: Icons.cloud_upload,
                  label: 'Guest Uploads',
                  subtitle: 'Approve / reject',
                  onTap: () => _open(UploadsScreen(admin: admin)),
                ),
                _AdminTile(
                  icon: Icons.view_carousel,
                  label: 'Home Slider',
                  subtitle: 'Carousel images',
                  onTap: () => _open(const CarouselScreen()),
                ),
                _AdminTile(
                  icon: Icons.card_giftcard,
                  label: 'Gifts & Payments',
                  subtitle: 'Currencies & links',
                  onTap: () => _open(const PaymentsScreen()),
                ),
                _AdminTile(
                  icon: Icons.quiz,
                  label: 'AI FAQs',
                  subtitle: 'Chatbot answers',
                  onTap: () => _open(const FaqsScreen()),
                ),
                _AdminTile(
                  icon: Icons.support_agent,
                  label: 'A&A Assistant and guide',
                  subtitle: 'Answer questions',
                  onTap: () => _open(HandoffScreen(admin: admin)),
                ),
                _AdminTile(
                  icon: Icons.sticky_note_2,
                  label: 'AI Notes',
                  subtitle: 'Knowledge for AI',
                  onTap: () => _open(AiNotesScreen(admin: admin)),
                ),
                _AdminTile(
                  icon: Icons.key,
                  label: 'Logins',
                  subtitle: 'Create access codes',
                  onTap: () => _open(const AccessCodesScreen()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Three live counters (pending uploads, unanswered questions, total uploads).
class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.future});

  final Future<DashboardStats?> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardStats?>(
      future: future,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        if (stats == null) {
          // Hide quietly when offline — the panels still work.
          return const SizedBox.shrink();
        }
        return Row(
          children: [
            _StatCard(
              label: 'Pending',
              value: stats.pendingUploads,
              color: AppColors.passportGold,
            ),
            const SizedBox(width: 10),
            _StatCard(
              label: 'Unanswered',
              value: stats.unansweredQuestions,
              color: AppColors.danger,
            ),
            const SizedBox(width: 10),
            _StatCard(
              label: 'Total uploads',
              value: stats.totalUploads,
              color: AppColors.success,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SectionCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.passportGold.withValues(alpha: 0.18),
                foregroundColor: AppColors.deepInk,
                child: Icon(icon),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Guest Uploads moderation screen
// ============================================================================

class UploadsScreen extends StatelessWidget {
  const UploadsScreen({required this.admin, super.key});

  final AdminUser admin;

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(
        title: 'Guest Uploads',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'Pending Guest Uploads',
              subtitle:
                  'Approve or reject photos/videos before they appear in gallery.',
            ),
            const SizedBox(height: 12),
            _UploadModeration(admin: admin),
          ],
        ),
      ),
    );
  }
}

class _UploadModeration extends StatefulWidget {
  const _UploadModeration({required this.admin});

  final AdminUser admin;

  @override
  State<_UploadModeration> createState() => _UploadModerationState();
}

class _UploadModerationState extends State<_UploadModeration> {
  late Future<List<GuestUpload>?> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.fetchUploads();
  }

  void _reload() {
    setState(() => _future = ApiService.instance.fetchUploads());
  }

  Future<void> _moderate(GuestUpload upload, UploadStatus status) async {
    final ok = await ApiService.instance.moderateUpload(
      id: upload.id,
      status: status,
      moderatedBy: widget.admin.name,
    );
    // Keep the local in-session copy in sync for offline viewing.
    AppState.updateUpload(upload.id, status);
    if (!mounted) return;
    if (ok) {
      _reload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not reach the server. Updated on this device only.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GuestUpload>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        // Online: show the shared backend list. Offline (null): fall back to
        // the local in-session uploads so the screen still works.
        final backend = snapshot.data;
        if (backend != null) {
          if (backend.isEmpty) {
            return const SectionCard(child: Text('No uploads yet.'));
          }
          return Column(children: [for (final u in backend) _card(u)]);
        }
        return ValueListenableBuilder<List<GuestUpload>>(
          valueListenable: AppState.uploads,
          builder: (context, uploads, _) {
            if (uploads.isEmpty) {
              return const SectionCard(child: Text('No uploads yet.'));
            }
            return Column(children: [for (final u in uploads) _card(u)]);
          },
        );
      },
    );
  }

  Widget _card(GuestUpload upload) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    upload.caption,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _UploadStatus(upload.status),
              ],
            ),
            const SizedBox(height: 6),
            Text('${upload.type} by ${upload.guestName}'),
            const SizedBox(height: 4),
            Text(
              'File: ${upload.fileName} (${_formatBytes(upload.fileSizeBytes)})',
            ),
            if (upload.hasMedia) ...[
              const SizedBox(height: 12),
              _MediaPreview(upload: upload),
            ],
            if (upload.status == UploadStatus.pending &&
                widget.admin.canModerate) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _moderate(upload, UploadStatus.rejected),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _moderate(upload, UploadStatus.approved),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// AI Handoff (chatbot questions) screen
// ============================================================================

class HandoffScreen extends StatelessWidget {
  const HandoffScreen({required this.admin, super.key});

  final AdminUser admin;

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(
        title: 'AI Handoff',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'AI Handoff Questions',
              subtitle:
                  'Questions the assistant could not answer are sent here. Organiser usually replies; super admins can also answer.',
            ),
            const SizedBox(height: 12),
            _QuestionModeration(admin: admin),
          ],
        ),
      ),
    );
  }
}

class _QuestionModeration extends StatefulWidget {
  const _QuestionModeration({required this.admin});

  final AdminUser admin;

  @override
  State<_QuestionModeration> createState() => _QuestionModerationState();
}

class _QuestionModerationState extends State<_QuestionModeration> {
  late Future<List<SupportQuestion>?> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.fetchHandoffs();
  }

  void _reload() {
    setState(() => _future = ApiService.instance.fetchHandoffs());
  }

  Future<void> _answer(SupportQuestion question, String answer) async {
    final ok = await ApiService.instance.answerHandoff(
      id: question.id,
      answer: answer,
      answeredBy: widget.admin.name,
    );
    AppState.answerQuestion(question.id, answer);
    if (!mounted) return;
    if (ok) {
      _reload();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not reach the server. Saved on this device only.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SupportQuestion>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final backend = snapshot.data;
        if (backend != null) {
          if (backend.isEmpty) {
            return const SectionCard(
              child: Text('No AI handoff questions yet.'),
            );
          }
          return Column(children: [for (final q in backend) _card(q)]);
        }
        return ValueListenableBuilder<List<SupportQuestion>>(
          valueListenable: AppState.supportQuestions,
          builder: (context, questions, _) {
            if (questions.isEmpty) {
              return const SectionCard(
                child: Text('No AI handoff questions yet.'),
              );
            }
            return Column(children: [for (final q in questions) _card(q)]);
          },
        );
      },
    );
  }

  Widget _card(SupportQuestion question) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _QuestionCard(
        question: question,
        canAnswer: widget.admin.canModerate,
        onAnswer: (answer) => _answer(question, answer),
      ),
    );
  }
}

class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    required this.question,
    required this.canAnswer,
    required this.onAnswer,
  });

  final SupportQuestion question;
  final bool canAnswer;
  final ValueChanged<String> onAnswer;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  final _answerController = TextEditingController();

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.question.question,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text('Asked by ${widget.question.askedBy}'),
          if (widget.question.isAnswered) ...[
            const SizedBox(height: 10),
            Text('Answer: ${widget.question.answer}'),
          ] else if (widget.canAnswer) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Reply as admin'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                final answer = _answerController.text.trim();
                if (answer.isNotEmpty) {
                  widget.onAnswer(answer);
                }
              },
              child: const Text('Send Reply'),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Home Slider (carousel) management screen
// ============================================================================

class CarouselScreen extends StatelessWidget {
  const CarouselScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(
        title: 'Home Slider',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'Home Slider Images',
              subtitle:
                  'Add or remove the photos shown in the app home screen carousel.',
            ),
            const SizedBox(height: 12),
            const _CarouselManager(),
          ],
        ),
      ),
    );
  }
}

/// Admin tool to manage the home screen carousel: pick an image from the
/// device, upload it to the backend, and add/remove slides.
class _CarouselManager extends StatefulWidget {
  const _CarouselManager();

  @override
  State<_CarouselManager> createState() => _CarouselManagerState();
}

class _CarouselManagerState extends State<_CarouselManager> {
  final _picker = ImagePicker();
  final _captionController = TextEditingController();

  late Future<List<CarouselSlide>> _slidesFuture;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _slidesFuture = ApiService.instance.fetchCarouselSlides();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _slidesFuture = ApiService.instance.fetchCarouselSlides());
  }

  Future<void> _addSlide() async {
    if (_busy) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    final url = await ApiService.instance.uploadMedia(picked.path);
    if (url == null) {
      _finish(
        'Upload failed. Please check the server connection and admin login.',
      );
      return;
    }

    final created = await ApiService.instance.createCarouselSlide(
      imageUrl: url,
      caption: _captionController.text.trim(),
    );
    if (!mounted) return;
    if (created) {
      _captionController.clear();
      _finish('Slide added ✓');
      _reload();
    } else {
      _finish('The slide could not be saved.');
    }
  }

  Future<void> _deleteSlide(CarouselSlide slide) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final ok = await ApiService.instance.deleteCarouselSlide(slide.id);
    if (!mounted) return;
    _finish(ok ? 'Slide deleted ✓' : 'The slide could not be deleted.');
    if (ok) _reload();
  }

  void _finish(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _captionController,
            decoration: const InputDecoration(
              labelText: 'Caption (optional)',
              hintText: 'e.g. Mehndi Night',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _busy ? null : _addSlide,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate),
            label: Text(_busy ? 'Working...' : 'Pick & upload image'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _message!.endsWith('✓')
                    ? AppColors.success
                    : AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FutureBuilder<List<CarouselSlide>>(
            future: _slidesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final slides = snapshot.data ?? const <CarouselSlide>[];
              if (slides.isEmpty) {
                return const Text('No slides yet. Add an image above.');
              }
              return Column(
                children: [
                  for (final slide in slides)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: MediaImage(
                              source: slide.imageUrl,
                              width: 64,
                              height: 44,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              slide.caption.isEmpty
                                  ? 'Slide ${slide.sortOrder}'
                                  : slide.caption,
                            ),
                          ),
                          IconButton(
                            onPressed: _busy ? null : () => _deleteSlide(slide),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Shared small widgets
// ============================================================================

/// Tappable preview of a guest's uploaded photo/video in the moderation list,
/// so the admin can actually see the media before approving. Opens full screen.
class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.upload});

  final GuestUpload upload;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaViewerScreen(
            source: upload.fileUrl!,
            title: upload.caption,
            isVideo: upload.isVideo,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              upload.isVideo
                  ? const ColoredBox(color: Colors.black54)
                  : MediaImage(source: upload.fileUrl!),
              if (upload.isVideo)
                const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Tap to preview',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

class _UploadStatus extends StatelessWidget {
  const _UploadStatus(this.status);

  final UploadStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      UploadStatus.pending => const StatusChip(
        label: 'Pending',
        color: AppColors.passportGold,
      ),
      UploadStatus.approved => const StatusChip(
        label: 'Approved',
        color: AppColors.success,
      ),
      UploadStatus.rejected => const StatusChip(
        label: 'Rejected',
        color: AppColors.danger,
      ),
    };
  }
}
