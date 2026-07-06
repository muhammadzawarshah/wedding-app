import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_config.dart';
import '../../models/wedding_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_components.dart';
import '../../widgets/media_image.dart';
import '../../widgets/passport_background.dart';
import '../media_viewer_screen.dart';

// ============================================================================
// Shared admin helpers
// ============================================================================

/// Success (ends with ✓) / error message line shown under admin forms.
class _ResultMessage extends StatelessWidget {
  const _ResultMessage(this.message);

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final ok = text.endsWith('✓');
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: ok ? AppColors.success : AppColors.danger,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Confirmation dialog used before any destructive delete.
Future<bool> _confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete?'),
      content: Text('$what will be permanently deleted. Are you sure?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Picks an image from the gallery and uploads it via `POST /admin/media`,
/// returning the stored (relative) URL, or null if cancelled / failed.
Future<String?> _pickAndUploadImage() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1920,
    imageQuality: 85,
  );
  if (picked == null) return null;
  return ApiService.instance.uploadMedia(picked.path);
}

/// Wraps a panel body in the standard passport background + scaffold so each
/// management screen looks consistent with the rest of the app.
class _PanelScaffold extends StatelessWidget {
  const _PanelScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(title: title, child: child),
    );
  }
}

/// Loading / empty / offline states shared by the list panels.
class _ListState extends StatelessWidget {
  const _ListState({required this.loading, required this.message});

  final bool loading;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SectionCard(child: Text(message));
  }
}

// ============================================================================
// 1. Wedding Settings
// ============================================================================

class WeddingSettingsScreen extends StatefulWidget {
  const WeddingSettingsScreen({super.key});

  @override
  State<WeddingSettingsScreen> createState() => _WeddingSettingsScreenState();
}

class _WeddingSettingsScreenState extends State<WeddingSettingsScreen> {
  final _bride = TextEditingController();
  final _groom = TextEditingController();
  final _date = TextEditingController();
  final _venueName = TextEditingController();
  final _venueAddress = TextEditingController();
  final _venueUrl = TextEditingController();
  final _transportDescription = TextEditingController();
  final _mapUrl = TextEditingController();
  final _streamUrl = TextEditingController();
  final _giftUrl = TextEditingController();
  final _liveTitle = TextEditingController();
  bool _liveIsActive = false;

