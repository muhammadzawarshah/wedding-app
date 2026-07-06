import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/mock_wedding_data.dart';
import '../services/api_service.dart';
import '../services/my_uploads.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/guest_memories_wall.dart';
import '../widgets/passport_background.dart';

class UploadMemoriesScreen extends StatefulWidget {
  const UploadMemoriesScreen({super.key});

  @override
  State<UploadMemoriesScreen> createState() => _UploadMemoriesScreenState();
}

class _UploadMemoriesScreenState extends State<UploadMemoriesScreen> {
  final _nameController = TextEditingController();
  final _captionController = TextEditingController();
  final _picker = ImagePicker();

  String _type = 'Photo';
  XFile? _picked;
  String? _message;
  bool _submitting = false;
  int _refresh = 0; // bumped after a successful upload to reload the wall

  Future<void> _pickMedia() async {
    final XFile? file = _type == 'Video'
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1920,
            imageQuality: 88,
          );
    if (file == null) return;
    setState(() {
      _picked = file;
      _message = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _nameController.text.trim();
    final caption = _captionController.text.trim();

    if (name.isEmpty || caption.isEmpty) {
      setState(() => _message = 'Please add your name and a caption.');
      return;
    }
    if (_picked == null) {
      setState(() => _message = 'Please choose a $_type to upload.');
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });

    // 1) Upload the actual file so an admin can preview it before approving.
    final uploaded = await ApiService.instance.uploadGuestMedia(_picked!.path);
    if (uploaded == null) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _message =
            'The file could not be uploaded. Please check your connection and try again.';
      });
      return;
    }

    // 2) Create the moderation record pointing at the uploaded file.
    final uploadId = await ApiService.instance.createUpload(
      guestName: name,
      caption: caption,
      fileName: uploaded.fileName,
      mediaType: _type,
      fileSizeBytes: uploaded.size,
      fileUrl: uploaded.url,
    );

    // Remember this upload on the device so the guest sees their own pending
    // memory in the wall until an admin approves it.
    if (uploadId != null) {
      await MyUploads.add(
        MyUpload(
          id: uploadId,
          guestName: name,
          caption: caption,
          fileUrl: uploaded.url,
          mediaType: _type,
        ),
      );
    }

    // Local copy for offline admin viewing.
    AppState.addUpload(
      guestName: name,
      caption: caption,
      type: _type,
      fileName: uploaded.fileName,
      fileSizeBytes: uploaded.size,
    );

    if (!mounted) return;
    _nameController.clear();
    _captionController.clear();
    setState(() {
      _type = 'Photo';
      _picked = null;
      _submitting = false;
      _refresh++;
      _message = uploadId != null
          ? 'Memory submitted to the wedding team. It will appear for guests after admin approval.'
          : 'The file uploaded, but the record was not saved. Please try again.';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(
        title: 'Upload Memories',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle(
                    title: 'Share a photo or video',
                    subtitle:
                        'Choose a photo or video to send for admin approval before it appears in the gallery.',
                    light: false,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Your name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Memory type'),
                    items: const [
                      DropdownMenuItem(value: 'Photo', child: Text('Photo')),
                      DropdownMenuItem(value: 'Video', child: Text('Video')),
                    ],
                    onChanged: (value) => setState(() {
                      _type = value ?? 'Photo';
                      _picked = null; // reset selection when switching type
                    }),
                  ),
                  const SizedBox(height: 12),
                  _MediaPicker(
                    type: _type,
                    picked: _picked,
                    onPick: _pickMedia,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _captionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Caption'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload),
                    label: Text(
                      _submitting ? 'Uploading...' : 'Submit for Approval',
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _message!.startsWith('Memory submitted')
                            ? AppColors.success
                            : AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            GuestMemoriesWall(refreshToken: _refresh),
          ],
        ),
      ),
    );
  }
}

/// Tile that lets the guest choose a photo/video and previews the selection.
class _MediaPicker extends StatelessWidget {
  const _MediaPicker({
    required this.type,
    required this.picked,
    required this.onPick,
  });

  final String type;
  final XFile? picked;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.paperBlue.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.deepInk.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 56,
                child: picked == null
                    ? Icon(
                        type == 'Video' ? Icons.video_call : Icons.add_a_photo,
                        color: AppColors.deepInk,
                      )
                    : (type == 'Video'
                          ? const ColoredBox(
                              color: Colors.black54,
                              child: Icon(
                                Icons.play_circle_fill,
                                color: Colors.white,
                              ),
                            )
                          : Image.file(File(picked!.path), fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                picked == null
                    ? 'Tap to choose a $type from your device'
                    : picked!.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.attach_file),
          ],
        ),
      ),
    );
  }
}
