import 'package:flutter/material.dart';

import '../../models/wedding_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_components.dart';
import '../../widgets/passport_background.dart';

/// Admin screen to write free-form knowledge notes for the AI assistant.
/// When a guest's question isn't covered by the live wedding data or FAQs, the
/// chatbot also reads these notes before forwarding the question to a human.
class AiNotesScreen extends StatefulWidget {
  const AiNotesScreen({required this.admin, super.key});

  final AdminUser admin;

  @override
  State<AiNotesScreen> createState() => _AiNotesScreenState();
}

class _AiNotesScreenState extends State<AiNotesScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  late Future<List<AiNote>?> _future;
  bool _busy = false;
  String? _message;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.fetchNotes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = ApiService.instance.fetchNotes());
  }

  void _finish(String message, {bool ok = false}) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
      _ok = ok;
    });
  }

  Future<void> _add() async {
    if (_busy) return;
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _finish('Please enter note content.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final ok = await ApiService.instance.createNote(
      title: _titleController.text.trim(),
      content: content,
      createdBy: widget.admin.name,
    );
    if (!mounted) return;
    if (ok) {
      _titleController.clear();
      _contentController.clear();
      _finish('Note saved ✓', ok: true);
      _reload();
    } else {
      _finish(
        'The note could not be saved. Please check the server and admin login.',
      );
    }
  }

  Future<void> _toggle(AiNote note) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await ApiService.instance.updateNote(note.id, {
      'active': !note.active,
    });
    if (!mounted) return;
    _finish(ok ? 'Updated ✓' : 'The note could not be updated.', ok: ok);
    if (ok) _reload();
  }

  Future<void> _delete(AiNote note) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This note will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    final ok = await ApiService.instance.deleteNote(note.id);
    if (!mounted) return;
    _finish(ok ? 'Note deleted ✓' : 'The note could not be deleted.', ok: ok);
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(
        title: 'AI Notes',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'AI knowledge notes',
              subtitle:
                  'Add extra information the AI can share with guests when the app data and FAQs do not cover a question.',
            ),
            const SizedBox(height: 12),
            _addCard(),
            const SizedBox(height: 16),
            _listCard(),
          ],
        ),
      ),
    );
  }

  Widget _addCard() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title (optional)',
              hintText: 'e.g. Transport',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Note for the AI',
              hintText: 'e.g. Bus leaves Riga at 9am on 17 July.',
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _busy ? null : _add,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.note_add),
            label: Text(_busy ? 'Working...' : 'Add note'),
          ),
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(
              _message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ok ? AppColors.success : AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _listCard() {
    return FutureBuilder<List<AiNote>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final notes = snapshot.data;
        if (notes == null) {
          return const SectionCard(
            child: Text(
              'Could not reach the server, or admin login is required.',
            ),
          );
        }
        if (notes.isEmpty) {
          return const SectionCard(child: Text('No notes yet.'));
        }
        return Column(
          children: [
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SectionCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.title.isEmpty ? 'Note' : note.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(note.content),
                            if (!note.active) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'disabled',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: note.active ? 'Disable' : 'Enable',
                        onPressed: _busy ? null : () => _toggle(note),
                        icon: Icon(
                          note.active
                              ? Icons.toggle_on
                              : Icons.toggle_off_outlined,
                          color: note.active ? AppColors.success : null,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: _busy ? null : () => _delete(note),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
