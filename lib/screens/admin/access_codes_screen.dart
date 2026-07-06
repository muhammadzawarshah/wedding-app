import 'package:flutter/material.dart';

import '../../models/wedding_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_components.dart';
import '../../widgets/passport_background.dart';

/// Couple-only screen to create and manage the 4-digit logins stored in the
/// backend database. Mirrors the website's "Logins" admin panel.
class AccessCodesScreen extends StatefulWidget {
  const AccessCodesScreen({super.key});

  @override
  State<AccessCodesScreen> createState() => _AccessCodesScreenState();
}

/// The login "types" offered in the create form, mapped to role + attending.
enum _LoginType { attendingGuest, nonAttendingGuest, organizer }

extension _LoginTypeX on _LoginType {
  String get label => switch (this) {
    _LoginType.attendingGuest => 'Attending guest',
    _LoginType.nonAttendingGuest => 'Non-attending guest',
    _LoginType.organizer => 'Organiser',
  };

  UserRole get role => switch (this) {
    _LoginType.attendingGuest => UserRole.guest,
    _LoginType.nonAttendingGuest => UserRole.guest,
    _LoginType.organizer => UserRole.organizer,
  };

  bool get attending => this != _LoginType.nonAttendingGuest;
}

class _AccessCodesScreenState extends State<AccessCodesScreen> {
  final _labelController = TextEditingController();
  final _codeController = TextEditingController();
  _LoginType _type = _LoginType.attendingGuest;

  late Future<List<AccessCode>?> _future;
  bool _busy = false;
  String? _message;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.fetchAccessCodes();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = ApiService.instance.fetchAccessCodes());
  }

  void _finish(String message, {bool ok = false}) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
      _ok = ok;
    });
  }

  Future<void> _create() async {
    if (_busy) return;
    final label = _labelController.text.trim();
    final code = _codeController.text.trim();
    if (label.isEmpty) {
      _finish('Please enter a name or label.');
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      _finish('The code must be exactly 4 digits.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    final error = await ApiService.instance.createAccessCode(
      label: label,
      code: code,
      role: _type.role,
      attending: _type.attending,
    );
    if (!mounted) return;
    if (error == null) {
      _labelController.clear();
      _codeController.clear();
      _finish('Login created ✓', ok: true);
      _reload();
    } else {
      _finish(error);
    }
  }

  Future<void> _toggleActive(AccessCode code) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await ApiService.instance.updateAccessCode(code.id, {
      'active': !code.active,
    });
    if (!mounted) return;
    _finish(ok ? 'Updated ✓' : 'The login could not be updated.', ok: ok);
    if (ok) _reload();
  }

  Future<void> _delete(AccessCode code) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete login?'),
        content: Text(
          '${code.label} (${code.code}) will be permanently deleted.',
        ),
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
    final ok = await ApiService.instance.deleteAccessCode(code.id);
    if (!mounted) return;
    _finish(ok ? 'Login deleted ✓' : 'The login could not be deleted.', ok: ok);
    if (ok) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: AppScaffold(
        title: 'Logins',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(
              title: 'Create & manage logins',
              subtitle:
                  'Guest codes can be attending or non-attending. Only attending guests can use the Upload Memories form.',
            ),
            const SizedBox(height: 12),
            _createCard(),
            const SizedBox(height: 16),
            _listCard(),
          ],
        ),
      ),
    );
  }

  Widget _createCard() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Name / label',
              hintText: 'e.g. Sharma Family',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(
              labelText: '4-digit code',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<_LoginType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              for (final type in _LoginType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _type = value);
            },
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _busy ? null : _create,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.key),
            label: Text(_busy ? 'Working...' : 'Create login'),
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
    return FutureBuilder<List<AccessCode>?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final codes = snapshot.data;
        if (codes == null) {
          return const SectionCard(
            child: Text(
              'Could not reach the server, or admin login is required.',
            ),
          );
        }
        if (codes.isEmpty) {
          return const SectionCard(child: Text('No logins yet.'));
        }
        return Column(
          children: [
            for (final code in codes)
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
                              '${code.label} · ${code.code}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              code.active
                                  ? code.typeLabel
                                  : '${code.typeLabel} · disabled',
                              style: TextStyle(
                                color: code.active ? null : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: code.active ? 'Disable' : 'Enable',
                        onPressed: _busy ? null : () => _toggleActive(code),
                        icon: Icon(
                          code.active
                              ? Icons.toggle_on
                              : Icons.toggle_off_outlined,
                          color: code.active ? AppColors.success : null,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: _busy ? null : () => _delete(code),
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