  bool _loading = true;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _bride,
      _groom,
      _date,
      _venueName,
      _venueAddress,
      _venueUrl,
      _transportDescription,
      _mapUrl,
      _streamUrl,
      _giftUrl,
      _liveTitle,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final overview = await ApiService.instance.fetchOverview();
    if (!mounted) return;
    _bride.text = overview.brideName;
    _groom.text = overview.groomName;
    _date.text = overview.weddingDate;
    _venueName.text = overview.venueName;
    _venueAddress.text = overview.venueAddress;
    _venueUrl.text = overview.venueUrl;
    _transportDescription.text = overview.transportDescription;
    _mapUrl.text = overview.mapUrl;
    _streamUrl.text = overview.streamUrl;
    _giftUrl.text = overview.giftUrl;
    _liveTitle.text = overview.liveTitle;
    setState(() {
      _liveIsActive = overview.liveIsActive;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_bride.text.trim().isEmpty || _groom.text.trim().isEmpty) {
      setState(() => _message = 'Bride and groom names are required.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    final overview = WeddingOverview(
      brideName: _bride.text.trim(),
      groomName: _groom.text.trim(),
      weddingDate: _date.text.trim(),
      venueName: _venueName.text.trim(),
      venueAddress: _venueAddress.text.trim(),
      venueUrl: _venueUrl.text.trim(),
      transportDescription: _transportDescription.text.trim(),
      mapUrl: _mapUrl.text.trim(),
      streamUrl: _streamUrl.text.trim(),
      giftUrl: _giftUrl.text.trim(),
      liveTitle: _liveTitle.text.trim(),
      liveIsActive: _liveIsActive,
    );
    final ok = await ApiService.instance.updateWedding(overview.toAdminJson());
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = ok
          ? 'Wedding details saved ✓'
          : 'The wedding details could not be saved. Please check the server.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'Wedding details',
      child: _loading
          ? const _ListState(loading: true, message: '')
          : SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _field(_bride, 'Bride name'),
                  _field(_groom, 'Groom name'),
                  _field(_date, 'Wedding date', hint: 'e.g. 11 July 2026'),
                  _field(_venueName, 'Venue name'),
                  _field(_venueAddress, 'Venue address', lines: 2),
                  _field(
                    _venueUrl,
                    'Venue website (URL)',
                    hint: 'The venue\'s own website — shown as a link',
                    keyboard: TextInputType.url,
                  ),
                  _field(
                    _transportDescription,
                    'Transport popup description',
                    hint:
                        'e.g. On 17/07, transport will run from Riga to the venue.',
                    lines: 3,
                  ),
                  _field(
                    _mapUrl,
                    'Map link (URL)',
                    keyboard: TextInputType.url,
                  ),
                  _field(
                    _streamUrl,
                    'Live stream link (URL)',
                    keyboard: TextInputType.url,
                  ),
                  _field(
                    _giftUrl,
                    'Gift / registry link (URL)',
                    keyboard: TextInputType.url,
                  ),
                  _field(
                    _liveTitle,
                    'Live banner title',
                    hint: 'e.g. Nikkah Live Now',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Live stream active'),
                    subtitle: const Text(
                      'Shows the "Live" banner on the home screen.',
                    ),
                    value: _liveIsActive,
                    onChanged: (v) => setState(() => _liveIsActive = v),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Saving...' : 'Save changes'),
                  ),
                  _ResultMessage(_message),
                ],
              ),
            ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int lines = 1,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: lines,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

// ============================================================================
// 2. Events
// ============================================================================

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late Future<AdminContent?> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.fetchAdminContent();
  }

  void _reload() {
    setState(() => _future = ApiService.instance.fetchAdminContent());
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _edit({WeddingEvent? existing}) async {
    final result = await showModalBottomSheet<WeddingEvent>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EventEditorSheet(initial: existing),
    );
    if (result == null) return;
    final ok = existing == null
        ? await ApiService.instance.createContent(
            'events',
            result.toAdminJson(),
          )
        : await ApiService.instance.updateContent(
            'events',
            existing.id,
            result.toAdminJson(),
          );
    _snack(
      ok
          ? (existing == null ? 'Event added ✓' : 'Event updated ✓')
          : 'The event could not be saved.',
    );
    if (ok) _reload();
  }

  Future<void> _delete(WeddingEvent event) async {
    if (!await _confirmDelete(context, 'Event "${event.title}"')) return;
    final ok = await ApiService.instance.deleteContent('events', event.id);
    _snack(ok ? 'Event deleted ✓' : 'The event could not be deleted.');
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'Itinerary',
      child: FutureBuilder<AdminContent?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ListState(loading: true, message: '');
          }
          final content = snapshot.data;
          if (content == null) {
            return const _ListState(
              loading: false,
              message:
                  'Could not reach the server. Please check your connection.',
            );
          }
          final events = content.events;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Add event'),
              ),
              const SizedBox(height: 16),
              if (events.isEmpty)
                const SectionCard(child: Text('No events yet.'))
              else
                for (final e in events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              if (e.isLive)
                                const StatusChip(
                                  label: 'Live',
                                  color: AppColors.danger,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${e.date} • ${e.time}'),
                          if (e.venue.isNotEmpty) Text(e.venue),
                          if (e.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              e.description,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _EditDeleteRow(
                            onEdit: () => _edit(existing: e),
                            onDelete: () => _delete(e),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({this.initial});

  final WeddingEvent? initial;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _date = TextEditingController(text: widget.initial?.date ?? '');
  late final _time = TextEditingController(text: widget.initial?.time ?? '');
  late final _venue = TextEditingController(text: widget.initial?.venue ?? '');
  late final _desc = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final _stream = TextEditingController(
    text: widget.initial?.streamUrl ?? '',
  );
  late final _recording = TextEditingController(
    text: widget.initial?.recordingUrl ?? '',
  );
  late final _sortOrder = TextEditingController(
    text: (widget.initial?.sortOrder ?? 0).toString(),
  );
  late bool _isLive = widget.initial?.isLive ?? false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _title,
      _date,
      _time,
      _venue,
      _desc,
      _stream,
      _recording,
      _sortOrder,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_title.text.trim().isEmpty ||
        _date.text.trim().isEmpty ||
        _time.text.trim().isEmpty ||
        _venue.text.trim().isEmpty ||
        _desc.text.trim().isEmpty) {
      setState(
        () => _error = 'Title, date, time, venue and description are required.',
      );
      return;
    }
    Navigator.pop(
      context,
      WeddingEvent(
        title: _title.text.trim(),
        date: _date.text.trim(),
        time: _time.text.trim(),
        venue: _venue.text.trim(),
        description: _desc.text.trim(),
        streamUrl: _stream.text.trim(),
        recordingUrl: _recording.text.trim(),
        isLive: _isLive,
        sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditorSheetShell(
      title: widget.initial == null ? 'Add event' : 'Edit event',
      onSave: _submit,
      children: [
        _sheetField(_title, 'Event title', hint: 'e.g. Mehndi Night'),
        _sheetField(_date, 'Date', hint: 'e.g. Day 1 / 11 July'),
        _sheetField(_time, 'Time', hint: 'e.g. 6:00 PM'),
        _sheetField(_venue, 'Venue'),
        _sheetField(_desc, 'Description', lines: 2),
        _sheetField(
          _stream,
          'Live stream URL (optional)',
          keyboard: TextInputType.url,
        ),
        _sheetField(
          _recording,
          'Recording URL (optional)',
          keyboard: TextInputType.url,
        ),
        _sheetField(
          _sortOrder,
          'Order (0 = first)',
          keyboard: TextInputType.number,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Live now'),
          value: _isLive,
          onChanged: (v) => setState(() => _isLive = v),
        ),
        _ResultMessage(_error),
      ],
    );
  }
}

// ============================================================================
// 3. Family
// ============================================================================

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  late Future<AdminContent?> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.fetchAdminContent();
  }

  void _reload() {
    setState(() => _future = ApiService.instance.fetchAdminContent());
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _edit({FamilyMember? existing}) async {
    final result = await showModalBottomSheet<FamilyMember>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FamilyEditorSheet(initial: existing),
    );
    if (result == null) return;
    final ok = existing == null
        ? await ApiService.instance.createContent(
            'family',
            result.toAdminJson(),
          )
        : await ApiService.instance.updateContent(
            'family',
            existing.id,
            result.toAdminJson(),
          );
    _snack(
      ok
          ? (existing == null ? 'Family member added ✓' : 'Updated ✓')
          : 'The family member could not be saved.',
    );
    if (ok) _reload();
  }

  Future<void> _delete(FamilyMember member) async {
    if (!await _confirmDelete(context, '"${member.name}"')) return;
    final ok = await ApiService.instance.deleteContent('family', member.id);
    _snack(ok ? 'Deleted ✓' : 'The family member could not be deleted.');
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'Family',
      child: FutureBuilder<AdminContent?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ListState(loading: true, message: '');
          }
          final content = snapshot.data;
          if (content == null) {
            return const _ListState(
              loading: false,
              message:
                  'Could not reach the server. Please check your connection.',
            );
          }
          final family = content.family;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.person_add),
                label: const Text('Add family member'),
              ),
              const SizedBox(height: 16),
              if (family.isEmpty)
                const SectionCard(child: Text('No family members yet.'))
              else
                for (final m in family)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SectionCard(
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: m.isRemoteImage
                                ? MediaImage(
                                    source: m.imageAsset,
                                    width: 52,
                                    height: 52,
                                  )
                                : Container(
                                    width: 52,
                                    height: 52,
                                    color: AppColors.paperBlueDark,
                                    child: const Icon(
                                      Icons.person,
                                      color: AppColors.mutedInk,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                Text('${m.relation} • ${m.side}'),
                              ],
                            ),
                          ),
                          _EditDeleteRow(
                            onEdit: () => _edit(existing: m),
                            onDelete: () => _delete(m),
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _FamilyEditorSheet extends StatefulWidget {
  const _FamilyEditorSheet({this.initial});

  final FamilyMember? initial;

  @override
  State<_FamilyEditorSheet> createState() => _FamilyEditorSheetState();
}

class _FamilyEditorSheetState extends State<_FamilyEditorSheet> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _relation = TextEditingController(
    text: widget.initial?.relation ?? '',
  );
  late final _side = TextEditingController(text: widget.initial?.side ?? '');
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final _sortOrder = TextEditingController(
    text: (widget.initial?.sortOrder ?? 0).toString(),
  );
  late List<String> _images = _initialImages();
  late bool _showRelation = widget.initial?.showRelation ?? true;
  bool _uploading = false;
  String? _error;

  List<String> _initialImages() {
    final imgs = widget.initial?.rawImages ?? const <String>[];
    if (imgs.isNotEmpty) return List<String>.from(imgs);
    final single = widget.initial?.rawImageUrl ?? '';
    return single.isNotEmpty ? <String>[single] : <String>[];
  }

  @override
  void dispose() {
    _name.dispose();
    _relation.dispose();
    _side.dispose();
    _description.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _addImage() async {
    setState(() => _uploading = true);
    final url = await _pickAndUploadImage();
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) {
        _images = [..._images, url];
        _error = null;
      } else {
        _error =
            'The image could not be uploaded. Please check the server and admin login.';
      }
    });
  }

  void _removeImage(int index) {
    setState(() {
      _images = [
        for (var i = 0; i < _images.length; i++)
          if (i != index) _images[i],
      ];
    });
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _side.text.trim().isEmpty) {
      setState(() => _error = 'Name and side are required.');
      return;
    }
    Navigator.pop(
      context,
      FamilyMember(
        name: _name.text.trim(),
        relation: _relation.text.trim(),
        side: _side.text.trim(),
        description: _description.text.trim(),
        imageAsset: '',
        rawImageUrl: _images.isNotEmpty ? _images.first : '',
        rawImages: _images,
        showRelation: _showRelation,
        sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditorSheetShell(
      title: widget.initial == null
          ? 'Add family member'
          : 'Edit family member',
      onSave: _submit,
      children: [
        _sheetField(_name, 'Name'),
        _sheetField(_relation, 'Relation', hint: 'e.g. Mom & Dad / Bride'),
        _sheetField(
          _side,
          'Side',
          hint: "e.g. Couple / Groom's Family / Pets",
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show relationship tag'),
          subtitle: const Text('Turn off to hide the relation label.'),
          value: _showRelation,
          onChanged: (v) => setState(() => _showRelation = v),
        ),
        _sheetField(
          _description,
          'Description (optional)',
          hint: 'Shown beside the photos when a guest opens them',
          lines: 3,
        ),
        _sheetField(
          _sortOrder,
          'Order (0 = first)',
          keyboard: TextInputType.number,
        ),
        const SizedBox(height: 8),
        const Text('Photos — first is the cover; guests browse the rest'),
        const SizedBox(height: 8),
        _MultiPhotoGrid(
          images: _images,
          uploading: _uploading,
          onAdd: _addImage,
          onRemove: _removeImage,
        ),
        _ResultMessage(_error),
      ],
    );
  }
}

/// A wrap of photo thumbnails (first = cover) with add + remove, used by the
/// family editor for multiple images.
class _MultiPhotoGrid extends StatelessWidget {
  const _MultiPhotoGrid({
    required this.images,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> images;
  final bool uploading;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < images.length; i++)
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: MediaImage(
                    source: AppConfig.resolveMedia(images[i]),
                    width: 74,
                    height: 74,
                  ),
                ),
                if (i == 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      color: AppColors.passportGold.withValues(alpha: 0.92),
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: const Text(
                        'Cover',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F292E),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => onRemove(i),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: 74,
          height: 74,
          child: OutlinedButton(
            onPressed: uploading ? null : onAdd,
            style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
            child: uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 4. Gallery
// ============================================================================

class GalleryAdminScreen extends StatefulWidget {
  const GalleryAdminScreen({super.key});

  @override
  State<GalleryAdminScreen> createState() => _GalleryAdminScreenState();
}

class _GalleryAdminScreenState extends State<GalleryAdminScreen> {
  late Future<AdminContent?> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.fetchAdminContent();
  }

  void _reload() {
    setState(() => _future = ApiService.instance.fetchAdminContent());
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _edit({GalleryItem? existing}) async {
    final result = await showModalBottomSheet<GalleryItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GalleryEditorSheet(initial: existing),
    );
    if (result == null) return;
    final ok = existing == null
        ? await ApiService.instance.createContent(
            'gallery',
            result.toAdminJson(),
          )
        : await ApiService.instance.updateContent(
            'gallery',
            existing.id,
            result.toAdminJson(),
          );
    _snack(
      ok
          ? (existing == null ? 'Gallery item added ✓' : 'Updated ✓')
          : 'The gallery item could not be saved.',
    );
    if (ok) _reload();
  }

  Future<void> _delete(GalleryItem item) async {
    if (!await _confirmDelete(context, '"${item.title}"')) return;
    final ok = await ApiService.instance.deleteContent('gallery', item.id);
    _snack(ok ? 'Deleted ✓' : 'The gallery item could not be deleted.');
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'Gallery',
      child: FutureBuilder<AdminContent?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ListState(loading: true, message: '');
          }
          final content = snapshot.data;
          if (content == null) {
            return const _ListState(
              loading: false,
              message:
                  'Could not reach the server. Please check your connection.',
            );
          }
          final gallery = content.gallery;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add gallery item'),
              ),
              const SizedBox(height: 16),
              if (gallery.isEmpty)
                const SectionCard(child: Text('The gallery is empty.'))
              else
                for (final g in gallery)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SectionCard(
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: g.isRemoteImage
                                ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MediaViewerScreen(
                                        source: g.imageAsset,
                                        title: g.title,
                                        isVideo: g.isVideo,
                                      ),
                                    ),
                                  )
                                : null,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Stack(
                                children: [
                                  g.isRemoteImage && !g.isVideo
                                      ? MediaImage(
                                          source: g.imageAsset,
                                          width: 64,
                                          height: 64,
                                        )
                                      : Container(
                                          width: 64,
                                          height: 64,
                                          color: AppColors.paperBlueDark,
                                          child: Icon(
                                            g.isVideo
                                                ? Icons.play_circle_fill
                                                : Icons.image,
                                            color: AppColors.mutedInk,
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if (g.caption.isNotEmpty)
                                  Text(
                                    g.caption,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                Text(
                                  g.isVideo ? 'Video' : 'Photo',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          _EditDeleteRow(
                            onEdit: () => _edit(existing: g),
                            onDelete: () => _delete(g),
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _GalleryEditorSheet extends StatefulWidget {
  const _GalleryEditorSheet({this.initial});

  final GalleryItem? initial;

  @override
  State<_GalleryEditorSheet> createState() => _GalleryEditorSheetState();
}

class _GalleryEditorSheetState extends State<_GalleryEditorSheet> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _caption = TextEditingController(
    text: widget.initial?.caption ?? '',
  );
  late final _mediaUrl = TextEditingController(
    text: widget.initial?.rawMediaUrl ?? '',
  );
  late bool _isVideo = widget.initial?.isVideo ?? false;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    _mediaUrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _uploading = true);
    final url = await _pickAndUploadImage();
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) _mediaUrl.text = url;
      _error = url == null
          ? 'The image could not be uploaded. Please check the server and admin login.'
          : null;
    });
  }

  void _submit() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    if (_mediaUrl.text.trim().isEmpty) {
      setState(
        () => _error =
            'Media URL is required. Pick a photo or paste a video link.',
      );
      return;
    }
    Navigator.pop(
      context,
      GalleryItem(
        title: _title.text.trim(),
        caption: _caption.text.trim(),
        imageAsset: '',
        rawMediaUrl: _mediaUrl.text.trim(),
        isVideo: _isVideo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditorSheetShell(
      title: widget.initial == null ? 'Add gallery item' : 'Edit gallery item',
      onSave: _submit,
      children: [
        _sheetField(_title, 'Title'),
        _sheetField(_caption, 'Caption', lines: 2),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('This is a video'),
          subtitle: const Text('Turn this on, then paste the video URL below.'),
          value: _isVideo,
          onChanged: (v) => setState(() => _isVideo = v),
        ),
        _sheetField(_mediaUrl, 'Media URL', keyboard: TextInputType.url),
        if (!_isVideo) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickImage,
            icon: _uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload),
            label: Text(_uploading ? 'Uploading...' : 'Pick & upload photo'),
          ),
        ],
        _ResultMessage(_error),
      ],
    );
  }
}

// ============================================================================
// 5. FAQs
// ============================================================================

class FaqsScreen extends StatefulWidget {
  const FaqsScreen({super.key});

  @override
  State<FaqsScreen> createState() => _FaqsScreenState();
}

class _FaqsScreenState extends State<FaqsScreen> {
  late Future<AdminContent?> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.fetchAdminContent();
  }

  void _reload() {
    setState(() => _future = ApiService.instance.fetchAdminContent());
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _edit({FaqEntry? existing}) async {
    final result = await showModalBottomSheet<FaqEntry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FaqEditorSheet(initial: existing),
    );
    if (result == null) return;
    final ok = existing == null
        ? await ApiService.instance.createContent('faqs', result.toAdminJson())
        : await ApiService.instance.updateContent(
            'faqs',
            existing.id,
            result.toAdminJson(),
          );
    _snack(
      ok
          ? (existing == null ? 'FAQ added ✓' : 'FAQ updated ✓')
          : 'The FAQ could not be saved.',
    );
    if (ok) _reload();
  }

  Future<void> _delete(FaqEntry faq) async {
    if (!await _confirmDelete(context, 'FAQ "${faq.keyword}"')) return;
    final ok = await ApiService.instance.deleteContent('faqs', faq.id);
    _snack(ok ? 'Deleted ✓' : 'The FAQ could not be deleted.');
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'AI FAQs',
      child: FutureBuilder<AdminContent?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ListState(loading: true, message: '');
          }
          final content = snapshot.data;
          if (content == null) {
            return const _ListState(
              loading: false,
              message:
                  'Could not reach the server. Please check your connection.',
            );
          }
          final faqs = content.faqs;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle(
                title: 'Chatbot answers',
                subtitle:
                    'Keywords and answers used by the AI Assistant when guests ask questions.',
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Add FAQ'),
              ),
              const SizedBox(height: 16),
              if (faqs.isEmpty)
                const SectionCard(child: Text('No FAQs yet.'))
              else
                for (final f in faqs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.keyword,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(f.answer),
                          const SizedBox(height: 8),
                          _EditDeleteRow(
                            onEdit: () => _edit(existing: f),
                            onDelete: () => _delete(f),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _FaqEditorSheet extends StatefulWidget {
  const _FaqEditorSheet({this.initial});

  final FaqEntry? initial;

  @override
  State<_FaqEditorSheet> createState() => _FaqEditorSheetState();
}

class _FaqEditorSheetState extends State<_FaqEditorSheet> {
  late final _keyword = TextEditingController(
    text: widget.initial?.keyword ?? '',
  );
  late final _answer = TextEditingController(
    text: widget.initial?.answer ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _keyword.dispose();
    _answer.dispose();
    super.dispose();
  }

  void _submit() {
    if (_keyword.text.trim().isEmpty || _answer.text.trim().isEmpty) {
      setState(() => _error = 'Keyword and answer are both required.');
      return;
    }
    Navigator.pop(
      context,
      FaqEntry(
        id: widget.initial?.id ?? '',
        keyword: _keyword.text.trim(),
        answer: _answer.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditorSheetShell(
      title: widget.initial == null ? 'Add FAQ' : 'Edit FAQ',
      onSave: _submit,
      children: [
        _sheetField(
          _keyword,
          'Keyword / question',
          hint: 'e.g. timing, parking, dress code',
        ),
        _sheetField(_answer, 'Answer', lines: 4),
        _ResultMessage(_error),
      ],
    );
  }
}

// ============================================================================
// Gifts & Payments
// ============================================================================

const List<String> _currencyCodes = [
  'GBP', 'EUR', 'USD', 'PKR', 'INR', 'AED',
  'SAR', 'CAD', 'AUD', 'BDT', 'TRY', 'CHF',
];

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  late Future<AdminContent?> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.fetchAdminContent();
  }

  void _reload() {
    setState(() => _future = ApiService.instance.fetchAdminContent());
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _edit({PaymentMethod? existing}) async {
    final result = await showModalBottomSheet<PaymentMethod>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaymentEditorSheet(initial: existing),
    );
    if (result == null) return;
    final ok = existing == null
        ? await ApiService.instance.createContent(
            'payments',
            result.toAdminJson(),
          )
        : await ApiService.instance.updateContent(
            'payments',
            existing.id,
            result.toAdminJson(),
          );
    _snack(
      ok
          ? (existing == null ? 'Payment method added ✓' : 'Updated ✓')
          : 'The payment method could not be saved.',
    );
    if (ok) _reload();
  }

  Future<void> _delete(PaymentMethod p) async {
    if (!await _confirmDelete(context, '${p.currency} ${p.typeLabel}')) return;
    final ok = await ApiService.instance.deleteContent('payments', p.id);
    _snack(ok ? 'Deleted ✓' : 'The payment method could not be deleted.');
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return _PanelScaffold(
      title: 'Gifts & Payments',
      child: FutureBuilder<AdminContent?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ListState(loading: true, message: '');
          }
          final content = snapshot.data;
          if (content == null) {
            return const _ListState(
              loading: false,
              message:
                  'Could not reach the server. Please check your connection.',
            );
          }
          final payments = content.payments;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionCard(
                child: Text(
                  'Add a gift option per currency. Guests pick a currency, then '
                  'pay by link, QR code, or bank details.',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Add payment method'),
              ),
              const SizedBox(height: 16),
              if (payments.isEmpty)
                const SectionCard(child: Text('No payment methods yet.'))
              else
                for (final p in payments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SectionCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${p.currency} • ${p.typeLabel}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if (p.description.isNotEmpty)
                                  Text(p.description),
                              ],
                            ),
                          ),
                          _EditDeleteRow(
                            onEdit: () => _edit(existing: p),
                            onDelete: () => _delete(p),
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentEditorSheet extends StatefulWidget {
  const _PaymentEditorSheet({this.initial});

  final PaymentMethod? initial;

  @override
  State<_PaymentEditorSheet> createState() => _PaymentEditorSheetState();
}

class _PaymentEditorSheetState extends State<_PaymentEditorSheet> {
  late String _currency = (widget.initial?.currency.isNotEmpty ?? false)
      ? widget.initial!.currency
      : _currencyCodes.first;
  late String _type = widget.initial?.type ?? 'link';
  late final _link = TextEditingController(text: widget.initial?.link ?? '');
  late final _account = TextEditingController(
    text: widget.initial?.accountDetails ?? '',
  );
  late final _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final _sortOrder = TextEditingController(
    text: (widget.initial?.sortOrder ?? 0).toString(),
  );
  late String _qrUrl = widget.initial?.rawQrUrl ?? '';
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    _account.dispose();
    _description.dispose();
    _sortOrder.dispose();
    super.dispose();
  }

  Future<void> _pickQr() async {
    setState(() => _uploading = true);
    final url = await _pickAndUploadImage();
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (url != null) {
        _qrUrl = url;
        _error = null;
      } else {
        _error = 'The QR image could not be uploaded.';
      }
    });
  }

  void _submit() {
    if (_type == 'link' && _link.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the payment link.');
      return;
    }
    if (_type == 'qr' && _qrUrl.isEmpty) {
      setState(() => _error = 'Please upload a QR image.');
      return;
    }
    if (_type == 'account' && _account.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the account details.');
      return;
    }
    Navigator.pop(
      context,
      PaymentMethod(
        id: widget.initial?.id ?? '',
        currency: _currency,
        type: _type,
        link: _type == 'link' ? _link.text.trim() : '',
        rawQrUrl: _type == 'qr' ? _qrUrl : '',
        accountDetails: _type == 'account' ? _account.text.trim() : '',
        description: _description.text.trim(),
        active: true,
        sortOrder: int.tryParse(_sortOrder.text.trim()) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditorSheetShell(
      title: widget.initial == null
          ? 'Add payment method'
          : 'Edit payment method',
      onSave: _submit,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _currency,
          decoration: const InputDecoration(labelText: 'Currency'),
          items: [
            for (final c in _currencyCodes)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => setState(() => _currency = v ?? _currency),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Payment type'),
          items: const [
            DropdownMenuItem(value: 'link', child: Text('Link (PayPal / Wise)')),
            DropdownMenuItem(value: 'qr', child: Text('QR code (scan to pay)')),
            DropdownMenuItem(
              value: 'account',
              child: Text('Bank / account details'),
            ),
          ],
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        const SizedBox(height: 14),
        if (_type == 'link')
          _sheetField(
            _link,
            'Payment link (URL)',
            hint: 'https://paypal.me/…',
            keyboard: TextInputType.url,
          ),
        if (_type == 'qr') ...[
          const Text('QR code image (guests scan to pay)'),
          const SizedBox(height: 8),
          _PhotoPickerRow(
            imageUrl: _qrUrl,
            uploading: _uploading,
            onPick: _pickQr,
          ),
          const SizedBox(height: 14),
        ],
        if (_type == 'account')
          _sheetField(
            _account,
            'Account details',
            hint: 'Bank name, account number, IBAN…',
            lines: 3,
          ),
        _sheetField(
          _description,
          'Note for guests (optional)',
          hint: 'e.g. Please add your name as the reference',
          lines: 2,
        ),
        _sheetField(
          _sortOrder,
          'Order (0 = first)',
          keyboard: TextInputType.number,
        ),
        _ResultMessage(_error),
      ],
    );
  }
}

// ============================================================================
// Shared editor-sheet building blocks
// ============================================================================

/// Standard scrollable bottom sheet used by every editor, with a Save button
/// pinned at the bottom and keyboard-aware padding.
class _EditorSheetShell extends StatelessWidget {
  const _EditorSheetShell({
    required this.title,
    required this.onSave,
    required this.children,
  });

  final String title;
  final VoidCallback onSave;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.warmWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.mutedInk.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.check),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _sheetField(
  TextEditingController controller,
  String label, {
  String? hint,
  int lines = 1,
  TextInputType? keyboard,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: keyboard,
      inputFormatters: keyboard == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
}

/// Inline edit + delete buttons used by the list cards.
class _EditDeleteRow extends StatelessWidget {
  const _EditDeleteRow({
    required this.onEdit,
    required this.onDelete,
    this.compact = false,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, color: AppColors.deepInk),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Edit'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
          ),
        ),
      ],
    );
  }
}

/// A thumbnail + "pick photo" button used in the family editor.
class _PhotoPickerRow extends StatelessWidget {
  const _PhotoPickerRow({
    required this.imageUrl,
    required this.uploading,
    required this.onPick,
  });

  final String imageUrl;
  final bool uploading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final resolved = imageUrl.isEmpty ? '' : AppConfig.resolveMedia(imageUrl);
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: resolved.isEmpty
              ? Container(
                  width: 56,
                  height: 56,
                  color: AppColors.paperBlueDark,
                  child: const Icon(Icons.person, color: AppColors.mutedInk),
                )
              : MediaImage(source: resolved, width: 56, height: 56),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: uploading ? null : onPick,
            icon: uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload),
            label: Text(
              uploading
                  ? 'Uploading...'
                  : (imageUrl.isEmpty ? 'Pick photo' : 'Change photo'),
            ),
          ),
        ),
      ],
    );
  }
}
